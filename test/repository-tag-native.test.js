import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {repositoryFindTag} from '../src/item_repository.js';
import {nativeItemTag} from '../src/item_stack_compare.js';
import {appropriateStorePanel} from '../src/store_item_acquisition.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-repository-tag-observations.json',import.meta.url)));
test('recursive repository tag search matches original physical order, normalization, stale/status gates and string comparisons',()=>{
 for(const row of data.rows.filter(r=>r.case.mode!=='panel')){
  const c=row.case,trace=[],repo={*ids(){if(!c.empty)yield* [1,3];}},child={*ids(){yield 2;}},items={1:{id:1,tag:c.first??'Bag',repo:c.nested===false?null:child},2:{id:2,tag:c.child??'Target'},3:{id:3,tag:c.last??'Target'}};
  const result=repositoryFindTag(repo,c.query??'Target',{lookup:id=>{trace.push(id);return{status:id===c.badStatus?1:0,object:id===c.missing?null:items[id]};},asItem:o=>o,tag:o=>nativeItemTag(o.tag),repository:o=>o.repo});
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
test('store panel uses active base-row BYTE and original unknown-panel warning/default4',async()=>{
 for(const row of data.rows.filter(r=>r.case.mode==='panel')){const trace=[];assert.equal(await appropriateStorePanel({},49,{baseInfo:()=>({storePanel:row.case.panel}),warning:()=>trace.push('warning')}),row.result);assert.deepEqual(trace,row.trace);}
});
