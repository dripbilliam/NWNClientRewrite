import {parseGff} from '../src/gff.js';
import {typedGff,gffField,writeGff} from '../src/gff_writer.js';
// Integration fixture only. Derive the spell/class level from active rules;
// prepare its ordinary ninth-level slot in an owned high-level BIC copy. This
// does not exercise the character creator or alter the installed preset.
export function createTimeStopFixture(original,session){
 const spellId=session.characterRules.spells.orderedRows.findIndex(r=>/^nw_s0_timestop$/i.test(String(r.ImpactScript))),draft=typedGff(parseGff(original).root),cls=draft.fields.ClassList.value[0];
 if(spellId<0)throw new Error('Installed Time Stop fixture spell is unavailable');
 const level=session.spellBook.level(spellId,cls.fields.Class.value);
 if(level!==9)throw new Error('Time Stop fixture expects an active ninth-level wizard spell');
 cls.fields.ClassLevel.value=17;if(draft.fields.Int.value<19)draft.fields.Int.value=19;
 while(draft.fields.LvlStatList.value.length<17){
  const history=structuredClone(draft.fields.LvlStatList.value.at(-1));
  for(const [name,field]of Object.entries(history.fields))if(/^(KnownList|FeatList)/.test(name))field.value=[];
  for(const skill of history.fields.SkillList?.value??[])skill.fields.Rank.value=0;
  draft.fields.LvlStatList.value.push(history);
 }
 const known=structuredClone(cls.fields.KnownList8.value[0]),memo=structuredClone(cls.fields.MemorizedList8.value[0]);
 if(!known||!memo)throw new Error('Installed eighth-level slot templates are unavailable');
 known.fields.Spell.value=spellId;memo.fields.Spell.value=spellId;memo.fields.Ready.value=1;
 if(memo.fields.SpellMetaMagic)memo.fields.SpellMetaMagic.value=0;if(memo.fields.DomainSpell)memo.fields.DomainSpell.value=0;
 cls.fields.KnownList9=gffField(15,[known]);cls.fields.MemorizedList9=gffField(15,[memo]);
 return{bytes:writeGff('BIC ',draft),spellId,level,classIndex:0,classLevel:17};
}
