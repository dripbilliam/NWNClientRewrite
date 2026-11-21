'use strict';
// Optional internal transport contract, not a replacement for generic framing.
// Canonical Host data has deterministic serialization and is captured together
// synchronously. plan()/rawWorldFrames retain their original mutable/toJSON
// semantics; planSnapshot() freezes the encoded projection at plan time.
// Its explicitly reported generic fallback retains original mutability.
const {RawWorldDeltas}=require('../../raw-world-deltas.cjs');
const {rawWorldFrames}=require('../../raw-world-frames.cjs');
const snapshots=new WeakMap();
const stringify=value=>JSON.stringify(value,(_key,v)=>typeof v==='bigint'?{native64:String(v)}:v);
const metadataKeys=['bridgeMode','bridgeBaseSerial','removedObjectIds'];
const MAXIMUM_FRAME_BYTES=1024*1024;
const MAXIMUM_TOTAL_BYTES=64*1024*1024;

class SnapshotRawWorldDeltas {
 #deltas=new RawWorldDeltas();
 #active=null;
 #identity={};
 #retire(reason){
  if(!this.#active)return;
  const record=this.#active;this.#active=null;
  record.state=reason;record.current=null;record.rows=null;record.header=null;record.generic=null;
 }
 // Original generic API. No snapshot capture, DTO traversal or extra stringify.
 plan(input){return this.#deltas.plan(input);}
 reset(){this.#deltas.reset();this.#retire('reset');}
 acknowledge(scope){const accepted=this.#deltas.acknowledge(scope);if(accepted)this.#retire('acknowledged');return accepted;}
 planSnapshot(input){
  // This new API promises an immutable projection, not generic toJSON-per-pass
  // equivalence. Its intended caller is our synchronous canonical Host only.
  const changed=this.#deltas.plan(input);
  if(changed===null)return null;
  const pending=this.#deltas.pending;
  const scope={connection:pending.connection,generation:pending.generation,serial:pending.serial};
  const descriptor=Object.freeze({schema:'raw-world-plan-snapshot-v1',...scope,bridgeMode:changed.bridgeMode,objectCount:changed.objects.length,removedCount:changed.removedObjectIds.length});
  const record={...scope,state:'pending',identity:this.#identity,framing:'encoded',descriptor,rows:null,header:null,generic:null,current:null};
  record.current=()=>this.#active===record&&this.#deltas.pending!==null&&this.#deltas.pending.connection===record.connection&&this.#deltas.pending.generation===record.generation&&this.#deltas.pending.serial===record.serial;
  // Reserved metadata would require replacement at its existing key positions.
  // Preserve the original generic route for that non-Host envelope instead of
  // inventing a reordered or duplicate-key JSON header.
  let reusable=metadataKeys.every(key=>!Object.hasOwn(input.data,key))&&typeof pending.header==='string'&&pending.header.startsWith('{')&&pending.header.endsWith('}');
  const rows=[];
  if(reusable)for(const object of changed.objects){
   const encoded=pending.records.get(object.id);
   if(typeof encoded!=='string'){reusable=false;break;}
   rows.push(Object.freeze({encoded,bytes:Buffer.byteLength(encoded)}));
  }
  if(reusable){
   const tail=stringify({bridgeMode:changed.bridgeMode,bridgeBaseSerial:changed.bridgeBaseSerial,removedObjectIds:changed.removedObjectIds});
   record.header=pending.header==='{}'?tail:pending.header.slice(0,-1)+','+tail.slice(1);
   record.rows=Object.freeze(rows);
  }else{
   // Only this explicitly reported fallback retains decoded rows. No Map or
   // original delta-owner internals leave this module. Generic framing keeps
   // its existing callback/mutable-data behavior and error timing.
   record.framing='generic';record.generic=changed;
  }
  this.#active=record;snapshots.set(descriptor,record);
  return descriptor;
 }
 // Cold read-only mode/status: encoded promises capture-at-plan-time payload;
 // generic explicitly retains old mutable framing. Pending is not an ACK or
 // evidence that a complete stream was sent. The caller resets after errors.
 snapshotStatus(snapshot){
  const record=snapshots.get(snapshot);
  if(!record||record.identity!==this.#identity)return Object.freeze({known:false,pending:false});
  return Object.freeze({known:true,pending:record.state==='pending'&&record.current!==null&&record.current(),framing:record.framing,state:record.state});
 }
}
function pendingRecord(snapshot){
 const record=snapshots.get(snapshot);
 if(!record)throw Error('Unknown raw world plan snapshot');
 if(record.state!=='pending'||record.current===null||!record.current())throw Error('Raw world plan snapshot is stale: '+record.state);
 return record;
}
function assertPending(record){if(record.state!=='pending'||record.current===null||!record.current())throw Error('Raw world plan snapshot is stale: '+record.state);}
function* rawWorldSnapshotFrames(snapshot,maximum=MAXIMUM_FRAME_BYTES){
 const record=pendingRecord(snapshot);
 if(record.generic!==null){
  // Private new API fallback; the generic helper itself is unchanged.
  const stream=rawWorldFrames({serial:record.serial,generation:record.generation,data:record.generic,connection:record.connection},maximum);
  while(true){assertPending(record);const next=stream.next();if(next.done)return;assertPending(record);yield next.value;}
 }
 const suffix=',"connection":'+record.connection+'}';
 const encode=text=>{if(Buffer.byteLength(text)>maximum)throw Error('Raw protocol record exceeds frame bound');return text+'\n';};
 const prefix=kind=>'{'+'"kind":"raw-world-'+kind+'","serial":'+record.serial+',"generation":'+record.generation;
 assertPending(record);
 yield encode(prefix('begin')+',"count":'+record.descriptor.objectCount+',"data":'+record.header+suffix);
 assertPending(record);
 let batch=[],size=0,total=0;
 for(const row of record.rows){
  assertPending(record);total+=row.bytes;
  if(total>MAXIMUM_TOTAL_BYTES)throw Error('Raw world snapshot exceeds bound');
  if(batch.length&&(batch.length>=64||size+row.bytes+1024>maximum)){
   yield encode(prefix('chunk')+',"objects":['+batch.join(',')+']'+suffix);
   assertPending(record);batch=[];size=0;
  }
  batch.push(row.encoded);size+=row.bytes+1;
 }
 assertPending(record);
 if(batch.length){yield encode(prefix('chunk')+',"objects":['+batch.join(',')+']'+suffix);assertPending(record);}
 yield encode(prefix('end')+suffix);
}
module.exports={SnapshotRawWorldDeltas,rawWorldSnapshotFrames,rawWorldFrames,MAXIMUM_FRAME_BYTES,MAXIMUM_TOTAL_BYTES};
