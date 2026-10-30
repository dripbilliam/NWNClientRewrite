// Wire identity and decoded fields only. Godot owns the original class cast,
// resource reference, positional cue, resource IO and audio playback.
class RawScriptSounds {
 constructor(identities){this.identities=identities;this.serial=0;}
 frame(world,message,generation,connection){
  if(message.kind!=='script-sound')return null;
  const object=world.registry.get(message.objectId);
  if(!object||object.replicationRemoved||(object.areaId!==world.areaId&&!(object.objectType===4&&object.id===world.areaId)&&object.objectType!==3))return null;
  const source={id:object.id,objectType:object.objectType,lifetime:this.identities.identity(object)};
  for(const field of ['replicated','staticState','lightState','state','mapPin'])if(object[field]?.position!==undefined)source[field]={position:structuredClone(object[field].position)};
  const value=message.soundBytes!==undefined?{soundBytes:Array.from(message.soundBytes)}:{sound:message.sound};
  return {kind:'raw-script-sounds',connection,generation,areaId:world.areaId,serial:++this.serial,events:[{source,...value}]};
 }
}
module.exports={RawScriptSounds};
