import {intEntry} from './combat_stats.js';
const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native item presentation ${name} is unavailable`);return v|0;};
const required=(p,name)=>{if(typeof p?.[name]!=='function')throw new Error(`Native item presentation provider ${name} is unavailable`);return p[name];};
const properties=(item,active)=>{const list=active?item.activeProperties:item.passiveProperties;if(!Array.isArray(list))throw new Error('Native item property pool is unavailable');return list;};

// GetUsedActivePropertyUsesLeft140469170..1404692a9. Remaining is a flag;
// daily display reads UsesPerDay, not a synthesized decrement counter.
export function itemActiveUsesLeft(item,index){
  index=integer(index,'property index')&255;const prop=properties(item,true)[index];if(!prop||prop.type!==15||prop.remaining===0)return 0;
  if(prop.costValue===1)return integer(item.stackSize,'stack size')&255;
  if(prop.costValue>=2&&prop.costValue<=6){const charges=integer(item.charges,'charges');return charges>0?Math.trunc(charges/(7-prop.costValue))&65535:0;}
  if(prop.costValue>=8&&prop.costValue<=12)return prop.usesPerDay&255;
  return 0;
}

// UpdateUsedActiveProperties14046cf20 through cache writes14046d07f.
// Sender routing uses this result; no full or delta packet is fabricated here.
export function updateItemActiveUseCache(item,force){
  force=integer(force,'force');const list=properties(item,true),uses=Array(8).fill(0);let mask=0,changedMask=0;
  for(let index=0;index<list.length;index++){
    const prop=list[index];if(prop.type!==15)continue;
    const cost=prop.costValue,selected=cost===1?prop.remaining!==0:cost>=2&&cost<=6?integer(item.charges,'charges')>0:
      cost===7||cost===13?true:cost>=8&&cost<=12?(prop.usesPerDay&255)>0:false;
    if(!selected)continue;
    if(index<8)uses[index]=itemActiveUsesLeft(item,index)&255;
    mask=(mask|(1<<(index&31)))&255;
  }
  if(!Array.isArray(item.activeUseBytes)||item.activeUseBytes.length!==8)throw new Error('Native active-use BYTE cache is unavailable');
  for(let index=0;index<8;index++)if(uses[index]!==item.activeUseBytes[index])changedMask|=1<<index;
  const updated=mask!==(integer(item.activeUseMask,'active-use mask')&255)||changedMask!==0||force===1;
  if(updated){item.activeUseMask=mask;item.activeUseBytes=uses;}
  return{updated,mask,changedMask,uses,full:force!==0};
}

// UpdateVisualEffect14046d140. Dynamic SubTypeResRef/VisualFX tables take
// precedence over the verified legacy elemental/alignment switches.
export async function selectItemVisual(item,rules,p){
  const base=required(p,'baseInfo')(item);if(!base)throw new Error('Native item visual dereferences unavailable base-item storage');
  if((integer(base.modelType,'model type')&255)!==2)return 0;
  const list=properties(item,false),explicit=list.find(prop=>prop.type===83);
  if(explicit)return(explicit.subtype+1)&255;
  let selected=false,visual=0;
  for(const prop of list){
    if(selected)break;
    if(prop.type<16||prop.type>19)continue;
    if(!rules.iprp_damagecost)throw new Error('Native IPRP_DAMAGECOST visual table is unavailable');
    // Native sets its stop flag BEFORE checking VFX. A zero cell blocks
    // later damage/alignment visuals, even though no visual was selected.
    if(intEntry(rules.iprp_damagecost,prop.costValue,'VFX').value===0)return 0;
    if(!rules.itempropdef)throw new Error('Native ITEMPROPDEF visual table is unavailable');
    const row=(rules.itempropdef.orderedRows??[...rules.itempropdef.rows.values()])[prop.type];
    const key=Object.keys(row??{}).find(k=>k.toLowerCase()==='subtyperesref'),name=row?.[key];
    const table=name!==undefined&&name!==''&&name!=='****'?await required(p,'subtypeTable')(name):null;
    const hasColumn=table?.columns?.some(k=>k.toLowerCase()==='visualfx');
    if(hasColumn){const entry=intEntry(table,prop.subtype,'VisualFX');if(entry.found){visual=(entry.value+1)&255;selected=true;}}
    else{
      const type=prop.type===16?prop.subtype:prop.param1Value,adjusted=type>2?(type-2)&65535:type;
      const value=({4:1,5:2,7:3,8:4,11:5})[adjusted];if(value!==undefined){visual=value;selected=true;}
    }
  }
  if(visual!==0||selected)return visual;
  for(const prop of list){
    if([7,17,57].includes(prop.type)){if(prop.subtype===4)return 7;if(prop.subtype===5)return 6;}
    else if([9,19,59].includes(prop.type)){if([0,3,6].includes(prop.subtype))return 7;if([2,5,8].includes(prop.subtype))return 6;}
    else if(prop.type===36)return 6;
    else if(prop.type===48&&[17,24,25].includes(prop.subtype))return 7;
    else if(prop.type===67){if(!rules.iprp_meleecost)throw new Error('Native IPRP_MeleeCost visual table is unavailable');if(intEntry(rules.iprp_meleecost,prop.costValue,'VFX').value!==0)return 7;}
  }
  return 0;
}
