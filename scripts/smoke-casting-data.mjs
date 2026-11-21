// Read installed module rules and BIC class data into independent fixtures.
// This does not import/play characters, execute casts or bypass HP acceptance.
import fs from 'node:fs/promises';
import {openLocalModule} from './local-module.mjs';
import {loadCharacterRules} from '../src/character.js';
import {parseGff} from '../src/gff.js';
import {castingSpell} from '../src/spell_metadata.js';
import {nativeClassLevel} from '../src/spell_caster_level.js';
import {initializeClassSkillPenalties} from '../src/skill_caches.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const [install,modulePath]=process.argv.slice(2),rules=await loadCharacterRules(await openLocalModule(install,modulePath));
const counts={spells:rules.spells.orderedRows.length,classSlots:0},classes=[],failures=[];
for(let id=0;id<counts.spells;id++){
  try{const spell=castingSpell(rules,id);if(!spell||spell.id!==id)throw new Error('Physical spell identity changed');}
  catch(error){failures.push({operation:'casting-metadata',spellId:id,error:error.message});}
}
const files=(await fs.readdir(`${install}/data/lcv`)).filter(name=>name.toLowerCase().endsWith('.bic')).sort();
for(const file of files){
  const root=parseGff(await fs.readFile(`${install}/data/lcv/${file}`),'BIC ').root,o={creatureData:structuredClone(root)};initializeClassSkillPenalties(o);
  for(let index=0;index<o.creatureData.ClassList.length;index++){
    const c=o.creatureData.ClassList[index];
    try{const level=nativeClassLevel(o,index,1,1,rules);classes.push({file,index,classType:c.Class,level:c.ClassLevel,casterLevel:level});counts.classSlots++;}
    catch(error){failures.push({operation:'class-level',file,index,classType:c.Class,error:error.message});}
  }
}
console.log(JSON.stringify({counts,characterFiles:files.length,classes,failures,diagnostics:runtimeDiagnostics.records,
  limits:'Installed active-data and class fixtures; not full BIC import, authored casting, campaign acceptance or original process CPU parity.'},null,2));
if(failures.length)process.exitCode=1;
