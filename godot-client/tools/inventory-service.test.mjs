import test from 'node:test';import assert from 'node:assert/strict';
import {InventoryService} from './inventory-service.mjs';
import {SpellbookService} from './spellbook-service.mjs';
import {parse2da} from '../../src/area.js';
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return{promise,resolve};};
const turn=()=>new Promise(r=>setImmediate(r));
function fixture(){
 const actor={id:1,objectType:5,areaId:7,replicated:{name:{text:'Authored actor'}},appearance:{gender:0},playerState:{combat:{armorClass:12,field898:20,field978:35},abilities:{current:[10]}}},item={id:2,objectType:6,item:{baseItem:0,name:{text:'Authored sword'},parts:[1],colors:[],properties:[],stackSize:3},inventoryLocation:{ownerId:1,channel:'R',x:0,y:0}},world={areaId:7,localObjectId:1,registry:new Map([[1,actor],[2,item]]),inventories:new Map([['R',{entries:[{id:2,x:0,y:0}]}],['I',{entries:[]}]]),containers:new Map()},calls=[],sent=[];
 const baseitems={columns:['InvSlotWidth','InvSlotHeight','EquipableSlots','Container'],rows:new Map([[0,{InvSlotWidth:'1',InvSlotHeight:'3',EquipableSlots:'16',Container:'0'}]])},encumbrance={rows:new Map([[10,{Normal:'100'}]])},session={world,areaGeneration:3,closed:false};
 for(const name of ['inventoryWindow','inventoryPanel','itemAction','containerInput','examine','interact'])session[name]=async request=>{calls.push({name,request});return{sent:true};};
 const actions={session,capture:()=>({actor,actorId:1,areaId:7,areaGeneration:session.areaGeneration,connection:1}),owned:scope=>!session.closed&&scope.actor===session.world.registry.get(1)&&scope.areaId===session.world.areaId&&scope.areaGeneration===session.areaGeneration,emit:row=>sent.push(row),tables:async()=>{},rules:{baseitems},text:{resolve:async value=>value?.text??'',rules:async()=>encumbrance},icon:async()=>null,targeter:{active:false},diagnose:()=>{}};
 const service=new InventoryService({actions});return{service,actions,actor,item,world,session,calls,sent};
}
async function shortcutFixture(){
 const f=fixture();Object.assign(f.item.item,{identified:1,canUse:1});
 f.actions.rules.baseitems=parse2da('2DA V2.0\n\nInvSlotWidth InvSlotHeight EquipableSlots Container Stacking QBBehaviour WeaponType WeaponSize WeaponWield\n0 1 3 16 0 99 0 0 1 0\n');
 f.world.quickbar=Array.from({length:36},()=>({type:0}));f.icons=[];f.actions.icon=async descriptor=>{f.icons.push(descriptor);return null;};
 f.session.assignQuickbar=async request=>{f.calls.push({name:'assignQuickbar',request});f.world.quickbar[request.index]=structuredClone(request.button);return{sent:true};};
 f.session.activateQuickbar=async request=>{f.calls.push({name:'activateQuickbar',request});return{sent:true};};
 f.book=new SpellbookService({actions:f.actions});await f.service.open();await f.book.refresh(true);
 f.shortcut=()=>({quickbarId:f.book.quick.id,viewId:f.service.view.id,entryId:0,index:35});return f;
}
test('inventory shortcut uses original item configuration, complete icon metadata and the existing assignment/activation session owners',async()=>{
 const f=await shortcutFixture(),before=structuredClone(f.item.inventoryLocation);await f.book.assignInventory(f.shortcut(),f.service);
 const b=f.world.quickbar[35];assert.equal(b.type,1);assert.equal(b.itemId,2);assert.equal(b.intParam&65535,255);assert.deepEqual(f.item.inventoryLocation,before);
 assert.equal(f.calls.filter(c=>c.name==='assignQuickbar').length,1);assert.ok(f.icons.some(d=>d.kind==='item'&&d.appearance.baseItem===0&&d.appearance.parts[0]===1));
 await f.book.quickActivate({quickbarId:f.book.quick.id,index:35});assert.equal(f.calls.at(-1).name,'activateQuickbar');assert.equal(f.calls.at(-1).request.index,35);
});
test('inventory shortcut rejects stale views, foreign rows, pending transfers, missing usability and invalid destinations before assignment',async()=>{
 for(const change of [f=>f.item.item.identified=0,f=>f.item.item.canUse=0,f=>f.service.pending.set(2,{}),f=>f.service.view.rows.get(0).channel='C',f=>f.world.registry.set(2,{...f.item}),f=>f.session.areaGeneration++,f=>f.world.quickbar[0]={type:3,intParam:7},f=>f.service.reset()]){
  const f=await shortcutFixture(),request=f.shortcut();change(f);await assert.rejects(f.book.assignInventory(request,f.service));assert.equal(f.calls.filter(c=>c.name==='assignQuickbar').length,0);
 }
 const f=await shortcutFixture();for(const index of [-1,36,0.5])await assert.rejects(f.book.assignInventory({...f.shortcut(),index},f.service));
});
test('inventory shortcut revalidates both owners after pending rule preparation',async()=>{
 const f=await shortcutFixture(),gate=deferred();f.actions.tables=()=>gate.promise;const request=f.shortcut(),work=f.book.assignInventory(request,f.service);f.service.reset();gate.resolve();await assert.rejects(work,/stale/);assert.equal(f.calls.filter(c=>c.name==='assignQuickbar').length,0);
});
test('inventory opens via actual session requests and projects canonical locations, layout, stack and statistics',async()=>{const f=fixture();await f.service.open();assert.deepEqual(f.calls.map(c=>c.name),['inventoryWindow','inventoryPanel']);const v=f.sent.find(c=>c.kind==='inventory-view');assert.equal(v.items[0].height,3);assert.equal(v.items[0].stack,3);assert.equal(v.layout.length,18);assert.equal(v.summary.weight,4);assert.equal(v.armorClass,12);assert.equal(f.item.inventoryLocation.channel,'R');});
test('item actions never predict a transfer and stay pending until matching authoritative acknowledgement',async()=>{const f=fixture();await f.service.open();await f.service.action({viewId:f.service.view.id,entryId:0,operation:'equip',slot:16});assert.equal(f.item.inventoryLocation.channel,'R');assert.equal(f.calls.at(-1).request.slot,16);await assert.rejects(f.service.action({viewId:f.service.view.id,entryId:0,operation:'drop'}),/waiting/);f.service.receive({kind:'inventory-result',itemId:2,operation:'equip',success:true,alternate:true});assert.equal(f.service.pending.size,1);f.service.receive({kind:'inventory-result',itemId:2,operation:'equip',success:true});assert.equal(f.service.pending.size,0);assert.equal(f.item.inventoryLocation.channel,'R');});
test('invalid equip masks, repository bounds and closed-container destinations never reach protocol sender',async()=>{const f=fixture();await f.service.open();for(const fields of [{operation:'equip',slot:2},{operation:'move',x:10,y:0},{operation:'move',x:0,y:36},{operation:'move',destination:'container'}])await assert.rejects(f.service.action({viewId:f.service.view.id,entryId:0,...fields}));assert.equal(f.calls.filter(c=>c.name==='itemAction').length,0);});
test('old page/view and replaced canonical item or actor cannot authorize actions',async()=>{for(const replace of [f=>f.item.item.stackSize++,f=>f.world.registry.set(2,{...f.item}),f=>f.world.registry.set(1,{...f.actor}),f=>f.session.areaGeneration++,f=>f.session.world={...f.world}]){const f=fixture();await f.service.open();replace(f);await assert.rejects(f.service.action({viewId:f.service.view.id,entryId:0,operation:'drop'}));assert.equal(f.calls.filter(c=>c.name==='itemAction').length,0);}});
test('late icon completion cannot populate a closed or replacement world window',async()=>{for(const retire of [f=>f.service.close(),f=>{f.session.world={...f.world};return Promise.resolve();}]){const f=fixture(),gate=deferred();f.actions.icon=()=>gate.promise;await f.service.open();await retire(f);gate.resolve('data:image/png;base64,authored');await turn();assert.equal(f.sent.filter(c=>c.kind==='inventory-icon').length,0);}});
test('page changes request native panel selection and reject commands from the previous view',async()=>{const f=fixture();await f.service.open();const id=f.service.view.id;await f.service.choose({viewId:id,page:5});assert.equal(f.calls.at(-1).request.panel,5);assert.equal(f.service.page,5);await assert.rejects(f.service.action({viewId:id,entryId:0,operation:'drop'}),/stale/);});
test('real container status auto-opens, primary/alternate ownership stays separate and same-ID reopen retires old selections',async()=>{
 const f=fixture();f.world.containers.set('C',100);f.world.inventories.set('C',{entries:[],pageCount:2});f.service.receive({kind:'container-status',targetId:100,primary:0});assert.equal(f.service.opened,false);
 f.service.receive({kind:'container-status',targetId:100,primary:1});await turn();await turn();assert.equal(f.service.opened,true);const id=f.service.view.id;assert.equal(f.sent.findLast(r=>r.kind==='inventory-view').container.ownerId,100);
 f.service.receive({kind:'container-status',targetId:100,primary:1});assert.throws(()=>f.service.current(id),/stale/);
});
test('container paging wraps by original low-byte policy and cannot complete into a replacement container context',async()=>{
 const f=fixture();f.world.containers.set('C',100);f.world.inventories.set('C',{entries:[],pageCount:2});await f.service.open();await f.service.container({viewId:f.service.view.id,operation:'previous'});assert.equal(f.service.containerPage,1);assert.equal(f.calls.at(-1).request.targetId,100);
 const gate=deferred();f.session.containerInput=()=>gate.promise;const work=f.service.container({viewId:f.service.view.id,operation:'next'});f.service.receive({kind:'container-status',targetId:100,primary:1});gate.resolve();await work;assert.equal(f.service.containerPage,0);
});
test('container transfer carries server owner IDs and keeps ownership unchanged before actual world updates',async()=>{
 const f=fixture();f.world.containers.set('C',100);f.world.inventories.set('C',{entries:[],pageCount:2});await f.service.open();await f.service.action({viewId:f.service.view.id,entryId:0,operation:'move',destination:'container',x:2,y:7});assert.equal(f.calls.at(-1).request.destinationId,100);assert.deepEqual(f.item.inventoryLocation,{ownerId:1,channel:'R',x:0,y:0});
});
test('authoritative container page-count shrink clamps the local visible page without inventing item changes',async()=>{
 const f=fixture();f.world.containers.set('C',100);f.world.inventories.set('C',{entries:[],pageCount:3});await f.service.open();await f.service.container({viewId:f.service.view.id,operation:'previous'});assert.equal(f.service.containerPage,2);f.world.inventories.get('C').pageCount=1;await f.service.refresh();assert.equal(f.service.containerPage,0);assert.equal(f.calls.filter(row=>row.name==='itemAction').length,0);
});

test('unrelated replication does not invalidate a visible item, but changed target membership, location or metadata still does',async()=>{
 const f=fixture();await f.service.open();const id=f.service.view.id;
 f.actor.inventoryStats={gold:123};f.world.inventories.get('R').entries.push({id:99,x:4,y:0});
 assert.equal(f.service.selected(id,0).row.object,f.item);
 f.world.inventories.get('R').entries[0].x=1;assert.throws(()=>f.service.selected(id,0),/stale/);
 f.world.inventories.get('R').entries[0].x=0;f.item.item.stackSize++;assert.throws(()=>f.service.selected(id,0),/stale/);
});

test('uncommitted asynchronous presentation metadata cannot retire the currently visible view',async()=>{const f=fixture();await f.service.open();const id=f.service.view.id,gate=deferred();f.actions.text.resolve=()=>gate.promise;const work=f.service.refresh(true);await turn();assert.equal(f.service.current(id).id,id);gate.resolve('Authored delayed label');await work;assert.notEqual(f.service.view.id,id);assert.throws(()=>f.service.current(id),/stale/);});

test('a committed harmless refresh can overtake an in-flight item click without losing its canonical selection',async()=>{
 const f=fixture();await f.service.open();const id=f.service.view.id;f.actor.inventoryStats={gold:123};await f.service.refresh();
 assert.notEqual(f.service.view.id,id);assert.equal(f.service.selected(id,0).row.object,f.item);assert.throws(()=>f.service.current(id),/stale/);
 await f.service.action({viewId:id,entryId:0,operation:'examine'});assert.equal(f.calls.at(-1).request.targetId,2);
 f.item.item.stackSize++;assert.throws(()=>f.service.selected(id,0),/stale/);
});
test('retained in-flight item owners stay bounded and cannot survive page, actor, item or connection retirement',async()=>{
 for(const change of [f=>f.service.reset(),f=>f.session.areaGeneration++,f=>f.world.registry.set(1,{...f.actor}),f=>f.world.registry.set(2,{...f.item}),f=>f.world.inventories.get('R').entries[0].x++,f=>f.service.page=1]){
  const f=fixture();await f.service.open();const id=f.service.view.id;await f.service.refresh(true);change(f);assert.throws(()=>f.service.selected(id,0),/stale/);
 }
 const f=fixture();await f.service.open();const id=f.service.view.id;for(let i=0;i<10;i++)await f.service.refresh(true);assert.equal(f.service.recentViews.size,8);assert.throws(()=>f.service.selected(id,0),/stale/);f.service.reset();assert.equal(f.service.recentViews.size,0);
});
