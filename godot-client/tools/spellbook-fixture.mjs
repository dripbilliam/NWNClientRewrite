import {parseGff} from '../../src/gff.js';
import {typedGff,writeGff} from '../../src/gff_writer.js';
import {spellFamilyChildren} from '../../src/spell_family.js';
import {spellLevelByClass} from '../../src/spell_book.js';

// Return an in-memory local test character. Never write back to the installed
// sample, user vault or source workspace. The real server admits and owns it.
export function familyTestCharacter(bytes,rules,{classIndex=0,spellId=321}={}){
 const parsed=parseGff(bytes),root=typedGff(parsed.root),cls=root.fields.ClassList?.value[classIndex];
 if(!cls)throw Error('Authored family fixture class is unavailable');
 const level=spellLevelByClass(rules,spellId,cls.fields.Class.value),children=spellFamilyChildren(rules,spellId);
 if(level<0||level>9||children.length<2)throw Error('Active original spell-family metadata is unavailable');
 const known=cls.fields['KnownList'+level]?.value,memory=cls.fields['MemorizedList'+level]?.value;
 if(!known?.length||!memory?.length)throw Error('Sample wizard lacks a compatible physical spell pool');
 if(!known.some(row=>row.fields.Spell.value===spellId)){const entry=structuredClone(known[0]);entry.fields.Spell.value=spellId;known.push(entry);}
 memory[0].fields.Spell.value=spellId;memory[0].fields.Ready.value=1;memory[0].fields.SpellMetaMagic.value=0;
 const output=writeGff('BIC ',root),check=parseGff(output).root.ClassList[classIndex];
 if(!check['KnownList'+level].some(row=>row.Spell===spellId)||check['MemorizedList'+level][0].Spell!==spellId)throw Error('Authored family fixture failed read-back');
 return{bytes:output,metadata:{classIndex,level,spellId,children,physicalSlot:0}};
}
