import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {ItemRepository,repositoryFit,repositoryScan,repositoryAdd,repositoryAddPanel} from '../src/item_repository.js';

test('no-merge insertion matches384 full native AddItem/CheckFit/FindPosition/AddPanel executions',async()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-repository-add-observations.json',import.meta.url)));
  assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.observations.length,384);
  for(const {case:c,result:expected} of oracle.observations){
    let warnings=0;const repo=new ItemRepository(0x7f000000,10,36,60,c.expand),item={id:1,objectType:6,base:1,width:c.width,height:c.height,stackSize:1,possessorId:0x7f000000,repositoryX:255,repositoryY:255};
    const other={id:c.pool===2?1:2,objectType:6,width:10,height:36,repositoryX:0,repositoryY:0};if(c.pool)repo.insertHead(other.id);
    const p={module:()=>({id:0}),objectById:()=>null,itemById:id=>id===other.id?other:null,baseInfo:i=>({width:i.width,height:i.height}),warning:()=>warnings++};
    const value=await repositoryAdd(repo,{item},c.x,c.y,123,0,p);
    assert.deepEqual({value,x:item.repositoryX,y:item.repositoryY,height:repo.height,ids:[...repo.ids()],warnings},expected,JSON.stringify(c));
  }
});

test('gold and complete merge change the item reference before native transfer events',async()=>{
  const events=[],destroyed=[],owner={id:2,objectType:5},module={id:0},repo=new ItemRepository(2,10,36,60,0),objects=new Map([[2,owner]]);
  const item={id:3,base:76,objectType:6,possessorId:0x7f000000,stackSize:50},ref={item},gold=[];
  const p={module:()=>module,objectById:id=>objects.get(id),baseItem:i=>i.base,addGold:(...args)=>gold.push(args),destroyItem:i=>destroyed.push(i.id),event:(...args)=>events.push(args)};
  assert.equal(await repositoryAdd(repo,ref,255,255,0,0,p),1);assert.equal(ref.item,null);assert.equal(repo.length,0);
  assert.deepEqual(gold,[[owner,50,1]]);assert.deepEqual(events,[[0x7f000000,0,19,[0x7f000000,0x7f000000,2],[50]]]);
  const existing={id:4,base:49,stackSize:5},added={id:5,base:49,possessorId:0x7f000000,stackSize:3};repo.insertHead(4);events.length=0;
  const merged={item:added},feedback=[];
  assert.equal(await repositoryAdd(repo,merged,1,2,0,1,{...p,itemById:()=>existing,compareItems:()=>1,baseInfo:()=>({stacking:10}),mergeFeedback:(...args)=>feedback.push(args)}),1);
  assert.equal(merged.item,existing);assert.equal(existing.stackSize,8);assert.deepEqual(destroyed,[3,5]);assert.equal(feedback.length,1);
  assert.deepEqual(events,[[4,0,19,[4,0x7f000000,2],[3]]]);
});

test('partial merge remains applied when placement fails and only merge==1 scans stacks',async()=>{
  const repo=new ItemRepository(0x7f000000,10,36,60,0),existing={id:2,base:49,objectType:6,stackSize:9,width:10,height:36,repositoryX:0,repositoryY:0};repo.insertHead(2);
  const added={id:3,base:49,objectType:6,stackSize:4,possessorId:0x7f000000,width:1,height:1,repositoryX:255,repositoryY:255},ref={item:added};
  let compares=0;const p={module:()=>({id:0}),objectById:()=>null,itemById:()=>existing,baseItem:i=>i.base,
    baseInfo:i=>({stacking:10,width:i.width,height:i.height}),compareItems:()=>{compares++;return 1;}};
  assert.equal(await repositoryAdd(repo,ref,255,255,0,2,p),0);assert.equal(compares,0);assert.equal(existing.stackSize,9);
  assert.equal(await repositoryAdd(repo,ref,255,255,0,1,p),0);assert.equal(existing.stackSize,10);assert.equal(added.stackSize,3);assert.equal(ref.item,added);
});

test('panel limit uses a BYTE quotient and preserves native zero-divisor failure',()=>{
  const repo=new ItemRepository(1,10,144,60,1);assert.equal(repositoryAddPanel(repo),1);assert.equal(repo.height,150);assert.equal(repositoryAddPanel(repo),0);
  repo.height=0;assert.throws(()=>repositoryAddPanel(repo),/divide by zero/);
});

test('repository fit matches1050 executions of the original body, including wrapped rectangles and canonical lookup order',()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-repository-fit-observations.json',import.meta.url)));
  assert.equal(oracle.observations.length,1050);
  for(const c of oracle.observations){
    const repo=new ItemRepository(0x80000001,10,36,60,0),lookups=[];
    for(const entry of [...c.items].reverse())repo.insertHead(entry.id);
    const p={baseInfo:i=>i.base===1?{width:c.width,height:c.height}:c.items.find(r=>r.id===i.id),itemById:id=>{
      lookups.push(id);const r=c.items.find(r=>r.id===id);
      return !r||r.stale?null:{id:r.id,base:2,objectType:r.type,repositoryX:r.x??0,repositoryY:r.y??0};}};
    assert.equal(repositoryFit(repo,{id:1,base:1},c.x,c.y,p),c.result,JSON.stringify(c));
    assert.deepEqual(lookups,c.lookups,JSON.stringify(c));
  }
});

test('repository constructor narrows cells, preserves canonical IDs and enforces native boundary fallback',()=>{
  const warnings=[],repo=new ItemRepository(-2147483647,266,292,61,2,m=>warnings.push(m));
  assert.equal(repo.ownerId,0x80000001);assert.equal(repo.width,10);assert.equal(repo.height,36);assert.equal(repo.boundary,360);
  assert.equal(repo.expand,2);assert.equal(warnings.length,1);
  assert.equal(new ItemRepository(1,10,36,1,0,()=>{}).boundary,360);
  const a=repo.insertHead(0x80000002),b=repo.insertHead(0x80000003);
  assert.deepEqual([...repo.ids()],[0x80000003,0x80000002]);assert.equal(repo.head,b);assert.equal(repo.tail,a);
  assert.equal(b.next,a);assert.equal(a.previous,b);assert.equal(repo.length,2);
  assert.throws(()=>new ItemRepository(1,0,36,60,0),/divide by zero/);
  assert.throws(()=>new ItemRepository(1,10,36,0,0),/divide by zero/);
});

test('repository scans rows first, prevents page crossing and retains the current item during fit queries',()=>{
  const repo=new ItemRepository(1,10,36,60,0),objects=new Map(),p={baseInfo:i=>({width:i.width,height:i.height}),itemById:id=>objects.get(id)};
  const block={id:2,objectType:6,width:10,height:5,repositoryX:0,repositoryY:0};objects.set(2,block);repo.insertHead(2);
  const item={id:3,objectType:6,width:2,height:2};
  assert.deepEqual(repositoryScan(repo,item,p),{x:0,y:6});
  assert.equal(repositoryFit(repo,item,0,5,p),0);
  objects.set(3,{...item,repositoryX:0,repositoryY:6});repo.insertHead(3);
  assert.deepEqual(repositoryScan(repo,item,p),{x:0,y:6});
  assert.equal(repositoryScan(repo,{...item,width:11},p),null);
});
