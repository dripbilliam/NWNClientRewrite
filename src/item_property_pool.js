import {activeItemProperty} from './combat_on_hit.js';
import {intEntry} from './combat_stats.js';

const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native item property ${name} is unavailable`);return v|0;};
const required=(p,name)=>{if(typeof p?.[name]!=='function')throw new Error(`Native item property provider ${name} is unavailable`);return p[name];};

// PropertiesList portion of LoadDataFromGff14046a269..14046a50e. One effect
// constructor is invoked even for a property later rejected by ITEMPROPS.
export function importedPropertyEffect(entry,create){
  const values=[(entry.PropertyName??0)&65535,(entry.Subtype??0)&65535,(entry.CostTable??0)&255,
    (entry.CostValue??0)&65535,(entry.Param1??0)&255,(entry.Param1Value??0)&255,
    (entry.UsesPerDay??255)&255,(entry.ChanceAppear??0)&255,(entry.Useable??1)&255];
  const effect=create(91,values);effect.durationType=2;effect.propertyId='0000000000000000';effect.customTag=String(entry.CustomTag??'');return effect;
}

// RestoreUsedActiveProperty14046b580. Cost types outside8..12 still reset
// remaining to1; an explicit UsesPerDay BYTE skips the entire default restore.
export function restoreActiveProperty(property,onlyUnset){
  if(property.type!==15||onlyUnset!==0&&property.usesPerDay!==255)return;
  if(property.costValue>=8&&property.costValue<=12)property.usesPerDay=property.costValue-7;
  property.remaining=1;
}
// Bulk owner14046b4d0 traverses the physical active array and applies the
// same TYPE15/cost/UsesPerDay policy; it does not replenish charges or stacks.
export function restoreActiveProperties(item,onlyUnset){
 onlyUnset=integer(onlyUnset,'bulk restore flag');if(!Array.isArray(item.activeProperties))throw new Error('Native active property storage is unavailable');
 for(const property of item.activeProperties)restoreActiveProperty(property,onlyUnset);
}

// OnApplyItemProperty14042e5c0: acceptance/materialization phase through83e.
// Full possession/equipment/cost propagation is supplied by the owner callback,
// never silently inferred from an authored PropertiesList.
export async function applyItemProperty(item,effect,rules,p){
  if(item?.objectType!==6)return 1;
  const base=required(p,'baseInfo')(item);if(!base)return 1;
  const integers=effect.integers;if(!Array.isArray(integers)||integers.length<9)throw new Error('Native item property integer storage is unavailable');
  if((integers[0]|0)===61){
    const id=integer(required(p,'baseItem')(item),'base item');
    if(id===8||id===11)integers[1]=0;else if(id===6||id===7)integers[1]=1;else if(id===61)integers[1]=2;
  }
  // The numeric column is BasePropColumn itself, without an offset. Physical
  // column identity matters even when headers are duplicated.
  if(rules.itemprops===undefined)throw new Error('Native ITEMPROPS ownership is unavailable');
  if(rules.itemprops===null)return 1;
  const column=integer(base.basePropColumn,'base property column')&255,table=rules.itemprops,row=integers[0]|0;
  const cells=table.orderedCells;if(!Array.isArray(cells)||!Array.isArray(table.columns))throw new Error('Native ITEMPROPS physical cells are unavailable');
  const value=row>=0&&row<cells.length&&column<table.columns.length?cells[row][column]:undefined;
  // Reuse the native INT conversion/default policy without a header lookup.
  const entry=intEntry({defaultValue:table.defaultValue,orderedRows:value===undefined?[]:[{cell:value}]},0,'cell');
  if(entry.value===0)return 1;
  const propertyId=required(p,'allocatePropertyId')();
  if(typeof propertyId!=='string'||! /^[0-9a-f]{16}$/.test(propertyId))throw new Error('Native item property uint64 ID is unavailable');
  if(effect.propertyId==='0000000000000000')effect.propertyId=propertyId;
  const property={type:integers[0]&65535,subtype:integers[1]&65535,costTable:integers[2]&255,costValue:integers[3]&65535,
    param1:integers[4]&255,param1Value:integers[5]&255,usesPerDay:integers[6]&255,chance:integers[7]&255,
    remaining:integers[8]|0,durationType:(effect.durationType&7)===1?1:2,customTag:String(effect.customTag??''),propertyId};
  const active=activeItemProperty(integers[0]);
  const appliedProperty={...property}; // Native callback receives the stack copy.
  required(p,'appendProperty')(item,property,active);
  if(active){restoreActiveProperty(property,1);await required(p,'activeChanged')(item,1);}
  await required(p,'propertyChanged')(item,appliedProperty,effect);
  return 0;
}

// Global14141ef30 is preincremented, distinct from CGameEffect's IDs.
export class ItemPropertyIds {
  constructor(initial=0n){this.value=BigInt.asUintN(64,initial);}
  next(){this.value=BigInt.asUintN(64,this.value+1n);return this.value.toString(16).padStart(16,'0');}
}
