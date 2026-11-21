// Raw decoded messages and shared source identities only. Godot owns routing,
// active-table interpretation, models, attachment and visual phase timing.
class RawVisualEvents{
 constructor(identities){this.identities=identities;this.serial=0;}
 frame(world,generation,connection,message){
  const events=[];
  if(message.kind==='object-updates')for(const event of world.presentationChanges){
   if(event.action!=='visual-effects')continue;
   const actor=world.registry.get(event.id);
   if(!actor||actor.replicationRemoved||actor.areaId!==world.areaId)continue;
   events.push({kind:'loop',id:event.id,lifetime:this.identities.identity(actor),changes:structuredClone(event.changes)});
  }
  if(message.kind==='object-visual'){
   const actor=world.registry.get(message.targetId);
   if(actor&&(actor.replicationRemoved||actor.areaId!==world.areaId))return null;
   const source=world.registry.get(message.sourceId);
   events.push({kind:'instant',id:message.targetId,lifetime:actor?this.identities.identity(actor):0,sourceLifetime:source&&!source.replicationRemoved&&source.areaId===world.areaId?this.identities.identity(source):0,message:structuredClone(message)});
  }
  if(message.kind==='area-visual')events.push({kind:'area',id:0x7f000000,lifetime:0,message:structuredClone(message)});
  if(message.kind==='safe-projectile'){
   const target=world.registry.get(message.header.targetId),source=world.registry.get(message.header.sourceId);
   const current=actor=>actor&&!actor.replicationRemoved&&actor.areaId===world.areaId;
   if(target&&!current(target))return null;
   events.push({kind:'projectile',id:message.header.targetId,lifetime:current(target)?this.identities.identity(target):0,sourceLifetime:current(source)?this.identities.identity(source):0,message:structuredClone(message)});
  }
  return events.length?{kind:'raw-visual-events',connection,generation,areaId:world.areaId,serial:++this.serial,events}:null;
 }
}
module.exports={RawVisualEvents};
