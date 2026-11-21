import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {setItemPossessor} from '../src/item_possession.js';
import {ItemRepository} from '../src/item_repository.js';

test('possession, event/feedback order and quickbar selection match1024 complete native executions',async()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-item-possession-observations.json',import.meta.url)));
  assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.observations.length,1024);
  for(const {case:c,result:expected} of oracle.observations){
    const objects=new Map(Object.entries(oracle.definitions).map(([id,d])=>[Number(id),{id:Number(id),objectType:d.type,possessorId:d.owner??0x7f000000,nativeField504:d.veto??0,pc:d.pc??0}]));
    const item={id:100,possessorId:c.old,droppable:0,pickpocketable:0,identified:7},events=[],feedback=[],quickbar=[];
    const repository=c.contents?new ItemRepository(100,7,5,35,0):null;if(repository){repository.insertHead(112);repository.insertHead(111);}
    const p={module:()=>({id:0}),objectById:id=>objects.get(id),repository:()=>repository,statsPC:o=>o.pc,quickbar:()=>c.quickbar?{}:null,
      event:(source,target,type,objects,integers)=>events.push({source,target,type,objects,integers}),
      feedback:(o,code,data)=>feedback.push({owner:o.id,code,...data}),removeQuickbarItem:(o,id)=>quickbar.push([o.id,id])};
    await setItemPossessor(item,c.new,c.scripts,c.messages,c.quantity,p);
    assert.deepEqual({possessorId:item.possessorId,droppable:item.droppable,pickpocketable:item.pickpocketable,events,feedback,quickbar},expected,JSON.stringify(c));
  }
});

test('same possessor returns before reading configuration, module, flags or dispatching effects',async()=>{
  const item={possessorId:0x80000001};await setItemPossessor(item,-2147483647,undefined,undefined,undefined,{});
  assert.equal(item.possessorId,0x80000001);
});
