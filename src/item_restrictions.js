import {intEntry} from './combat_stats.js';
import {savingThrowSpell} from './spell_metadata.js';

const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native item restriction ${name} is unavailable`);return v|0;};
const required=(p,name)=>{if(typeof p?.[name]!=='function')throw new Error(`Native item restriction provider ${name} is unavailable`);return p[name];};
const propertyType=prop=>integer(prop.type,'property type')&65535;
const subtype=prop=>integer(prop.subtype,'property subtype')&65535;
const passive=async(item,p)=>{
  const list=await required(p,'passiveProperties')(item);
  if(!Array.isArray(list))throw new Error('Native passive item property pool is unavailable');
  return list;
};

// CheckUseMagicDeviceSkill1403d2ef0. The first cost bracket decides; a failed
// requirement cell does not advance to a later bracket. Rank is signed BYTE.
export async function useMagicDevice(o,item,kind,rules,p){
  const rank=(integer(await required(p,'skillRank')(o,19),'UMD rank')<<24)>>24;
  if(integer(await required(p,'canUseSkill')(o,19),'UMD usability')===0)return 0;
  const cost=integer(await required(p,'itemCost')(item,0,1,1,1),'item cost'),table=rules.usemagicdevice;
  if(!table)throw new Error('Native UseMagicDevice table is unavailable');
  const column=['SkillReq_Class','SkillReq_Race','SkillReq_Align'][integer(kind,'UMD restriction kind')]??'';
  const count=table.orderedRows?.length??table.rows.size;
  for(let row=0;row<count;row++){
    if(cost>intEntry(table,row,'DeviceCostMax').value)continue;
    const threshold=intEntry(table,row,column);
    return Number(threshold.found&&rank>=threshold.value);
  }
  return 0;
}

// CheckAlignmentRestrictions1403d2830. Group/specific restrictions union
// their permitted alignment cells. Native neutral is1, lawful2/chaotic3,
// good4/evil5; the grid is lawful/neutral/chaotic by good/neutral/evil.
export async function alignmentRestrictions(o,item,rules,p){
  if(!integer(await required(p,'hasProperty')(item,62),'alignment property')&&
    !integer(await required(p,'hasProperty')(item,65),'specific alignment property'))return 1;
  if(await useMagicDevice(o,item,2,rules,p)===1)return 1;
  const allowed=Array(9).fill(false),groups={1:[1,3,4,5,7],2:[0,1,2],3:[6,7,8],4:[0,3,6],5:[2,5,8]};
  for(const prop of await passive(item,p)){
    if(propertyType(prop)===62)for(const index of groups[subtype(prop)]??[])allowed[index]=true;
    if(propertyType(prop)===65){
      const index=subtype(prop);
      if(index>=9)throw new Error('Native specific-alignment property would read outside its nine-cell pool');
      allowed[index]=true;
    }
  }
  const good=integer(await required(p,'goodEvil')(o),'simple good/evil')&255;
  const law=integer(await required(p,'lawChaos')(o),'simple law/chaos')&255;
  return Number(allowed[(law===1?3:law===3?6:0)+(good===1?1:good===5?2:0)]);
}

// Class1403d2c00 and race1403d2ce0 scan the passive pool in physical order.
export async function classRestrictions(o,item,rules,p){
  if(!integer(await required(p,'hasProperty')(item,63),'class property')||await useMagicDevice(o,item,0,rules,p)===1)return 1;
  const classes=await required(p,'classIds')(o);
  if(!Array.isArray(classes))throw new Error('Native item class list is unavailable');
  for(const prop of await passive(item,p))if(propertyType(prop)===63)
    for(let i=0;i<(classes.length&255);i++)if(subtype(prop)===(integer(classes[i],'class ID')&255))return 1;
  return 0;
}
export async function raceRestrictions(o,item,rules,p){
  if(!integer(await required(p,'hasProperty')(item,64),'race property')||await useMagicDevice(o,item,1,rules,p)===1)return 1;
  const race=integer(await required(p,'race')(o),'race')&65535;
  for(const prop of await passive(item,p))if(propertyType(prop)===64&&subtype(prop)===race)return 1;
  return 0;
}

// CanUseItem's scroll block1403d24b7..1403d26a3 checks every class with
// PickSchool and a nonzero school. It reads the FIRST active property,
// without filtering that property's type or testing its remaining uses.
export async function scrollSchoolAllowed(o,item,rules,p){
  const classes=await required(p,'classIds')(o);
  if(!Array.isArray(classes))throw new Error('Native item class list is unavailable');
  if(!rules.classes)throw new Error('Native item classes table is unavailable');
  let result=1;
  for(let index=0;index<(classes.length&255);index++){
    if(intEntry(rules.classes,integer(classes[index],'class ID')&255,'PickSchool').value===0)continue;
    const school=integer(await required(p,'classSchool')(o,index),'class school')&255;if(school===0)continue;
    const prop=await required(p,'firstActiveProperty')(item);if(!prop)continue;
    if(!rules.iprp_spells)throw new Error('Native item iprp_spells table is unavailable');
    const id=intEntry(rules.iprp_spells,subtype(prop),'SpellIndex').value,spell=savingThrowSpell(rules,id);if(!spell)continue;
    if(!rules.spellschools)throw new Error('Native spellschools table is unavailable');
    if(spell.school===intEntry(rules.spellschools,school,'Opposition').value)result=0;
  }
  return result;
}

// CheckProficiencies1403d2d90. Chest armor is special, even when its ReqFeat
// list differs. Other slots accept ANY required feat, without use counters.
export async function itemProficient(o,item,slot,p){
  slot=integer(slot,'equipment slot');const base=await required(p,'baseInfo')(item);
  if(!base||integer(base.equipableSlots,'equipable slots')===0)return 0;
  if(slot===2){
    if((integer(base.modelType,'model type')&255)!==3)return 0;
    const ac=integer(await required(p,'armorClass')(item),'armor class');
    if(ac<1)return 1;
    return Number(integer(await required(p,'hasFeat')(o,ac>=6?2:ac>=4?4:3),'armor proficiency')!==0);
  }
  if(!Array.isArray(base.requiredFeats))throw new Error('Native base-item required feat pool is unavailable');
  const count=base.requiredFeats.length&255;if(count===0)return 1;
  for(let i=0;i<count;i++)if(integer(await required(p,'hasFeat')(o,integer(base.requiredFeats[i],'required feat')&65535),'weapon proficiency')!==0)return 1;
  return 0;
}
