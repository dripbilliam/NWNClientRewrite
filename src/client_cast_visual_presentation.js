import {createCastVisualController,clearCastVisuals,releaseCastVisuals,driveCastVisualController} from './cast_visual_controller.js';
import {clientCastFieldReader,readClientCastFields,hasClientCastFields} from './client_cast_fields.js';

// Local-authority presentation bridge. Native controller state is independent
// of server creatures. Async assets own proxy handles so a late load cannot
// resurrect a model that the native timer/teardown has already destroyed.
export class ClientCastVisualPresentation{
 constructor({objects,spell,castFields,voiceFields,animation=canonical=>canonical.animationState??0,now,difference,loadModel,destroyModel,sourceModel,nodePose,attach,forget,updateAttachments,report,oneShot}){
  Object.assign(this,{objects,spell,castFields,voiceFields,animation,now,difference,loadModel,destroyModel,sourceModel,nodePose,attach,forget,updateAttachments,report,oneShot});this.records=new Map();this.models=new Set();this.events=[];this.disposed=false;this.lastTime={...now()};
  this.p={spell,create:(resource,category)=>this.create(resource,category),sourceModel,nodePose,oneShot,
   attach:(handle,parent,part,flags)=>this.command(handle,{kind:'attach',parent,part,flags}),play:(handle,clip,speed,flags,time)=>this.command(handle,{kind:'play',clip,speed,flags,time}),
   listen:(handle,event,callback,context)=>this.command(handle,{kind:'listen',event,callback,context}),destroy:handle=>this.destroy(handle)};
 }
 event(event){this.events.push(event);if(this.events.length>48)this.events.shift();}
 record(source){
  let record=this.records.get(source.id);if(record?.source===source)return record;
  if(record)this.clear(record);
  record={source,visuals:createCastVisualController(),animation:0,spellId:-1,previousCasting:0,suppressSound:0,race:-1,gender:255};this.records.set(source.id,record);return record;
 }
 project(record){
  const canonical=record.source.canonical;record.animation=this.animation(canonical);
  if(hasClientCastFields(record.animation)){
   if(typeof this.castFields!=='function')throw new Error('Native cast message field projection is unavailable');
   if(!readClientCastFields(record,record.animation,clientCastFieldReader(this.castFields(canonical))))throw new Error('Native cast message field read overflow');
  }
  const animation=record.animation&65535,casting=(animation-15>>>0)<6||animation===61||(animation-250>>>0)<4||animation===261;
  if(casting){
   try{
    if(typeof this.voiceFields!=='function')throw new Error('Native chant race/gender projection is unavailable');
    const voice=this.voiceFields(canonical);record.race=voice.race;
    // A failed/uncreated model keeps the native appearance ctor's D0=255.
    // Do not install incoming appearance cells before successful model creation.
    if(this.sourceModel(record.source,255,1))record.gender=voice.gender;
   }catch(error){if(!record.voiceFailure){record.voiceFailure=true;this.report('visual.cast-voice-fields-unavailable',error.message,{sourceId:record.source.id});}record.race=-1;}
  }
  if(casting&&!record.bridgeReported){record.bridgeReported=true;this.report('visual.cast-client-fields-adapter-incomplete','Native cast fields, suppression and chant selection use local scalar/appearance projection; full update packets, dirty flags and replication remain incomplete',{sourceId:record.source.id,spellId:record.spellId});}
 }
 release(source,head,hand,ground){
  if(this.disposed)return;const record=this.record(source);this.project(record);
  // The native driver normally observes casting before the projectile arrives.
  // A newly loaded actor still takes the same release-entry timer branch.
  driveCastVisualController(record,0,this.withOwner(record));
  releaseCastVisuals(record.visuals,[head,hand,ground],source,this.withOwner(record));record.visuals.released=1;
 }
 withOwner(record){return{...this.p,create:(resource,category)=>this.create(resource,category,record),oneShot:(resource,position,priority,gain)=>{this.event({kind:'sound',sourceId:record.source.id,resource});this.p.oneShot(resource,position,priority,gain);}};}
 create(resource,category,record){
  if(!record)throw new Error('Cast visual requires a source controller');
  if(!record.sceneReported){record.sceneReported=true;this.report('visual.cast-async-scene-adapter-incomplete','Native synchronous model/cache and scene gates use an asynchronous renderer adapter',{sourceId:record.source.id});}
  const handle={resource,category,record,commands:[],model:null,destroyed:false};this.models.add(handle);this.event({kind:'create',sourceId:record.source.id,resource,category});
  void this.load(handle);return handle;
 }
 async load(handle){
  let model;
  try{
   model=await this.loadModel(handle.resource);
   this.objects.sync?.();
   if(this.disposed||handle.destroyed||this.objects.get(handle.record.source.id)!==handle.record.source){this.destroyModel(model);this.destroy(handle);return;}
   handle.model=model;this.event({kind:'loaded',sourceId:handle.record.source.id,resource:handle.resource,clips:model.model?.animations?.map(a=>a.name)??[]});
   for(const command of handle.commands.splice(0))this.apply(handle,command);
  }catch(error){
   // Failed native NewCAurObject leaves its slot null. Clear only this handle;
   // a later cast may already have replaced the same physical slot.
   for(const group of [handle.record.visuals.conjure,handle.record.visuals.cast])for(let i=0;i<3;i++)if(group[i]===handle)group[i]=null;
   this.report('visual.cast-model-failed',error.message,{sourceId:handle.record.source.id,resource:handle.resource,stack:error.stack});this.destroy(handle);
   if(model&&handle.model!==model)this.destroyModel(model);
  }
 }
 command(handle,command){if(handle.destroyed)return;if(handle.model)this.apply(handle,command);else handle.commands.push(command);}
 apply(handle,c){
  const model=handle.model;
  if(c.kind==='attach'){
   if(!this.attach||!this.forget)throw new Error('Native cast model attachment adapter is unavailable');
   if(!c.parent){this.forget(model);model.root.removeFromParent();}
   else if(!this.attach(model,c.parent,c.part,c.flags))this.report('visual.cast-anchor-unavailable','Cast visual attachment part is unavailable',{sourceId:handle.record.source.id,resource:handle.resource,part:c.part});
  }else if(c.kind==='listen'){if(model.animator?.eventDispatcher)model.animator.eventDispatcher.add(c.event,()=>{this.event({kind:'callback',resource:handle.resource,event:c.event});c.callback(handle,c.context);});else this.report('visual.cast-event-unavailable','Cast visual model has no animation event dispatcher',{resource:handle.resource,event:c.event});}
  else{
   const played=model.animator?.playNative(c.clip,{speed:c.speed,flags:c.flags,time:c.time});this.event({kind:'play',sourceId:handle.record.source.id,resource:handle.resource,clip:c.clip,flags:c.flags,played:!!played});
   if(!played)this.report('visual.cast-clip-unavailable','Authored cast visual animation cannot play',{sourceId:handle.record.source.id,resource:handle.resource,clip:c.clip});
  }
 }
 destroy(handle){
  if(handle.destroyed)return;handle.destroyed=true;this.models.delete(handle);handle.commands=[];
  if(handle.model){this.forget?.(handle.model);handle.model.animator?.eventDispatcher?.destroy();this.destroyModel(handle.model);}
  this.event({kind:'destroy',sourceId:handle.record.source.id,resource:handle.resource});
 }
 clear(record){clearCastVisuals(record.visuals,'conjure',this.p);clearCastVisuals(record.visuals,'cast',this.p);}
 update(delta){
  if(this.disposed)return;const now=this.now(),elapsed=this.difference(now,this.lastTime).time>>>0;this.lastTime={...now};
  for(const [id,record]of this.records)if(this.objects.get(id)!==record.source){this.clear(record);this.records.delete(id);}
  for(const source of this.objects.mirrors.values())if(source.objectType===5){
   const record=this.record(source);
   try{this.project(record);driveCastVisualController(record,elapsed,this.withOwner(record));}
   catch(error){this.report('visual.cast-controller-failed',error.message,{sourceId:source.id,stack:error.stack});this.clear(record);}
  }
  for(const handle of [...this.models])if(handle.model)try{handle.model.animator?.update(delta);}catch(error){this.report('visual.cast-animation-failed',error.message,{resource:handle.resource,stack:error.stack});this.destroy(handle);}
  this.updateAttachments?.();
 }
 snapshot(){return{active:[...this.models].map(h=>({sourceId:h.record.source.id,resource:h.resource,category:h.category,loaded:!!h.model})),controllers:[...this.records.values()].filter(r=>r.previousCasting||r.visuals.released||r.visuals.conjure.some(Boolean)||r.visuals.cast.some(Boolean)).map(r=>({sourceId:r.source.id,spellId:r.spellId,spellItemId:r.spellItemId,suppressSound:r.suppressSound,race:r.race,gender:r.gender,animation:r.animation,conjureTime:r.visuals.conjureTime,castTime:r.visuals.castTime,released:r.visuals.released})),events:this.events};}
 dispose(){this.disposed=true;for(const record of this.records.values())this.clear(record);this.records.clear();for(const handle of [...this.models])this.destroy(handle);}
}
