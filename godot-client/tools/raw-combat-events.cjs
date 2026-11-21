// Transport identities and decoded records only. All table/model selection and
// animation scheduling belong to Godot; no combat or spell outcomes run here.
class RawCombatEvents {
 constructor(){this.identities=new WeakMap();this.nextIdentity=0;this.serial=0;}
 identity(object){if(!this.identities.has(object))this.identities.set(object,++this.nextIdentity);return this.identities.get(object);}
 object(object){return {...object,nativeLifetime:this.identity(object)};}
 frame(world,generation,connection){
  const events=[];
  for(const event of world.presentationChanges){
   // Casting scalars must travel with their animation, before the throttled
   // world snapshot. This clones decoded fields, without table/asset work.
   if(event.action==='movement'&&event.changes?.animation!==undefined){
    const object=world.registry.get(event.id);
    if(object?.objectType===5&&object.replicated?.cast&&!object.replicationRemoved&&object.areaId===world.areaId)events.push({action:'cast-state',id:event.id,lifetime:this.identity(object),animation:event.changes.animation,cast:structuredClone(object.replicated.cast),ageMs:0});
    continue;
   }
   if(!['cast-animation','attack-animation'].includes(event.action))continue;
   const object=world.registry.get(event.id);
   if(!object||object.replicationRemoved||object.areaId!==world.areaId)continue;
   events.push({...structuredClone(event),lifetime:this.identity(object),ageMs:0});
  }
  return events.length?{kind:'raw-combat-events',connection,generation,areaId:world.areaId,serial:++this.serial,events}:null;
 }
}
module.exports={RawCombatEvents};
