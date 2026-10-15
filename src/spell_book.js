import {intEntry,rulesetInt} from './combat_stats.js';
import {creatureRoot} from './creature_rules.js';
import {abilityModifierCells} from './ability_modifier_cache.js';

const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native spellbook ${n} is unavailable`);return v|0;};
const byte=(v,n)=>integer(v,n)&255;
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native spellbook provider ${n} is unavailable`);return p[n];};
const names=['Str','Dex','Con','Int','Wis','Cha'];
const metaFeats={1:11,2:12,4:25,8:29,16:33,32:37};
const classBooleans=new Set(['SpellCaster','MemorizesSpells','PlayerClass','PickDomains','PickSchool','LearnScroll','SpellbookRestricted','Arcane']);
const classField=(rules,id,name)=>{if(!rules.classes)throw new Error('Native spellbook class table is unavailable');const value=intEntry(rules.classes,id,name).value;return classBooleans.has(name)?Number(value!==0):value;};
const physicalRow=(table,id)=>table?.orderedRows?.[id]??(table?.orderedRows?undefined:table?.rows?.get(id));
const textField=(row,name)=>row?.[Object.keys(row??{}).find(k=>k.toLowerCase()===name.toLowerCase())];

// CNWSpell::GetSpellLevel1402af530. Stock columns use ctor-owned BYTE
// cells; custom columns query the active SPELLS table by physical spell ID.
export function spellLevelByClass(rules,id,classId){
  id=integer(id,'spell ID');classId=byte(classId,'class ID');
  if(!rules.spells)throw new Error('Native spellbook SPELLS table is unavailable');
  const spell=physicalRow(rules.spells,id);if(!spell)return 255;
  if(classId===255||classField(rules,classId,'SpellCaster')===0&&classField(rules,classId,'PlayerClass')!==0)return 255;
  const column=String(textField(physicalRow(rules.classes,classId),'SpellTableColumn')??'').split('\0')[0];
  const entry=intEntry(rules.spells,id,column);return entry.found?entry.value&255:255;
}
// GetMetaMagicLevelCost1402a3f70 uses the active ruleset, not a new 2DA
// or combinations of flags. Unknown/composite masks (including255) cost0.
export function metamagicLevelCost(rules,mask){
  mask=byte(mask,'metamagic');const mapping={1:['EMPOWER',2],2:['EXTEND',1],4:['MAXIMIZE',3],8:['QUICKEN',4],16:['SILENT',1],32:['STILL',1]};
  const entry=mapping[mask];return entry?rulesetInt(rules,`SPELL_METAMAGIC_${entry[0]}_COST`,entry[1])&255:0;
}
export function createSpellClassState(){return{known:Array.from({length:10},()=>[]),memorized:Array.from({length:10},()=>[]),
  knownCapacity:Array(10).fill(0),memorizedCapacity:Array(10).fill(0),perDay:Array(10).fill(0),maximumPerDay:Array(10).fill(0)};}
const grow=(state,kind,level)=>{const n=state[kind][level].length,capacity=state[`${kind}Capacity`][level];if(n===capacity)state[`${kind}Capacity`][level]=capacity===0?16:capacity*2;};

// SetNumberMemorizedSpellSlots_ClassInfo140416610. Shrinking with delete0
// does nothing; deletion visits the tail first and retains allocation capacity.
export function resizeMemorizedSlots(state,level,count,deleteSlots=1,p={}){
  level=byte(level,'slot level');count=byte(count,'slot count');deleteSlots=integer(deleteSlots,'slot deletion flag');
  if(level>=10){p.warning?.('nSpellLevel < CNWSPELL_NUM_LEVELS');return;}
  const pool=state.memorized[level];while(pool.length<count){grow(state,'memorized',level);pool.push(null);}
  if(deleteSlots!==0)while(pool.length>count){const old=pool.pop();if(old)p.deleteSlot?.(old);}
}
const classes=o=>{const list=creatureRoot(o)?.ClassList;if(!Array.isArray(list))throw new Error('Native spellbook class storage is unavailable');return list.slice(0,list.length&255);};
const stateAt=(o,index)=>{if(!Array.isArray(o.nativeTalentClasses))throw new Error('Native spellbook pools are unavailable');return o.nativeTalentClasses[index&255];};

// ConfirmDomainSpell1403f24d0/1403f2580: both domain BYTEs and physical
// domain rows are used; a missing domain logs then tries the second.
export function confirmDomainSpell(o,index,level,id,rules,p={}){
  index=byte(index,'class index');level=byte(level,'domain level');id=integer(id,'domain spell ID')>>>0;
  const c=classes(o)[index];if(!c){p.warning?.('nMultiClass < m_nNumMultiClasses');return 0;}
  if(classField(rules,c.Class&255,'PickDomains')===0)return 0;
  if(!rules.domains)throw new Error('Native spellbook domain rules are unavailable');
  if(level>=10)throw new Error('Native domain spell query reads beyond its ten-level storage');
  for(const domain of [(c.Domain1??0)&255,(c.Domain2??1)&255]){
    if(!physicalRow(rules.domains,domain)){p.warning?.('CNWSCreatureStats_ClassInfo::ConfirmDomainSpell() Invalid Domain');continue;}
    const entry=intEntry(rules.domains,domain,`Level_${level}`),spell=entry.found?entry.value>>>0:0xffffffff;
    if(spell!==0xffffffff&&spell===id)return 1;
  }
  return 0;
}
// GetSpellMinAbilityMet140408b70 contains target-build engine class enum
// exemptions11..26. Remaining classes use their active casting ability.
export function spellMinAbilityMet(o,index,level,rules,p){
  index=byte(index,'class index');level=byte(level,'minimum-ability level');const c=classes(o)[index],id=c?(c.Class&255):255;
  if(id>=11&&id<=26)return 1;
  if(classField(rules,id,'SpellCaster')===0)return 0;
  const ability=String(textField(physicalRow(rules.classes,id),'SpellcastingAbil')??'').toUpperCase(),n=names.findIndex(name=>name.toUpperCase()===ability);
  let score=0,bonus=0;if(n>=0){score=byte(required(p,'abilityScore')(o,n),'casting ability');bonus=(byte(required(p,'abilityBonus')(o,n),'casting ability bonus')<<24)>>24;}
  return Number((score-bonus&255)>=level-1+rulesetInt(rules,'CHARGEN_BASE_ABILITY_MIN_PRIMARY',11));
}

// GetSpellGainWithBonus140408120. Ability admission subtracts bonuses,
// while extra slots use the actual signed cached modifier (including items).
export function spellGainWithBonus(o,index,level,rules,p){
  index=byte(index,'class index');level=byte(level,'gain level');const list=classes(o),c=list[index],id=c?(c.Class&255):255;
  const row=physicalRow(rules.classes,id);if(!row)throw new Error('Native spell gain class storage is unavailable');
  const ability=String(textField(row,'SpellcastingAbil')??'').toUpperCase(),n=names.findIndex(name=>name.toUpperCase()===ability);
  let score=0,total=0,modifier=0;if(n>=0){score=byte(required(p,'abilityScore')(o,n),'gain ability');total=(byte(required(p,'abilityBonus')(o,n),'gain bonus')<<24)>>24;modifier=(byte(required(p,'abilityModifier')(o,n),'gain modifier')<<24)>>24;}
  if((score-total&255)<level-1+rulesetInt(rules,'CHARGEN_BASE_ABILITY_MIN_PRIMARY',11))return 0;
  let bonus=level!==0&&modifier>0&&modifier>=level?Math.trunc((modifier-level+4)/4):0;
  if(level!==0&&classField(rules,id,'PickSchool')!==0&&index<8&&((c?.School??0)&255)!==0)bonus++;
  const arcane=integer(required(p,'arcaneClass')(id),'arcane class');let prestige=0;
  for(let other=0;other<list.length;other++){
    if(other===index)continue;const r=list[other],rid=r.Class&255;if(rid===255||classField(rules,rid,'SpellCaster')!==0)continue;
    let divisor=classField(rules,rid,arcane!==0?'ArcSpellLvlMod':'DivSpellLvlMod')&255;if(divisor===0)continue;
    if(list.length>2)for(let rival=0;rival<list.length;rival++){
      if(rival===other||rival===index)continue;const s=list[rival];
      if(classField(rules,s.Class&255,'SpellCaster')!==0&&integer(p.arcaneClass(s.Class&255),'rival arcane class')===arcane&&
        ((s.ClassLevel&255)>((c?.ClassLevel??0)&255)))divisor=0;
      else if(classField(rules,s.Class&255,'SpellCaster')!==0&&p.arcaneClass(s.Class&255)===arcane&&(s.ClassLevel&255)===((c?.ClassLevel??0)&255)&&index<rival)divisor=0;
    }
    if(divisor!==0)prestige=(prestige+Math.trunc(((r.ClassLevel&255)-1+divisor)/divisor))&255;
  }
  const gain=integer(required(p,'classSpellGain')(id,((c?.ClassLevel??0)+prestige)&255,level),'class gain')&255;
  return gain===255?0:(gain+bonus)&255;
}

// SetMemorizedSpellSlot140415c00: even a slot outside the owned array
// returns1 after validation. It neither creates extra slots nor readies them.
export function setMemorizedSpellSlot(o,index,slot,id,domainLevel,meta,checkAbility,rules,p){
  index=byte(index,'class index');slot=byte(slot,'slot');id=integer(id,'spell ID')>>>0;domainLevel=byte(domainLevel,'domain level');meta=byte(meta,'metamagic');
  const c=classes(o)[index];if(!c){p.warning?.('nMultiClass < m_nNumMultiClasses');return 0;}
  const spell=physicalRow(rules.spells,id);if(!spell)return 0;
  let level=domainLevel;
  if(domainLevel===0){level=spellLevelByClass(rules,id,c.Class);if(level===255){p.warning?.('nSpellLevel != (uint8_t) -1');return 0;}}
  else if(classField(rules,c.Class&255,'PickDomains')===0||!confirmDomainSpell(o,index,domainLevel,id,rules,p)||domainLevel===255)return 0;
  if(meta!==0&&((intEntry(rules.spells,id,'MetaMagic').value&255)&meta)===0)return 0;
  if(metaFeats[meta]!==undefined&&integer(required(p,'hasFeat')(o,metaFeats[meta]),'metamagic feat')===0)return 0;
  level=(level+metamagicLevelCost(rules,meta))&255;
  if(level>=10||checkAbility!==0&&spellMinAbilityMet(o,index,level,rules,p)===0)return 0;
  const pool=stateAt(o,index)?.memorized[level];if(!pool)throw new Error('Native memorized pool is unavailable');
  if(slot<pool.length){const record=pool[slot]??(pool[slot]={id:0,ready:1,metamagic:0,domain:0});record.id=id;record.ready=0;record.metamagic=meta;record.domain=Number(domainLevel!==0);}
  return 1;
}
export function addKnownSpell(o,index,id,rules,p){
  index=byte(index,'known class');id=integer(id,'known spell')>>>0;const c=classes(o)[index];if(!c){p.warning?.('nMultiClass < m_nNumMultiClasses');return;}
  const level=spellLevelByClass(rules,id,c.Class);if(level>=10)return;
  if(integer(o.nativeStatsIsPCb0,'stats PC flag')!==0&&classField(rules,c.Class&255,'LearnScroll')===0&&byte(required(p,'knownSpellsLeft')(o,index,level),'remaining known capacity')===0)return;
  const state=stateAt(o,index);if(!state)throw new Error('Native known spell state is unavailable');grow(state,'known',level);state.known[level].push(id);
}

// ReadSpellsFromGff14040f3e0: derives native levels for known entries,
// imports NPC slot counts as BYTE, and writes Ready at the AUTHORED level
// after attempting SetMemorizedSpellSlot, irrespective of its return value.
export function importSpellBook(o,data,rules,p,readyDefault=0){
  const list=classes(o);o.nativeTalentClasses??=list.map(()=>createSpellClassState());
  if(o.nativeTalentClasses.length!==list.length||o.nativeTalentClasses.some(s=>!Array.isArray(s.known)||!Array.isArray(s.memorized)))throw new Error('Native spellbook import requires constructor-owned pools');
  for(let index=0;index<list.length;index++){
    const c=data.ClassList?.[index];if(!c)continue;
    required(p,'updateMemorizedSlots')(o);
    for(let level=0;level<10;level++){
      const known=c[`KnownList${level}`];if(Array.isArray(known))for(const entry of known.slice(0,known.length&65535))if(entry)addKnownSpell(o,index,(entry.Spell??65535)&65535,rules,p);
      const memo=c[`MemorizedList${level}`];if(!Array.isArray(memo))continue;
      const count=memo.length&255;if(integer(o.nativeStatsIsPCb0,'stats PC flag')===0)resizeMemorizedSlots(stateAt(o,index),level,count,1,p);
      for(let slot=0;slot<count;slot++){
        const entry=memo[slot];if(!entry)continue;
        const id=(entry.Spell??65535)&65535,domain=Number(((entry.DomainSpell??0)&255)!==0),meta=(entry.SpellMetaMagic??0)&255;
        const ready=Object.hasOwn(entry,'Ready')?Number((entry.Ready&255)!==0):Number(readyDefault!==0);
        const domainLevel=domain!==0?(level-(meta!==0?metamagicLevelCost(rules,meta):0))&255:0;
        setMemorizedSpellSlot(o,index,slot,id,domainLevel,meta,0,rules,p);
        const record=stateAt(o,index).memorized[level][slot];if(record)record.ready=ready;
      }
    }
  }
}

// GetSpellUsesLeft140409160. Master spell replacement is single-hop;
// memorized use counts test ready!=0 without checking the slot's metamagic.
export function spellUsesLeft(o,id,index,domainLevel,meta,rules,p){
  id=integer(id,'use spell')>>>0;index=byte(index,'use class');domainLevel=byte(domainLevel,'use domain');meta=byte(meta,'use metamagic');
  if(integer(o.nativeEquipmentLock97c,'spell override flag')!==0){
    if((integer(o.nativeStatsIsPCb0,'stats PC flag')!==0||required(p,'possessed')(o)!==0)&&
      (((meta+1)&254)!==0||![o.nativeSpellOverride9e8,o.nativeSpellOverride9ec,o.nativeSpellOverride9f0].some(v=>integer(v,'override spell ID')>>>0===id)))return 0;
    return 1;
  }
  const c=classes(o)[index];if(!c)return 0;
  if(meta!==0&&meta!==255&&metaFeats[meta]===undefined)return 0;
  if(metaFeats[meta]!==undefined&&required(p,'hasFeat')(o,metaFeats[meta])===0)return 0;
  if(!physicalRow(rules.spells,id))return 0;
  const master=intEntry(rules.spells,id,'Master');const replacement=master.found?master.value>>>0:id;
  if(replacement!==id){id=replacement;if(!physicalRow(rules.spells,id))return 0;}
  const memorizes=classField(rules,c.Class&255,'MemorizesSpells')!==0;
  let level=spellLevelByClass(rules,id,c.Class);
  if(memorizes&&domainLevel!==0){if(!confirmDomainSpell(o,index,domainLevel,id,rules,p))return 0;level=domainLevel;}
  if(level===255)return 0;
  const baseLevel=level;level=(level+metamagicLevelCost(rules,meta))&255;
  if(spellMinAbilityMet(o,index,level,rules,p)===0)return 0;
  const state=stateAt(o,index);if(!state)throw new Error('Native spell-use pools are unavailable');
  if(!memorizes){
    if(classField(rules,c.Class&255,'SpellbookRestricted')!==0){
      const known=state.known[baseLevel]??[],count=known.length&65535;
      // The outer cursor is INT, but GetKnownSpell accepts BYTE. Only the
      // first256 physical entries are addressable even with a larger count.
      if(!known.slice(0,Math.min(256,count)).some(spell=>spell===id))return 0;
    }
    return level<10?state.perDay[level]&255:0;
  }
  if(level>=10)return 0;const pool=state.memorized[level];if(pool.length>255)throw new Error('Native memorized use scan wraps its BYTE index');
  return pool.reduce((count,record)=>record?.id===id&&record.ready!==0?(count+1)&255:count,0);
}

// UpdateNumberMemorizedSpellSlots140418a60. Bonus counters are UINT and
// capped255 before the final BYTE addition, including negative raw values.
export function updateMemorizedSpellSlots(o,rules,p){
  classes(o).forEach((c,index)=>{if(classField(rules,c.Class&255,'SpellCaster')===0||classField(rules,c.Class&255,'MemorizesSpells')===0)return;
    for(let level=0;level<10;level++){
      const bonus=integer(c.bonusSpellSlots?.[level]??0,'bonus slot counter')>>>0;
      resizeMemorizedSlots(stateAt(o,index),level,(spellGainWithBonus(o,index,level,rules,p)+Math.min(255,bonus))&255,1,p);
    }
  });
}

export function spellAbilityProviders(o){return{
  abilityScore:(_o,n)=>o.stats.equippedAbilities[names[n]],abilityBonus:(_o,n)=>(o.stats.abilityBonuses??o.stats.equippedBonuses)[names[n]],
  abilityModifier:(_o,n)=>o[abilityModifierCells[n]],
};}

// GetMemorizedSpellReadyCount_ClassInfo140405110. Domain metamagic
// traversal uses XOR2 masks; normal traversal scans every nonzero-meta
// record at each computed level, rather than comparing with that mask.
export function memorizedReadyCount(o,index,id,meta,rules,p={}){
  index=byte(index,'ready class');id=integer(id,'ready spell')>>>0;meta=byte(meta,'ready metamagic');
  if(index>7){p.warning?.('nMultiClass < CNUMMULTICLASS');return{count:0,level:255,slot:255};}
  const c=classes(o)[index];if(!c)throw new Error('Native ready-count class storage is unavailable');
  const state=stateAt(o,index),out={count:0,level:255,slot:255};const spell=physicalRow(rules.spells,id);if(!spell)return out;
  const entry=intEntry(rules.spells,id,'Master'),master=entry.found?entry.value>>>0:id;
  let base=spellLevelByClass(rules,id,c.Class);if(base===255){base=spellLevelByClass(rules,master,c.Class);if(base===255){const innate=intEntry(rules.spells,id,'Innate');base=innate.found?innate.value&255:255;}}
  const scan=(level,predicate)=>{
    if(level>=10)return;const pool=state.memorized[level];if(pool.length>255)throw new Error('Native ready-count scan wraps its BYTE cursor');
    pool.forEach((record,slot)=>{if(record&&record.ready!==0&&predicate(record)){out.count=(out.count+1)&255;if(level<out.level){out.level=level;out.slot=slot;}}});
  };
  if(classField(rules,c.Class&255,'PickDomains')!==0)for(let domain=0;domain<10;domain++){
    if(domain===base||confirmDomainSpell(o,index,domain,id,rules,p)===0)continue;
    if(meta===0||meta===255){scan(domain,r=>r.id===id);if(meta===0)continue;}
    for(let i=meta===255?0:5;i<6;i++){const mask=meta===255?i^2:meta;scan((domain+metamagicLevelCost(rules,mask))&255,r=>r.id===id&&(r.metamagic&255)===mask);}
  }
  if(base!==255){
    if(meta===0||meta===255){scan(base,r=>r.id===id||r.id===master);if(meta===0)return out;}
    for(let i=meta===255?0:5;i<6;i++){const mask=meta===255?1<<i:meta;scan((base+metamagicLevelCost(rules,mask))&255,r=>r.id===id&&(r.metamagic&255)!==0);}
  }
  return out;
}
export function spellLikeReady(o,id){
  if(!Array.isArray(o.nativeSpellLikeAbilities))throw new Error('Native spell-like storage is unavailable');
  return Number(o.nativeSpellLikeAbilities.some(entry=>entry.id===(id>>>0)&&entry.remaining===1));
}
// SetSpellLikeAbilityReady140416b00 changes the first matching ID/level
// whose INT ready value differs. Duplicate abilities remain separate.
export function setSpellLikeReady(o,id,ready,casterLevel){
  id=integer(id,'ability spell')>>>0;ready=integer(ready,'ability ready');casterLevel=byte(casterLevel,'ability caster level');
  if(!Array.isArray(o.nativeSpellLikeAbilities))throw new Error('Native spell-like storage is unavailable');
  const entry=o.nativeSpellLikeAbilities.find(e=>e.id===id&&e.remaining!==ready&&(e.casterLevel&255)===casterLevel);
  if(!entry)return 0;entry.remaining=ready;return 1;
}
// GetSpellLikeAbilityCasterLevel140408aa0 returns the first ID match,
// regardless of remaining uses, and255 when the ID is absent.
export function spellLikeCasterLevel(o,id){
  if(!Array.isArray(o.nativeSpellLikeAbilities))throw new Error('Native spell-like storage is unavailable');
  const entry=o.nativeSpellLikeAbilities.find(e=>e.id===(integer(id,'ability spell')>>>0));return entry?byte(entry.casterLevel,'ability caster level'):255;
}
// UnReadySpell140416eb0. Admission and slot selection are separate: uses
// can be positive even when no ready slot has exactly this metamagic mask.
export function unreadySpell(o,id,index,domainLevel,meta,rules,p){
  id=integer(id,'unready spell')>>>0;index=byte(index,'unready class');domainLevel=byte(domainLevel,'unready domain');meta=byte(meta,'unready metamagic');
  if(integer(o.nativeEquipmentLock97c,'spell override flag')!==0){
    if(integer(o.nativeStatsIsPCb0,'PC flag')===0&&required(p,'possessed')(o)===0)return 1;
    return Number(((meta+1)&254)===0&&[o.nativeSpellOverride9e8,o.nativeSpellOverride9ec,o.nativeSpellOverride9f0].some(v=>integer(v,'override spell ID')>>>0===id));
  }
  const c=classes(o)[index];if(!c||spellUsesLeft(o,id,index,domainLevel,meta,rules,p)===0||!physicalRow(rules.spells,id))return 0;
  const master=intEntry(rules.spells,id,'Master');if(master.found&&(master.value>>>0)!==id){id=master.value>>>0;if(!physicalRow(rules.spells,id))return 0;}
  if(domainLevel===0){domainLevel=spellLevelByClass(rules,id,c.Class);if(domainLevel===255)return 0;}
  else if(confirmDomainSpell(o,index,domainLevel,id,rules,p)===0)return 0;
  const level=(domainLevel+metamagicLevelCost(rules,meta))&255,state=stateAt(o,index);
  if(classField(rules,c.Class&255,'MemorizesSpells')===0){
    if(level<10)state.perDay[level]=(state.perDay[level]-1)&255;else p.warning?.('nSpellLevel < CNWSPELL_NUM_LEVELS');return 1;
  }
  if(level>=10)return 0;const pool=state.memorized[level],count=pool.length&255;
  for(let slot=0;slot<count;slot++){const record=pool[slot];if(record&&record.id===id&&(record.metamagic&255)===meta&&(record.ready&255)!==0){record.ready=0;return 1;}}
  return 0;
}
// Creature DecrementSpellReadyCount14038a590 has an independent unlimited
// flag;254 consumes a spell-like entry instead of a class slot.
export function consumeSpellReady(o,id,index,domainLevel,meta,casterLevel,rules,p){
  if(integer(o.nativeField81c,'unlimited spell flag')!==0)return 1;
  if(byte(index,'consume class')===254)return setSpellLikeReady(o,id,0,casterLevel);
  return unreadySpell(o,id,index,domainLevel,meta,rules,p);
}
// AdjustSpellUsesPerDay1403f00a0 caps the UINT bonus before BYTE addition
// and uses a signed BYTE delta to decide whether to clamp remaining uses.
// Raising the maximum does not restore already spent slots.
export function adjustSpellUsesPerDay(o,rules,p){
  classes(o).forEach((c,index)=>{if(classField(rules,c.Class&255,'MemorizesSpells')!==0)return;
    const state=stateAt(o,index);for(let level=0;level<10;level++){
      const previous=state.maximumPerDay[level]&255,bonus=integer(c.bonusSpellSlots?.[level]??0,'bonus slot counter')>>>0;
      const maximum=(spellGainWithBonus(o,index,level,rules,p)+Math.min(255,bonus))&255;
      state.maximumPerDay[level]=maximum;
      if(((maximum-previous)<<24>>24)<0&&maximum<(state.perDay[level]&255))state.perDay[level]=maximum;
    }
  });
}
// GetHasSilencedSpell1404026a0 checks any silent slot at the base level,
// even an unready different spell. An unavailable level exits the class loop.
export function hasSilencedSpell(o,id,rules){
  if(!physicalRow(rules.spells,id))return 0;
  const list=classes(o);for(let index=0;index<list.length;index++){
    const level=spellLevelByClass(rules,id,list[index].Class);if(level===255)return 0;
    if(stateAt(o,index).memorized[level]?.some(record=>record&&(record.metamagic&255)===16))return 1;
  }
  return 0;
}
const component=(rules,id,letter)=>String(textField(physicalRow(rules.spells,id),'VS')??'').split('\0')[0].includes(letter.toLowerCase());
// GetCreatureHasTalent1403faab0, spell branch. The impaired-state branch
// tests component exceptions/other still slots without a remaining-use check.
export function hasSpellTalent(o,id,meta,rules,p){
  id=integer(id,'talent spell');meta=byte(meta,'talent metamagic');if(id===-1||!physicalRow(rules.spells,id))return 0;
  const word=integer(o.nativeField8d4,'component state')&65535,list=classes(o);
  if((word&6)===6||word===0){
    let found=false;
    for(let index=0;index<list.length;index++)if(spellUsesLeft(o,id,index,0,classField(rules,list[index].Class&255,'MemorizesSpells')===0?0:meta,rules,p)!==0||spellLikeReady(o,id)!==0)found=true;
    return Number(found&&((word&8)!==0||!component(rules,id,'V')||hasSilencedSpell(o,id,rules)!==0));
  }
  if(!component(rules,id,'V')||!component(rules,id,'S')){
    if(component(rules,id,'V')&&hasSilencedSpell(o,id,rules)!==0)return 1;
    if(component(rules,id,'S'))for(let index=0;index<list.length;index++){
      const level=spellLevelByClass(rules,id,list[index].Class);
      if(level<10&&stateAt(o,index).memorized[level].some(record=>record&&record.id!==0&&(record.metamagic&255)===32))return 1;
    }
  }
  return 0;
}
// ExecuteCommandGetHasSpell1405257e0. The spontaneous-conversion
// branch can overwrite an accumulated count and count duplicate slots again.
export function scriptHasSpell(o,id,rules,p){
  id=integer(id,'script spell')>>>0;let spell=physicalRow(rules.spells,id);if(!spell||o?.objectType!==5)return 0;
  const first=id,masterEntry=intEntry(rules.spells,id,'Master'),master=masterEntry.found?masterEntry.value>>>0:id;
  if(master!==id&&physicalRow(rules.spells,master)){spell=physicalRow(rules.spells,master);const next=intEntry(rules.spells,master,'Master');id=next.found?next.value>>>0:master;}
  const pointerId=spell===physicalRow(rules.spells,first)?first:master;let count=0;
  classes(o).forEach((c,index)=>{
    if(classField(rules,c.Class&255,'SpellCaster')!==1)return;
    if(classField(rules,c.Class&255,'MemorizesSpells')===0){count=(count+spellUsesLeft(o,id,index,0,0,rules,p))|0;return;}
    count=(count+memorizedReadyCount(o,index,id,255,rules,p).count)|0;
    if(intEntry(rules.spells,pointerId,'SpontaneouslyCast').value===0)return;
    const level=spellLevelByClass(rules,pointerId,c.Class),pool=stateAt(o,index).memorized[level]??[];
    if((id-31>>>0)<5||(id-431>>>0)<5){
      if(classField(rules,c.Class&255,'CanCastSpontaneously')!==0)count=pool.reduce((n,r)=>r&&(r.ready&255)!==0&&r.domain===0?(n+1)&255:n,0);
    }else for(const record of pool)count=(count+memorizedReadyCount(o,index,record?.id??0xffffffff,255,rules,p).count)|0;
  });
  return(count+spellLikeReady(o,id))|0;
}
