import test from 'node:test';import assert from 'node:assert/strict';
import {ShortcutChoiceService} from './shortcut-choice-service.mjs';
import {skillUseRequest} from './skill-input.mjs';
import {SpellbookService} from './spellbook-service.mjs';import {parse2da} from '../../src/area.js';import {ActionService} from './action-service.mjs';
import {familyTestCharacter} from './spellbook-fixture.mjs';import {parseGff} from '../../src/gff.js';import {writeGff,gffField as field,gffRecord as record} from '../../src/gff_writer.js';
const defer=()=>{let resolve;const promise=new Promise(r=>resolve=r);return{promise,resolve};};
const flush=()=>new Promise(r=>setImmediate(r));
function fixture(){
 const raw={classes:'Name SpellCaster MemorizesSpells SpellbookRestricted PlayerClass SpellTableColumn MinCastingLevel PickDomains\n0 10 1 1 1 1 Caster 1 0\n1 11 1 0 1 1 Caster 1 0',spells:'Name IconResRef SpellDesc TargetType MetaMagic Master Innate Caster SubRadSpell1 SubRadSpell2 SubRadSpell3 SubRadSpell4 Range\n0 20 parent 100 3 63 0 1 1 1 2 3 4 S\n1 21 good 101 3 63 0 1 1 **** **** **** **** S\n2 22 evil 102 3 63 0 1 1 **** **** **** **** S\n3 23 law 103 3 63 0 1 1 **** **** **** **** S\n4 24 chaos 104 4 63 0 1 1 **** **** **** **** S\n5 25 simple 105 1 63 5 1 1 **** **** **** **** S',feat:'FEAT UsesPerDay SpellId\n0 30 1 5',domains:'Name\n',ranges:'PrimaryRange\n0 0\n1 2',baseitems:'Name\n',iprp_spells:'Name\n',appearance:'Name\n',skills:'Name\n',ruleset:'Label Value\n',racialtypes:'Name\n'};
 const rules=Object.fromEntries(Object.entries(raw).map(([key,value])=>[key,parse2da('2DA V2.0\n\n'+value)]));
 const actor={id:0xffffffff,objectType:5,areaId:9,replicated:{position:[1,2,0],stats:{classes:[{id:0,level:2},{id:1,level:2}]}},playerState:{feats:[0],bonusFeats:[],featUses:{0:1},spellbooks:{0:{known:[0,5],memorized:{1:[{spell:0,ready:1,domain:0,metamagic:0},null,{spell:5,ready:1,domain:0,metamagic:0}]}},1:{known:[5],memorized:{},usesLeft:{1:3}}},specialAbilities:[]}};
 const world={localObjectId:actor.id,areaId:9,registry:new Map([[actor.id,actor]]),quickbar:Array.from({length:36},()=>({type:0})),spellTargetingOverrides:new Map()},sent=[],calls=[];
 const session={world,closed:false,areaGeneration:2,assignQuickbar:async request=>{calls.push({method:'assignQuickbar',request});world.quickbar[request.index]=structuredClone(request.button);return{sent:true};},prepareSpell:async request=>{calls.push({method:'prepareSpell',request});return{sent:true};},castSpell:async request=>{calls.push({method:'castSpell',request});return{sent:true};},activateQuickbar:async request=>calls.push({method:'activateQuickbar',request})};
 const text={rules:async key=>rules[key],resolve:async value=>({10:'Wizard',11:'Sorcerer',20:'Protection',21:'Good',22:'Evil',23:'Law',24:'Chaos',25:'Simple'})[value.strRef]??'Description '+value.strRef};
 const actions=new ActionService({session,connection:3,text,active:()=>true,send:row=>sent.push(row)});let now=0;
 const service=new SpellbookService({actions,now:()=>now});return{raw,rules,actor,world,sent,calls,session,actions,service,advance:()=>now+=6000};
}
const view=f=>f.sent.findLast(row=>row.kind==='spellbook-view');
async function opened(f){await f.service.open({level:1});return view(f);}

async function choiceFixture(){
 const f=fixture();f.world.registry.objects=f.world.registry;f.world.party=[];f.actor.inventoryStats={skills:[{index:0,value:4,flag:true}],feats:[]};f.actor.appearance={appearance:0,gender:0};
 f.rules.skills=parse2da('2DA V2.0\n\nName\n0 40\n');f.rules.baseitems=parse2da('2DA V2.0\n\nName Container EquipableSlots Stacking QBBehaviour WeaponType WeaponSize WeaponWield\n0 100 0 16 1 0 0 1 0\n');
 f.item={id:10,objectType:6,item:{baseItem:0,identified:1,canUse:1,properties:[],stackSize:1,name:{text:'Authored sword'}},inventoryLocation:{ownerId:f.actor.id,channel:'R',x:0,y:0}};f.world.registry.set(10,f.item);
 const resolve=f.actions.text.resolve;f.actions.text.resolve=value=>value?.text??resolve(value);
 f.assigned=[];f.choices=new ShortcutChoiceService({actions:f.actions,shortcuts:f.service,onAssign:row=>f.assigned.push(row)});await f.service.refresh(true);
 f.openChoices=()=>f.choices.open({requestId:50,quickbarId:f.service.quick.id,index:35});await f.openChoices();return f;
}
const chooseMenu=(f,slot)=>f.actions.select({menuId:f.actions.menu.id,slot});

test('shortcut assignment wheel reuses item/spell/feat/skill/command groups without constructing a DOM view',async()=>{
 const f=await choiceFixture();assert.equal(typeof globalThis.document,'undefined');
 assert.deepEqual(f.actions.menu.view.entries.map(e=>e.label),['Items','Spells','Feats','Skills','Commands','Clear slot']);
 await chooseMenu(f,1);const parent=f.actions.menu.view.entries.find(e=>e.label==='Protection');assert.ok(parent.children);assert.equal(parent.binding,undefined);
 await chooseMenu(f,parent.slot);assert.deepEqual(f.actions.menu.view.entries.map(e=>e.label),['Good','Evil','Law','Chaos']);
 await chooseMenu(f,1);assert.equal(f.world.quickbar[35].type,2);assert.equal(f.world.quickbar[35].intParam,2);assert.equal(f.actions.menu,null);assert.equal(f.assigned.length,1);
});
test('default item, skill, feat and original command choices use the canonical native assignment sender',async()=>{
 for(const [category,type,id]of [[2,1,10],[4,3,0],[3,4,0],[0,42,0]]){
  const f=await choiceFixture();await chooseMenu(f,category);await chooseMenu(f,0);const button=f.world.quickbar[35];assert.equal(button.type,type);assert.equal(type===1?button.itemId:button.intParam,id);assert.equal(f.calls.at(-1).method,'assignQuickbar');
 }
 const f=await choiceFixture();await chooseMenu(f,6);assert.equal(f.world.quickbar[35].type,0);assert.equal(f.actions.menu,null);
});
test('large shortcut categories keep More pages and exact physical entry identity',async()=>{
 const f=await choiceFixture();f.actor.playerState.feats=Array.from({length:12},(_,i)=>i);f.rules.feat=parse2da('2DA V2.0\n\nFEAT UsesPerDay SpellId\n'+f.actor.playerState.feats.map(i=>`${i} ${30+i} 1 5`).join('\n'));
 await f.openChoices();await chooseMenu(f,3);assert.equal(f.actions.menu.view.entries.length,8);await chooseMenu(f,7);assert.equal(f.actions.menu.view.entries.length,5);
 await chooseMenu(f,2);assert.equal(f.world.quickbar[35].intParam,9);
});

test('innate families and current familiar commands retain their original distinct shortcut kinds',async()=>{
 const innate=await choiceFixture();innate.actor.playerState.specialAbilities=[{spell:0,level:3}];await innate.openChoices();
 await chooseMenu(innate,5);await chooseMenu(innate,0);await chooseMenu(innate,1);assert.equal(innate.world.quickbar[35].type,44);assert.equal(innate.world.quickbar[35].intParam,2);assert.equal(innate.world.quickbar[35].domainLevel,3);
 for(const removed of [false,true]){
  const f=await choiceFixture(),familiar={id:22,objectType:5,replicated:{master:f.actor.id,field908:3,name:{text:'Familiar'}}};f.world.registry.set(22,familiar);f.actor.familiarId=22;
  await f.openChoices();await chooseMenu(f,0);const entry=f.actions.menu.view.entries.find(e=>e.label==='Possess Familiar');assert.ok(entry);
  if(removed){familiar.replicationRemoved=true;await assert.rejects(chooseMenu(f,entry.slot));assert.equal(f.assigned.length,0);}else{await chooseMenu(f,entry.slot);assert.equal(f.world.quickbar[35].type,38);}
 }
});

test('skill shortcut activation reaches the shared native target selector and validated network skill writer',async()=>{
 const f=fixture(),packets=[];f.world.quickbar[0]={type:3,intParam:4};
 f.session.controlledActor=()=>f.actor;f.session.validateCastTarget=(_area,actor,id)=>assert.equal(id,actor.id);f.session.peer={sendGameMessage:async bytes=>packets.push(bytes)};
 await f.service.refresh(true);await f.service.quickActivate({quickbarId:f.service.quick.id,index:0});assert.equal(f.actions.targeter.active,true);assert.equal(packets.length,0);
 await f.actions.selectTarget({token:f.actions.targetToken,targetId:f.actor.id,position:[2,3,-4]});assert.deepEqual(packets[0],skillUseRequest({packedSkill:4,targetId:f.actor.id}));assert.equal(f.actions.targeter.active,false);
});
test('revoked choices, changed shortcut contents and retired actor/menu owners cannot assign through an old wheel',async()=>{
 for(const change of [f=>f.actor.playerState.feats=[],f=>f.world.quickbar[0]={type:3,intParam:4},f=>f.session.areaGeneration++,f=>f.world.registry.set(f.actor.id,{...f.actor})]){
  const f=await choiceFixture();await chooseMenu(f,3);change(f);await assert.rejects(chooseMenu(f,0));assert.equal(f.assigned.length,0);
 }
 const f=await choiceFixture();const id=f.actions.menu.id;f.actions.cancel({requestId:50});await assert.rejects(f.actions.select({menuId:id,slot:6}),/no longer/);
});
test('cancelled asynchronous shortcut construction cannot replace a newer menu and a pending write cannot dispatch twice',async()=>{
 const f=await choiceFixture(),gate=defer();f.choices.choices=()=>gate.promise;const pending=f.openChoices();await flush();f.actions.cancel({requestId:50});gate.resolve([]);await pending;assert.equal(f.actions.menu,null);
 const current=await choiceFixture(),write=defer();await chooseMenu(current,0);const id=current.actions.menu.id;current.session.assignQuickbar=()=>write.promise;const first=chooseMenu(current,0);await flush();await assert.rejects(current.actions.select({menuId:id,slot:0}),/no longer/);write.resolve({sent:true});await first;assert.equal(current.assigned.length,1);
});

test('read-only spellbook enumerates prepared, known, empty and spontaneous pools and original family children',async()=>{
 const f=fixture(),before=structuredClone(f.actor),v=await opened(f);
 assert.equal(v.classes.length,2);assert.equal(v.known.length,2);assert.equal(v.memory.length,3);assert.equal(v.memory[1].spellId,-1);assert.equal(v.memory[0].uses,1);
 const parent=v.known.find(row=>row.spellId===0);await assert.rejects(()=>f.service.assign({viewId:v.viewId,entryId:parent.entryId,index:0}),/variant/);
 await f.service.familyChoice({viewId:v.viewId,entryId:parent.entryId});assert.deepEqual(view(f).family.map(row=>row.label),['Good','Evil','Law','Chaos']);assert.ok(view(f).family.every(row=>row.canDrag));assert.deepEqual(f.actor,before);
 await f.service.query({classIndex:1,level:1,metamagic:0});assert.equal(view(f).prepared,false);assert.equal(view(f).usesLeft,3);assert.equal(view(f).known[0].uses,3);
});
test('variant drag assigns its leaf, shortcut uses original typed targeter, old handles cannot assign',async()=>{
 const f=fixture(),v=await opened(f);await f.service.familyChoice({viewId:v.viewId,entryId:v.known[0].entryId});const family=view(f),evil=family.family.find(row=>row.spellId===2);
 await f.service.assign({viewId:family.viewId,entryId:evil.entryId,index:13});assert.equal(f.world.quickbar[13].intParam,2);assert.equal(f.calls.at(-1).request.button.type,2);
 await assert.rejects(()=>f.service.assign({viewId:family.viewId,entryId:evil.entryId,index:14}),/stale/);
 const q=f.service.quick.id;await f.service.quickActivate({quickbarId:q,index:13});assert.ok(f.actions.targeter.active);await f.actions.selectTarget({token:f.actions.targetToken,targetId:f.actor.id,position:[1,0,-2]});assert.equal(f.calls.at(-1).method,'castSpell');assert.equal(f.calls.at(-1).request.spellId,2);
});
test('preparation copies known parent and reserves until actual replication; timeout never fabricates ready slots',async()=>{
 const f=fixture(),v=await opened(f),before=structuredClone(f.actor.playerState.spellbooks);const parent=v.known.find(row=>row.spellId===0);
 await f.service.prepare({viewId:v.viewId,entryId:parent.entryId});const request=f.calls.at(-1).request;assert.equal(request.spellId,0);assert.equal(request.slot,1);assert.deepEqual(f.actor.playerState.spellbooks,before);assert.ok(view(f).memory[1].pending);
 const current=view(f);await assert.rejects(()=>f.service.prepare({viewId:current.viewId,entryId:current.known[0].entryId}),/empty/);
 f.advance();await f.service.refresh();assert.equal(view(f).memory[1].pending,false);assert.ok(f.sent.some(row=>row.kind==='book-notice'));assert.deepEqual(f.actor.playerState.spellbooks,before);
});
test('prepared-slot exchange preserves native write order and never mutates the replicated pool',async()=>{
 const f=fixture(),v=await opened(f),before=structuredClone(f.actor.playerState.spellbooks);await f.service.prepare({viewId:v.viewId,entryId:v.memory[0].entryId,destinationId:v.memory[2].entryId});
 assert.deepEqual(f.calls.filter(row=>row.method==='prepareSpell').map(row=>[row.request.slot,row.request.spellId]),[[0,5],[2,0]]);assert.deepEqual(f.actor.playerState.spellbooks,before);
});
test('clearing waits for server state, duplicate slot writes and failed sends are retryable',async()=>{
 const f=fixture(),v=await opened(f),gate=defer();f.session.prepareSpell=async()=>gate.promise;const work=f.service.prepare({viewId:v.viewId,entryId:v.memory[0].entryId,clear:true});await flush();await assert.rejects(()=>f.service.prepare({viewId:v.viewId,entryId:v.memory[0].entryId,clear:true}),/pending/);gate.resolve();await work;
 assert.equal(f.actor.playerState.spellbooks[0].memorized[1][0].spell,0);assert.ok(view(f).memory[0].pending);
 f.actor.playerState.spellbooks[0].memorized[1][0]=null;await f.service.refresh();assert.equal(view(f).memory[0].pending,false);
 const current=view(f);f.session.prepareSpell=async()=>{throw Error('send failed');};await assert.rejects(()=>f.service.prepare({viewId:current.viewId,entryId:current.memory[2].entryId,clear:true}),/send failed/);assert.equal(f.service.pending.size,0);
});
test('retired actors, changed slot state, unowned metamagic and delayed closed views cannot dispatch',async()=>{
 const f=fixture(),v=await opened(f);f.actor.playerState.spellbooks[0].memorized[1][0].ready=0;await assert.rejects(()=>f.service.assign({viewId:v.viewId,entryId:v.known[0].entryId,index:0}),/stale/);await assert.rejects(()=>f.service.query({metamagic:1}),/not available/);
 const gate=defer();f.actions.tables=async()=>gate.promise;const opening=f.service.open();f.service.close();gate.resolve(f.rules);await opening;assert.equal(f.service.opened,false);assert.equal(f.service.view,null);assert.equal(f.calls.length,0);
});
test('quickbar move sends destination then clears old source; pending dispatch cannot duplicate or clear replaced source',async()=>{
 const f=fixture();f.world.quickbar[0]={type:2,intParam:5,classIndex:0,metamagic:0,domainLevel:0};await opened(f);const old=f.service.quick.id;
 await f.service.quickEdit({quickbarId:old,index:12,sourceIndex:0});assert.deepEqual(f.calls.map(row=>row.request.index),[12,0]);assert.equal(f.world.quickbar[0].type,0);assert.equal(f.world.quickbar[12].intParam,5);await assert.rejects(()=>f.service.quickActivate({quickbarId:old,index:12}),/stale/);
 const q=f.service.quick.id;await f.service.quickEdit({quickbarId:q,index:12,clear:true});assert.equal(f.world.quickbar[12].type,0);
});
test('delayed original icons never overwrite a replacement book or quickbar snapshot',async()=>{
 const f=fixture(),gate=defer();f.service.icon=async()=>gate.promise;const v=await opened(f),q=f.service.quick.id;await f.service.query({classIndex:1,level:1,metamagic:0});gate.resolve('authored png');await flush();assert.equal(f.sent.filter(row=>row.kind==='book-icon'&&row.viewId===v.viewId).length,0);assert.equal(f.sent.filter(row=>row.kind==='quickbar-icon'&&row.quickbarId===q).length,0);
});

test('in-flight shortcut commands tolerate harmless presentation refreshes but never replaced bindings or owners',async()=>{
 const f=fixture();f.world.quickbar[0]={type:42,intParam:22};await opened(f);const owner=f.service.quick.id;
 await f.service.refresh(true);assert.notEqual(f.service.quick.id,owner);assert.equal(f.service.quickCurrent(owner).id,owner);
 await f.service.quickActivate({quickbarId:owner,index:0});assert.equal(f.calls.at(-1).method,'activateQuickbar');
 f.world.quickbar[0]={type:3,intParam:3};assert.throws(()=>f.service.quickCurrent(owner),/stale/);
 const current=f.service.quick.id;f.service.reset();assert.throws(()=>f.service.quickCurrent(current),/stale/);assert.equal(f.service.recentQuick.size,0);
 const bounded=fixture();await opened(bounded);const first=bounded.service.quick.id;for(let i=0;i<10;i++)await bounded.service.refresh(true);assert.equal(bounded.service.recentQuick.size,8);assert.throws(()=>bounded.service.quickCurrent(first),/stale/);
});
test('domain and owned metamagic preparation preserve the base domain level and shared family ID',async()=>{
 const f=fixture();await f.actions.tables();f.actor.playerState.feats.push(12);f.actor.replicated.stats.classes[0].domains=[0,1];f.actor.playerState.spellbooks[0].memorized[2]=[null];
 f.rules.classes=parse2da('2DA V2.0\n\nName SpellCaster MemorizesSpells SpellbookRestricted PlayerClass SpellTableColumn MinCastingLevel PickDomains\n0 10 1 1 0 1 Caster 1 1');f.rules.domains=parse2da('2DA V2.0\n\nLevel_1\n0 0\n1 5');
 Object.assign(f.actions.rules,{classes:f.rules.classes,domains:f.rules.domains});await f.service.open({classIndex:0,level:2,metamagic:2});const v=view(f),source=v.known.find(row=>row.spellId===0&&row.domain);assert.ok(source);await f.service.prepare({viewId:v.viewId,entryId:source.entryId});const request=f.calls.at(-1).request;assert.equal(request.spellId,0);assert.equal(request.domainLevel,1);assert.equal(request.metamagic,2);assert.equal(request.slot,0);assert.equal(f.actor.playerState.spellbooks[0].memorized[2][0],null);
});
test('in-memory family character fixture preserves original bytes and native slot field widths',()=>{
 const f=fixture(),cls=record({Class:field(2,0),ClassLevel:field(2,2),KnownList1:field(15,[record({Spell:field(2,5)},3)]),MemorizedList1:field(15,[record({Spell:field(2,5),Ready:field(0,0),SpellMetaMagic:field(0,0)},3)])},2),source=writeGff('BIC ',record({FirstName:field(12,'Authored character'),ClassList:field(15,[cls])})),before=Uint8Array.from(source);
 const derived=familyTestCharacter(source,f.rules,{spellId:0}),out=parseGff(derived.bytes).root;assert.deepEqual(source,before);assert.deepEqual(derived.metadata.children,[1,2,3,4]);assert.equal(out.ClassList[0].MemorizedList1[0].Spell,0);assert.equal(out.ClassList[0].MemorizedList1[0].Ready,1);assert.equal(out.ClassList[0].KnownList1.length,2);assert.equal(parseGff(source).root.ClassList[0].KnownList1.length,1);
});
