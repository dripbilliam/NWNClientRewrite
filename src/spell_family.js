import {talentSpell,castingSpell} from './spell_metadata.js';

// Family membership comes from active SubRadSpell1..8 rows, never a spell-ID
// list or a name prefix. Master remains the native owner's resource mapping.
export function isSpellFamily(rules,id){return Boolean(talentSpell(rules,id)?.children.length);}
export function spellFamilyChildren(rules,id,ancestors=[]){
 const seen=new Set([...ancestors,id]);return(talentSpell(rules,id)?.children??[]).filter(child=>{if(seen.has(child)||!castingSpell(rules,child))return false;seen.add(child);return true;});
}
export function spellFamilyContains(rules,parent,child){
 const pending=[parent],seen=new Set();while(pending.length){const id=pending.pop();if(seen.has(id))continue;seen.add(id);for(const next of spellFamilyChildren(rules,id)){if(next===child&&child!==parent)return true;pending.push(next);}}return false;
}
export async function spellShortcutChoice(rules,binding,describe,path=[],budget={remaining:2048}){
 const id=binding.intParam;if(path.includes(id)||path.length>=32||--budget.remaining<0||!castingSpell(rules,id))return null;
 const details=await describe(id);if(!isSpellFamily(rules,id))return{...details,binding:{...binding}};
 const children=(await Promise.all(spellFamilyChildren(rules,id,path).map(child=>spellShortcutChoice(rules,{...binding,intParam:child},describe,[...path,id],budget)))).filter(Boolean);
 return{...details,children};
}
export function* spellChoiceBindings(choices){for(const entry of choices){if(entry.children)yield* spellChoiceBindings(entry.children);else if(entry.binding)yield entry.binding;}}
