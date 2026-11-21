import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {itemPropertyPrice,recalculateItemPrice,getItemPrice} from '../src/item_price.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-item-price-observations.json',import.meta.url))),f=Math.fround;
const fl=value=>typeof value==='string'?({nan:NaN,inf:Infinity,'-inf':-Infinity})[value]:value;
const hex=value=>{const bytes=new ArrayBuffer(4),v=new DataView(bytes);v.setFloat32(0,value,true);return v.getUint32(0,true).toString(16).padStart(8,'0');};
const property=p=>({type:p.type??15,subtype:p.subtype??1,costValue:p.costValue??2,durationType:p.durationType??2,...p});
test('three complete item price owners match1439 original executions including FLOAT rounding, status, retained scratch and unsigned arithmetic',async()=>{
 assert.equal(capture.rows.length,1439);
 for(const expected of capture.rows){
  const c=expected.case,calls=[],item={baseItem:c.baseItem??0,plot:c.plot??0,identified:c.identified??0,charges:c.charges??50,nativeBaseArmor35c:c.armor??3,stackSize:c.stack??3,nativeBasePrice38c:c.base??11,nativeUnidentifiedPrice390:c.unidentified??5,nativeAddCost394:c.add??2,nativePriceDirty398:c.dirty??0,passiveProperties:(c.passive??[]).map(property),activeProperties:(c.active??[]).map(property)};
  const p={
   baseInfo:()=>{calls.push(['baseInfo']);return c.nullBase?null:{category:c.category??0,baseCost:fl(c.baseCost??10),itemMultiplier:fl(c.multiplier??1),stacking:c.stacking??1,ilrStackSize:c.ilrStackSize??7};},
   float:(table,row,column)=>{calls.push(['float',table,row,column]);const entry=c.floats?.[table]??{status:0,value:0};return{...entry,value:f(fl(entry.value))};},
   string:(table,row,column)=>{calls.push(['string',table,row,column]);return c.subtype??{status:0,value:''};},
   namedTable:(name,flag)=>{calls.push(['namedTable',name,flag]);return c.named===false?null:'named';},int:(table,row,column)=>{calls.push(['int',table,row,column]);return c.costType??{status:0,value:0};},
   costTable:id=>{calls.push(['costTable',id&255]);return c.costPresent===false?null:'cost';},
   column:(table,column)=>{calls.push(['column',table,column]);return table==='cost'?6:3;},
   floatColumn:(table,row,column)=>{calls.push(['floatColumn',table,row,column]);return{status:0,value:f(fl((table==='spells'?c.spellCosts:c.useCosts)?.[row]??0))};},
   rule:(label,fallback)=>{calls.push(['rule',label,fallback]);return c.rule??50;},
   propertyPrice:(_o,entry)=>{const passive=item.passiveProperties.indexOf(entry),name=passive>=0?`passive${passive}`:`active${item.activeProperties.indexOf(entry)}`;calls.push(['propertyPrice',name]);return f(fl(entry.price??0));},
   recalculate:o=>{calls.push(['recalculate']);o.nativeBasePrice38c=c.newBase??17;o.nativeUnidentifiedPrice390=c.newUnidentified??3;o.nativeAddCost394=c.newAdd??2;},
  };
  let result;
  if(c.mode==='property')result=hex(await itemPropertyPrice(item,property(c.property??{}),p));
  else if(c.mode==='recalculate')await recalculateItemPrice(item,p);
  else result=await getItemPrice(item,c.stackFlag??0,c.identifiedFlag??1,c.ilrFlag??0,c.overridePlot??0,p);
  const cells=Object.fromEntries([[0x38c,item.nativeBasePrice38c],[0x390,item.nativeUnidentifiedPrice390],[0x394,item.nativeAddCost394],[0x398,item.nativePriceDirty398]].map(([offset,value])=>[offset,value>>>0]));
  assert.deepEqual({calls,cells,result},{calls:expected.calls,cells:expected.cells,result:c.mode==='property'?expected.floatResult:c.mode==='get'?expected.result:undefined},JSON.stringify(c));
 }
});
