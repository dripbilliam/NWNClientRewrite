import {abilityModifier} from './combat_stats.js';
export const abilityModifierCells=['nativeStrModifierD39','nativeDexModifierD3b','nativeConModifierD3d','nativeIntModifierD3f','nativeWisModifierD41','nativeChaModifierD43'];
const names=['Str','Dex','Con','Int','Wis','Cha'];
// Stats byte caches consumed by ExecuteCommandGetAbilityModifier14051e340.
// GetDEXMod(param0) returns D3b directly, with no armor cap.
export function refreshAbilityModifierCache(o,rules){
  const word=o.nativeField8d4&65535;
  for(let index=0;index<6;index++){
    const score=index===1&&(word&6)!==6&&word!==0&&(o.combatMode&255)!==11?3:o.stats.equippedAbilities[names[index]];
    if(!Number.isInteger(score))throw new Error('Native ability modifier cache score is unavailable');
    o[abilityModifierCells[index]]=abilityModifier(score&255,rules)&255;
  }
}
export function scriptAbilityModifier(o,index){
  if(!o||index<0||index>5)return 0;
  if(!Number.isInteger(index)||!Number.isInteger(o[abilityModifierCells[index]]))throw new Error('Native ability modifier cache is unavailable');
  return(o[abilityModifierCells[index]]<<24)>>24;
}
