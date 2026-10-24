import {NativeAreaGeometry,NativeGeometryResources} from './area_geometry.js';
import {NativeAreaCollisionStore} from './area_collision_store.js';
import {noNonWalkPolysDetailed} from './area_collision.js';
import {nativePlacementOrientation,noDoorPolygons,doorMeshBoundingBox} from './object_surface_mesh.js';
import {resolveDoorModel} from './area.js';
import {clientDriveLine,clientDriveEdge,clientCreatureLine} from './client_drive_collision.js';
import {nativeFloatEntry} from './movement_rate.js';
import {resourceFlow} from './resource_flow.js';
const f=Math.fround,invalid=0x7f000000;
// Resolver/area-owned geometry projection. Native polygon readers and query
// code operate on private collision objects, never NetworkWorld proxies.
export class NetworkDriveGeometry{
 constructor(scene){
  this.scene=scene;this.resources=new NativeGeometryResources(scene.resolver,(error,data)=>scene.report('network.drive-geometry-unavailable',error.message,data),{actionPoints:false});
  const a=scene.area;this.area={id:a.id,resRef:a.resRef,width:a.width,height:a.height,tilesetResRef:a.tileset,tilePlacements:a.tiles.map(t=>({Tile_ID:t.fields['14'],Tile_Height:t.fields['18'],Tile_Orientation:t.fields['24']}))};this.geometry=new NativeAreaGeometry(this.area,this.resources);this.cacheKey=null;
 }
 obstacles(){return resourceFlow(this.obstacleResources());}
 *obstacleResources(){
  const s=this.scene,objects=[...s.world.registry.objects.values()].filter(o=>!o.replicationRemoved&&o.areaId===s.area.id&&[9,10].includes(o.objectType));
  // Only physical inputs can invalidate this scene-owned projection. HP,
  // effects, inventory and other replicated state do not change PWK/DWK
  // polygons. Snapshot before yielding so a tick cannot mix old and new poses.
  const inputs=objects.map(o=>{
   const state=o.replicated??{},fixed=o.staticState??o.lightState??{},position=state.position??fixed.position;if(!position)return null;
   const raw=state.orientation??fixed.orientation,vector=Array.isArray(raw)?raw:raw?.vector,bearing=vector?Math.atan2(vector[1],vector[0]):f((raw?.yaw??0)*Math.PI/180),orientation=nativePlacementOrientation(bearing);
   return{type:o.objectType,id:o.id,position:position.slice(),orientation,...(o.objectType===9?{appearance:state.appearance??fixed.appearance}:{doorType:state.doorType,genericType:state.genericType,doorOpenState:state.doorOpenState??0})};
  });
  const signature=JSON.stringify(inputs);if(signature===this.cacheKey)return this.cache;
  const records=yield Promise.all(inputs.map(async o=>{
   if(!o)return null;
   if(o.type===9){try{return{...o,mesh:(await this.resources.placeableMesh(o.appearance)).mesh};}catch(e){if(e.code==='RESOURCE_NOT_FOUND')return null;throw e;}}
   const descriptor=resolveDoorModel(o.doorType,o.genericType,s.tables.genericdoors,s.tables.doortypes);if(descriptor?.visible===false)return null;if(!descriptor?.model)throw Error('Native drive door model unavailable');
   const mesh=await this.resources.objectMesh(descriptor.model,'door');return{type:10,id:o.id,nativePosition:o.position,nativeOrientation:o.orientation,nativeDoorSurface:mesh,nativeAnimation:[22,50,51,72][o.doorOpenState]};
  }));
  const store=new NativeAreaCollisionStore(),doors=new Map();
  for(const r of records){if(!r)continue;if(r.type===9){if(r.mesh.vertices.length)store.add(r.id,r.orientation,r.position,r.mesh.vertices,r.mesh.faces);}else{const box=doorMeshBoundingBox(r.nativeDoorSurface,r.nativePosition,[...r.nativeOrientation]);if(box.status){store.addDoorBounds(r.id,...box.bounds);doors.set(r.id,r);}}}
  const result={store,doors,inputs};this.cacheKey=signature;this.cache=result;return result;
 }
 query(actor,options={}){return resourceFlow(this.queryResources(actor,options));}
 *queryResources(actor,{capture=null,acknowledgement=false}={}){
  //8001f0 repairs server paths with1/64 radius/height and no creatures;
  //7fdeb0 local driving instead uses the actor's appearance dimensions.
  const s=this.scene,a=actor.appearance?.appearance,read=name=>nativeFloatEntry(s.tables.appearance,a,name).value,radius=acknowledgement?1/64:read('PERSPACE'),height=acknowledgement?1/64:read('HEIGHT'),{store,doors,inputs}=yield this.obstacles();
  const objects=new Map();for(const o of acknowledgement?[]:s.world.registry.objects.values()){
   if(o.replicationRemoved||o.areaId!==s.area.id)continue;
   const position=s.motion?.objects.get(o.id)?.render??o.replicated?.position??o.staticState?.position??o.lightState?.position;if(!position)continue;
   objects.set(o.id,{id:o.id,objectType:o.objectType,position:position.slice(),radius:o.objectType===5?nativeFloatEntry(s.tables.appearance,o.appearance?.appearance,'PERSPACE').value:0});
  }
  // A later asynchronous input tick must not replace this query's IDs while
  // its pose map still belongs to the old tick. Carry the iterator position
  // forward, but keep membership/iteration private to each captured query.
  const membership={ids:[...objects.keys()],cursor:this.creatureMembership?.cursor??-1};if(!acknowledgement)this.creatureMembership=membership;
  const geometry=this.geometry.providers({cached:true}),providers={...geometry,
   noNonWalkWorld:(start,end,low,high,space)=>noNonWalkPolysDetailed(store,start,end,low,high,space,invalid,{id:invalid},0,null,0,{doorPolygons:(id,start,end,low,high,radius)=>{const door=doors.get(id);return door?noDoorPolygons(door,start,end,low,high,radius,{22:0,50:1,51:2},0):1;}}),
   noCreatures:(start,end,id,space)=>clientCreatureLine(membership,start,end,space,id,{object:oid=>objects.get(oid),radius:o=>o.radius,
    // Normal player state is available here. Native3b0/110/114 and client630
    // DM/control bypass storage need their own verified replication adapter.
    owner:()=>actor}),
   extensionWalkable:(start,end)=>clientDriveEdge(this.area,start,end,geometry)};
  // One native input tick can test dozens of slide candidates. Reuse its
  // private collision projection instead of rebuilding it for every line.
  const trace=capture?{actorId:actor.id,radius,height,cursor:membership.cursor,objects:structuredClone([...objects.values()]),obstacles:structuredClone(inputs??[]),queries:[]}:null;if(trace)capture(trace);
  const area=this.area;return(from,to)=>resourceFlow((function*(){const result=(yield clientDriveLine(area,from,to,radius,height,actor.id,acknowledgement?0:1,providers))===1;if(trace)trace.queries.push({from:from.slice(),to:to.slice(),clear:result});return result;})());
 }
 async clear(from,to,actor){return(await this.query(actor))(from,to);}
}
