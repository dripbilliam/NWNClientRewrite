'use strict';
// Transport facts only. No timer construction, world mirror, lookup or simulation.
const MAX_FRAMES=64,MAX_BYTES=1024*1024,MAX_SERIAL=Number.MAX_SAFE_INTEGER;
const own=(value,key)=>{if(value===null||typeof value!=='object')return undefined;const d=Object.getOwnPropertyDescriptor(value,key);return d&&Object.hasOwn(d,'value')?d.value:undefined;};
const uint=(value,max=0xffffffff)=>Number.isInteger(value)&&value>=0&&value<=max;
const serial=value=>Number.isSafeInteger(value)&&value>=0;
const life=value=>value===null||Number.isSafeInteger(value)&&value>0;
const GAP_REASONS=new Set(['decoder-rejected','incomplete-records','lifecycle-gap','late-bind','transport-gap','capture-incomplete','source-unknown','reset-unverified']);
const freeze=value=>{if(value&&typeof value==='object'){for(const key of Object.keys(value))freeze(value[key]);Object.freeze(value);}return value;};
function scope(value={}){
 const generation=own(value,'generation'),areaId=own(value,'areaId');
 if(generation!==undefined&&generation!==null&&!serial(generation)||areaId!==undefined&&areaId!==null&&!uint(areaId))throw Error('Invalid clock ingress scope');
 return {generation:generation??null,areaId:areaId??null};
}
function project(message){
 const type=own(message,'kind');
 if(type==='module-info'){const rate=own(own(message,'module'),'minutesPerHour');if(!uint(rate,255))throw Error('Invalid module clock rate');return {type,minutesPerHour:rate};}
 if(type==='module-time'){const mask=own(message,'mask');if(!uint(mask,255))throw Error('Invalid module-time boundary');return {type,mask};}
 if(type==='module-pause-state'){
  const mask=own(message,'mask'),value=own(message,'value'),source=own(message,'exclusionIds');
  if(!uint(mask,3)||!uint(value,1)||!Array.isArray(source)||source.length>65535)throw Error('Invalid received clock pause fields');
  const exclusionIds=[];for(let at=0;at<source.length;at++){const id=own(source,String(at));if(!uint(id))throw Error('Invalid pause exclusion ID');exclusionIds.push(id);}
  return {type,mask,value,exclusionIds};
 }
 if(type==='client-area'){const areaId=own(own(message,'area'),'id');if(!uint(areaId))throw Error('Invalid client-area clock boundary');return {type,areaId};}
 if(type==='object-control'){
  const playerId=own(message,'playerId'),objectId=own(message,'objectId'),major=own(message,'major'),minor=own(message,'minor');
  if(!uint(playerId)||!uint(objectId)||!(major===5&&minor===2||major===14&&minor===14))throw Error('Invalid native control boundary');
  return {type,playerId,objectId,sourceMajor:major,sourceMinor:minor};
 }
 return null;
}
function lifecycle(fact){
 const operation=own(fact,'operation'),recordIndex=own(fact,'recordIndex'),objectId=own(fact,'objectId'),objectType=own(fact,'objectType');
 const nativeLifetime=own(fact,'nativeLifetime'),knownLifetimeBefore=own(fact,'knownLifetimeBefore'),knownLifetimeAfter=own(fact,'knownLifetimeAfter'),ownership=own(fact,'ownership'),deletionFlag=own(fact,'deletionFlag'),cause=own(fact,'cause');
 if(!['create','remove','reset'].includes(operation)||!serial(recordIndex)||!uint(objectId)||!uint(objectType,255)||objectType===0||!life(nativeLifetime)||!life(knownLifetimeBefore)||!life(knownLifetimeAfter)||!['new','retained','unknown'].includes(ownership)||!(deletionFlag===null||typeof deletionFlag==='boolean')||typeof cause!=='string'||!/^[A-Za-z0-9_.:-]{1,64}$/.test(cause))throw Error('Invalid private accepted lifecycle fact');
 return {type:'accepted-lifecycle',operation,recordIndex,objectId,objectType,nativeLifetime,knownLifetimeBefore,knownLifetimeAfter,ownership,deletionFlag,cause};
}
function nativeLifecycle(accepted,connection){
 const epoch=own(accepted,'epoch'),transaction=own(accepted,'transaction'),receivedConnection=own(accepted,'connection');
 const complete=own(accepted,'complete'),recordHistoryComplete=own(accepted,'recordHistoryComplete'),constructionHistoryComplete=own(accepted,'constructionHistoryComplete');
 if(own(accepted,'version')!==1||!Number.isSafeInteger(epoch)||epoch<1||!Number.isSafeInteger(transaction)||transaction<1||receivedConnection!==connection||typeof complete!=='boolean'||recordHistoryComplete!==complete||typeof constructionHistoryComplete!=='boolean')throw Error('Invalid actual lifecycle boundary');
 const fact=own(accepted,'fact'),operation=own(fact,'operation'),recordIndex=own(fact,'recordIndex'),objectId=own(fact,'objectId'),objectType=own(fact,'objectType'),ownership=own(fact,'ownership'),deletionFlag=own(fact,'deletionFlag'),areaId=own(fact,'areaId'),physicalToken=own(fact,'physicalToken');
 const ownerAbsentCertified=own(fact,'ownerAbsentCertified'),constructionCertified=own(fact,'constructionCertified'),aiRegistrationCertified=own(fact,'aiRegistrationCertified');
 if(!['create','remove'].includes(operation)||!serial(recordIndex)||!uint(objectId)||objectId<0x80000000||objectType!==5||!['new','retained','unknown'].includes(ownership)||![null,0,1].includes(deletionFlag)||!(areaId===null||uint(areaId))||!(physicalToken===null||typeof physicalToken==='string'&&/^[A-Za-z0-9_.:-]{1,128}$/.test(physicalToken))||typeof ownerAbsentCertified!=='boolean'||typeof constructionCertified!=='boolean'||typeof aiRegistrationCertified!=='boolean')throw Error('Invalid actual lifecycle fact');
 if(operation==='create'&&deletionFlag!==null||operation==='remove'&&deletionFlag===null||constructionCertified&&(operation!=='create'||ownership!=='new'||physicalToken===null||!aiRegistrationCertified||!constructionHistoryComplete)||aiRegistrationCertified&&!constructionCertified||ownerAbsentCertified&&(operation!=='remove'||physicalToken!==null)||ownership==='unknown'&&physicalToken!==null)throw Error('Contradictory actual lifecycle certification');
 return {type:'accepted-lifecycle',version:2,lifecycleEpoch:epoch,transaction,operation,recordIndex,objectId,objectType,ownership,deletionFlag,areaId,physicalToken,ownerAbsentCertified,constructionCertified,aiRegistrationCertified,constructionHistoryComplete};
}
class NativeClockIngress {
 #send; #beginHistory; #readLifecycle; #maximumFrames; #maximumBytes; #maximumSerial;
 #session; #connection; #lastConnection; #sequence; #queue; #bytes; #pendingGap; #complete; #reason; #counts; #uncertain;
 constructor({send,beginHistory=null,acceptedLifecycle=null,maximumFrames=MAX_FRAMES,maximumBytes=MAX_BYTES,maximumSerial=MAX_SERIAL}={}){
  if(typeof send!=='function'||beginHistory!==null&&typeof beginHistory!=='function'||acceptedLifecycle!==null&&typeof acceptedLifecycle!=='function'||!Number.isInteger(maximumFrames)||maximumFrames<1||maximumFrames>MAX_FRAMES||!Number.isInteger(maximumBytes)||maximumBytes<1||maximumBytes>MAX_BYTES||!Number.isSafeInteger(maximumSerial)||maximumSerial<1)throw TypeError('Invalid clock ingress options');
  this.#send=send;this.#beginHistory=beginHistory;this.#readLifecycle=acceptedLifecycle;this.#maximumFrames=maximumFrames;this.#maximumBytes=maximumBytes;this.#maximumSerial=maximumSerial;
  this.#session=null;this.#connection=-1;this.#lastConnection=-1;this.#sequence=0;this.#queue=[];this.#bytes=0;this.#pendingGap=null;this.#complete=false;this.#reason='not-begun';this.#counts={};this.#uncertain=false;
 }
 #note(name){this.#counts[name]=Math.min(MAX_SERIAL,(this.#counts[name]??0)+1);}
 #current(session,connection){if(this.#session!==session||this.#session===null||this.#connection!==connection){this.#note('stale');return false;}return true;}
 #taint(reason){this.#note('taints');if(this.#complete||!this.#reason){this.#reason=reason;}this.#complete=false;this.#pendingGap??=reason;}
 begin(session,connection){
  if(!session||typeof session!=='object'||Array.isArray(session)||!serial(connection))throw TypeError('Invalid clock ingress begin owner');
  if(connection<=this.#lastConnection){this.#note('stale');return {recorded:false,reason:'old-or-duplicate-connection'};}
  this.#session=session;this.#connection=connection;this.#lastConnection=connection;this.#sequence=0;this.#queue=[];this.#bytes=0;this.#pendingGap=null;this.#counts={};this.#uncertain=false;
  let trusted=false;try{trusted=this.#beginHistory!==null&&this.#beginHistory(session)===true;}catch{this.#note('beginHistoryErrors');}
  this.#complete=trusted&&this.#readLifecycle!==null;this.#reason=this.#complete?null:trusted?'lifecycle-unbound':'begin-unverified';
  return this.#emit({type:'begin',lifecycleBound:this.#readLifecycle!==null},scope());
 }
 #frame(event,selectedScope){
  if(this.#sequence>=this.#maximumSerial){this.#taint('serial-exhausted');this.#note('serialExhausted');return null;}
  const frame=freeze({kind:'native-clock-protocol',version:1,connection:this.#connection,serial:++this.#sequence,history:{complete:this.#complete,reason:this.#reason},scope:selectedScope,event});
  const encoded=JSON.stringify(frame)+'\n';return {frame,encoded,bytes:Buffer.byteLength(encoded)};
 }
 #sendOne(item){
  this.#note('sendAttempts');let result;
  try{result=this.#send(item.frame,item.encoded);}catch{result=null;}
  const status=own(result,'status');
  if(status==='accepted'){
   const pressure=own(result,'backpressure');if(pressure!==undefined&&typeof pressure!=='boolean'){this.#note('unknown');this.#uncertain=true;this.#taint('delivery-unknown');return 'unknown';}
   this.#note('accepted');if(pressure)this.#note('backpressure');return 'accepted';
  }
  if(status==='unavailable'){this.#note('unavailable');return 'unavailable';}
  // An exception, Promise, bare bool (including socket.write(false)), malformed
  // or explicit unknown outcome may already have written bytes. Never retry it.
  this.#note('unknown');this.#uncertain=true;this.#taint('delivery-unknown');return 'unknown';
 }
 #enqueue(item){
  if(item.bytes>this.#maximumBytes||this.#queue.length>=this.#maximumFrames||this.#bytes+item.bytes>this.#maximumBytes){this.#note('dropped');this.#note('overflows');this.#taint('queue-overflow');return 'dropped';}
  this.#queue.push(item);this.#bytes+=item.bytes;return 'queued';
 }
 #deliver(item,allowSend=true){
  if(!item)return {recorded:false,reason:'serial-exhausted'};
  if(item.bytes>MAX_BYTES){this.#note('dropped');this.#taint('frame-oversize');return {recorded:false,delivery:'dropped',serial:item.frame.serial};}
  if(this.#queue.length||!allowSend||this.#uncertain){const delivery=this.#enqueue(item);return {recorded:delivery!=='dropped',delivery,serial:item.frame.serial};}
  const outcome=this.#sendOne(item);
  const delivery=outcome==='unavailable'?this.#enqueue(item):outcome==='unknown'?'uncertain':'accepted';
  return {recorded:delivery!=='dropped',delivery,serial:item.frame.serial};
 }
 #drain(){
  if(this.#uncertain)return 'unknown';
  while(this.#queue.length){
   const item=this.#queue[0],outcome=this.#sendOne(item);
   if(outcome==='unavailable')return 'unavailable';
   this.#queue.shift();this.#bytes-=item.bytes;
   if(outcome==='unknown')return 'unknown';
  }
  return 'open';
 }
 flush(session,connection){
  if(!this.#current(session,connection))return {recorded:false,reason:'stale-session'};
  const result=this.#drain();if(result!=='open')return {recorded:true,delivery:result==='unknown'?'uncertain':'queued'};
  if(this.#pendingGap){const cause=this.#pendingGap;this.#pendingGap=null;return this.#deliver(this.#frame({type:'history-gap',cause},scope()));}
  return {recorded:true,delivery:'idle'};
 }
 #emit(event,selectedScope){
  const flushed=this.flush(this.#session,this.#connection);
  return this.#deliver(this.#frame(event,selectedScope),flushed.delivery!=='uncertain');
 }
 observe(session,connection,message,selectedScope={}){
  if(!this.#current(session,connection))return {recorded:false,reason:'stale-session'};
  let event,projectedScope;
  try{event=project(message);projectedScope=scope(selectedScope);}catch{this.#taint('invalid-clock-event');return {recorded:false,reason:'invalid-clock-event'};}
  if(event===null){this.#note('ignored');return {recorded:false,reason:'not-clock-event'};}
  return this.#emit(event,projectedScope);
 }
 lifecycle(session,connection,privateBoundary,selectedScope={}){
  if(!this.#current(session,connection))return {recorded:false,reason:'stale-session'};
  let accepted,event,projectedScope;
  try{
   if(this.#readLifecycle===null)throw Error('Unbound private lifecycle callback');
   accepted=this.#readLifecycle(session,privateBoundary);if(accepted===null)return {recorded:false,reason:'not-lifecycle-event'};
   if(typeof own(accepted,'complete')!=='boolean')throw Error('Missing private history certainty');
   event=own(accepted,'source')==='native_client_clock_lifecycle_v1'?nativeLifecycle(accepted,connection):lifecycle(own(accepted,'fact'));projectedScope=scope(selectedScope);
  }catch{this.#taint('invalid-lifecycle-fact');return {recorded:false,reason:'invalid-lifecycle-fact'};}
  if(own(accepted,'complete')!==true)this.#taint('incomplete-records');
  return this.#emit(event,projectedScope);
 }
 gap(session,connection,reason){
  if(!this.#current(session,connection))return {recorded:false,reason:'stale-session'};
  if(!GAP_REASONS.has(reason))throw TypeError('Unknown clock history gap reason');
  this.#taint(reason);return this.flush(session,connection);
 }
 retire(session,connection){
  if(!this.#current(session,connection))return {retired:false};
  const discardedFrames=this.#queue.length;this.#session=null;this.#queue=[];this.#bytes=0;this.#pendingGap=null;this.#complete=false;this.#reason='retired';return {retired:true,discardedFrames};
 }
 snapshot(){return {active:this.#session!==null,connection:this.#connection,lastConnection:this.#lastConnection,serial:this.#sequence,history:{complete:this.#complete,reason:this.#reason},transportUncertain:this.#uncertain,queuedFrames:this.#queue.length,queuedBytes:this.#bytes,pendingGap:this.#pendingGap,limits:{frames:this.#maximumFrames,bytes:this.#maximumBytes,serial:this.#maximumSerial},counts:{...this.#counts}};}
}
module.exports={NativeClockIngress,MAX_CLOCK_INGRESS_FRAMES:MAX_FRAMES,MAX_CLOCK_INGRESS_BYTES:MAX_BYTES};
