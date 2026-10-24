import {ClientObjectArray} from '../../src/client_object_array.js';
import {createClientDummyState,createClientVisualDummy} from '../../src/client_projectile_dummy.js';

// A single internal allocator for visual and (future) projectile hosts. These
// objects never enter NetworkWorld.registry or consume its server-ID cursor.
export class ClientDummies {
 constructor({session,connection,active,ready,prepare,write,send,diagnose=()=>{},report={}}){
  Object.assign(this,{session,connection,active,ready,prepare,write,send,diagnose,report});
  this.objects=new ClientObjectArray({objects:()=>[],render:()=>null});this.owned=new Map();this.queue=[];this.jobs=new Set();this.context=null;this.serial=0;this.closed=false;
  Object.assign(report,{created:0,retired:0,areaAllocated:0,areaRetired:0,aborted:0,discarded:0,status:[],scope:'Private original c_dummy admission; native frame owner handles projected expiry. Full server world-timer synchronization and cache/display virtuals remain pending.'});
 }
 follow(){
  const world=this.session.world,generation=this.session.areaGeneration,areaId=world.areaId;
  if(this.context?.world===world&&this.context.generation===generation&&this.context.areaId===areaId)return;
  for(const record of [...this.owned.values()])this.destroy(record);
  for(const request of this.queue.splice(0))request.resolve(null);
  this.context={world,generation,areaId,resource:null};
 }
 valid(context){return !this.closed&&!this.session.closed&&this.active()&&this.context===context&&this.session.world===context.world&&this.session.areaGeneration===context.generation&&context.world.areaId===context.areaId;}
 scope(context){const scope=this.ready();return this.valid(context)&&scope?.connection===this.connection&&scope.areaId===context.areaId&&scope.generation===context.generation?scope:null;}
 has(actor){const record=this.owned.get(actor.id);return record?.actor===actor&&this.valid(record.context);}
 allocateArea(){this.follow();if(!this.valid(this.context))return null;const actor={id:0x7f000000,objectType:11,areaId:this.context.areaId};const allocation=this.objects.array.addInternalObject(actor);if(allocation.status!==0)return null;const record={actor,context:this.context,token:++this.serial,area:true};this.owned.set(actor.id,record);this.report.areaAllocated++;return record;}
 releaseArea(actor){const record=this.owned.get(actor.id);if(record?.area&&record.actor===actor)this.destroy(record);}
 host(actor){const record=this.owned.get(actor.id);if(!record||!this.has(actor))return null;return{id:actor.id,token:record.token,objectType:5,areaId:record.context.areaId,creatureData:{Appearance_Type:201},model:record.model};}
 create(role,position,lifetime){
  if(this.closed)return Promise.resolve(null);this.follow();
  if(!['point','source','target'].includes(role)||!Array.isArray(position)||position.length!==3||!position.every(Number.isFinite)||!Number.isInteger(lifetime)||lifetime<0||lifetime>0xffffffff)return Promise.reject(Error('Invalid private client dummy request'));
  if(this.queue.length>=512){this.diagnose('visual.dummy-queue-limit','Private dummy admission queue is full');return Promise.resolve(null);}
  return new Promise(resolve=>{this.queue.push({role,position,lifetime,context:this.context,resolve});this.flush();});
 }
 flush(){
  if(this.closed)return;this.follow();
  while(this.jobs.size<2&&this.queue.length&&this.scope(this.queue[0].context)){
   const request=this.queue.shift();const work=this.admit(request).catch(error=>{if(this.valid(request.context))this.diagnose('visual.dummy-admission-failed',error.message);return null;}).then(request.resolve).finally(()=>this.jobs.delete(work));this.jobs.add(work);
  }
 }
 async resource(context){
  if(!context.resource)context.resource=(async()=>{
   const result=await this.prepare('c_dummy');if(!this.valid(context))return null;
   if(!result||result.manifest?.kind!=='visual-model'||result.manifest.modelResources?.[0]?.toLowerCase()!=='c_dummy')throw Error('Original private c_dummy resource is unavailable');
   const model=result.manifest.rigs?.entities?.[0]?.models?.[0];if(!model?.partNames?.length)throw Error('Original dummy anchors are unavailable');
   const envelope=await this.write(result);if(!this.valid(context))return null;
   return{envelope,model:{parts:[...model.partNames],loadedName:'c_dummy'}};
  })().catch(error=>{context.resource=null;throw error;});
  return context.resource;
 }
 async admit({role,position,lifetime,context}){
  const resource=await this.resource(context);if(!resource||!this.scope(context)){this.report.discarded++;return null;}
  let actor;const record={context,token:++this.serial,model:resource.model};
  try{
   const result=await createClientVisualDummy(role,position,lifetime,{
    construct:()=>{actor=createClientDummyState();record.actor=actor;return actor;},loadModel:async(s,name,part,flags)=>{if(name!=='c_dummy'||part!==255||flags!==0)throw Error('Unexpected original dummy model request');s.model=resource;return 1;},
    currentArea:()=>this.valid(context)?context:null,register:s=>this.objects.array.addInternalObject(s),setId:(s,id)=>s.id=id,
    setArea:(s)=>s.areaId=context.areaId,registerAI:()=>{},setScene:()=>{},setPosition:(s,point)=>s.position=point,
    // Replayed by the native frame owner only after its model imports. Delaying
    // the start until actual admission avoids expiring while disk IO is pending.
    setDelay:(s,...args)=>s.delayRequest=args
   });
   if(!this.scope(context)||result.aborted||!result.registered){if(actor)this.objects.remove(actor);this.report.aborted++;if(result.aborted&&role==='source')this.diagnose('visual.object-dummy-source-native-abort','Original source-role registration status-zero abort retained');return null;}
   actor.creatureData={Appearance_Type:201};this.owned.set(actor.id,record);this.report.created++;
   this.send({...this.scope(context),kind:'client-dummy',id:actor.id,token:record.token,role,position:actor.position,appearance:actor.appearance,delay:actor.delayRequest,resource:resource.envelope});
   return actor;
  }catch(error){if(actor)this.objects.remove(actor);throw error;}
 }
 status(message){
  const record=this.owned.get(message.id),scope=record&&this.scope(record.context);
  if(!record||record.token!==message.token||!scope||scope.transferId!==message.transferId)return false;
  if(this.report.status.length<256)this.report.status.push({id:message.id,token:message.token,stage:message.stage});
  if(['expired','failed'].includes(message.stage))this.destroy(record);
  return true;
 }
 destroy(record){this.objects.remove(record.actor);this.owned.delete(record.actor.id);record.actor.destroyed=true;record.actor.model=null;this.report[record.area?'areaRetired':'retired']++;}
 async close(){if(this.closed)return;this.closed=true;for(const request of this.queue.splice(0))request.resolve(null);for(const record of [...this.owned.values()])this.destroy(record);await Promise.allSettled([...this.jobs]);this.context=null;this.report.closed=true;this.report.pending=this.jobs.size;}
}
