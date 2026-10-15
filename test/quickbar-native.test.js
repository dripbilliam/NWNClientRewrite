import test from 'node:test';
import assert from 'node:assert/strict';
import {initializeQuickbar,setQuickbarButton,getQuickbarButton,loadQuickbar,saveQuickbar,removeQuickbarItem,quickbarRequest} from '../src/quickbar.js';
import {quickbarAssignmentMenu} from '../src/quickbar_menu.js';
import {GameObjectArray,OBJECT_INVALID} from '../src/game_object_array.js';
import {ModuleSession} from '../src/module_session.js';
const p=(items)=>({object:id=>items.find(i=>i.id===id),at:(repo,x,y)=>repo?.find(i=>i.repositoryX===x&&i.repositoryY===y),equipped:(o,s)=>o.equipped?.get(s),slot:(o,i)=>[...o.equipped??[]].find(([_s,v])=>v===i)?.[0]});
test('native quickbar owns36 independent records; setters preserve unrelated fields and clear only type/int',()=>{
  const a={};initializeQuickbar(a);assert.equal(a.nativeQuickbar4e0.length,36);assert.notEqual(a.nativeQuickbar4e0[0],a.nativeQuickbar4e0[1]);
  setQuickbarButton(a,35,{type:1,itemId:0xf1234567,secondaryItemId:0xffffffff,intParam:0x20001});
  setQuickbarButton(a,35,{type:2,classIndex:2,intParam:123,metamagic:16,domainLevel:7});
  assert.equal(getQuickbarButton(a,35).itemId,0xf1234567);assert.equal(getQuickbarButton(a,35).classIndex,2);
  setQuickbarButton(a,35,null);assert.equal(getQuickbarButton(a,35).intParam,0);assert.equal(getQuickbarButton(a,35).itemId,0xf1234567);
  assert.equal(setQuickbarButton(a,36,{type:4,intParam:1}),false);
});
test('QBList item restore uses equipped, repository and container coordinates with new canonical IDs',()=>{
  const equipped={id:101,repositoryX:0,repositoryY:0},inside={id:303,repositoryX:1,repositoryY:2},bag={id:202,repositoryX:4,repositoryY:5,nativeRepository:[inside]},actor={equipped:new Map([[16,equipped]]),nativeRepository:[bag]};
  loadQuickbar(actor,[{QBObjectType:1,QBItemInvSlot:16},{QBObjectType:1,QBItemReposX:1,QBItemReposY:2,QBContReposX:4,QBContReposY:5}],p([equipped,inside,bag]));
  assert.equal(getQuickbarButton(actor,0).itemId,101);assert.equal(getQuickbarButton(actor,1).itemId,303);assert.equal(getQuickbarButton(actor,1).intParam,0xff00ff);
});
test('QBList roundtrip preserves spell class index/metamagic/domain, special records and item locations',()=>{
  const item={id:0xe0000001,repositoryX:3,repositoryY:7,ownerId:99,activeProperties:[{}]},actor={id:99,nativeRepository:[item],equipped:new Map()},providers=p([item,actor]);initializeQuickbar(actor);
  setQuickbarButton(actor,0,{type:1,itemId:item.id,intParam:0x40003});setQuickbarButton(actor,12,{type:2,classIndex:1,intParam:52,metamagic:8,domainLevel:3});setQuickbarButton(actor,24,{type:18,commandLabel:'Label',commandLine:'Command'});
  const saved=saveQuickbar(actor,providers);assert.equal(saved[0].QBItemInvSlot,0xffffffff);assert.equal(saved[0].QBItemReposY,7);assert.equal(saved[0].QBCastPropIndex,3);
  item.id=55;const restored={id:99,nativeRepository:[item],equipped:new Map()};loadQuickbar(restored,saved,p([item,restored]));
  assert.equal(getQuickbarButton(restored,0).itemId,55);assert.equal(getQuickbarButton(restored,0).intParam,0x40003);assert.deepEqual(saveQuickbar(restored,p([item,restored])),saved);
});
test('legacy feat and quickbar conversions match the native import switch',()=>{
  const a={};loadQuickbar(a,[{QBObjectType:4,QBINTParam1:1002},...[2,3,4,6,7,8,9,11,12].map(n=>({QBObjectType:10,QBINTParam1:n}))],p([]));
  assert.equal(getQuickbarButton(a,0).intParam,65002);assert.deepEqual(a.nativeQuickbar4e0.slice(1,10).map(b=>[b.type,b.intParam]),[[3,10],[4,28],[4,19],[4,204],[4,30],[4,389],[4,390],[4,425],[4,947]]);
});
test('item removal clears both weapon-set references and activation uses live actor/target IDs',()=>{
  const registry=new GameObjectArray(),a={areaId:10},item={objectType:6};registry.addInternalObject(a);registry.addInternalObject(item);initializeQuickbar(a);
  setQuickbarButton(a,0,{type:1,itemId:item.id});setQuickbarButton(a,4,{type:1,itemId:999,secondaryItemId:item.id});
  assert.equal(quickbarRequest(a,getQuickbarButton(a,0),registry).itemId,item.id);assert.deepEqual(removeQuickbarItem(a,item.id),[0,4]);
  setQuickbarButton(a,12,{type:2,intParam:123,classIndex:2,metamagic:8});assert.deepEqual(quickbarRequest(a,getQuickbarButton(a,12),registry,0xf1234567),{action:'spell.cast',actorId:a.id,areaId:10,targetId:0xf1234567,spellId:123,classIndex:2,metamagic:8,domainLevel:0});
});
test('assignment radial paginates active entries without truncation and exposes clear',()=>{
  const entries=Array.from({length:19},(_,id)=>({label:`Feat${id}`,binding:{type:4,intParam:id}}));
  const root=quickbarAssignmentMenu('F1',[{slot:3,label:'Feats',icon:'IR_XABILITY',entries}]);assert.equal(root.entries.at(-1).binding,null);
  let menu=root.entries[0].children(),seen=[];while(menu){seen.push(...menu.entries.filter(e=>e.binding).map(e=>e.binding.intParam));menu=menu.entries.find(e=>e.children)?.children();}assert.deepEqual(seen,entries.map(e=>e.binding.intParam));
});
test('SetLocked stores raw INT and defers every lock/unlock callback with canonical caller ID',async()=>{
  const calls=[],s=new ModuleSession({}, {runNativeAI:false}),caller=s.register('creature','caller',{}),door=s.register('door','door',{locked:0,scripts:{lock:'lock',unlock:'unlock'}}),placeable=s.register('placeable','placeable',{locked:0,scripts:{lock:'lock',unlock:'unlock'}});
  s.vm={run:async(name,self,options)=>calls.push({name,self,options,locked:s.commands.GetLastLocked([],{self}),unlocked:s.commands.GetLastUnlocked([],{self})})};s.program=async n=>n;
  for(const o of [door,placeable]){s.commands.SetLocked([o.id,-2],{self:caller.id});s.commands.SetLocked([o.id,0],{self:caller.id});assert.equal(o.locked,0);}
  assert.equal(calls.length,0);assert.equal(s.scheduler.events.length,4);
  while(s.scheduler.events.length)await s.dispatch(s.scheduler.events.shift());
  assert.deepEqual(calls.map(c=>[c.name,c.self,c.options.scriptEventContext]),[['lock',door.id,10006],['unlock',door.id,10010],['lock',placeable.id,9006],['unlock',placeable.id,9011]]);assert.ok(calls.every(c=>(c.name==='lock'?c.locked:c.unlocked)===caller.id));
  s.commands.SetLocked([door.id,0],{self:caller.id});assert.equal(s.scheduler.events.length,1,'No change still emits an event');s.commands.SetLocked([OBJECT_INVALID,1],{self:caller.id});assert.equal(s.scheduler.events.length,1);
});
