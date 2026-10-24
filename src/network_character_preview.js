import {parseGff} from './gff.js';
import {characterStats} from './character.js';
import {abilityModifier} from './combat_stats.js';
// The server supplies a SaveStats GFF. Extract presentation records without
// constructing creatures, assigning IDs, importing effects or running scripts.
export function serverCharacterPreviewSummary(bytes,rules=null){
 const root=parseGff(bytes,'BIC ').root,result={abilities:{},classes:[],skills:[],feats:[],spells:[]};
 for(const name of ['Str','Dex','Con','Int','Wis','Cha'])if(Number.isInteger(root[name]))result.abilities[name]=root[name];
 for(const [name,field]of Object.entries({race:'Race',subrace:'Subrace',gender:'Gender',experience:'Experience',hitPoints:'HitPoints',currentHitPoints:'CurrentHitPoints',portrait:'PortraitId',portraitRef:'Portrait',lawChaos:'LawfulChaotic',goodEvil:'GoodEvil',description:'Description',firstName:'FirstName',lastName:'LastName'}))if(root[field]!==undefined)result[name]=root[field];
 result.classes=(root.ClassList??[]).map(c=>({id:c.Class,level:c.ClassLevel}));result.skills=(root.SkillList??[]).map((s,id)=>({id,rank:s.Rank}));result.feats=(root.FeatList??[]).map(f=>f.Feat);
 for(const name of ['firstName','lastName','description']){const value=result[name];if(value?.entries?.length)result[name]={text:(value.entries.find(e=>e.language===0)??value.entries[0]).text};}
 for(const c of root.ClassList??[])for(const [key,list]of Object.entries(c))if(/^KnownList\d$/.test(key))for(const spell of list)result.spells.push({classId:c.Class,level:Number(key.at(-1)),id:spell.Spell});
 if(rules){const stats=characterStats(root,rules);result.abilities=stats.equippedAbilities;result.abilityModifiers=Object.fromEntries(Object.entries(result.abilities).map(([name,value])=>[name,abilityModifier(value,rules)]));result.hitPoints=stats.maxHP;result.currentHitPoints=stats.currentHP;result.nextExperience=stats.nextXP;result.armorClass=stats.combat?.armorClass;result.saves=stats.combat?.saves;result.baseAttackBonus=stats.combat?.baseAttackBonus;}
 return result;
}
