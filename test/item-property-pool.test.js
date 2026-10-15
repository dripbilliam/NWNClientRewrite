import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {applyItemProperty,importedPropertyEffect,ItemPropertyIds} from '../src/item_property_pool.js';

test('property acceptance, IDs, active/passive classification and counters match144 native executions',async()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-item-property-pool-observations.json',import.meta.url)));
  assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.observations.length,144);
  for(const {case:c,result:expected} of oracle.observations){
    const ids=new ItemPropertyIds(41n),effect={integers:[c.type,9,0x102,c.cost,0x103,0x104,c.uses,0x105,7],customTag:'tag',durationType:c.duration,propertyId:'0000000000000000'};
    let property,pool=null,column=null;
    const cols=Array.from({length:256},(_,i)=>`column${i}`),cells=[];cells[c.type]=Array(256).fill(String(c.allowed));
    const table={columns:cols,defaultValue:'****',orderedCells:cells};
    const consumed=await applyItemProperty({objectType:6},effect,{itemprops:c.tablePresent?table:null},{
      baseInfo:()=>c.validBase?{basePropColumn:c.column}:null,baseItem:()=>c.base,allocatePropertyId:()=>ids.next(),
      appendProperty:(_item,p,a)=>{property=p;pool=a;column=c.column;},activeChanged:()=>{},propertyChanged:()=>{}});
    // The native INT query is still issued for a rejected zero-valued cell.
    if(c.validBase&&c.tablePresent)column=c.column;
    const result={consumed,pool,column,effectPropertyId:Number(BigInt('0x'+effect.propertyId)),nextPropertyId:Number(ids.value),subtype:effect.integers[1]};
    if(property)result.property=property;
    assert.deepEqual(result,expected,JSON.stringify(c));
  }
});

test('GFF property defaults and independent uint64 property IDs retain explicit use counters',()=>{
  let constructors=0;
  const create=(type,integers)=>({type,integers,id:String(++constructors)});
  const a=importedPropertyEffect({},create),b=importedPropertyEffect({PropertyName:15,Useable:0,UsesPerDay:259},create);
  assert.deepEqual(a.integers,[0,0,0,0,0,0,255,0,1]);assert.equal(a.durationType,2);
  assert.equal(b.integers[6],3);assert.equal(b.integers[8],0);assert.equal(constructors,2);
  const ids=new ItemPropertyIds(0xffffffffffffffffn);assert.equal(ids.next(),'0000000000000000');assert.equal(ids.next(),'0000000000000001');
});

test('ITEMPROPS admission uses physical duplicate columns and native default INT policy',async()=>{
  let added=0;const p={baseInfo:()=>({basePropColumn:1}),baseItem:()=>49,allocatePropertyId:()=> '0000000000000001',appendProperty:()=>added++,activeChanged:()=>{},propertyChanged:()=>{}};
  const e=()=>importedPropertyEffect({},(type,integers)=>({type,integers}));
  const table={columns:['same','same'],orderedCells:[['0','0x1']],defaultValue:'5'};
  assert.equal(await applyItemProperty({objectType:6},e(),{itemprops:table},p),0);assert.equal(added,1);
  table.orderedCells=[];assert.equal(await applyItemProperty({objectType:6},e(),{itemprops:table},p),0);assert.equal(added,2);
  await assert.rejects(applyItemProperty({objectType:6},e(),{},p),/ITEMPROPS ownership/);
});
