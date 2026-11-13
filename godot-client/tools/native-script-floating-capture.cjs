'use strict';
// Opt-in test observation only. It never supplies an actor, packet or outcome.
const {isDeepStrictEqual}=require('node:util');
const clone=value=>structuredClone(value),uint32=value=>Number.isInteger(value)&&value>=0&&value<=0xffffffff,positive=value=>Number.isSafeInteger(value)&&value>=1;
function actorOwner(session,connection,identities){
 if(session?.closed||session?.phase!=='playing'||!session?.peer||session.peer.closed||!Number.isSafeInteger(connection)||connection<0||!Number.isSafeInteger(session?.areaGeneration)||session.areaGeneration<0||!uint32(session?.world?.areaId))throw Error('ScriptFloating current admitted scope is unavailable');
 const actor=session.world.registry.get(session.world.localObjectId);if(!actor||actor.objectType!==5||actor.replicationRemoved||actor.destroyed||actor.areaId!==session.world.areaId||!uint32(actor.id))throw Error('Actual current creature target required');
 const nativeLifetime=identities.identity(actor),knownLifetime=session.world.entityDisclosures.token(actor);if(!positive(nativeLifetime)||!positive(knownLifetime))throw Error('Current disclosure identities required');
 return {session,peer:session.peer,world:session.world,actor,scope:{connection,generation:session.areaGeneration,areaId:session.world.areaId},source:{id:actor.id,objectType:actor.objectType,areaId:actor.areaId,nativeLifetime,knownLifetime}};
}
class ScriptFloatingCapture{
 constructor(decode,identities){if(typeof decode!=='function'||typeof identities?.identity!=='function')throw Error('Actual decoder/identity owners required');this.decode=decode;this.identities=identities;this.owner=null;this.peer=null;this.world=null;this.sourceObject=null;this.scope=null;this.source=null;this.readiness=null;this.readyOwner=null;this.packets=[];this.deliveries=[];this.failure=null;}
 ready(session,connection,observed){
  if(this.readiness)throw Error('ScriptFloating readiness already dispatched');
  const selected=actorOwner(session,connection,this.identities),state=observed?.state;
  if(observed?.kind!=='observed'||observed.connection!==connection||observed.generation!==selected.scope.generation||observed.areaId!==selected.scope.areaId||!positive(observed.nativeProcessId)||!state||state.ready!==true||state.admission_ready!==true||state.object_visuals_complete!==true||state.pending_batches!==0||!['entities','hidden','desired'].every(key=>Number.isSafeInteger(state[key])&&state[key]>=0)||state.desired<1||state.entities+state.hidden!==state.desired||state.generation!==selected.scope.generation||state.area_id!==selected.scope.areaId||state.controlled_id!==selected.source.id)throw Error('Actual current native raw world is not ready for ScriptFloating');
  this.readyOwner=selected;this.readiness={at:Date.now(),scope:clone(selected.scope),source:clone(selected.source),sessionPhase:session.phase,nativeProcessId:observed.nativeProcessId,native:{ready:true,admission_ready:true,object_visuals_complete:true,pending_batches:0,entities:state.entities,hidden:state.hidden,desired:state.desired,generation:state.generation,area_id:state.area_id,controlled_id:state.controlled_id},movementAcceptance:false,pixelAcceptance:false};return clone(this.readiness);
 }
 arm(session,connection){
  if(this.owner)throw Error('ScriptFloating stimulus already armed');const selected=actorOwner(session,connection,this.identities),ready=this.readyOwner;
  if(!ready||ready.session!==session||ready.peer!==selected.peer||ready.world!==selected.world||ready.actor!==selected.actor||!isDeepStrictEqual(this.readiness.scope,selected.scope)||!isDeepStrictEqual(this.readiness.source,selected.source))throw Error('ScriptFloating readiness retired before stimulus');
  this.owner=session;this.peer=selected.peer;this.world=selected.world;this.sourceObject=selected.actor;this.scope=selected.scope;this.source=selected.source;
 }
 current(session,connection){if(!this.owner||session!==this.owner||session.closed||session.phase!=='playing'||session.peer!==this.peer||this.peer.closed||session.world!==this.world||connection!==this.scope.connection||session.areaGeneration!==this.scope.generation||session.world.areaId!==this.scope.areaId||session.world.localObjectId!==this.source.id)return false;const actor=session.world.registry.get(this.source.id);return actor===this.sourceObject&&actor.objectType===5&&!actor.replicationRemoved&&!actor.destroyed&&actor.areaId===this.source.areaId&&this.identities.identity(actor)===this.source.nativeLifetime&&session.world.entityDisclosures.token(actor)===this.source.knownLifetime;}
 packet(session,connection,bytes){
  if(!this.owner||bytes?.[0]!==80||bytes?.[1]!==18||bytes?.[2]!==11)return;
  if(bytes.length>4096){this.failure??='Feedback game message exceeds4KiB capture bound';return;}
  const message=this.decode(bytes,{serverBuild:session.serverBuild});if(![93,94].includes(message.type))return;
  if(!this.current(session,connection)){this.failure??='ScriptFloating packet scope retired';return;}
  if(this.packets.length>=8){this.failure??='ScriptFloating packet count exceeds8';return;}
  this.packets.push({at:Date.now(),major:18,minor:11,hex:Buffer.from(bytes).toString('hex'),message:clone(message)});
 }
 delivered(frame,session,connection){
  if(!this.owner||frame.kind!=='ui-protocol'||frame.message?.kind!=='combat-feedback'||![93,94].includes(frame.message.type))return;
  if(!this.current(session,connection)||frame.generation!==this.scope.generation||frame.connection!==undefined&&frame.connection!==connection){this.failure??='ScriptFloating Host delivery scope retired';return;}
  const message=clone(frame.message),metadata=message.nativeTextEvent;delete message.nativeTextEvent;
  if(!metadata||metadata.version!==1||!positive(metadata.serial)||metadata.connection!==connection||metadata.generation!==this.scope.generation||metadata.areaId!==this.scope.areaId||!isDeepStrictEqual(metadata.source,this.source)){this.failure??='ScriptFloating actual Host source metadata differs';return;}
  if(this.deliveries.length>=8){this.failure??='ScriptFloating delivery count exceeds8';return;}
  this.deliveries.push({at:Date.now(),message,metadata:clone(metadata)});
 }
 finish(native){
  const checks={actualReadySource:Boolean(this.readiness&&isDeepStrictEqual(this.readiness.scope,this.scope)&&isDeepStrictEqual(this.readiness.source,this.source)),capturedPacketCount:this.packets.length===4,matchingDeliveryCount:this.deliveries.length===4,oneToOnePayload:this.packets.length===this.deliveries.length&&this.packets.every((packet,index)=>isDeepStrictEqual(packet.message,this.deliveries[index].message)),expectedNativeFields:false,nativeOwnerAccepted:native?.success===true,nativeSourceScope:isDeepStrictEqual(native?.scope,this.scope),nativeTargetIdentity:isDeepStrictEqual(native?.source,this.source),sourceStillCurrent:Boolean(this.owner&&this.current(this.owner,this.scope.connection)),noCaptureFailure:this.failure===null};
  const expected=[{type:93,echo:0},{type:93,echo:1},{type:94,echo:0,text:'NATIVE_SCRIPT94_NO_ECHO'},{type:94,echo:1,text:'NATIVE_SCRIPT94_ECHO'}];
  checks.expectedNativeFields=this.packets.length===4&&this.packets.every(({message},index)=>{const row=expected[index],data=message.data;return message.type===row.type&&data.objects['0']===this.source.id&&data.integers[row.type===93?'1':'0']===row.echo&&(row.type===93?data.integers['0']===57779:data.strings['0']?.text===row.text);});
  return {success:Object.values(checks).every(Boolean),checks,...this.snapshot(),native:clone(native),scopeDescription:'Captured game-message input, real decoder and matching Host source echo. Original-server provenance must be supplied independently by the owned live runner/fixture; focused unit tests may supply authored codec bytes.'};
 }
 nativeExit(value,endSourceCurrent){
  const checks={nativeLifecycle:value?.success===true&&!value?.failure,playable:value?.playable===true,objectsComplete:value?.object_visuals_complete===true,environment:value?.environment_accepted===true,workersDrained:value?.workers_remaining===0,finishAcknowledged:value?.protocol_finish_ack===true,currentEndSource:endSourceCurrent===true,nativeWorldScope:Boolean(this.scope&&value?.world?.ready===true&&value.world.generation===this.scope.generation&&value.world.area_id===this.scope.areaId&&value.world.controlled_id===this.source.id),noMovementClaim:value?.gameplay_success===false};
  return {success:Object.values(checks).every(Boolean),checks,nativeGameplaySuccess:value?.gameplay_success??null,movementAcceptance:false,pixelAcceptance:false,scope:'Dedicated ScriptFloating lifecycle/current-world validation; generic movement/picking and pixel acceptance are not claimed.'};
 }
 snapshot(){return {readiness:clone(this.readiness),scope:clone(this.scope),source:clone(this.source),packets:clone(this.packets),deliveries:clone(this.deliveries),failure:this.failure,observationSource:'Reassembled peer game-message input; caller must independently retain original-server fixture/endpoint identity.'};}
}
module.exports={ScriptFloatingCapture};
