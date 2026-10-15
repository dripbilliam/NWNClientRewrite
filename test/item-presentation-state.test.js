import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {parse2da} from '../src/area.js';
import {itemActiveUsesLeft,updateItemActiveUseCache,selectItemVisual} from '../src/item_presentation_state.js';
const oracle=()=>JSON.parse(readFileSync(new URL('../backups/animations/native-item-presentation-observations.json',import.meta.url)));

test('active item use counts match2430 complete native executions',()=>{
  const o=oracle();assert.equal(o.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(o.left.length,2430);
  for(const {case:c,value} of o.left){
    const item={activeProperties:[{type:15,costValue:c.cost,remaining:c.remaining,usesPerDay:c.uses}],charges:c.charges,stackSize:c.stack};
    assert.equal(itemActiveUsesLeft(item,0),value,JSON.stringify(c));
  }
});

test('active cache masks match90 native executions, including physical indices beyond eight',()=>{
  const o=oracle();assert.equal(o.caches.length,90);
  for(const {case:c,props,result} of o.caches){
    const item={activeProperties:props,charges:c.charges,stackSize:256,activeUseMask:85,activeUseBytes:[0,1,2,3,4,5,6,7]};
    const state=updateItemActiveUseCache(item,c.force);
    assert.deepEqual({mask:item.activeUseMask,uses:item.activeUseBytes,clientQueries:Number(state.updated)},result,JSON.stringify(c));
    assert.equal(state.full,c.force!==0);
  }
  const item={activeProperties:[],charges:0,stackSize:1,activeUseMask:0,activeUseBytes:Array(8).fill(0)};
  assert.equal(updateItemActiveUseCache(item,2).updated,false);assert.equal(updateItemActiveUseCache(item,1).updated,true);
});

test('item visual priority and dynamic metadata/legacy fallback match3960 native executions',async()=>{
  const o=oracle();assert.equal(o.visuals.length,3960);
  for(const {case:c,result} of o.visuals){
    const definition=parse2da(`2DA V2.0\n\nSubTypeResRef\n${Array.from({length:84},(_,i)=>`${i} ${c.mode==='legacy'?'****':'child'}`).join('\n')}`);
    const table=c.mode==='missing-table'?null:parse2da(`2DA V2.0\n\n${c.mode==='no-column'?'Other':'VisualFX'}\n${Array.from({length:256},(_,i)=>`${i} ${c.mode==='bad-cell'?'****':c.visualValue}`).join('\n')}`);
    const cost=parse2da(`2DA V2.0\n\nVFX\n0 0\n1 ${c.vfx}`),rules={itempropdef:definition,iprp_damagecost:cost,iprp_meleecost:cost};
    const item={passiveProperties:[{type:c.type,subtype:c.subtype,param1Value:c.subtype,costValue:1},{type:36,costValue:1}]};
    assert.equal(await selectItemVisual(item,rules,{baseInfo:()=>({modelType:2}),subtypeTable:()=>table}),result,JSON.stringify(c));
  }
});
