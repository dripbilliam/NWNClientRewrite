// Decoded voice26/1 identity transport only. Godot selects SSF/WAV/resources,
// source priorities and playback; this module performs no audio preparation.
class RawVoiceEvents {
 constructor(identities){this.identities=identities;this.serial=0;}
 frame(world,message,generation,connection){
  if(message.kind!=='voice-play')return null;
  const object=world.registry.get(message.objectId);
  if(!object||object.objectType!==5||object.replicationRemoved||object.areaId!==world.areaId)return null;
  return {kind:'raw-voice-events',connection,generation,areaId:world.areaId,serial:++this.serial,events:[{objectId:message.objectId,voiceCode:message.voiceCode&255,lifetime:this.identities.identity(object),soundsetId:(object.appearance?.field8A0??65535)&65535}]};
 }
}
module.exports={RawVoiceEvents};
