import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {loadItemFromGff,readItemGffField} from '../src/item_gff_load.js';
import {parseGff} from '../src/gff.js';
import {writeGff,record as R,field as F} from '../scripts/native-oracle-data.mjs';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-item-gff-wrapper-observations.json',import.meta.url)));
test('full item GFF wrapper matches387 original branch/status/order/width executions',async()=>{
 assert.equal(capture.rows.length,387);
 for(const expected of capture.rows){
  const c=expected.case,calls=[],item={drop:7,pick:9};
  const result=await loadItemFromGff(item,{},c.loading,c.inside,{
   read:(_data,kind,name,fallback)=>{
    const status=name==='EquippedRes'?c.equipped:name==='InventoryRes'?c.inventory:name==='Dropable'?c.dropStatus:c.pickStatus;
    const raw=status?c.value&255:0,value=kind==='resref'?status?c.reference:'':kind==='bool'?Number(raw!==0):raw;
    calls.push(['read',kind,name,fallback,status,value]);return{status,value};
   },
   loadTemplate:(_o,ref)=>{calls.push(['template',ref]);return c.result;},field:(_o,offset,value)=>{item[offset===0x448?'drop':'pick']=value;},
   loadData:(_o,_data,loading,inside)=>{calls.push(['data',loading>>>0,inside|0]);return c.result;},
   savedState:()=>calls.push(['saved']),addTag:()=>calls.push(['tag','ItemTag',42]),visual:()=>calls.push(['visual']),
  });
  assert.deepEqual({result:result>>>0,drop:item.drop,pick:item.pick,calls},{result:expected.result,drop:expected.drop,pick:expected.pick,calls:expected.calls},JSON.stringify(c));
 }
});
test('item GFF metadata controls template presence and raw BYTE versus BOOL overrides',()=>{
 const data=parseGff(writeGff('UTI ',R({EquippedRes:F(11,''),InventoryRes:F(10,'wrong'),Dropable:F(0,255),Pickpocketable:F(4,1)})),'UTI ').root;
 assert.deepEqual(readItemGffField(data,'resref','EquippedRes','fallback'),{status:1,value:''});
 assert.deepEqual(readItemGffField(data,'resref','InventoryRes','fallback'),{status:0,value:'fallback'});
 assert.deepEqual(readItemGffField(data,'byte','Dropable',0),{status:1,value:255});
 assert.deepEqual(readItemGffField(data,'bool','Dropable',0),{status:1,value:1});
 assert.deepEqual(readItemGffField(data,'bool','Pickpocketable',0),{status:0,value:0});
});
