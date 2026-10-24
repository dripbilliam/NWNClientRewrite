import {clientPathAnimation} from './network_motion.js';
const f=Math.fround,copy=point=>point.map(f),same=(a,b)=>a.length===b.length&&a.every((v,i)=>v===b[i]);

// Client8001f0: received waypoints are repaired for connectivity from the
// displayed pose, not routed anew. Virtual+230 is800da0 (last old waypoint).
export async function acceptClientPath(state,path,serverPosition,clear,project){
 if(!state.area||!path.length||state.script&&state.sequence&&state.sequence!==state.lastSequence)return null;
 path=path.map(copy);const render=copy(state.render),position=copy(serverPosition);
 if(await clear(render,path[0]))return{path};
 if(await clear(render,position))return{path:[position,...path]};
 for(let i=1;i<path.length;i++)if(await clear(render,path[i]))return{path:path.slice(i)};
 const previous=state.path.map(copy);
 if(previous.length&&await clear(previous.at(-1),path.at(-1)))return{path:[...previous.slice(state.cursor),path.at(-1)]};
 return{path,reset:position,projected:await project(path[0])};
}

// Native collision admission is synchronous. Our resource reads can yield;
// keep only the current actor's newest path and retry a changed pose on the
// next frame. This queue never holds the canonical packet-import queue.
export class NetworkPathAcceptance{
 constructor(scene){this.scene=scene;this.pending=new Map();this.running=new Map();}
 current(request){const s=this.scene,m=request.motion,o=request.object;return !s.closed&&this.pending.get(o.id)===request&&s.world.registry.get(o.id)===o&&!o.replicationRemoved&&o.areaId===s.area.id&&s.motion.objects.get(o.id)===m&&clientPathAnimation(m.animation)&&!(m.script&&request.changes.actionFlag&&request.changes.actionFlag!==m.driveSequence);}
 observe(object,changes,created=false){
  const s=this.scene,defer=Boolean(changes.path?.length),prior=s.motion.ensure(object);
  const stale=!created&&prior?.script&&prior.driveSequence!==undefined&&changes.actionFlag&&changes.actionFlag!==prior.driveSequence;
  s.motion.observe(object,changes,created,{deferPath:defer});
  const m=s.motion.objects.get(object.id);
  if(!m)return;
  if(stale&&(changes.animation===undefined||changes.animation===0||changes.animation===1||clientPathAnimation(changes.animation)))return;
  if(!defer){if(changes.path!==undefined||changes.animation!==undefined&&!clientPathAnimation(changes.animation))this.pending.delete(object.id);return;}
  const request={object,motion:m,changes:structuredClone(changes),serverPosition:(changes.position??object.replicated.position).slice()};this.pending.set(object.id,request);
  if(!this.current(request)){this.pending.delete(object.id);return;}
  return this.start(object.id);
 }
 start(id){
  if(this.running.has(id))return this.running.get(id);
  if(this.scene.canAcceptPaths?.()===false)return Promise.resolve();
  const task=this.process(id).finally(()=>this.running.delete(id));this.running.set(id,task);return task;
 }
 async process(id){
  const s=this.scene;
  for(let attempt=0;attempt<3;attempt++){
   const request=this.pending.get(id);if(!request)return;
   if(!this.current(request)){this.pending.delete(id);return;}
   const m=request.motion,prior=m.path,cursor=m.cursor,position=m.position.slice(),render=m.render.slice(),script=m.script,sequence=m.driveSequence;
   let result;
   try{const clear=await s.acknowledgementGeometry().query(request.object,{acknowledgement:true});result=await acceptClientPath({area:true,render,path:prior,cursor,script,lastSequence:sequence,sequence:request.changes.actionFlag??0},request.changes.path,request.serverPosition,clear,async point=>[point[0],point[1],s.motion.height(point,point[2])]);}
   catch(error){if(this.pending.get(id)!==request)continue;this.pending.delete(id);if(!s.closed)s.report('network.path-admission-unavailable',error.message,{objectId:id});return;}
   if(!this.current(request))continue;
   if(m.path!==prior||m.cursor!==cursor||!same(m.position,position)||!same(m.render,render)||m.script!==script||m.driveSequence!==sequence)continue;
   this.pending.delete(id);if(!result)return;
   const active=m.active;s.motion.acceptPath(m,result,request.changes);if(!active&&m.active){const binding=s.objects.get(id);if(binding)binding.animation=null;}return;
  }
 }
 update(){for(const id of this.pending.keys())void this.start(id);}
 dispose(){this.pending.clear();}
}
