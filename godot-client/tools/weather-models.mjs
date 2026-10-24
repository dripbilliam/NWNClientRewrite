// Original resource bundles are immutable within one admitted world. Six
// private instances are requested by Godot's native weather state, never
// inserted into the canonical game-object registry or simulated as entities.
export class WeatherModels{
 constructor({session,connection,active,ready,prepare,write,particles,send,diagnose=()=>{}}){Object.assign(this,{session,connection,active,ready,prepare,write,particles,send,diagnose});this.closed=false;this.context=null;this.resources=new Map();this.types=new Map();this.batches=new Map();this.jobs=new Set();this.serial=0;this.emitterSerial=2**41;}
 valid(context){const scope=this.ready();return !this.closed&&!this.session.closed&&this.active()&&this.context===context&&this.session.world===context.world&&context.scope.connection===this.connection&&scope&&['connection','areaId','generation','transferId'].every(k=>scope[k]===context.scope[k]);}
 track(work){this.jobs.add(work);return work.finally(()=>this.jobs.delete(work));}
 async receive(message,world){
  if(this.closed||this.session.closed||!this.active())return;
  const scope=Object.fromEntries(['connection','areaId','generation','transferId'].map(k=>[k,message[k]]));
  if(!this.context||this.context.world!==world||Object.keys(scope).some(k=>scope[k]!==this.context.scope[k])){
   for(const record of this.batches.values())record.retired=true;
   this.batches.clear();this.resources.clear();this.types.clear();this.context={scope,world,lastBatch:0,modelIds:new Set()};
  }
  const context=this.context;if(!this.valid(context)||!message.weather.enabled||!message.weather.type)return;
  const type=message.weather.type,row=message.rows[type];
  if(!row||![row.model,row.animation].every(v=>typeof v==='string'&&/^[a-z0-9_]{1,16}$/i.test(v))){this.diagnose('godot.weather-resource-unavailable','WeatherTypes model/animation entry is unavailable');return;}
  if(this.types.has(type))return this.types.get(type);
  const work=this.load(context,type,row).catch(error=>{if(this.valid(context)){this.types.delete(type);this.diagnose('godot.weather-resource-failed',error.message);}});this.types.set(type,work);return this.track(work);
 }
 async load(context,type,row){
  const result=await this.prepare(row.model.toLowerCase());if(!this.valid(context))return;if(!result)throw Error('Original weather resource staging is unavailable');
  const envelope=await this.write(result);if(!this.valid(context))return;
  const resourceId=++this.serial,entry={context,type,resourceId,metadata:result.manifest,animation:row.animation.toLowerCase()};this.resources.set(resourceId,entry);
  this.send({...context.scope,kind:'weather-resource',type,resourceId,animation:entry.animation,resource:envelope});
 }
 activate(message){return this.track(this.add(message));}
 async add(message){
  const entry=this.resources.get(message.resourceId),context=this.context;
  if(!entry||entry.context!==context||!this.valid(context)||message.type!==entry.type||this.batches.has(message.batchId))return;
  if(!Number.isSafeInteger(message.batchId)||message.batchId<=context.lastBatch||!Array.isArray(message.ids)||message.ids.length!==6||new Set(message.ids).size!==6||message.ids.some(v=>!Number.isSafeInteger(v)||v<1||v>1e9||context.modelIds.has(v)))throw Error('Invalid or recycled native weather instance identity');
  context.lastBatch=message.batchId;for(const id of message.ids)context.modelIds.add(id);
  const delivery=this.particles();if(!delivery)throw Error('Weather particle owner is unavailable');
  const record={batchId:message.batchId,models:[...message.ids],context,entry,delivery,retired:false};this.batches.set(record.batchId,record);
  const add=[];
  for(const id of record.models)for(const source of entry.metadata.particles?.emitters??[]){const row=structuredClone(source);row.id=++this.emitterSerial;row.objectId=-(2**32+id);row.weatherModel=id;row.awaitPose=true;row.engineLighting=Boolean((row.properties.flags??0)&8)||[true,1,'1','true'].includes(row.properties.tinted);for(const binding of [row.nativeParent,row.nativeRoot,row.referenceTarget?.nativeRoot,row.referenceTarget?.attachment?.binding,row.referenceTarget?.attachment?.fallback])if(binding)binding.weatherModel=id;add.push(row);}
  record.objects=record.models.map(id=>-(2**32+id));
  await delivery.patch({removeObjects:[],add});
  if(record.retired||!this.valid(context)){await delivery.patch({removeObjects:record.objects,add:[]});return;}
  const emitters=add.map(row=>({...row,clips:Object.fromEntries(Object.entries(row.clips??{}).map(([key,clip])=>[key,{length:clip.length,events:clip.events??[]}]))}));
  this.send({...context.scope,kind:'weather-particles',resourceId:entry.resourceId,batchId:record.batchId,emitters});
 }
 release(message){return this.track(this.remove(message));}
 async remove(message){const record=this.batches.get(message.batchId);if(!record||!this.valid(record.context))return;record.retired=true;this.batches.delete(record.batchId);await record.delivery.patch({removeObjects:record.objects??record.models.map(id=>-(2**32+id)),add:[]});}
 async close(){if(this.closed)return;this.closed=true;for(const record of this.batches.values())record.retired=true;await Promise.allSettled([...this.jobs]);this.batches.clear();this.resources.clear();this.types.clear();this.context=null;}
}
