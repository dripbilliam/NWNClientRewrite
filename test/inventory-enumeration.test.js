import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {ItemRepository} from '../src/item_repository.js';
import {inventoryItem} from '../src/inventory_enumeration.js';
const invalid=0x7f000000;
test('inventory enumeration matches864 original seven-call sequences over carried items, bags, stores and stale IDs',()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-inventory-enumeration-observations.json',import.meta.url)));assert.equal(oracle.observations.length,864);
  const repo=ids=>{const r=new ItemRepository(77,10,36,60,0);for(const id of ids.slice().reverse())r.insertHead(id);return r;};
  for(const row of oracle.observations){const c=row.case,o={id:77,objectType:c.kind,nativeRepository:repo(c.root),nativeInventoryEnumeration:{outer:0,inner:0,bagId:invalid},nativeItemEnumeration460:0,nativeStoreEnumeration388:0,nativeStoreEnumeration38a:0,
    nativeStoreRepositories:[[],[101],[],[100,102],[]].map(repo)},items=new Map(Array.from({length:5},(_,n)=>{const id=n+100;return[id,{id,objectType:6,container:id<=101?c.container:0,possessorId:id===100?c.bagOwner:id===101?100:77,nativeRepository:repo(id===100?c.children:id===101?[104]:[])}];}));
    const p={repository:o=>o.nativeRepository,item:id=>items.get(id),baseInfo:o=>({container:o.container}),storeRepositories:o=>o.nativeStoreRepositories};
    for(let n=0;n<7;n++){
      const id=inventoryItem(c.first&&n===0,c.kind?o:null,p),state=o.nativeInventoryEnumeration;
      assert.deepEqual({id,outer:state.outer,inner:state.inner,bag:state.bagId,item:o.nativeItemEnumeration460,store:o.nativeStoreEnumeration388,category:o.nativeStoreEnumeration38a},row.outputs[n],JSON.stringify({case:c,step:n}));
    }
  }
});
