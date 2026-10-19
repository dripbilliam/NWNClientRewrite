const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native bonus spell slots ${n} is unavailable`);return v|0;};
const call=(p,n,...a)=>{if(typeof p?.[n]!=='function')throw new Error(`Native bonus spell slots provider ${n} is unavailable`);return p[n](...a);};
const classes=(o,p)=>call(p,'classes',o),count=(o,p)=>classes(o,p).length&255;
const warn=(p,text)=>call(p,'warning',text);
const counters=c=>{if(!Array.isArray(c.bonusSpellSlots)||c.bonusSpellSlots.length!==10)throw new Error('Native bonus spell slot counters are unavailable');return c.bonusSpellSlots;};
const perDay=(o,index,p)=>{const state=call(p,'state',o,index);if(!Array.isArray(state?.perDay)||state.perDay.length!==10)throw new Error('Native per-day spell counters are unavailable');return state.perDay;};

// Stats SetNumberMemorizedSpellSlots140416540. Equipment/area suppression
// flags keep truncated records allocated; native class-info resize owns storage.
export function setNumberMemorizedSpellSlots(o,index,level,value,p){
  index=integer(index,'class index')&255;level=integer(level,'level')&255;value=integer(value,'slot count')&255;
  if(index>=count(o,p))warn(p,'nMultiClass < m_nNumMultiClasses');
  if(index<count(o,p))call(p,'resize',o,index,level,value,Number(integer(o.nativeField9f4,'field9f4')===0&&integer(o.nativeEquipmentLock97c,'equipment lock')===0));
}
// ModifyNumberBonusSpells14040f110. Signed DWORD addition/clamp for counters,
// unsigned cap255 for the getter, then SATURATING (not wrapping) BYTE addition.
export function modifyNumberBonusSpells(o,index,level,delta,p){
  index=integer(index,'class index')&255;level=integer(level,'level')&255;delta=integer(delta,'delta');
  if(index>=count(o,p))warn(p,'nMultiClass < m_nNumMultiClasses');
  if(index>=count(o,p))return;
  if(level<10){const values=counters(classes(o,p)[index]),value=(integer(values[level],'counter')+delta)|0;if(value<0)warn(p,'delta makes bonus spells negative newVal >= 0');values[level]=Math.max(0,value);}
  else warn(p,'nSpellLevel < CNWSPELL_NUM_LEVELS');
  let bonus=0;if(index>=count(o,p))warn(p,'nMultiClass < m_nNumMultiClasses');
  if(index<count(o,p)&&level<10)bonus=Math.min(255,integer(counters(classes(o,p)[index])[level],'counter')>>>0);
  const gain=integer(call(p,'gain',o,index,level),'spell gain')&255;
  setNumberMemorizedSpellSlots(o,index,level,Math.min(255,gain+bonus),p);
}
export function spellsPerDayLeft(o,index,level,p){
  index=integer(index,'class index')&255;level=integer(level,'level')&255;
  if(index>=count(o,p))warn(p,'nMultiClass < m_nNumMultiClasses');
  if(index<count(o,p)){if(level<10)return integer(perDay(o,index,p)[level],'per-day counter')&255;warn(p,'nSpellLevel < CNWSPELL_NUM_LEVELS');}return 0;
}
export function decrementSpellsPerDayLeft(o,index,level,p){
  index=integer(index,'class index')&255;level=integer(level,'level')&255;
  if(index>=count(o,p))warn(p,'nMultiClass < m_nNumMultiClasses');
  if(index<count(o,p)){if(level<10){const values=perDay(o,index,p);values[level]=(integer(values[level],'per-day counter')-1)&255;}else warn(p,'nSpellLevel < CNWSPELL_NUM_LEVELS');}
}
// ApplyBonusSpellOfLevel46e820 / RemoveBonusSpellOfLevel473c30. Last matching
// class slot wins. Compare full property subtype WORD against class BYTE; level
// comes directly from the low BYTE of CostValue, independent of pricing 2DAs.
function matchingClass(o,property,p){let selected=-1;for(let i=0;i<count(o,p);i++)if((integer(call(p,'classType',o,i),'class type')&255)===(integer(property.subtype,'property subtype')&65535))selected=i;return selected;}
export function applyBonusSpellOfLevel(_item,property,o,_slot,_loading,p){
  const index=matchingClass(o,property,p);if(index>=0)modifyNumberBonusSpells(o,index,integer(property.costValue,'property cost value')&255,1,p);return 0;
}
export function removeBonusSpellOfLevel(_item,property,o,_slot,p){
  const index=matchingClass(o,property,p);if(index>=0){const level=integer(property.costValue,'property cost value')&255;modifyNumberBonusSpells(o,index,level,-1,p);
    if(integer(call(p,'memorizes',integer(property.subtype,'property subtype')&255),'memorizes')===0&&spellsPerDayLeft(o,index,level,p)!==0)decrementSpellsPerDayLeft(o,index,level,p);
  }return 0;
}
