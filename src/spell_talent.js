import {TalentCandidates,selectionTalent} from './talent.js';
import {talentSpell} from './spell_metadata.js';
import {intEntry} from './combat_stats.js';

const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native spell talent ${name} is unavailable`);return v|0;};
const required=(p,name)=>{if(typeof p?.[name]!=='function')throw new Error(`Native spell talent provider ${name} is unavailable`);return p[name];};

// SpellLike1403fcc30: selector tests remaining!=0, distinct from
// GetIsInSpellLikeAbilityList's remaining==1 eligibility test.
export async function spellLikeTalent(o,category,maxCR,rules,p){
  const pool=new TalentCandidates(maxCR),list=await required(p,'spellLikeList')(o);
  if(!Array.isArray(list))throw new Error('Native spell-like talent list is unavailable');
  for(const entry of list){
    if(integer(entry.remaining,'ability remaining uses')===0)continue;
    const id=integer(entry.id,'ability ID'),spell=talentSpell(rules,id);if(!spell)continue;
    if(!await required(p,'suitable')(o,spell,category,maxCR,{classIndex:0,level:0,slot:0,memorized:0,parentId:-1}))continue;
    pool.add({...selectionTalent(),type:0,id,classIndex:254,casterLevel:integer(entry.casterLevel,'ability caster level')&255},spell.maxCR);
  }
  return pool.pick(p);
}

// Known1403fb330 and Memorized1403fb940. The known count is WORD, its
// traversal cursor BYTE; refuse a native wrap rather than hanging the host.
export async function classSpellTalent(o,category,maxCR,index,memorized,rules,p){
  index=integer(index,'class index')&255;const pool=new TalentCandidates(maxCR);
  for(let level=0;level<10;level++){
    if(!memorized&&(integer(await required(p,'spellsPerDayLeft')(o,index,level),'spells per day')&255)===0)continue;
    const n=integer(await required(p,memorized?'memorizedCount':'knownCount')(o,index,level),'spell count')&(memorized?255:65535);
    if(!memorized&&n>255)throw new Error('Native known talent scan would wrap its BYTE cursor');
    for(let slot=0;slot<n;slot++){
      const entry=await required(p,memorized?'memorizedSlot':'knownSlot')(o,index,level,slot);
      const id=memorized?integer(entry?.id??-1,'memorized spell ID'):integer(entry,'known spell ID');
      const spell=talentSpell(rules,id);if(!spell||memorized&&(integer(entry.ready,'memorized ready flag')&255)===0)continue;
      for(const selectedId of spell.children.length?spell.children:[id]){
        const selected=talentSpell(rules,selectedId);if(!selected)continue;
        const details={classIndex:index,level,slot,memorized:Number(memorized),parentId:spell.children.length?id:-1};
        const suitability=await required(p,'suitable')(o,selected,category,maxCR,details);
        if(!suitability)continue;
        pool.add({...selectionTalent(),type:0,id:selectedId,classIndex:index,
          metamagic:memorized?integer(suitability.metamagic,'memorized metamagic')&255:0},selected.maxCR);
      }
    }
  }
  return pool.pick(p);
}

// CheckSpellSuitability1403f1bf0 calls HasTalent before the area category
// check. Missing area skips that filter; effective non-full PvP swaps1/11.
export async function spellSuitability(o,spell,category,maxCR,details,p){
  let meta=details.memorized?integer(await required(p,'slotMetamagic')(o,details),'slot metamagic')&255:0;
  if(!await required(p,'hasSpellTalent')(o,spell.id,meta)&&!await required(p,'hasSpellTalent')(o,details.parentId,meta))return null;
  const area=await required(p,'area')(o);
  if(area){
    const pvp=integer(await required(p,'effectivePVP')(area),'effective PvP')&255;
    const wanted=pvp!==2&&(category===1||category===11)?category===1?11:1:category;
    if(spell.category!==wanted)return null;
  }
  let level=spell.innate;
  if(details.memorized){meta=integer(await required(p,'slotMetamagic')(o,details),'slot metamagic')&255;
    if(meta!==0)level+=integer(await required(p,'metamagicCost')(meta),'metamagic level cost')&255;}
  return maxCR===-1||level*2-1<=maxCR?{metamagic:meta}:null;
}

// SpellFromItem1403fc3b0: equipped items invoke suitability; carried items
// use direct categories/potion aliases and ignore the supplied numeric cap.
// Both pools retain active property indices and canonical item IDs.
export async function itemSpellTalent(o,category,maxCR,rules,p){
  const pool=new TalentCandidates(maxCR);
  const add=async(item,equipped)=>{
    const properties=await required(p,'activeProperties')(item);
    if(!Array.isArray(properties))throw new Error('Native active item property list is unavailable');
    for(let index=0;index<properties.length;index++){
      const prop=properties[index];if((integer(prop.type,'item property type')&65535)!==15)continue;
      if(integer(prop.remaining,'item property remaining uses')===0&&(equipped||integer(await required(p,'charges')(item),'item charges')<=0))continue;
      if(!rules.iprp_spells)throw new Error('Native iprp_spells table is unavailable');
      const id=intEntry(rules.iprp_spells,integer(prop.subtype,'item property subtype')&65535,'SpellIndex').value;
      const spell=talentSpell(rules,id);if(!spell)continue;
      if(equipped){
        if(!await required(p,'suitable')(o,spell,category,maxCR,{classIndex:0,level:0,slot:0,memorized:0,parentId:-1}))continue;
      }else{
        const start=({17:4,18:6,21:8,20:13})[category],alias=integer(await required(p,'baseItem')(item),'base item')===49&&start!==undefined&&((spell.category-start)>>>0)<=1;
        if(spell.category!==category&&!alias)continue;
      }
      pool.add({...selectionTalent(),type:0,id,itemId:integer(item.id,'canonical item ID')>>>0,itemPropertyIndex:index},spell.maxCR);
    }
  };
  for(let index=0;index<18;index++){
    const item=await required(p,'equipmentSlot')(o,1<<index);
    if(!item||!await required(p,'hasProperty')(item,15)||!await required(p,'canUseItem')(o,item,1))continue;
    await add(item,true);
  }
  for(const id of await required(p,'repositoryIds')(o)){
    const item=await required(p,'itemById')(id);if(!item||!await required(p,'canUseItem')(o,item,1))continue;
    const base=integer(await required(p,'baseItem')(item),'base item');
    if(base===49&&(((category-4)>>>0)<=5||((category-13)>>>0)<=1))continue;
    if(integer(await required(p,'equipableSlots')(item),'equipable slots')!==0||!await required(p,'hasProperty')(item,15))continue;
    await add(item,false);
  }
  return pool.pick(p);
}
