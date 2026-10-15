import {OBJECT_INVALID} from './game_object_array.js';

// SpellCastAndImpact14049c4b0, ordinary non-countered owner. Presentation
// messages are separate from the event8 which actually runs ImpactScript.
export async function castSpellAndImpact(actor,id,position,targetId,index,itemId,flags,unused,path,instant,p){
  const spell=p.spell(id);if(!spell)return;
  if(actor.nativeSpellImpact224!==0){actor.nativeSpellImpact224=1;return;}
  if(flags!==0)throw new Error('Native countered spell impact is not implemented');
  if(instant===0&&actor.objectType===5)await p.broadcast(actor,spell,itemId,targetId);
  if(spell.hasProjectile===1)await p.projectile(actor,spell,targetId,path);
  const payload={spellId:id|0,featId:actor.nativeSpellFeat23c&65535,casterId:actor.id>>>0,targetId:targetId>>>0,
    itemId:itemId>>>0,position:position.map(Math.fround),script:spell.impactScript,areaId:actor.areaId??OBJECT_INVALID};
  // AddEventDeltaTime14049c8f5: caller AND recipient are the caster. The
  // target is carried inside the payload and resolved again at dispatch.
  if(!Number.isInteger(actor.nativeSpellProjectileTime220))throw new Error('Native spell impact travel time is unavailable');
  await p.enqueue(8,actor.id,actor.id,actor.nativeSpellProjectileTime220>>>0,payload);
  actor.nativeSpellImpact224=1;
}
