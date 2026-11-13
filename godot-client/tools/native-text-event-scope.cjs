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
// The existing wire decoder projects every native byte through CP1252. This
// inverse preserves those bytes; it does not translate or resolve game text.
const high=[0x20ac,0x81,0x201a,0x192,0x201e,0x2026,0x2020,0x2021,0x2c6,0x2030,0x160,0x2039,0x152,0x8d,0x17d,0x8f,0x90,0x2018,0x2019,0x201c,0x201d,0x2022,0x2013,0x2014,0x2dc,0x2122,0x161,0x203a,0x153,0x9d,0x17e,0x178];
const byteProjection=value=>{
 if(typeof value!=='string')return null;
 const bytes=[];for(const char of value){const point=char.codePointAt(0),slot=high.indexOf(point);if(slot>=0)bytes.push(slot+128);else if(point<128||point>=160&&point<=255)bytes.push(point);else return null;}
 return {bytes};
};
const nameBytes=value=>{
 if(typeof value==='string')return byteProjection(value);
 if(!value||typeof value!=='object')return null;
 if(typeof own(value,'text')==='string')return byteProjection(own(value,'text'));
 const first=own(value,'firstName'),last=own(value,'lastName');
 if(first!==undefined||last!==undefined)return {...(first!==undefined?{firstName:nameBytes(first)}:{}),...(last!==undefined?{lastName:nameBytes(last)}:{})};
 return structuredClone(value); // Unresolved localized references stay explicit.
};
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
 tokenContext(world,source){
  if(!source)return null;
  const get=method(own(world,'registry'),'get');if(!get)return null;
  const object=get.call(own(world,'registry'),source.id);
  const row={id:source.id,objectType:source.objectType,areaId:source.areaId,nativeLifetime:source.nativeLifetime,clientKnownLifetime:source.knownLifetime};
  // Retain only provider inputs at dispatch, before Godot's coalesced object
  // snapshot can acquire newer names/stats. This is not a new world store.
  for(const section of ['replicated','appearance']){
   const raw=own(object,section);if(!raw||typeof raw!=='object')continue;
   const selected={};const name=own(raw,'name');if(name!==undefined)selected.name=nameBytes(name);
   if(section==='replicated'){
    const stats=own(raw,'stats');if(stats&&typeof stats==='object'){
     selected.stats={};for(const key of ['race','racialType','fieldD20','fieldD28','fieldE58','fieldDE4','fieldDE6']){const value=own(stats,key);if(value===null||['string','number','boolean'].includes(typeof value))selected.stats[key]=['fieldD28','fieldE58'].includes(key)?byteProjection(value):value;}
     const classes=own(stats,'classes');if(Array.isArray(classes))selected.stats.classes=classes.slice(0,1).map(first=>({...(own(first,'id')!==undefined?{id:own(first,'id')}:{}),...(own(first,'level')!==undefined?{level:own(first,'level')}: {})}));
    }
   }
   row[section]=selected;
  }
  return row;
 }
 capture(world,message,generation,connection){
  const selected=sourceId(message);if(!selected.supported)return null;
  const rawArea=own(world,'areaId'),areaId=rawArea===undefined||rawArea===null?null:rawArea;
  if(!safe(connection)||!safe(generation)||areaId!==null&&!uint32(areaId)||this.serial>=this.maximumSerial)invalid();
  const event={version:1,serial:++this.serial,connection,generation,areaId,source:this.reference(world,selected.id,areaId),nativeByteProjection:'windows-1252'};
  const time=own(world,'time');event.nativeWorld={};
  for(const [field,key] of [['native160','year'],['native164','month'],['native16c','hour'],['native17c','dawn'],['native17d','dusk']]){
   const value=own(time,key);if(uint32(value)&&(key==='year'||value<=255))event.nativeWorld[field]=value;
  }
  const players=own(world,'players');if(players instanceof Map){event.nativePlayers={};event.nativePlayersComplete=own(world,'playerRosterKnown')===true;for(const [id,player] of players){if(!uint32(id))continue;const name=byteProjection(own(player,'name'));event.nativePlayers[id]={known:true,present:true,...(name!==null?{name}:{})};}}
  if(own(message,'kind')==='server-speech'){
   const actorName=this.actorName(world,event.source);if(actorName!==null)event.actorName=actorName;
  }
  // Localized11/12's decoded token context can differ from its speaker.
  // This identifies an additional received reference, not display policy.
  // Explicit null means captured but unavailable; absence remains legacy.
  if(own(message,'kind')==='server-speech'&&[11,12].includes(own(message,'channel'))){
   event.context=this.reference(world,own(message,'contextId'),areaId);
   event.contextData=this.tokenContext(world,event.context);
   const actorName=this.actorName(world,event.context);if(actorName!==null)event.contextActorName=actorName;
  }
  return event;
 }
}

module.exports={NativeTextEventScope,byteProjection};
