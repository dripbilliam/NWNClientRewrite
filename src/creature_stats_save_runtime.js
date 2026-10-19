import {creatureRoot} from './creature_rules.js';
import {saveCreatureStats} from './creature_stats_save.js';
import {importCreatureGender} from './creature_appearance_state.js';
import {getLocalizedString} from './localized_string.js';
import {nativeAssignedString} from './native_gff_fields.js';
import {decodeGffText} from './gff_text.js';
import {intEntry} from './combat_stats.js';
import {objectTemplateResRef} from './create_object.js';

const savedFields={Race:'nativeRace9e2',Str:'nativeStr9de',Dex:'nativeDex9e0',Con:'nativeCon9df',SoundSetFile:'nativeSound9e4',BaseAttackBonus:'nativeBaseAttackA54',RefSaveThrow:'nativeReflexA5b',WillSaveThrow:'nativeWillA5c',FortSaveThrow:'nativeFortitudeA5a',ArmorClass:'nativeArmorA50',MaxHitPoints:'nativeMaximumHPA58',PortraitId:'nativePortraitId9da',Portrait:'nativePortrait9c8',Appearance_Type:'nativeAppearance9dc'};
const zeroFields=new Set(['DataMigration','Age','StartingPackage','MClassLevUpIn','willbonus','fortbonus','refbonus','OverrideBAB','NaturalAC','GoodEvil','LawfulChaotic','Color_Skin','Color_Hair','Color_Tattoo1','Color_Tattoo2','Phenotype','Appearance_Head','Tail_New','Wings_New']);
const emptyLoc=()=>({strRef:0xffffffff,entries:[]});
const loc=value=>typeof value==='string'?{strRef:0xffffffff,entries:[{languageId:0,text:value}]}:value??emptyLoc();

// Live base fields and existing canonical stat providers. No resource clone,
// object-ID allocation, or substitution of rendered/equipped appearance data.
export async function saveLiveCreatureStats(s,o,root){
 if(o?.objectType!==5||!o.stats)throw new Error('Native SaveStats requires loaded creature stats');
 const data=creatureRoot(o),combat=()=>o.stats.combat;
 const stat=name=>{
  if(name==='IsPC')return o.nativeStatsIsPCb0;if(name==='IsDM')return Number(o.isDM);
  if(name==='Gender')return importCreatureGender(data);if(name==='MovementRate')return o.nativeMovementRate;
  if(name==='FactionID')return o.factionId;if(name==='ChallengeRating')return o.nativeChallengeRatingD0;
  if(['FirstName','LastName','Description'].includes(name))return loc(data[name]);
  if(['DescriptionOverride','Subrace','Deity'].includes(name))return data[name]??'';
  if(name==='Conversation')return objectTemplateResRef(data.Conversation??'');
  if(name==='Interruptable')return Number((data[name]??1)!==0);
  // Extended authored cells need their import owner before they can become
  // canonical live values. Do not silently substitute a stale x-prefixed cell.
  if(Object.hasOwn(data,`x${name}`))throw new Error(`Native SaveStats ${name} extended-field import is unavailable`);
  if(Object.hasOwn(data,name))return data[name];
  if(zeroFields.has(name)||name.startsWith('BodyPart_')||name==='ArmorPart_RFoot')return 0;
  throw new Error(`Native SaveStats live ${name} storage is unavailable`);
 };
 const creature=name=>{
  if(name==='Tag')return o.tag;if(name==='Gold')return o.nativeGold898;if(name==='Plot')return Number(o.plot);
  if(name==='BodyBag')return o.nativeBodyBag8a8;if(name==='NoPermDeath')return o.nativeNoPermDeath8bc;
  if(name==='SoundSetFile')return data[name]??65535;if(name==='Disarmable')return Number((data[name]??1)!==0);
  if(name==='HitPoints')return data.HitPoints;if(name==='FootstepType')return data[name]??-1;
  throw new Error(`Native SaveStats creature ${name} storage is unavailable`);
 };
 const baseById=id=>{
  const base=s.items.baseInfo({baseItem:id});if(!base)throw new Error('Native SaveStats base item is unavailable');
  const table=s.characterRules.baseitems;
  const cells=['NumDice','DieToRoll'].map(name=>{const cell=intEntry(table,id,name);if(!cell.found)throw new Error(`Native SaveStats base-item ${name} loader value is unavailable`);return cell.value&255;});
  return{...base,numDice:cells[0],die:cells[1]};
 };
 return saveCreatureStats({stats:stat,creature,saved:name=>o[savedFields[name]],locked:()=>o.nativeEquipmentLock97c,
  baseAttack:()=>combat().baseAttackBonus,save:name=>combat().saves[name],armor:()=>combat().armorClass,isDM:()=>Number(o.isDM),
  maximumHP:()=>o.stats.maxHP,currentHP:()=>o.stats.currentHP,
  portraitId:()=>data.PortraitId??65535,portrait:()=>objectTemplateResRef(data.Portrait??''),
  classInfo:root=>s.spellBook.saveClassInfo(o,root),combatInformation:locked=>locked?o.nativeCombatInformationA48:o.nativeCombatInformationD70,
  item:id=>{const item=s.registry.get(id);return item?.objectType===6?item:null;},
  itemName:async(item,previous,language,gender,translate)=>{
   const value=item.nativeItemLocalized?.[0x420];if(!value)throw new Error('Native SaveStats localized item name storage is unavailable');
   const out={value:previous},tlk=s.talkTable;
   await getLocalizedString(value,language,out,gender,translate,{
    internal:(value,key,out)=>{const entry=value.entries?.find(e=>e.languageId===(key>>>0));if(!entry)return 0;out.value=nativeAssignedString(entry.text);return 1;},
    hasTalkTable:()=>Boolean(tlk),setGender:value=>{tlk.state.gender=value;},fetch:async(ref,parse)=>{const result=await tlk.fetch(ref,parse);return{status:result.status,text:decodeGffText(result.record.text)};},
   });return out.value;
  },baseItem:item=>baseById(item.baseItem),baseItemById:baseById,equipped:slot=>s.equipmentSlot(o,slot),
 },root);
}
