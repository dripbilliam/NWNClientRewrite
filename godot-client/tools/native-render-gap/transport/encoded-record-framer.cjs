'use strict';
const {rawWorldFrames}=require('../../raw-world-frames.cjs');
const SNAPSHOT_BYTES=64*1024*1024,FRAME_BYTES=1024*1024,OBJECTS_PER_FRAME=64;
const issued=new WeakSet();
// Explicit PRIVATE producer assertion, not a detector of graph immutability.
// Only trusted, canonical JSON.stringify(native64-replacer) output may be sealed.
// Never call this for received strings, arbitrary object APIs, accessors, toJSON,
// mutable aliases or rows that can change at a yielded socket-write boundary.
const IMMUTABLE_SERIALIZED_JSON=Symbol('private-owned-canonical-json-strings-v1');
function sealImmutableEncodedPlan(input,contract){
 if(contract!==IMMUTABLE_SERIALIZED_JSON)throw Error('Explicit immutable serialized producer contract required');
 const {serial,generation,connection,records,headerJson}=input;
 if(!Number.isSafeInteger(serial)||serial<1||!Number.isSafeInteger(generation)||generation<0||!Array.isArray(records)||records.length>65536)throw Error('Invalid raw world envelope');
 if(connection!==undefined&&(!Number.isSafeInteger(connection)||connection<0))throw Error('Invalid raw world connection');
 if(typeof headerJson!=='string')throw Error('Canonical serialized header required');
 const strings=new Array(records.length);for(let i=0;i<records.length;i++){if(typeof records[i]!=='string')throw Error('Canonical serialized record required');strings[i]=records[i];}
 const plan=Object.freeze({serial,generation,connection,records:Object.freeze(strings),headerJson});issued.add(plan);return plan;
}
function* frameWithBudget(plan,maximum,snapshotBudget){
 if(!issued.has(plan))throw Error('Unissued encoded plan');
 const {serial,generation,connection,records,headerJson}=plan;
 const tail=connection===undefined?'':',"connection":'+connection;
 const encode=text=>{if(Buffer.byteLength(text)>maximum)throw Error('Raw protocol record exceeds frame bound');return text+'\n';};
 // UTF16 length is a lower bound for these UTF8 bytes. Reject a definitely
 // oversized header before concatenating it, at the same first-next boundary.
 if(headerJson.length>maximum)throw Error('Raw protocol record exceeds frame bound');
 const begin='{"kind":"raw-world-begin","serial":'+serial+',"generation":'+generation+',"count":'+records.length+',"data":'+headerJson+tail+'}';
 yield encode(begin);
 let batch=[],size=0,total=0;
 const chunk=()=>encode('{"kind":"raw-world-chunk","serial":'+serial+',"generation":'+generation+',"objects":['+batch.join(',')+']'+tail+'}');
 for(const record of records){
  const bytes=Buffer.byteLength(record);total+=bytes;
  // Preserve the original check-before-flush order, including the65th row.
  if(total>snapshotBudget)throw Error('Raw world snapshot exceeds bound');
  if(batch.length&&(batch.length>=OBJECTS_PER_FRAME||size+bytes+1024>maximum)){yield chunk();batch=[];size=0;}
  batch.push(record);size+=bytes+1;
 }
 if(batch.length)yield chunk();
 yield encode('{"kind":"raw-world-end","serial":'+serial+',"generation":'+generation+tail+'}');
}
function encodedRecordFrames(plan,maximum=FRAME_BYTES){return frameWithBudget(plan,maximum,SNAPSHOT_BYTES);}
// Unknown/unbranded input retains the actual legacy API and its getters,
// mutation observation, lazy exceptions and serialization behavior unchanged.
function selectWorldFrames({encodedPlan,legacyEnvelope},maximum=FRAME_BYTES){return issued.has(encodedPlan)?encodedRecordFrames(encodedPlan,maximum):rawWorldFrames(legacyEnvelope,maximum);}
module.exports={IMMUTABLE_SERIALIZED_JSON,sealImmutableEncodedPlan,encodedRecordFrames,selectWorldFrames,constants:Object.freeze({SNAPSHOT_BYTES,FRAME_BYTES,OBJECTS_PER_FRAME}),_testing:Object.freeze({withSnapshotBudget:(plan,maximum,budget)=>{if(!Number.isSafeInteger(budget)||budget<1||budget>SNAPSHOT_BYTES)throw Error('Invalid test budget');return frameWithBudget(plan,maximum,budget);}})};
