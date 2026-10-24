import {NetworkDriveGeometry} from '../../src/network_drive_geometry.js';
import {drivePreviewPlan,drivePreviewPath,blockedDrivePreviewAnimation} from '../../src/network_drive_preview.js';
import {acceptClientPath} from '../../src/network_path_acceptance.js';
import {nativeFloatEntry} from '../../src/movement_rate.js';

export function movementSnapshot(p,ids=null){
 if(!p?.motion)return{version:1,objects:[],ground:[]};
 const objects=[];
 for(const [id,state] of p.motion.objects){
  const o=p.world.registry.get(id);if(!o||o.replicationRemoved||o.areaId!==p.area.id||ids&&!ids.has(id))continue;
  const appearance=o.appearance?.appearance;
  objects.push({id,state:{...structuredClone(state),walkDistance:nativeFloatEntry(p.tables.appearance,appearance,'WALKDIST').value,runDistance:nativeFloatEntry(p.tables.appearance,appearance,'RUNDIST').value,modelType:p.objects.get(id)?.bodyType??state.modelType??1}});
 }
 return{version:1,objects,...(ids?{}:{ground:(p.groundTriangles??[]).map(t=>t.vertices)})};
}

// Reuse exact WOK/PWK/DWK and creature checks. A private query projection uses
// the native renderer's displayed positions, without writing source proxies or
// running a Three frame/animation loop.
export function createDriveStaging({presentation,frontend,geometry=p=>new NetworkDriveGeometry(p)}){
 const cache=new WeakMap();
 function context(request){
  const p=presentation(),world=frontend.world,actor=world?.registry.get(request.actorId);
  if(!p||p.closed||p.area.id!==request.areaId||world.areaId!==request.areaId||frontend.areaGeneration!==request.generation||!actor||actor.replicationRemoved||actor.areaId!==request.areaId)return null;
  const appearance=JSON.stringify(actor.appearance),current=()=>presentation()===p&&!p.closed&&frontend.world===world&&world.areaId===request.areaId&&frontend.areaGeneration===request.generation&&world.registry.get(actor.id)===actor&&!actor.replicationRemoved&&JSON.stringify(actor.appearance)===appearance;
  let base=cache.get(p);if(!base){base=geometry(p);cache.set(p,base);}
  return{p,world,actor,base,current};
 }
 async function preview(request){
  const c=context(request);if(!c||c.actor.id!==c.world.localObjectId||blockedDrivePreviewAnimation(c.actor.replicated?.animation)||(c.actor.replicated?.field8D4!==undefined&&(c.actor.replicated.field8D4&2)===0))return null;
  const plan=drivePreviewPlan({position:request.position,orientation:request.orientation,walkRate:c.actor.replicated.walkRate,runRate:c.actor.replicated.runRate},request.flags);
  await c.base.obstacles();if(!c.current())return null;
  const displayed=new Map();
  for(const o of c.world.registry.objects.values()){const position=o.replicated?.position??o.staticState?.position??o.lightState?.position;if(position)displayed.set(o.id,{render:position.slice()});}
  for(const row of request.poses??[])if(displayed.has(row.id))displayed.set(row.id,{render:row.position.slice()});
  displayed.set(c.actor.id,{render:request.render.slice()});
  const fork=Object.create(c.base);fork.scene=Object.create(c.p);fork.scene.motion={objects:displayed};
  const clear=await fork.query(c.actor),path=await drivePreviewPath(request.position,plan.target,clear,{render:request.render});
  if(!c.current())return null;
  return{plan,...(path?{path}:{path:null})};
 }
 async function admit(request){
  const c=context(request);if(!c)return null;
  const clear=await c.base.query(c.actor,{acknowledgement:true});if(!c.current())return null;
  const result=await acceptClientPath({...request.state,area:true},request.path,request.serverPosition,clear,async point=>[point[0],point[1],c.p.motion.height(point,point[2])]);
  return c.current()?result:null;
 }
 return{preview,admit};
}
