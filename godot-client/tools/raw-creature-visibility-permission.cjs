// Fresh 31/22 permission deliveries. Native stats110/114 are LOCAL caches;
// Godot owns their constructor/AI lifetime. Never replay a sticky header.
const uint=value=>Number.isInteger(value)&&value>=0&&value<=0xffffffff;
const {rawEntityLifetime:life}=require('./raw-entity-lifetime.cjs');
class RawCreatureVisibilityPermission{
 constructor(project=(world,actor)=>actor){if(typeof project!=='function')throw new TypeError('Visibility identity projection must be callable');this.project=project;this.serial=0;this.unavailable=0;}
 frames(world,message,generation,connection){
  if(message.kind!=='game-master-permission')return[];
  if(!uint(connection)||!uint(generation)||!uint(world.areaId)||![0,1].includes(message.permission)||![0,1].includes(message.field114)||!Number.isInteger(message.parameter)||message.parameter< -2147483648||message.parameter>2147483647){this.unavailable++;return[];}
  const candidate=world.registry.get(world.localObjectId);
  // The original updates connection permission even without a controlled
  // creature. Its per-creature writes must NOT migrate to a later actor.
  const actor=candidate?.objectType===5&&!candidate.replicationRemoved?candidate:null;
  const projected=actor?this.project(world,actor):null;
  const recipientOwner=actor&&typeof world.nativeClockOwnerTransport==='function'?world.nativeClockOwnerTransport(actor):null;
  return[{kind:'raw-creature-visibility-permission',connection,generation,
   areaId:world.areaId,actorId:actor?.id??null,lifetime:actor?life(projected?.id===actor.id?projected:null):null,
   recipientOwner:recipientOwner==null?null:structuredClone(recipientOwner),
   serial:++this.serial,permission:Boolean(message.permission),field114:Boolean(message.field114),
   parameter:message.parameter,source:'received_game_master_permission_31_22'}];
 }
}
module.exports={RawCreatureVisibilityPermission};
