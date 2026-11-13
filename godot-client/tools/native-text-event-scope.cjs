'use strict';

// Transport provenance only. The original decoder owns message fields; Godot
// owns channel/display policy, text resolution, queueing, assets and projection.
// Reuse the SAME canonical-object identity and disclosure owners as snapshots.
const own=(value,key)=>{
 if(value===null||typeof value!=='object')return undefined;
 const descriptor=Object.getOwnPropertyDescriptor(value,key);
 return descriptor&&Object.hasOwn(descriptor,'value')?descriptor.value:undefined;
};
const method=(value,key)=>{
 for(let object=value;object&&typeof object==='object';object=Object.getPrototypeOf(object)){
  const descriptor=Object.getOwnPropertyDescriptor(object,key);
  if(descriptor)return Object.hasOwn(descriptor,'value')&&typeof descriptor.value==='function'?descriptor.value:null;
 }
 return null;
};
const uint32=value=>Number.isInteger(value)&&value>=0&&value<=0xffffffff;
const safe=value=>Number.isSafeInteger(value)&&value>=0;
const positive=value=>Number.isSafeInteger(value)&&value>=1;
const invalid=()=>{throw new TypeError('Invalid native text event scope');};
const sourceId=message=>{
 const kind=own(message,'kind');
 if(kind==='server-speech')return {supported:true,id:own(message,'objectId')};
 if(kind==='combat-feedback'&&[93,94].includes(own(message,'type'))){
  return {supported:true,id:own(own(own(message,'data'),'objects'),'0')};
 }
 return {supported:false};
};

class NativeTextEventScope {
 constructor(nativeIdentities,{maximumSerial=Number.MAX_SAFE_INTEGER}={}){
  if(!positive(maximumSerial)||!method(nativeIdentities,'identity'))invalid();
  this.nativeIdentities=nativeIdentities;this.maximumSerial=maximumSerial;this.serial=0;
 }
 reference(world,selectedId,areaId){
  const registry=own(world,'registry'),get=method(registry,'get');
  const disclosures=own(world,'entityDisclosures'),token=method(disclosures,'token');
  if(!uint32(selectedId)||!get||!token)return null;
  const object=get.call(registry,selectedId);
  const id=own(object,'id'),rawType=own(object,'objectType'),rawObjectArea=own(object,'areaId');
  const objectType=rawType===undefined||rawType===null?null:rawType;
  const objectArea=rawObjectArea===undefined||rawObjectArea===null?null:rawObjectArea;
  if(id!==selectedId||!(objectType===null||uint32(objectType)&&objectType>0)||!(objectArea===null||uint32(objectArea))||objectArea!==null&&areaId!==null&&objectArea!==areaId||own(object,'replicationRemoved')===true)return null;
  const nativeLifetime=method(this.nativeIdentities,'identity').call(this.nativeIdentities,object);
  // token() is the existing disclosure owner, not a second entity registry.
  // It can lazily stamp a received object before its first bridge snapshot;
  // transportRow() later reuses that token. Accepted D invalidates it even
  // when the canonical proxy is retained and redisclosed with the same ID.
  const knownLifetime=token.call(disclosures,object);
  return positive(nativeLifetime)&&positive(knownLifetime)?{id,objectType,areaId:objectArea,nativeLifetime,knownLifetime}:null;
 }
 actorName(world,source){
  if(!source||source.objectType!==5)return null;
  const registry=own(world,'registry'),get=method(registry,'get');
  const read=method(world,'nativeActorNameTransport'),history=method(world,'nativeActorNameHistory');
  if(!get||!read||!history)return null; // Older captured owners have no such fact.
  const object=get.call(registry,source.id),certainty=history.call(world);
  if(own(object,'id')!==source.id||own(object,'objectType')!==5||own(certainty,'version')!==1||typeof own(certainty,'complete')!=='boolean')return null;
  // Opaque accepted A/P data only. Godot resolves native strings. Capturing
  // this here prevents a later/coalesced raw snapshot from renaming a chat.
  return {version:1,historyComplete:own(certainty,'complete'),state:structuredClone(read.call(world,object))};
 }
 capture(world,message,generation,connection){
  const selected=sourceId(message);if(!selected.supported)return null;
  const rawArea=own(world,'areaId'),areaId=rawArea===undefined||rawArea===null?null:rawArea;
  if(!safe(connection)||!safe(generation)||areaId!==null&&!uint32(areaId)||this.serial>=this.maximumSerial)invalid();
  const event={version:1,serial:++this.serial,connection,generation,areaId,source:this.reference(world,selected.id,areaId)};
  if(own(message,'kind')==='server-speech'){
   const actorName=this.actorName(world,event.source);if(actorName!==null)event.actorName=actorName;
  }
  // Localized11/12's decoded token context can differ from its speaker.
  // This identifies an additional received reference, not display policy.
  // Explicit null means captured but unavailable; absence remains legacy.
  if(own(message,'kind')==='server-speech'&&[11,12].includes(own(message,'channel')))event.context=this.reference(world,own(message,'contextId'),areaId);
  return event;
 }
}

module.exports={NativeTextEventScope};
