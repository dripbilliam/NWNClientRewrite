import {creatureRoot} from './creature_rules.js';
import {intEntry} from './combat_stats.js';
import {savingThrowSpell} from './spell_metadata.js';
import {nativeDistanceSquared} from './nearest_objects.js';

// BroadcastSpellCast140384300 ordinary (no counterspellers) path. Its
// observer spellcraft rolls use authoritative RNG even for NPC observers.
export async function broadcastOrdinarySpellCast(actor,spell,rules,p){
  const area=p.area(actor);if(!area)return;
  actor.nativeSpellIdentified808=[];
  for(let i=0;i<p.ids(area).length;i++){
    const viewer=p.creature(p.ids(area)[i]);if(!viewer||nativeDistanceSquared(actor.position,viewer.position)>Math.fround(p.range*p.range))continue;
    if(spell.userType!==1||intEntry(rules.spells,spell.id,'AltMessage').value!==0){actor.nativeSpellIdentified808.push(viewer.id);continue;}
    const visibility=p.visibility(viewer,actor.id);if(visibility===null||!(visibility&3))continue;
    let rank=(await p.skill(viewer,16,actor.id,0)<<24)>>24;
    const school=savingThrowSpell(rules,spell.id).school;
    for(const entry of creatureRoot(viewer).ClassList){
      if(intEntry(rules.classes,entry.Class&255,'PickSchool').value===0)continue;
      const specialization=(entry.School??0)&255;if(specialization===0)continue;
      if(specialization===school)rank+=2;
      else{const opposition=intEntry(rules.spellschools,specialization,'Opposition');if(!opposition.found)throw new Error('Native spellcraft opposition scratch is unavailable');if(opposition.value===school)rank-=5;}
    }
    const roll=(await p.roll(1,20))&65535,identified=Number(((rank+roll)|0)>=spell.innate+15||viewer.id===actor.id||viewer.masterId===actor.id);
    if(identified)actor.nativeSpellIdentified808.push(viewer.id);
    const client=p.client(viewer.id);if(client)await p.send(client,8,{objects:[actor.id],integers:[spell.id,identified,1]});
  }
}
