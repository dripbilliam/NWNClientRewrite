import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {addStoreItem} from '../src/store_item_acquisition.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-store-acquisition-observations.json',import.meta.url)));
test('store acquisition matches116 original runs of backwards traversal, suffix reinsertion, duplicates, stale IDs and ignored coordinates',async()=>{
 assert.equal(capture.rows.length,116);
 for(const expected of capture.rows){
  const c=expected.case,calls=[],incoming={label:'incoming',id:100,...c.incoming},items=(c.items??[]).map((row,i)=>({label:`item${i}`,id:101+i,...row})),order=items.map((item,i)=>({label:`node${i}`,item:item.missing?null:item})),ref={item:incoming};
  const result=await addStoreItem({},ref,c.panel??0,2,3,{
   baseInfo:item=>{calls.push(['baseInfo',item.label]);return{storePanelSort:item.sort??0};},price:(item,...args)=>{calls.push(['price',item.label,...args]);return item.price??0;},
   repository:(_o,panel)=>{assert.equal(panel,(c.panel??0)&255);return order;},head:()=>order[0]??null,tail:()=>order.at(-1)??null,
   item:(_repo,node)=>{calls.push(['item',node.label]);return node.item;},previous:(_repo,node)=>{calls.push(['previous',node.label]);return order[order.indexOf(node)-1]??null;},
   removeNode:(_repo,node)=>{calls.push(['remove',node.label]);order.splice(order.indexOf(node),1);},
   add:(_repo,ref,...args)=>{const item=ref.item;calls.push(['add',item.label,...args]);order.unshift({label:`added:${item.label}`,item});if(c.mutation&&item===incoming)ref.item=items.find(item=>item.label===c.mutation);return c.addResult??1;},warning:text=>calls.push(['warning',text]),
  });
  assert.deepEqual({result,calls,ref:ref.item.label,order:order.map(node=>node.item?.label??null)},{result:expected.result,calls:expected.calls,ref:expected.ref,order:expected.order},JSON.stringify(c));
 }
});
