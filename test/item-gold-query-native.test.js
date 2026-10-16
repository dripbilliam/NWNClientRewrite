import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {scriptItemGoldValue} from '../src/item_price.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-item-gold-query-observations.json',import.meta.url)));
test('GetGoldPieceValue command body matches32 original runs with signed INT output, raw lookup status and twice-called item cast',async()=>{
 assert.equal(capture.rows.length,32);
 for(const expected of capture.rows){
  const c=expected.case,calls=[],object={},item={};const value=await scriptItemGoldValue(17,{
   lookup:id=>{calls.push(['lookup',id]);return{status:c.lookup,object};},asItem:o=>{assert.equal(o,object);calls.push(['asItem']);return c.item?item:null;},
   price:(o,...args)=>{assert.equal(o,item);calls.push(['price',...args]);return c.price;},
  });assert.equal(expected.status,0);assert.deepEqual({calls,pushed:value>>>0},{calls:expected.calls,pushed:expected.pushed});
 }
});
