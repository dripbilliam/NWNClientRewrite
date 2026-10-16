import {creatureRoot} from './creature_rules.js';
import {abilityModifierCells} from './ability_modifier_cache.js';
const names=['Str','Dex','Con','Int','Wis','Cha'],first=[814,784,774,794,804,764],polymorph=['nativeStr9de','nativeDex9e0','nativeCon9df'];

// Full4097c0..40a68b. These are native great-ability feat enum ranges,
// not spell/module rules. The BONUS comes from the active ruleset per match.
export function featAbilityDeltas(feats,remove,p){
 const deltas=Array(6).fill(0);if(feats===null)return deltas;
 for(let ability=0;ability<6;ability++)for(let feat=first[ability]+9;feat>=first[ability];feat--)
  if(p.hasFeat(feats,feat)!==0)deltas[ability]=(deltas[ability]+p.rule('EPIC_GREAT_STAT_BONUS',1))|0;
 return remove!==0?deltas.map(value=>(-value)|0):deltas;
}

// ComputeFeatBonuses3f2110..3f22b4. Stats base BYTE writes precede current
// score/modifier queries; strength updates encumbrance before polymorph bases.
// CON changes no hit points here. Mental abilities dirty creature field544.
export async function computeFeatAbilityBonuses(actor,feats,remove,p){
 const deltas=await p.deltas(feats,remove),root=creatureRoot(actor);
 for(let ability=0;ability<6;ability++){
  const delta=deltas[ability]|0;if(delta===0)continue;
  root[names[ability]]=(root[names[ability]]+delta)&255;
  actor[abilityModifierCells[ability]]=(await p.modifier(actor,(await p.score(actor,ability))&255))&255;
  if(ability===0)await p.encumbrance(actor,1);
  if(ability<3){if((actor.nativeField97c|0)!==0)actor[polymorph[ability]]=(actor[polymorph[ability]]+delta)&255;}
  else actor.nativeField544=1;
 }
}
