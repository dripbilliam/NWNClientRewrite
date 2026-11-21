'use strict';
// Opt-in observation composed with every existing ScriptFloating gate.
const {ScriptFloatingCapture}=require('./native-script-floating-capture.cjs');
const {isDeepStrictEqual}=require('node:util');
const MARKERS=Object.freeze(['NATIVE_SPEECH_FIRST','NATIVE_SPEECH_REPLACEMENT']);
const clone=value=>structuredClone(value),marker=message=>message?.kind==='server-speech'&&MARKERS.includes(message.text?.text);
function nativeOrdinaryAccepted(value){
 const defaults={mode:2,largeFont:true},font='ttf fnt_default_hr 16';
 return value?.success===true&&value.checks===15&&value.failures?.length===0&&['stored','gameplay','owner','registry'].every(key=>isDeepStrictEqual(value.freshPopupPreferences?.[key],defaults))&&[value.first,value.replacement].every(row=>row?.mode===2&&row.font===font&&row.clock?.delegated===true&&row.clock.sharedRecord===true&&row.clock.registryTracked===true&&row.clock.registered===true);
}
class OrdinarySpeechCapture extends ScriptFloatingCapture{
 constructor(decode,identities){super(decode,identities);this.speechCommands=[];this.speechPackets=[];this.speechDeliveries=[];this.speechFailure=null;}
 command(message,session,connection){
  if(!MARKERS.includes(message?.text))return;
  if(!this.current(session,connection)||message.kind!=='chat'||message.channel!==1||message.generation!==this.scope.generation||message.areaId!==this.scope.areaId||message.actorId!==undefined&&message.actorId!==this.source.id)throw Error('Ordinary speech command scope differs');
  if(this.speechCommands.length>=2||message.text!==MARKERS[this.speechCommands.length])throw Error('Ordinary speech command order/count differs');
  this.speechCommands.push({at:Date.now(),kind:'chat',channel:message.channel,text:message.text,generation:message.generation,areaId:message.areaId,...(message.actorId!==undefined?{actorId:message.actorId}:{})});
 }
 packet(session,connection,bytes){
  super.packet(session,connection,bytes);
  if(!this.owner||bytes?.[0]!==80||bytes?.[1]!==9)return;
  if(bytes.length>4096){this.speechFailure??='Ordinary speech packet exceeds4KiB';return;}
  const message=this.decode(bytes,{serverBuild:session.serverBuild});if(!marker(message))return;
  if(!this.current(session,connection)||message.channel!==1||message.objectId!==this.source.id){this.speechFailure??='Ordinary speech packet scope differs';return;}
  if(this.speechPackets.length>=2||message.text.text!==MARKERS[this.speechPackets.length]){this.speechFailure??='Ordinary speech packet order/count differs';return;}
  this.speechPackets.push({at:Date.now(),major:9,minor:message.minor,hex:Buffer.from(bytes).toString('hex'),message:clone(message)});
 }
 delivered(frame,session,connection){
  super.delivered(frame,session,connection);if(!this.owner||frame.kind!=='ui-protocol'||!marker(frame.message))return;
  const message=clone(frame.message),metadata=message.nativeTextEvent;delete message.nativeTextEvent;
  if(!this.current(session,connection)||frame.connection!==undefined&&frame.connection!==connection||frame.generation!==this.scope.generation||message.channel!==1||message.objectId!==this.source.id||!metadata||metadata.version!==1||!Number.isSafeInteger(metadata.serial)||metadata.serial<1||metadata.connection!==connection||metadata.generation!==this.scope.generation||metadata.areaId!==this.scope.areaId||!isDeepStrictEqual(metadata.source,this.source)){this.speechFailure??='Ordinary speech Host provenance differs';return;}
  if(this.speechDeliveries.length>=2||message.text.text!==MARKERS[this.speechDeliveries.length]){this.speechFailure??='Ordinary speech delivery order/count differs';return;}
  this.speechDeliveries.push({at:Date.now(),message,metadata:clone(metadata),currentHostConnection:connection,explicitFrameConnection:frame.connection??null});
 }
 finish(native){
  const inherited=super.finish(native),ordinary=native?.ordinarySpeech;
  const checks={inheritedChecksPreserved:inherited.success&&Object.keys(inherited.checks).length===10&&native?.checks===16&&native?.failures?.length===0,commands:this.speechCommands.length===2,packets:this.speechPackets.length===2,deliveries:this.speechDeliveries.length===2,payloadMatch:this.speechPackets.length===2&&this.speechPackets.every((p,i)=>isDeepStrictEqual(p.message,this.speechDeliveries[i]?.message)),nativeAccepted:nativeOrdinaryAccepted(ordinary),nativeScope:isDeepStrictEqual(ordinary?.scope,this.scope)&&isDeepStrictEqual(ordinary?.source,this.source),receivedSerials:this.speechDeliveries.length===2&&ordinary?.first?.serial===this.speechDeliveries[0].metadata.serial&&ordinary?.replacement?.serial===this.speechDeliveries[1].metadata.serial,noCaptureFailure:this.speechFailure===null};
  return {...inherited,success:inherited.success&&Object.values(checks).every(Boolean),ordinarySpeechProof:{success:Object.values(checks).every(Boolean),checks,commands:clone(this.speechCommands),packets:clone(this.speechPackets),deliveries:clone(this.speechDeliveries),failure:this.speechFailure,native:clone(ordinary??null),scope:'Actual major9/Talk received packets and corresponding Host provenance; provenance must be independently supplied by the owned original-server wrapper. Authored unit tests are not live evidence.'}};
 }
}
module.exports={OrdinarySpeechCapture,MARKERS};
