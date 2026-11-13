'use strict';
const {types}=require('node:util');
const {RawWorldDeltas}=require('../../raw-world-deltas.cjs');
const {rawWorldFrames}=require('../../raw-world-frames.cjs');
const {IMMUTABLE_SERIALIZED_JSON,sealImmutableEncodedPlan,encodedRecordFrames}=require('./encoded-record-framer.cjs');
const isProxy=types.isProxy,ownKeys=Reflect.ownKeys,descriptor=Object.getOwnPropertyDescriptor,prototype=Object.getPrototypeOf,isFrozen=Object.isFrozen,freeze=Object.freeze,isArray=Array.isArray,apply=Reflect.apply;
const objectProto=Object.prototype,arrayProto=Array.prototype,bigintProto=BigInt.prototype,nativeJson=JSON,nativeStringify=JSON.stringify,nativeString=String,arrayIterator=arrayProto[Symbol.iterator],iteratorProto=prototype(apply(arrayIterator,[],[])),iteratorNext=descriptor(iteratorProto,'next').value;
const nativeMap=Map,mapProto=Map.prototype,mapGet=descriptor(mapProto,'get').value,mapSet=descriptor(mapProto,'set').value,mapHas=descriptor(mapProto,'has').value,mapKeys=descriptor(mapProto,'keys').value,arrayFilter=descriptor(arrayProto,'filter').value;
const planMethod=RawWorldDeltas.prototype.plan,ackMethod=RawWorldDeltas.prototype.acknowledge,resetMethod=RawWorldDeltas.prototype.reset;
function stableIntrinsics(){return descriptor(globalThis,'JSON')?.value===nativeJson&&descriptor(nativeJson,'stringify')?.value===nativeStringify&&descriptor(globalThis,'String')?.value===nativeString&&descriptor(globalThis,'Map')?.value===nativeMap&&descriptor(mapProto,'get')?.value===mapGet&&descriptor(mapProto,'set')?.value===mapSet&&descriptor(mapProto,'has')?.value===mapHas&&descriptor(mapProto,'keys')?.value===mapKeys&&descriptor(arrayProto,'filter')?.value===arrayFilter&&prototype(objectProto)===null&&prototype(arrayProto)===objectProto&&prototype(bigintProto)===objectProto&&!descriptor(objectProto,'toJSON')&&!descriptor(arrayProto,'toJSON')&&!descriptor(bigintProto,'toJSON')&&descriptor(arrayProto,Symbol.iterator)?.value===arrayIterator&&descriptor(iteratorProto,'next')?.value===iteratorNext;}
function inspectImmutableEnvelope(input,{maximumNodes=10000,maximumKeys=4096,maximumDepth=64,maximumString=1024*1024}={}){
 const budget=(value,limit)=>Number.isSafeInteger(value)&&value>=1&&value<=limit;
 if(!budget(maximumNodes,100000)||!budget(maximumKeys,65536)||!budget(maximumDepth,128)||!budget(maximumString,1024*1024))throw Error('Invalid private inspection budget');
 let nodes=0,properties=0,reason='supported';const done=new WeakSet(),active=new WeakSet();
 const fail=value=>{if(reason==='supported')reason=value;return false;};
 const shape=value=>{if(value===null||typeof value!=='object')return fail('noncanonical-container');if(isProxy(value))return fail('proxy');const p=prototype(value);if(p!==null&&p!==objectProto&&!(isArray(value)&&p===arrayProto))return fail('custom-prototype');return true;};
 const keys=value=>{const k=ownKeys(value);if(k.length>maximumKeys&&!isArray(value)){fail('budget');return null;}for(const key of k)if(typeof key!=='string'){fail('symbol-key');return null;}return k;};
 function visit(value,depth){
  if(++nodes>maximumNodes||depth>maximumDepth)return fail('budget');
  if(value===null||value===undefined||typeof value==='number'||typeof value==='boolean'||typeof value==='bigint')return true;
  if(typeof value==='string')return value.length<=maximumString||fail('budget');
  if(typeof value!=='object')return fail('function-or-symbol');
  if(!shape(value))return false;
  if(!isFrozen(value))return fail('mutable-value');
  if(active.has(value))return fail('cycle');if(done.has(value))return true;
  const k=keys(value);if(!k)return false;
  if(isArray(value)){const length=descriptor(value,'length')?.value;if(!Number.isSafeInteger(length)||length<0||length>65536||k.length!==length+1)return fail('sparse-or-custom-array');for(let i=0;i<length;i++)if(!descriptor(value,String(i)))return fail('sparse-or-custom-array');}
  active.add(value);
  for(const key of k){if(++properties>maximumNodes*8)return fail('budget');const d=descriptor(value,key);if(!d||!('value'in d))return fail('accessor');if(key==='toJSON')return fail('toJSON');if(isArray(value)&&key==='length')continue;if(!visit(d.value,depth+1))return false;}
  active.delete(value);done.add(value);return true;
 }
 const rootDescriptors=value=>{if(!shape(value))return null;if(isArray(value)){fail('noncanonical-container');return null;}const k=keys(value);if(!k)return null;const out=Object.create(null);for(const key of k){const d=descriptor(value,key);if(!d||!('value'in d)){fail('accessor');return null;}out[key]=d;}return out;};
 if(!stableIntrinsics())fail('intrinsics');
 if(reason==='supported'){
  const e=rootDescriptors(input);if(e){
   for(const key of ownKeys(e))if(!['connection','generation','serial','data'].includes(key))fail('noncanonical-envelope');
   const c=e.connection?.value,g=e.generation?.value,s=e.serial?.value;
   if(!Number.isSafeInteger(c)||c<0||!Number.isSafeInteger(g)||g<0||!Number.isSafeInteger(s)||s<1)fail('invalid-envelope');
   const data=reason==='supported'?rootDescriptors(e.data?.value):null;
   if(data){
    const records=data.objects?.value;
    if(!shape(records)||!isArray(records))fail('noncanonical-record-array');
    else{const rk=keys(records),length=descriptor(records,'length')?.value;if(!Number.isSafeInteger(length)||length<0||length>65536||!rk||rk.length!==length+1)fail('sparse-or-custom-array');
     else for(let i=0;i<length&&reason==='supported';i++){const d=descriptor(records,String(i));if(!d||!('value'in d)){fail('accessor');break;}const row=d.value;if(!shape(row)||isArray(row)){fail('noncanonical-record');break;}const id=descriptor(row,'id');if(!id||!('value'in id)||!Number.isSafeInteger(id.value)||id.value<0){fail('noncanonical-record-id');break;}visit(row,0);}}
    for(const key of ownKeys(data)){if(reason!=='supported')break;if(key==='objects')continue;if(key==='toJSON'){fail('toJSON');break;}visit(data[key].value,0);}
   }
  }
 }
 return{supported:reason==='supported',reason,nodes,properties};
}
function createImmutableEncodedProducer(options={}){
 const legacy=new RawWorldDeltas(),owned=new WeakMap(),statistics={plans:0,encoded:0,legacy:0,unchanged:0,nodes:0,properties:0,intrinsicsFrameFallbacks:0,maximumFrameFallbacks:0,fallbacks:Object.create(null)};
 return freeze({
  plan(input){
   statistics.plans++;
   // A pending original transaction rejects before graph work, exactly as the
   // original method does. Do not add getter observations or error repairs.
   const eligibility=legacy.pending?{supported:false,reason:'pending',nodes:0,properties:0}:inspectImmutableEnvelope(input,options);
   statistics.nodes+=eligibility.nodes;statistics.properties+=eligibility.properties;
   const data=apply(planMethod,legacy,[input]);if(data===null){statistics.unchanged++;return null;}
   const pending=legacy.pending,scope=freeze({connection:pending.connection,generation:pending.generation,serial:pending.serial});let encoded=null;
   if(eligibility.supported&&!stableIntrinsics()){eligibility.supported=false;eligibility.reason='intrinsics-changed';}
   if(eligibility.supported&&stableIntrinsics()){
    // These arrays and the result root were JUST allocated by the exact legacy
    // planner. Freezing them does not mutate canonical input/header/row owners.
    freeze(data.objects);freeze(data.removedObjectIds);freeze(data);
    const {objects,...header}=data;
    const headerJson=nativeStringify(header,(_key,v)=>typeof v==='bigint'?{native64:nativeString(v)}:v);
    const records=new Array(objects.length);for(let i=0;i<objects.length;i++)records[i]=apply(mapGet,pending.records,[objects[i].id]);
    encoded=sealImmutableEncodedPlan({...scope,records,headerJson},IMMUTABLE_SERIALIZED_JSON);statistics.encoded++;
   }else{statistics.legacy++;statistics.fallbacks[eligibility.reason]=(statistics.fallbacks[eligibility.reason]??0)+1;}
   const envelope=freeze({...scope,data}),ticket=freeze({kind:encoded?'encoded':'legacy',reason:encoded?'verified-immutable-plain-data':eligibility.reason,envelope});owned.set(ticket,encoded);return ticket;
  },
  frames(ticket,maximum){if(!owned.has(ticket))throw Error('Foreign producer ticket');const encoded=owned.get(ticket);if(encoded&&!stableIntrinsics()){statistics.intrinsicsFrameFallbacks++;return rawWorldFrames(ticket.envelope,maximum);}if(encoded&&maximum!==undefined&&(!Number.isSafeInteger(maximum)||maximum<1)){statistics.maximumFrameFallbacks++;return rawWorldFrames(ticket.envelope,maximum);}return encoded?encodedRecordFrames(encoded,maximum):rawWorldFrames(ticket.envelope,maximum);},
  acknowledge(message){return apply(ackMethod,legacy,[message]);},
  reset(){apply(resetMethod,legacy,[]);},
  inspect(){return{...statistics,fallbacks:{...statistics.fallbacks},selectionAuthority:'Caller; this library cannot attest which host imports it',counterScope:'Plan/ticket creation and generator selection, not emitted frames',scope:'Guarded source-only producer; no implicit freezing/copying of mutable canonical graphs. Stable standard runtime intrinsics throughout framing remain a prerequisite.'};}
 });
}
// Reviewable private host adapter: ONE planner owns plan/ACK/reset and its
// encoded tickets. plan returns the original data shape the host expects.
// This adapter is not imported or selected by any production/overlay host.
function createHostCompatibleImmutableProducer(options={}){
 const producer=createImmutableEncodedProducer(options);let tickets=new WeakMap();
 return freeze({
  plan(input){const ticket=producer.plan(input);if(ticket===null)return null;tickets.set(ticket.envelope.data,ticket);return ticket.envelope.data;},
  frames(envelope,maximum){
   if(envelope===null||typeof envelope!=='object'||isProxy(envelope)||isArray(envelope))return rawWorldFrames(envelope,maximum);
   const p=prototype(envelope);if(p!==objectProto&&p!==null)return rawWorldFrames(envelope,maximum);
   const d=descriptor(envelope,'data'),c=descriptor(envelope,'connection'),g=descriptor(envelope,'generation'),s=descriptor(envelope,'serial');
   if(!d||!c||!g||!s||!('value'in d)||!('value'in c)||!('value'in g)||!('value'in s))return rawWorldFrames(envelope,maximum);
   const ticket=d.value!==null&&typeof d.value==='object'?tickets.get(d.value):null;
   if(!ticket||c.value!==ticket.envelope.connection||g.value!==ticket.envelope.generation||s.value!==ticket.envelope.serial)return rawWorldFrames(envelope,maximum);
   return producer.frames(ticket,maximum);
  },
  acknowledge:producer.acknowledge,
  reset(){producer.reset();tickets=new WeakMap();},
  inspect:producer.inspect
 });
}
module.exports={inspectImmutableEnvelope,createImmutableEncodedProducer,createHostCompatibleImmutableProducer};
