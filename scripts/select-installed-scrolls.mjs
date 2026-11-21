// Test-fixture selection from the installed stock scroll corpus, using current
// class/spell/school/known metadata. Never imported by production client code.
import {parseGff} from '../src/gff.js';
import {intEntry} from '../src/combat_stats.js';
export async function selectInstalledLearnableScrolls(session,limit=2){
 const actor=session.player,p=session.items.learningProviders(),choices=[];
 for(const entry of session.resolver.key.resources.values()){
  if(entry.resourceType!==2025||!entry.resref.startsWith('nw_it_sparscr'))continue;
  const root=parseGff(await session.resolver.getResource(entry.resref,2025),'UTI ').root,prop=root.PropertiesList?.[0];if(root.BaseItem!==75||!prop)continue;
  const id=intEntry(session.characterRules.iprp_spells,prop.Subtype&65535,'SpellIndex').value>>>0,spell=p.spell(id);if(!spell)continue;
  for(let n=0;n<p.classCount(actor);n++){
   const type=p.classType(actor,n),level=p.spellLevel(spell,type);if(p.canLearn(type)===0||level===255||!p.spellGain(actor,n,level)||!p.minimumAbility(actor,n,level))continue;
   const school=p.classSchool(actor,n),opposition=school?p.opposition(school):null;if(opposition?.status===1&&opposition.value===p.spellSchool(spell))continue;
   if(actor.nativeTalentClasses[n].known[level].includes(id)||choices.some(c=>c.spellId===id))continue;
   choices.push({template:entry.resref,spellId:id,subtype:prop.Subtype&65535,classIndex:n,level});break;
  }
  if(choices.length===limit)break;
 }
 return choices;
}
