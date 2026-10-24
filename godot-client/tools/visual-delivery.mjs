import {NetworkVisualPresentation} from '../../src/network_visual_presentation.js';
import {deliverObjectVisualAsync} from '../../src/object_visual_delivery.js';
import {nativeStringEntry} from '../../src/spell_metadata.js';

// Decoded events reserve physical native list positions before model IO. The
// native list chooses duplicate removals using its current phase/cessation
// state, including reservations whose assets have not completed yet.
export class VisualDelivery {
 constructor({session,connection,active,ready,prepare,write,tables,particles,send,diagnose,report,dummies=null,now=()=>performance.now()}){
  Object.assign(this,{session,connection,active,ready,prepare,write,tables,particles,send,diagnose,report,dummies,now});this.instantJobs=new Set();
  this.entries=new Map();this.models=new Map();this.operations=[];this.jobs=new Set();this.modelJobs=new Set();this.serial=0;this.emitterSerial=2**40;this.closed=false;this.world=null;this.generation=-1;this.work=0;
  Object.assign(report,{reserved:0,ready:0,retired:0,discarded:0,models:0,status:[],diagnostics:[],input:[]});
 }
 scope(){return{connection:this.connection,areaId:this.session.world.areaId,generation:this.session.areaGeneration};}
 follow(){
  if(this.world===this.session.world&&this.area===this.session.world.areaId&&this.generation===this.session.areaGeneration)return;
  this.world=this.session.world;this.area=this.world.areaId;this.generation=this.session.areaGeneration;
  for(const entry of this.entries.values())entry.removed=true;
  this.entries.clear();this.models.clear();this.operations=[];
 }
 valid(entry){const scope=this.scope();return !this.closed&&this.active()&&!this.session.closed&&this.world===this.session.world&&entry.world===this.world&&entry.scope.areaId===scope.areaId&&entry.scope.generation===scope.generation&&this.entries.get(entry.id)===entry&&!entry.removed&&(entry.privateHost?this.dummies?.has(entry.actor):this.world.registry.get(entry.actorId)===entry.actor&&!entry.actor.replicationRemoved);}
 reserve(actorId,record,transient,privateActor=null){
  this.follow();const actor=privateActor??this.world.registry.get(actorId),privateHost=privateActor&&this.dummies?.host(privateActor);if(!actor||privateActor&&!privateHost||actor.replicationRemoved||actor.areaId!==this.area)return;
  const entry={id:++this.serial,actorId,actor,world:this.world,scope:this.scope(),record:structuredClone(record),transient,removed:false,preparing:false,retry:0,metadata:null};
  entry.privateHost=privateHost;this.entries.set(entry.id,entry);this.operations.push({kind:'visual-reserve',effectId:entry.id,actorId,privateToken:privateHost?.token??0,visualId:record.visualId,transient});this.report.reserved++;
  return entry;
 }
 receive(events){if(this.closed)return;this.follow();for(const event of events){if(event.action!=='visual-effects')continue;for(const change of event.changes){if(this.report.input.length<200)this.report.input.push({kind:'loop',action:change.action,actorId:event.id,visualId:change.visualId});if(change.action==='A')this.reserve(event.id,NetworkVisualPresentation.prototype.record.call(null,change),false);else if(change.action==='D')this.operations.push({kind:'visual-remove',actorId:event.id,visualId:change.visualId});}}}
 instant(message){const job=this.deliverInstant(message);this.instantJobs.add(job);return job.finally(()=>this.instantJobs.delete(job));}
 areaInstant(message){
  if(this.closed)return;this.follow();this.dummies?.follow();
  const host=this.dummies?.allocateArea();if(!host)return;
  const entry={id:++this.serial,actorId:host.actor.id,actor:host.actor,privateHost:{token:host.token},areaVisual:true,message:structuredClone(message),world:this.world,scope:this.scope(),record:{visualId:message.visualId},transient:true,removed:false,preparing:false,retry:0,metadata:null};
  this.entries.set(entry.id,entry);this.operations.push({kind:'visual-reserve',effectId:entry.id,actorId:entry.actorId,privateToken:host.token,areaVisual:true,visualId:message.visualId,transient:true});this.report.reserved++;
  if(this.report.input.length<200)this.report.input.push({kind:'area',actorId:entry.actorId,visualId:message.visualId});
 }
 async deliverInstant(message){
  if(this.report.input.length<200)this.report.input.push({kind:'instant',actorId:message.targetId,visualId:message.visualId});
  if(this.closed)return;this.follow();const world=this.world,scope=this.scope(),target=world.registry.get(message.targetId),table=await this.tables();
  if(this.closed||world!==this.session.world||scope.generation!==this.session.areaGeneration||scope.areaId!==world.areaId||target&&world.registry.get(target.id)!==target)return;
  const objects={get:id=>{const actor=world.registry.get(id);return actor&&!actor.replicationRemoved&&actor.areaId===scope.areaId?actor:null;}};
  await deliverObjectVisualAsync({...message,transform:{scale:1,translate:[0,0,0],rotate:[0,0,0]}},{visualType:id=>nativeStringEntry(table,id,'Type_FD'),object:id=>objects.get(id),renderObject:actor=>actor,
   createDummy:async(role,position,lifetime)=>this.dummies?.create(role,position,lifetime)??null,
   add:(actor,record)=>{if(this.closed||world!==this.session.world||scope.generation!==this.session.areaGeneration||scope.areaId!==world.areaId)return 0;record.networkTransform=structuredClone(message.visualTransform);return this.reserve(actor.id,record,true,this.dummies?.has(actor)?actor:null)?1:0;}});
 }
 flush(){
  if(this.closed)return;this.follow();this.dummies?.flush();const scope=this.ready();if(!scope||scope.areaId!==this.area||scope.generation!==this.generation)return;
  for(const operation of this.operations.splice(0))this.send({...scope,...operation});
  for(const entry of this.entries.values()){
   if(!this.valid(entry)){this.send({...scope,kind:'visual-cancel',effectId:entry.id});entry.removed=true;this.entries.delete(entry.id);if(entry.areaVisual)this.dummies?.releaseArea(entry.actor);continue;}
   if(entry.metadata||entry.preparing||entry.retry>this.now()||this.work>=2)continue;
   entry.preparing=true;this.work++;
   const job=this.prepareEntry(entry,scope).catch(error=>{if(this.valid(entry)){this.diagnose('visual.definition-preparation-failed',error.message);this.send({...scope,kind:'visual-cancel',effectId:entry.id});this.entries.delete(entry.id);if(entry.areaVisual)this.dummies?.releaseArea(entry.actor);}}).finally(()=>{entry.preparing=false;this.work--;this.jobs.delete(job);});
   this.jobs.add(job);
  }
 }
 async prepareEntry(entry,scope){
  const definition=await this.prepare(entry.areaVisual?{kind:'area-visual',message:entry.message}:{actorId:entry.actorId,record:entry.record,...(entry.privateHost?{privateHosts:[entry.privateHost]}:{})});
  if(!this.valid(entry)){this.report.discarded++;return;}
  if(!definition||definition.pending){entry.retry=this.now()+50;return;}
  const bundle=await this.write(definition,scope);if(!this.valid(entry)){this.report.discarded++;return;}
  entry.metadata=new Map(Object.entries(definition.resources).map(([key,value])=>[key,value.manifest]));entry.deliveryScope=scope;
  this.send({...scope,kind:'visual-ready',effectId:entry.id,file:bundle.file,sha256:bundle.sha256});this.report.ready++;
 }
 status(message){
  if(this.report.status.length<300)this.report.status.push({effectId:message.effectId,stage:message.stage,visualId:message.visualId,phase:message.phase,finished:message.finished,attached:message.attached});
  if(['retired','canceled','failed'].includes(message.stage)){const entry=this.entries.get(message.effectId);if(entry){entry.removed=true;this.entries.delete(entry.id);if(entry.areaVisual)this.dummies?.releaseArea(entry.actor);this.report.retired++;}}
 }
 modelCreated(message){return this.modelJob(this.addModel(message));}
 modelReleased(message){return this.modelJob(this.removeModel(message));}
 modelJob(work){this.modelJobs.add(work);return work.finally(()=>this.modelJobs.delete(work));}
 async addModel(message){
  const entry=this.entries.get(message.effectId);if(!entry||!this.valid(entry)||!entry.metadata?.has(message.resource)||this.models.has(message.modelId))return;
  const metadata=entry.metadata.get(message.resource),record={entry,id:message.modelId,removed:false};this.models.set(record.id,record);this.report.models++;
  const add=structuredClone(metadata.particles?.emitters??[]);
  for(const row of add){row.id=++this.emitterSerial;row.objectId=-record.id;row.visualModel=record.id;row.awaitPose=true;for(const binding of [row.nativeParent,row.nativeRoot,row.referenceTarget?.nativeRoot,row.referenceTarget?.attachment?.binding,row.referenceTarget?.attachment?.fallback])if(binding)binding.visualModel=record.id;}
  const delivery=this.particles();if(!delivery||!add.length)return;
  await delivery.patch({removeObjects:[],add});
  if(this.models.get(record.id)!==record||!this.valid(entry)){await delivery.patch({removeObjects:[-record.id],add:[]});return;}
  const native=add.map(row=>({...row,clips:Object.fromEntries(Object.entries(row.clips??{}).map(([key,clip])=>[key,{length:clip.length,events:clip.events??[]}]))}));
  for(let index=0;index<native.length;index+=32)this.send({...entry.deliveryScope,kind:'visual-model-particles',effectId:entry.id,modelId:record.id,emitters:native.slice(index,index+32)});
 }
 async removeModel(message){
  const record=this.models.get(message.modelId);if(!record||record.entry.id!==message.effectId)return;record.removed=true;this.models.delete(record.id);await this.particles()?.patch({removeObjects:[-record.id],add:[]});
 }
 async close(){if(this.closed)return;this.closed=true;for(const entry of this.entries.values())entry.removed=true;this.entries.clear();this.operations=[];await this.dummies?.close();await Promise.allSettled([...this.jobs,...this.modelJobs,...this.instantJobs]);this.models.clear();this.report.closed=true;this.report.pendingJobs=this.jobs.size+this.modelJobs.size+this.instantJobs.size;}
}
