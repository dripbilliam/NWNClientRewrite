const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native item-property query ${n} is unavailable`);return v|0;};
// ExecuteCommandGetItemProperty140528e60 walks the NWSObject effect pool
// after AsNWSItem admission. It deliberately does NOT filter type91 here.
// Type67 and hidden records are skipped; duration low bits must be1/2.
export function enumerateItemProperty(item,first,invalid){
  if(item?.objectType!==6)return invalid();
  if(item.authored?.EffectList?.length)throw new Error('Saved active item-effect import is unavailable');
  if(!Array.isArray(item.effects))throw new Error('Native item-property effect storage is unavailable');
  if(first)item.effectCursor=0;
  for(let index=integer(item.effectCursor??0,'cursor')&65535;index<item.effects.length;index++){
    const e=item.effects[index];if(!e.exposed||(integer(e.type,'effect type')&65535)===67||! [1,2].includes(integer(e.durationType,'duration type')&7))continue;
    item.effectCursor=(index+1)&65535;return structuredClone(e);
  }
  item.effectCursor=0;return invalid();
}
export function validItemProperty(effect){return Number(Boolean(effect&&(integer(effect.type,'effect type')&65535)===91));}
// GetItemPropertyType1405294b0/info1405292e0 return raw stored INTs.
export function itemPropertyValue(effect,ordinal){
  if(!validItemProperty(effect))return -1;
  const index=({614:0,734:1,769:2,770:3,771:4,772:5})[ordinal];
  return index===undefined?-1:integer(effect.integers?.[index],`integer${index}`);
}
// GetItemHasItemProperty1405282e0 compares query INT with zero-extended
// WORD property type. Active pool precedes passive; query is not WORD narrowed.
export function itemHasProperty(item,type){
  if(item?.objectType!==6)return 0;type=integer(type,'type');
  if(!Array.isArray(item.activeProperties)||!Array.isArray(item.passiveProperties))throw new Error('Native item-property pools are unavailable');
  return Number([...item.activeProperties,...item.passiveProperties].some(p=>p&&(integer(p.type,'pool type')&65535)===type));
}
