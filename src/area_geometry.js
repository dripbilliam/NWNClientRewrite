import { parse2da, parseTileset } from './area.js';
import { RESOURCE_TYPE, decodeResourceText } from './resource_archive.js';
import { parseTileSurfaceMesh, clippedAreaTileLine, noDeniedAreaTilePolygons, areaTileHeight } from './tile_surface_mesh.js';
import { testLineWalkable, testDirectLine } from './tile_line.js';
import { parseObjectSurfaceMesh } from './object_surface_mesh.js';
import { intEntry } from './combat_stats.js';
import { NativeAreaObjectGeometry } from './area_object_geometry.js';
import { tileLOSMaterials, clipAreaTileLOS, clearAreaTileLOS } from './tile_los.js';
import { clearAreaLOS } from './area_los.js';
import {tileNodeOrientation} from './tile_path_node.js';
import {plotSoundPath} from './sound_path.js';

const f = Math.fround;
// Shared resolver-scoped resource caches. Never key by a global model name:
// modules/haks/overrides may replace the same SET/WOK/2DA ResRef.
export class NativeGeometryResources {
  constructor(resolver, report, providers = {}) {
    this.resolver = resolver; this.report = report; this.providers = providers;
    this.models = new Map(); this.tilesets = new Map(); this.surfaces = null;
    this.objectModels = new Map(); this.placeables = null;
    this.doorTables = new Map();
    this.losMaterials = null;
  }
  surfaceTable() {
    return this.surfaces ??= this.resolver.getResource('surfacemat', RESOURCE_TYPE.TWO_DA)
      .then(bytes => parse2da(decodeResourceText(bytes)));
  }
  losMaterialMask() { return this.losMaterials ??= this.surfaceTable().then(tileLOSMaterials); }
  tileset(resRef) {
    if (!this.tilesets.has(resRef)) this.tilesets.set(resRef, this.resolver.getResource(resRef, RESOURCE_TYPE.SET)
      .then(bytes => {
        const text = decodeResourceText(bytes);
        if (!/^\s*Transition\s*=/im.test(text)) throw new Error('Native tileset Transition value is unavailable');
        const result = parseTileset(text); result.transition = f(result.transition); return result;
      }));
    return this.tilesets.get(resRef);
  }
  mesh(resRef) {
    if (!this.models.has(resRef)) this.models.set(resRef, (async () => {
      const table = await this.surfaceTable();
      return parseTileSurfaceMesh(await this.resolver.getResource(resRef, RESOURCE_TYPE.WOK), table, this.providers);
    })());
    return this.models.get(resRef);
  }
  objectMesh(resRef, kind) {
    const key = `${kind}:${resRef}`;
    if (!this.objectModels.has(key)) this.objectModels.set(key, this.resolver.getResource(resRef,
      kind === 'door' ? RESOURCE_TYPE.DWK : RESOURCE_TYPE.PWK).then(bytes => parseObjectSurfaceMesh(bytes, kind, this.providers)));
    return this.objectModels.get(key);
  }
  async placeableMesh(appearance) {
    // GetWalkMesh1402cd9b0 indexes the active physical placeables row array,
    // reading ModelName, then caches its PWK by appearance in the native manager.
    const table = await (this.placeables ??= this.resolver.getResource('placeables', RESOURCE_TYPE.TWO_DA)
      .then(bytes => parse2da(decodeResourceText(bytes))));
    const row = table.orderedRows[appearance];
    const model = row?.[table.columns.find(column => column.toLowerCase() === 'modelname')];
    if (!Number.isInteger(appearance) || appearance < 0 || !row || !model || model === '****')
      throw new Error('Native placeable appearance ModelName is unavailable');
    return { model: model.toLowerCase().slice(0, 16), mesh: await this.objectMesh(model.toLowerCase().slice(0, 16), 'placeable') };
  }
  async doorDescriptor(authored) {
    const appearance = (authored.Appearance ?? 0) >>> 0, genericType = (authored.GenericType_New ?? authored.GenericType ?? 0) >>> 0;
    const name = appearance === 0 ? 'genericdoors' : 'doortypes', index = appearance === 0 ? genericType : appearance;
    if (!this.doorTables.has(name)) this.doorTables.set(name, this.resolver.getResource(name, RESOURCE_TYPE.TWO_DA)
      .then(bytes => parse2da(decodeResourceText(bytes))));
    const table = await this.doorTables.get(name), row = table.orderedRows[index];
    const column = appearance === 0 ? 'modelname' : 'model';
    const model = row?.[table.columns.find(c => c.toLowerCase() === column)];
    if (!model || model === '****') throw new Error('Native door appearance model is unavailable');
    return { model: model.toLowerCase().slice(0, 16), table, index,
      visibleModel: appearance === 0 ? 1 : intEntry(table, index, 'VisibleModel').value };
  }
}

// LoadTileSetInfo 140362700: signed INT dimensions and placements,
// row-major tile locations, f32(height)*f32(SET Transition). Retain the
// authored placement separately; geometry loads lazily through the active
// module resolver and reports every unavailable/unsupported resource.
export class NativeAreaGeometry {
  constructor(area, resources, registry = null) {
    this.area = area; this.resources = resources; this.tiles = new Map();
    this.objects = registry && new NativeAreaObjectGeometry(area, resources, registry);
  }
  async tile(x, y) {
    const area = this.area;
    if (![area.width, area.height, x, y].every(Number.isInteger) || area.width <= 0 || area.height <= 0 || area.width * area.height > 65536)
      throw new Error('Native area dimensions are unavailable or invalid');
    if (x < 0 || y < 0 || x >= area.width || y >= area.height) return null;
    const index = y * area.width + x;
    if (!this.tiles.has(index)) this.tiles.set(index, (async () => {
      let model;
      try {
        if (!Array.isArray(area.tilePlacements) || area.tilePlacements.length < area.width * area.height)
          throw new Error('Native area Tile_List is unavailable or truncated');
        const placement = area.tilePlacements[index];
        const id = placement.Tile_ID ?? 0, orientation = placement.Tile_Orientation ?? 0, height = placement.Tile_Height ?? 0;
        if (![id, orientation, height].every(Number.isInteger)) throw new Error('Invalid native tile placement fields');
        const tileset = await this.resources.tileset(area.tilesetResRef);
        model = tileset.tiles[id]?.model;
        if (!model) throw new Error(`Native tileset has no model for tile ${id}`);
        if (orientation < 0 || orientation > 3) throw new Error('Native tile orientation is not implemented');
        const mesh = await this.resources.mesh(model);
        const fields=tileset.tiles[id].pathNodeFields;
        const atoi=value=>{const match=/^\s*([+-]?\d+)/.exec(value??'');return match?Number(match[1])|0:0;};
        const pathNodes={path:fields.PathNode?.charCodeAt(0)&255,pathOrientation:tileNodeOrientation(atoi(fields.Orientation)),
          visibility:fields.VisibilityNode?.charCodeAt(0)&255,visibilityOrientation:tileNodeOrientation(atoi(fields.VisibilityOrientation)),
          doorVisibility:fields.DoorVisibilityNode?.charCodeAt(0)&255,doorVisibilityOrientation:tileNodeOrientation(atoi(fields.DoorVisibilityOrientation)),doors:atoi(fields.Doors)&255};
        return { x, y, orientation, heightOffset: f(f(height | 0) * tileset.transition), mesh, model, tileId: id,pathNodes };
      } catch (error) {
        this.resources.report(error, { area: area.resRef, areaId: area.id, tileIndex: index, tileset: area.tilesetResRef, model,
          operation: 'native-area-tile-geometry' });
        throw error;
      }
    })());
    return this.tiles.get(index);
  }
  providers() {
    return { tile: (_area, x, y) => this.tile(x, y), clippedWalkable: (tile, from, to) => clippedAreaTileLine(tile, from, to,
      message => this.resources.report(new Error(message), { area: this.area.resRef, model: tile.model, operation: 'native-tile-triangle-walk' })),
    noNonWalkTile: (tile, from, to, low, high, radius, flag) => {
      try { return noDeniedAreaTilePolygons(tile, from, to, low, high, radius, flag); }
      catch (error) {
        this.resources.report(error, { area: this.area.resRef, areaId: this.area.id, model: tile.model, operation: 'native-tile-denied-polygons' });
        throw error;
      }
    } };
  }
  lineWalkable(from, to) { return testLineWalkable(this.area, from, to, this.providers()); }
  async soundPath(path){
    if(!this.objects)throw new Error('Native sound path door registry is unavailable');
    try{return await plotSoundPath(this.area,path,{tile:(x,y)=>this.tile(x,y),doors:tile=>this.objects.soundDoors(tile)});}
    catch(error){this.resources.report(error,{area:this.area.resRef,areaId:this.area.id,operation:'native-area-sound-path'});throw error;}
  }
  // ComputeHeight14036a210 scans the global32 ten-unit slots using
  // lower-inclusive/upper-exclusive bounds. Outside tiles return native -6.
  async height(point) {
    const [x,y]=point.map(f);
    if (![x,y].every(Number.isFinite)) throw new Error('Native area height point is unavailable');
    try { const tile=await this.tileAt([x,y]); return tile?areaTileHeight(tile,[x,y]):f(-6); }
    catch(error){this.resources.report(error,{area:this.area.resRef,areaId:this.area.id,operation:'native-area-height'});throw error;}
  }
  async tileAt(point){
    const [x,y]=point.map(f);
    if(![x,y].every(Number.isFinite))throw new Error('Native area GetTile point is unavailable');
    const slot=value=>{for(let i=0;i<32;i++)if(f(f(i)*10)<=value&&value<f(f(i+1)*10))return i;return -1;};
    const tileX=slot(x),tileY=slot(y);
    return tileX<0||tileY<0?null:this.tile(tileX,tileY);
  }
  async directLine(from, to, radius, height, flag, noCreatures) {
    try {
      if (!this.objects) throw new Error('Native direct-line object registry is unavailable');
      return await testDirectLine(this.area, from, to, radius, height, flag, {
        ...this.providers(),
        noNonWalkDetailed: (_area, ...args) => this.detailedPolygons(...args),
        noCreatures,
      });
    } catch (error) {
      this.resources.report(error, { area: this.area.resRef, areaId: this.area.id, operation: 'native-area-direct-line' });
      throw error;
    }
  }
  async detailedPolygons(from, to, low, high, radius, ignoredId, output, flag, excluded, transparent) {
    if (!this.objects) throw new Error('Native area collision registry is unavailable');
    return this.objects.query(from, to, low, high, radius, ignoredId, output, flag, excluded, transparent);
  }
  async lineOfSight(from, to, output, hit, sourceId, targetId, transparent) {
    try {
      if (!this.objects) throw new Error('Native area LOS object registry is unavailable');
      return await clearAreaLOS(this.area, from, to, output, hit, sourceId, targetId, transparent, {
        tile: (_area, x, y) => this.tile(x, y), clipTile: clipAreaTileLOS,
        clearTile: async (tile, direction, start, end, point) => clearAreaTileLOS(tile, direction, start, end, point, await this.resources.losMaterialMask()),
        object: id => this.objects.registry.get(id),
        door: id => { const object = this.objects.registry.get(id); return object?.objectType === 10 ? object : null; },
        detailed: (_area, ...args) => this.detailedPolygons(...args),
      });
    } catch (error) {
      this.resources.report(error, { area: this.area.resRef, areaId: this.area.id, sourceId, targetId, operation: 'native-area-line-of-sight' });
      throw error;
    }
  }
}
