const f=Math.fround,half=2**63;
const cvtt64low=value=>Number.isFinite(value)&&value>=-half&&value<half?Number(BigInt.asUintN(32,BigInt(Math.trunc(value)))):0;

// CNWSItem::GetPropertyCost1404656c0..1404659dd. Every FLOAT read writes
// its output, including failure. In particular a missing cost table multiplies
// by the retained prior FLOAT output; do not substitute an identity factor.
export async function itemPropertyPrice(item,property,p){
 if((property.durationType&255)===1)return f(0);
 let result=f(0),scratch=await p.float('definition',property.type&65535,'Cost');
 if((scratch.status|0)!==0)result=f(result+f(scratch.value));
 else{
  const subtype=await p.string('definition',property.type&65535,'SubTypeResRef');
  if((subtype.status|0)!==0){
   const table=await p.namedTable(subtype.value,0);
   if(table){scratch=await p.float(table,property.subtype&65535,'Cost');if((scratch.status|0)!==0)result=f(result+f(scratch.value));}
  }
 }
 const cost=await p.int('definition',property.type&65535,'CostTableResRef');
 if((cost.status|0)!==0&&(cost.value|0)!==0){
  const table=await p.costTable(cost.value|0);
  if(table)scratch=await p.float(table,property.costValue&65535,'Cost');
  result=f(result*f(scratch.value));
 }
 return result;
}

// ComputeCost140464e10..140465309. FLOAT operations are rounded at every
// SSE step; CVTTSS2SI uses the 64-bit destination before low-DWORD storage.
export async function recalculateItemPrice(item,p){
 let base=f(0),multiplier=f(1),positive=f(0),negative=f(0),active=f(0);
 const info=await p.baseInfo(item);
 if(info){base=(info.category&255)===4?f((await p.float('armor',item.nativeBaseArmor35c|0,'Cost')).value):f(info.baseCost);multiplier=f(info.itemMultiplier);}
 for(const property of item.passiveProperties){const cost=f(await p.propertyPrice(item,property));if(cost>0)positive=f(positive+cost);else negative=f(negative+cost);}
 if(item.activeProperties.length>0){
  let largest=f(0),second=f(0);const costTable=await p.costTable(3),costColumn=await p.column(costTable,'Cost'),spellColumn=await p.column('spells','Cost');
  for(const property of item.activeProperties){
   if((property.durationType&255)!==2)continue;
   if((property.type&65535)===15){
    const spell=f((await p.floatColumn('spells',property.subtype&65535,spellColumn)).value),uses=f((await p.floatColumn(costTable,property.costValue&65535,costColumn)).value);
    let cost=f(uses*spell);const value=property.costValue&65535;
    if(value>=2&&value<=6){const charges=Math.max(1,Math.min(250,(await p.rule('MAX_CHARGES_FOR_ITEM_COST',50))|0));cost=f(cost*f(f(item.charges|0)/f(charges)));}
    if(cost>largest){largest=cost;active=f(active+f(cost*f(.5)));}
    else{second=Number.isNaN(cost)||Number.isNaN(second)?second:cost>second?cost:second;active=f(active+f(cost*f(.5)));}
   }else{const cost=f(await p.propertyPrice(item,property));if(cost>0)positive=f(positive+cost);else negative=f(negative+cost);}
  }
  active=f(active+f(f(second*f(.25))+f(largest*f(.5))));
 }
 const rawBase=cvtt64low(base);item.nativeUnidentifiedPrice390=cvtt64low(f(f(rawBase)*multiplier));
 const total=(rawBase+cvtt64low(f(f(positive*positive)*f(1000)))+cvtt64low(active))>>>0,discount=cvtt64low(f(f(negative*negative)*f(1000)));
 item.nativeBasePrice38c=discount>total?0:cvtt64low(f(f((total-discount)>>>0)*multiplier));
}

// GetCost140468710..1404687fd; this owner alone clears price-dirty after
// ComputeCost. All cached DWORD arithmetic and comparisons are unsigned.
export async function getItemPrice(item,stack,identified,ilr,overridePlot,p){
 if((overridePlot|0)===0&&((item.plot|0)===1||((item.baseItem-69)>>>0)<=4))return 0;
 if((item.nativePriceDirty398|0)!==0){await p.recalculate(item);item.nativePriceDirty398=0;}
 let price=(identified|0)===0&&(item.identified|0)===0?item.nativeUnidentifiedPrice390>>>0:((item.nativeAddCost394|0)+(item.nativeBasePrice38c|0))>>>0;
 if((ilr|0)===1)price=Math.imul((await p.baseInfo(item)).ilrStackSize&255,price)>>>0;
 else if((stack|0)===1){
  if(price<1&&(item.stackSize|0)<((await p.baseInfo(item)).stacking&65535))return 0;
  price=Math.imul(item.stackSize|0,price)>>>0;
 }
 return Math.max(1,price);
}

// ExecuteCommandGetGoldPieceValue140525193..1405251ef after typed PopObject:
// successful raw lookup, virtual item cast twice, GetCost(1,0,0,0), PushInt.
export async function scriptItemGoldValue(id,p){
 const lookup=await p.lookup(id>>>0);if((lookup.status&255)!==0)return 0;
 if(!await p.asItem(lookup.object))return 0;
 return(await p.price(await p.asItem(lookup.object),1,0,0,0))|0;
}
