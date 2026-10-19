import {createClientDummyState,createClientProjectileDummy,createClientVisualDummy,updateClientProjectileDummy} from './client_projectile_dummy.js';
import {setClientObjectFade,updateClientObjectFade} from './client_object_fade.js';
const render=v=>[v[0],v[2],-v[1]];

// Owned local model/scene adapter for the native dummy receiver and expiry.
// It never enters the authoritative registry or consumes its object-ID cursor.
export class ClientProjectileDummyPresentation{
 constructor({objects,playerId,now,difference,loadModel,destroyModel,scene,report}){
  Object.assign(this,{objects,playerId,now,difference,loadModel,destroyModel,scene,report});this.owned=new Set();this.ai=new Set();this.area={scene,objects:new Set()};this.events=[];this.disposed=false;this.stats={created:0,registered:0,destroyed:0,failed:0};
  this.fade={worldTime:now,difference,modelHandle:s=>s.model,
   // Local renderer scene modes are not the native client configuration/cache.
   mode:()=>2,controlledId:()=>playerId(),display:(s,offset)=>this.event({kind:'dummyDisplay',id:s.id,offset}),
   targetAlpha:()=>{throw new Error('Native dummy target-alpha context is unavailable');},alpha:()=>{throw new Error('Native dummy model-alpha adapter is unavailable');},handleScene:()=>{throw new Error('Native dummy fade-completion scene adapter is unavailable');},
   snapshotDifference:()=>{throw new Error('Native dummy fade snapshot-time provider is unavailable');}};
 }
 event(e){this.events.push(e);if(this.events.length>64)this.events.shift();}
 async createVisual(role,position,lifetime){
  if(this.disposed)return null;let allocated=null;
  try{
   const result=await createClientVisualDummy(role,position,lifetime,{
    construct:()=>{allocated=createClientDummyState();this.owned.add(allocated);this.stats.created++;return allocated;},
    loadModel:async(s,name)=>{try{const model=await this.loadModel(name);if(this.disposed||s.destroyed){this.destroyModel(model);return 0;}s.model=model;s.resourceName=name;return 1;}catch(error){this.report('visual.object-dummy-model-failed',error.message,{resource:name,role,stack:error.stack});return 0;}},
    currentArea:()=>this.disposed?null:this.area,
    register:s=>this.objects.array.addInternalObject(s),setId:(s,id)=>s.id=id,
    setArea:(s,area)=>{s.area=area;area.objects.add(s.id);},registerAI:s=>{this.ai.add(s);this.stats.registered++;},
    setScene:(s,area)=>area.scene.add(s.model.root),setPosition:(s,point)=>{s.position=point;s.model.root.position.set(...render(point));},
    setDelay:(s,...args)=>setClientObjectFade(s,...args,this.fade)
   });
   if(this.disposed||result.dummy?.destroyed)return null;
   if(result.aborted||!result.registered){if(result.dummy)this.destroy(result.dummy);this.stats.failed++;this.report(role==='source'&&result.aborted?'visual.object-dummy-source-native-abort':'visual.object-dummy-admission-failed','Native object-visual dummy did not enter the scene',{role,position,lifetime});return null;}
   this.event({kind:'visualDummyReady',role,id:result.dummy.id,position:result.dummy.position,duration:result.dummy.duration,appearance:result.dummy.appearance});
   if(!this.visualSceneReported){this.visualSceneReported=true;this.report('visual.object-dummy-scene-adapter-incomplete','Object-visual dummy uses asynchronous model loading and local scene/display mode2; native cache/display scheduling remains incomplete');}
   return result.dummy;
  }catch(error){this.stats.failed++;if(allocated)this.destroy(allocated);this.report('visual.object-dummy-create-failed',error.message,{role,position,lifetime,stack:error.stack});return null;}
 }
 async create(targetId,position,travel){
  if(this.disposed)return null;let allocated=null;
  try{
   const result=await createClientProjectileDummy(targetId,position,travel,{
    construct:()=>{allocated=createClientDummyState();this.owned.add(allocated);this.stats.created++;return allocated;},
    loadModel:async(s,name)=>{
     let model;try{model=await this.loadModel(name);if(this.disposed||s.destroyed){this.destroyModel(model);return 0;}s.model=model;s.resourceName=name;this.event({kind:'dummyLoaded',resource:name});return 1;}
     catch(error){this.stats.failed++;this.report('visual.projectile-dummy-model-failed',error.message,{resource:name,stack:error.stack});return 0;}
    },
    player:()=>{if(typeof this.playerId!=='function'){this.report('visual.projectile-dummy-player-unavailable','The local client player projection is unavailable');return null;}return this.objects.get(this.playerId());},
    area:player=>player?this.area:null,
    register:s=>this.objects.array.addInternalObject(s),setId:(s,id)=>s.id=id,
    setArea:(s,area)=>{s.area=area;area.objects.add(s.id);},registerAI:s=>{this.ai.add(s);this.stats.registered++;},
    setScene:(s,area)=>area.scene.add(s.model.root),setPosition:(s,point)=>{s.position=point;s.model.root.position.set(...render(point));},
    setDelay:(s,...args)=>setClientObjectFade(s,...args,this.fade)
   });
   if(this.disposed||result.dummy?.destroyed)return null;
   if(result.aborted){if(result.dummy)this.destroy(result.dummy);this.stats.failed++;this.report('visual.projectile-dummy-registration-failed','Native client dummy allocation or registration failed',{targetId});return null;}
   if(!result.registered&&result.dummy){
    // The original leaves this allocation outside the client array/AI list.
    // Reclaim that inaccessible local adapter allocation; retain requested ID.
    this.report('visual.projectile-dummy-unregistered','Dummy model/player/area admission failed; projectile retains its requested target ID',{targetId});this.destroy(result.dummy);
   }else if(result.dummy){
    this.event({kind:'dummyReady',id:result.dummy.id,requestedTargetId:targetId,position:result.dummy.position,duration:result.dummy.duration,appearance:result.dummy.appearance});
    if(!this.sceneReported){this.sceneReported=true;this.report('visual.projectile-dummy-scene-adapter-incomplete','Dummy uses local scene/display mode2 and asynchronous model loading; complete native cache, display virtuals and scene scheduling remain incomplete');}
   }
   return result;
  }catch(error){this.stats.failed++;this.report('visual.projectile-dummy-create-failed',error.message,{targetId,stack:error.stack});if(allocated)this.destroy(allocated);return null;}
 }
 update(){
  if(this.disposed)return;
  for(const s of [...this.ai])try{updateClientProjectileDummy(s,{expired:s=>updateClientObjectFade(s,this.fade),removeAI:s=>this.ai.delete(s),deleteObject:id=>this.objects.array.delete(id),destroy:s=>this.destroy(s)});}
  catch(error){this.stats.failed++;this.report('visual.projectile-dummy-update-failed',error.message,{id:s.id,stack:error.stack});this.destroy(s);}
 }
 destroy(s){if(s.destroyed)return;s.destroyed=true;this.ai.delete(s);this.owned.delete(s);s.area?.objects.delete(s.id);this.objects.remove(s);if(s.model){this.destroyModel(s.model);s.model=null;}this.stats.destroyed++;this.event({kind:'dummyDestroy',id:s.id});}
 snapshot(){return{...this.stats,active:[...this.owned].map(s=>({id:s.id,position:s.position,appearance:s.appearance,temporary:s.temporary,duration:s.duration,registered:this.ai.has(s)})),events:this.events};}
 dispose(){if(this.disposed)return;this.disposed=true;for(const s of [...this.owned])this.destroy(s);}
}
