import { NativeAreaCollisionStore } from './area_collision_store.js';
import { noNonWalkPolysDetailed, queryDoorPolygons, handleTransparentDoor } from './area_collision.js';
import { nativePlacementOrientation, doorMeshBoundingBox, noDoorPolygons } from './object_surface_mesh.js';
import { intEntry } from './combat_stats.js';
import {doorTileCoordinates} from './sound_path.js';
import {nearestDoorActionPoint} from './door_action_point.js';
import {computePlaceableActionPoints,nearestPlaceableActionPoint} from './placeable_action_point.js';

const f = Math.fround;
const restingAnimations = [22, 50, 51, 72];
const stateGlobals = Object.freeze({ 22: 0, 50: 1, 51: 2 }); // verified target image globals dc9be4/dc9bdc/dc9be0
const signature = object => JSON.stringify([object.id, object.areaId, object.position, object.bearing, object.orientation, object.nativePosition, object.nativeOrientation, object.nativeMessageFields?.[0x32c], object.authored?.Appearance,
  object.authored?.GenericType_New, object.authored?.GenericType]);

// Resolver-scoped collision arrays using canonical registry objects. Explicit
// placeable insert/remove/replace operations preserve native slot/hole storage;
// unannounced mutations still fail before a stale query can be returned.
export class NativeAreaObjectGeometry {
  constructor(area, resources, registry) {
    this.area = area; this.resources = resources; this.registry = registry;
    this.store = null; this.loading = null; this.snapshots = new Map(); this.descriptors = new Map();
  }
  report(error, object, operation) {
    this.resources.report(error, { area: this.area.resRef, areaId: this.area.id, objectId: object?.id, sourceKey: object?.sourceKey, operation });
  }
  async placeableMesh(object){
    try{return (await this.resources.placeableMesh((object.nativeMessageFields?.[0x32c]??object.authored.Appearance??0)&65535))?.mesh??null;}
    catch(error){
      // A known absent PWK leaves the native cached mesh's counts at zero.
      // Active-rule lookup errors and corrupt/read failures are not empty meshes.
      if(error.code!=='RESOURCE_NOT_FOUND'||error.resourceType!==2053)throw error;
      this.report(error,object,'native-placeable-pwk-missing-empty-mesh');return null;
    }
  }
  checkPlaceable(object){
    if(object?.objectType!==9||this.registry.get(object.id)!==object)throw new Error('Native placeable collision operation requires its canonical object');
  }
  computePlaceablePoints(object,mesh){
    return computePlaceableActionPoints(object,{area:o=>o.areaId===this.area.id?this.area:null,walkMesh:()=>mesh,
      position:o=>o.nativePosition,orientation:o=>o.nativeOrientation,
      height:(area,point)=>{if(!area.nativeGeometry)throw new Error('Native placeable action-point terrain geometry is unavailable');return area.nativeGeometry.height(point);},
    });
  }
  async nearestPlaceablePoint(object,from){
    try{
      await this.load();this.checkPlaceable(object);
      if(this.snapshots.get(object.id)!==signature(object))throw new Error('Native placeable action-point area lifecycle is unavailable');
      return nearestPlaceableActionPoint(object,from,{position:o=>o.nativePosition});
    }catch(error){this.report(error,object,'native-placeable-nearest-action-point');throw error;}
  }
  async insertPlaceable(object,preparedMesh=undefined){
    try{
    this.checkPlaceable(object);const store=await this.load();
    if(this.snapshots.has(object.id))throw new Error('Native placeable collision insertion requires prior removal');
    if(object.areaId!==this.area.id)throw new Error('Native placeable collision destination area is inconsistent');
    const mesh=preparedMesh===undefined?await this.placeableMesh(object):preparedMesh;
    if(mesh?.vertices.length)object.nativeCollisionSlot=store.add(object.id,object.nativeOrientation,object.nativePosition,mesh.vertices,mesh.faces);
    this.snapshots.set(object.id,signature(object));return object.nativeCollisionSlot;
    }catch(error){this.report(error,object,'native-area-object-collision-insert');throw error;}
  }
  async removePlaceable(object){
    try{
    this.checkPlaceable(object);const store=await this.load();
    if(object.nativeCollisionSlot>=0)store.remove(object.nativeCollisionSlot);
    // The owning RemoveFromArea clears slot50c after RemoveStaticObject.
    // Keeping that write here makes this complete geometry operation usable
    // for zero-count meshes as well as physical static slots.
    object.nativeCollisionSlot=-1;this.snapshots.delete(object.id);
    }catch(error){this.report(error,object,'native-area-object-collision-remove');throw error;}
  }
  preparePlaceableOrientation(object){
    this.checkPlaceable(object);const previous=this.snapshots.get(object.id);
    if(previous===undefined||previous!==signature(object))throw new Error('Native placeable orientation requires current collision state');return previous;
  }
  commitPlaceableOrientation(object,previous){
    this.checkPlaceable(object);const current=signature(object),stored=this.snapshots.get(object.id);
    if(stored!==previous&&stored!==current)throw new Error('Native placeable orientation collision state changed unexpectedly');
    // The native orientation owner deliberately keeps the existing polygons
    // and action points when its dot-product guard skips replacement.
    this.snapshots.set(object.id,current);
  }
  async replacePlaceable(object,preparedMesh=undefined){
    try{
    this.checkPlaceable(object);const store=await this.load(),mesh=preparedMesh===undefined?await this.placeableMesh(object):preparedMesh;
    if(!this.snapshots.has(object.id)||object.areaId!==this.area.id)throw new Error('Native placeable collision replacement requires current area membership');
    if(mesh)store.replace(object.nativeCollisionSlot,object.id,object.nativeOrientation,object.nativePosition,mesh.vertices,mesh.faces);
    this.snapshots.set(object.id,signature(object));
    }catch(error){this.report(error,object,'native-area-object-collision-replace');throw error;}
  }
  load() {
    return this.loading ??= (async () => {
      const store = new NativeAreaCollisionStore(), snapshots = new Map(), descriptors = new Map();
      for (const id of this.area.objects) {
        const object = this.registry.get(id);
        if (!object) throw new Error('Native area collision object is absent from its canonical registry');
        if (![9, 10].includes(object.objectType)) continue;
        try {
          object.nativeOrientation ??= nativePlacementOrientation(object.bearing ?? 0);
          object.orientation=[object.nativeOrientation[0],object.nativeOrientation[2],f(-object.nativeOrientation[1])];
          object.nativePosition = [object.position[0], -object.position[2], object.position[1]].map(f);
          if (object.objectType === 9) {
            object.nativeCollisionSlot = -1;
            const mesh=await this.placeableMesh(object);
            if (mesh?.vertices.length) object.nativeCollisionSlot = store.add(object.id, object.nativeOrientation,
              object.nativePosition, mesh.vertices, mesh.faces);
            await this.computePlaceablePoints(object,mesh);
          } else {
            const descriptor = await this.resources.doorDescriptor(object.authored);
            object.nativeDoorField498=descriptor.visibleModel;
            object.nativeDoorSurface = await this.resources.objectMesh(descriptor.model, 'door');
            const result = doorMeshBoundingBox(object.nativeDoorSurface, object.nativePosition, [...object.nativeOrientation]);
            if (result.status !== 0){object.nativeDoorBounds4c8=result.bounds.map(v=>[...v]);store.addDoorBounds(object.id, ...result.bounds);}
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
  async automapDoorIds(tile){
    await this.load();const ids=[];let count=0;
    for(const id of this.area.objects){
      const door=this.registry.get(id);if(door?.objectType!==10)continue;
      count++;
      if(this.snapshots.get(id)!==signature(door))throw new Error('Native automap door insertion/position/orientation lifecycle is unavailable');
      if(doorTileCoordinates(door.nativePosition.slice(0,2),this.area.width,this.area.height).some(([x,y])=>x===tile.x&&y===tile.y))ids.push(id);
    }
    if(count!==this.descriptors.size)throw new Error('Native automap door removal lifecycle is unavailable');
    return ids;
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
  async nearestActionPoint(door,from,forceClosed){
    await this.load();
    if(this.snapshots.get(door.id)!==signature(door))throw new Error('Native door action-point insertion/position/orientation lifecycle is unavailable');
    return nearestDoorActionPoint(door,from,forceClosed,{area:o=>this.registry.get(o.areaId)??null,
      animation:o=>o.nativeAnimationD8,walkable:(area,point)=>area.nativeGeometry.positionWalkable(point)});
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
