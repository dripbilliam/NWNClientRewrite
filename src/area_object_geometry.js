import { NativeAreaCollisionStore } from './area_collision_store.js';
import { noNonWalkPolysDetailed, queryDoorPolygons, handleTransparentDoor } from './area_collision.js';
import { nativePlacementOrientation, doorMeshBoundingBox, noDoorPolygons } from './object_surface_mesh.js';
import { intEntry } from './combat_stats.js';
import {doorTileCoordinates} from './sound_path.js';

const f = Math.fround;
const restingAnimations = [22, 50, 51, 72];
const stateGlobals = Object.freeze({ 22: 0, 50: 1, 51: 2 }); // verified target image globals dc9be4/dc9bdc/dc9be0
const signature = object => JSON.stringify([object.id, object.areaId, object.position, object.bearing, object.authored?.Appearance,
  object.authored?.GenericType_New, object.authored?.GenericType]);

// Resolver-scoped initial area collision build using canonical registry objects.
// Dynamic insertion/position/orientation lifecycle must be mapped before allowing
// mutations through this query; fail explicitly instead of reusing stale meshes.
export class NativeAreaObjectGeometry {
  constructor(area, resources, registry) {
    this.area = area; this.resources = resources; this.registry = registry;
    this.store = null; this.loading = null; this.snapshots = new Map(); this.descriptors = new Map();
  }
  report(error, object, operation) {
    this.resources.report(error, { area: this.area.resRef, areaId: this.area.id, objectId: object?.id, sourceKey: object?.sourceKey, operation });
  }
  load() {
    return this.loading ??= (async () => {
      const store = new NativeAreaCollisionStore(), snapshots = new Map(), descriptors = new Map();
      for (const id of this.area.objects) {
        const object = this.registry.get(id);
        if (!object) throw new Error('Native area collision object is absent from its canonical registry');
        if (![9, 10].includes(object.objectType)) continue;
        try {
          object.nativeOrientation = nativePlacementOrientation(object.bearing ?? 0);
          object.nativePosition = [object.position[0], -object.position[2], object.position[1]].map(f);
          if (object.objectType === 9) {
            object.nativeCollisionSlot = -1;
            let loaded;
            try { loaded = await this.resources.placeableMesh((object.authored.Appearance ?? 0) & 65535); }
            catch (error) {
              // GetWalkMesh caches the newly constructed mesh even when a PWK
              // cannot be demanded. Constructor counts/pointers stay zero, and
              // AddToArea tests vertexCount>0 before AddStaticObject. Only a
              // known lookup failure takes this path; parse/read failures stop.
              if (error.code !== 'RESOURCE_NOT_FOUND' || error.resourceType !== 2053) throw error;
              this.report(error, object, 'native-placeable-pwk-missing-empty-mesh');
            }
            if (loaded?.mesh.vertices.length) object.nativeCollisionSlot = store.add(object.id, object.nativeOrientation,
              object.nativePosition, loaded.mesh.vertices, loaded.mesh.faces);
          } else {
            const descriptor = await this.resources.doorDescriptor(object.authored);
            object.nativeDoorSurface = await this.resources.objectMesh(descriptor.model, 'door');
            const result = doorMeshBoundingBox(object.nativeDoorSurface, object.nativePosition, [...object.nativeOrientation]);
            if (result.status !== 0) store.addDoorBounds(object.id, ...result.bounds);
            descriptors.set(object.id, descriptor);
          }
          snapshots.set(object.id, signature(object));
        } catch (error) { this.report(error, object, 'native-area-object-collision-load'); throw error; }
      }
      this.store = store; this.snapshots = snapshots; this.descriptors = descriptors; return store;
    })();
  }
  providers() {
    const providers = { object: id => this.registry.get(id) ?? null,
      doorOpenState: door => this.descriptors.get(door.id)?.visibleModel === 0 ? 3 : door.animationState,
      doorSurface: (door, ...args) => {
        const state = this.descriptors.get(door.id)?.visibleModel === 0 ? 3 : door.animationState;
        if (!Number.isInteger(state) || state < 0 || state > 3) throw new Error('Native resting door state is unavailable');
        door.nativeAnimation = restingAnimations[state];
        return noDoorPolygons(door, ...args, stateGlobals);
      },
      doorBlockSight: door => {
        const descriptor = this.descriptors.get(door.id);
        if (!descriptor) throw new Error('Native active door table is unavailable');
        const result = intEntry(descriptor.table, descriptor.index, 'BlockSight');
        if (!result.found) this.report(new Error('Native door BlockSight lookup returned its table fallback'), door, 'native-door-blocksight-lookup');
        return result.value;
      } };
    providers.doorPolygons = (...args) => queryDoorPolygons(...args, providers);
    providers.transparentDoor = (...args) => handleTransparentDoor(...args, providers);
    return providers;
  }
  async soundDoors(tile){
    await this.load();
    const result=[];
    for(const id of this.area.objects){
      const door=this.registry.get(id);if(door?.objectType!==10)continue;
      if(this.snapshots.get(id)!==signature(door))throw new Error('Native sound door insertion/position/orientation lifecycle is unavailable');
      if(!doorTileCoordinates(door.nativePosition.slice(0,2),this.area.width,this.area.height).some(([x,y])=>x===tile.x&&y===tile.y))continue;
      const descriptor=this.descriptors.get(id),block=intEntry(descriptor.table,descriptor.index,'BlockSight');
      // GetINTEntry writes its native fallback to the caller even on failure.
      if(descriptor.visibleModel===0&&!block.found)this.report(new Error('Native sound door BlockSight lookup returned its table fallback'),door,'native-sound-door-blocksight');
      result.push({id,visibleModel:descriptor.visibleModel,blockSight:block.value,openState:this.providers().doorOpenState(door),
        position:door.nativePosition.slice(0,2),orientation:door.nativeOrientation});
    }
    return result;
  }
  async query(...args) {
    try {
      const store = await this.load(), ids = new Set();
      for (const id of this.area.objects) {
        const object = this.registry.get(id);
        if (!object) throw new Error('Native collision object removal lifecycle is not implemented');
        if (![9, 10].includes(object.objectType)) continue;
        ids.add(id);
        if (this.snapshots.get(id) !== signature(object)) throw new Error('Native collision insertion/position/orientation update lifecycle is not implemented');
      }
      if (ids.size !== this.snapshots.size) throw new Error('Native collision area membership update lifecycle is not implemented');
      return noNonWalkPolysDetailed(store, ...args, this.providers());
    } catch (error) { this.report(error, null, 'native-area-object-collision-query'); throw error; }
  }
}
