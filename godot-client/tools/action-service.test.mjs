import test from 'node:test';import assert from 'node:assert/strict';
import {ActionService} from './action-service.mjs';import {parse2da} from '../../src/area.js';
import {SpellbookService} from './spellbook-service.mjs';
const defer=()=>{let resolve;const promise=new Promise(r=>resolve=r);return{promise,resolve};};
const tick=()=>new Promise(resolve=>setImmediate(resolve));
function fixture(){
 const raw={
  classes:'Name Icon SpellCaster MemorizesSpells SpellbookRestricted PlayerClass SpellTableColumn FeatsTable\n0 10 wizard 1 1 1 1 Caster authored_feats',
  spells:'Name IconResRef TargetType MetaMagic Master Innate Caster SubRadSpell1 SubRadSpell2 SubRadSpell3 SubRadSpell4 Range\n0 20 parent 3 63 0 1 1 1 2 3 4 S\n1 21 good 3 63 0 1 1 **** **** **** **** S\n2 22 evil 3 63 0 1 1 **** **** **** **** S\n3 23 law 3 63 0 1 1 **** **** **** **** S\n4 24 chaos 4 63 0 1 1 **** **** **** **** S\n5 25 ground 4 63 5 0 0 **** **** **** **** S',
  feat:'Feat UsesPerDay SpellId ReqAction TargetSelf HostileFeat ICON\n0 30 1 5 1 0 0 feat',
  authored_feats:'FeatIndex OnMenu\n0 0 1',domains:'Name GrantedFeat\n',ranges:'PrimaryRange\n0 0\n1 2\n2 8',
  baseitems:'Name\n',iprp_spells:'SpellIndex\n',appearance:'SIZECATEGORY\n0 3',skills:'Name\n',ruleset:'Label Value\n',racialtypes:'StrAdjust\n0 0'};
 const rules=Object.fromEntries(Object.entries(raw).map(([name,data])=>[name,parse2da('2DA V2.0\n\n'+data)]));
 const actor={id:0xffffffff,objectType:5,areaId:9,
  replicated:{position:[1,2,0],name:{text:'Caster'},stats:{classes:[{id:0,level:1}],racialType:0}},
  playerState:{feats:[0],bonusFeats:[],featUses:{0:1},specialAbilities:[],spellbooks:{0:{known:[0],memorized:{1:[{spell:0,ready:1,domain:0,metamagic:0}]}}}}
 };
 const npc={id:7,objectType:5,areaId:9,replicated:{position:[4,5,0],reaction:0,name:{text:'NPC'}}},door={id:8,objectType:10,areaId:9,replicated:{position:[8,5,0],animation:22,fieldFC:1}};
 const world={localObjectId:actor.id,areaId:9,registry:new Map([[actor.id,actor],[7,npc],[8,door]]),quickbar:[],spellTargetingOverrides:new Map()},calls=[],sent=[],diagnostics=[];
 const session={world,areaGeneration:2,closed:false,getResource:async name=>new TextEncoder().encode('2DA V2.0\n\n'+raw[name])};
 for(const name of ['interact','examine','castSpell','useFeat','changeMode','castSpellLike','useItem','selectScriptTarget','rest','walkTo','itemAction','associateCommand','quickChat','possessFamiliar'])session[name]=async request=>{calls.push({name,request});return{sent:true};};
 const text={rules:async name=>rules[name],resolve:async value=>({10:'Wizard',20:'Protection',21:'Good',22:'Evil',23:'Law',24:'Chaos',25:'Ground',30:'Ground feat'})[value.strRef]??String(value.strRef)};
 const service=new ActionService({session,connection:3,text,active:()=>true,send:row=>sent.push(row),diagnose:(...row)=>diagnostics.push(row)});
 return{raw,rules,actor,npc,door,world,session,calls,sent,diagnostics,service};
}
async function choose(f,slot){await f.service.select({menuId:f.service.menu.id,slot});}

async function itemFixture(){
 const f=fixture();f.actor.appearance={appearance:0,gender:0};
 f.rules.baseitems=parse2da('2DA V2.0\n\nName Container EquipableSlots Stacking QBBehaviour WeaponType WeaponSize WeaponWield\n0 100 0 0 1 1 0 1 0\n');
 f.rules.iprp_spells=parse2da('2DA V2.0\n\nName SpellIndex\n0 20 0\n1 25 5\n2 21 1\n');
 const properties=[{type:15,subtype:0,costValue:7,remaining:1},{type:99,subtype:0,costValue:0,remaining:1},...Array.from({length:4},(_,i)=>({type:15,subtype:i%2+1,costValue:2,remaining:1}))];
 f.item={id:99,objectType:6,item:{baseItem:0,identified:1,canUse:1,stackSize:1,name:{text:'Authored powers'},properties,propertyUses:[1,0,3,2,1,1]},inventoryLocation:{ownerId:f.actor.id,channel:'R',x:0,y:0}};
 f.world.registry.set(99,f.item);f.world.quickbar=Array.from({length:36},()=>({type:0}));
 f.session.assignQuickbar=async request=>{f.calls.push({name:'assignQuickbar',request});f.world.quickbar[request.index]=structuredClone(request.button);return{sent:true};};
 f.book=new SpellbookService({actions:f.service});await f.book.refresh(true);
 await f.service.open({requestId:12,targetId:99,position:[0,0,0],inventory:true});return f;
}
const shortcutRequest=f=>({quickbarId:f.book.quick.id,menuId:f.service.menu.id,requestId:12,slot:1,index:34});

test('item power family leaf drags retain the physical property and variant and activate through the original targeter',async()=>{
 const f=await itemFixture(),root=f.service.menu.id;
 assert.ok(f.sent.findLast(r=>r.kind==='action-menu').entries.some(e=>e.submenu));
 await choose(f,3);assert.equal(f.service.menu.view.entries.length,4);
 assert.ok(f.sent.findLast(r=>r.kind==='action-menu').entries.every(e=>e.canDrag));
 await f.book.assignRadial(shortcutRequest(f));
 const b=f.world.quickbar[34];assert.equal(b.type,1);assert.equal(b.itemId,99);assert.equal(b.intParam,1<<16);assert.equal(f.service.menu,null);
 const presented=f.sent.findLast(r=>r.kind==='quickbar-view').rows[34];assert.equal(presented.icon,'evil');assert.equal(presented.secondaryIcon.kind,'item');assert.equal(presented.uses,'*');
 assert.notEqual(root,f.sent.findLast(r=>r.kind==='action-menu').menuId);
 await f.book.quickActivate({quickbarId:f.book.quick.id,index:34});assert.ok(f.service.targeter.active);
 await f.service.selectTarget({token:f.service.targetToken,targetId:f.actor.id,position:[1,0,-2]});
 assert.equal(f.calls.at(-1).name,'useItem');assert.equal(f.calls.at(-1).request.propertyIndex,0);assert.equal(f.calls.at(-1).request.variant,1);
});
test('item power More pages retain physical property indices despite non-cast properties',async()=>{
 const f=await itemFixture();await choose(f,7);const entry=f.service.menu.view.entries[0];
 assert.equal(entry.quickbarBinding.intParam&65535,3);
 await f.book.assignRadial({...shortcutRequest(f),slot:0});assert.equal(f.world.quickbar[34].intParam,0xff0003);
 f.item.item.propertyUses[3]=0;await f.book.refresh(true);const presented=f.sent.findLast(r=>r.kind==='quickbar-view').rows[34];assert.equal(presented.uses,'0');assert.equal(presented.enabled,false);
});
test('item action shortcut rejects submenu parents, stale menu/item/world/shortcut owners and foreign contents',async()=>{
 const parent=await itemFixture();await assert.rejects(parent.book.assignRadial({...shortcutRequest(parent),slot:3}),/cannot be assigned/);
 for(const change of [f=>f.service.back({menuId:f.service.menu.id}),f=>f.item.item.propertyUses[0]++,f=>f.item.inventoryLocation.channel='C',f=>f.item.inventoryLocation.ownerId=7,f=>f.world.registry.set(99,{...f.item}),f=>f.session.areaGeneration++,f=>f.world.quickbar[0]={type:3,intParam:4},f=>f.service.reset()]){
  const f=await itemFixture();await choose(f,3);const request=shortcutRequest(f);change(f);
  await assert.rejects(f.book.assignRadial(request));assert.equal(f.calls.filter(r=>r.name==='assignQuickbar').length,0);
 }
});
test('pending radial assignment cannot dispatch twice; failed assignment remains retryable without consuming the item',async()=>{
 const f=await itemFixture();await choose(f,3);const gate=defer(),request=shortcutRequest(f),snapshot=structuredClone(f.item);
 f.session.assignQuickbar=()=>gate.promise;const first=f.book.assignRadial(request);await tick();await assert.rejects(f.book.assignRadial(request),/pending/);await assert.rejects(f.service.select({menuId:request.menuId,slot:1}),/no longer/);gate.resolve();await first;assert.deepEqual(f.item,snapshot);
 const retry=await itemFixture();await choose(retry,3);retry.session.assignQuickbar=async()=>{throw Error('write failed');};await assert.rejects(retry.book.assignRadial(shortcutRequest(retry)),/write failed/);assert.equal(retry.service.menu.pending,false);
});
test('item action assignment revalidates a leaf after asynchronous rule loading and ignores supplied binding fields',async()=>{
 const f=await itemFixture();await choose(f,3);const gate=defer(),request=shortcutRequest(f);f.service.tables=()=>gate.promise;
 const work=f.book.assignRadial(request);f.service.back({menuId:request.menuId});gate.resolve();await assert.rejects(work,/no longer/);assert.equal(f.calls.filter(r=>r.name==='assignQuickbar').length,0);
 const current=await itemFixture();await choose(current,3);
 await current.book.assignRadial({...shortcutRequest(current),binding:{type:1,itemId:7,intParam:0xff007f},itemId:7,propertyIndex:127,variant:255});
 assert.equal(current.world.quickbar[34].itemId,99);assert.equal(current.world.quickbar[34].intParam,1<<16);
});
test('a pending leaf dispatch cannot send twice and a failed dispatch is retryable',async()=>{
 const f=fixture(),gate=defer();f.session.examine=async()=>gate.promise;await f.service.open({requestId:1,targetId:7,position:[0,0,0]});const id=f.service.menu.id,first=choose(f,0);await assert.rejects(()=>f.service.select({menuId:id,slot:0}),/no longer/);gate.resolve();await first;
 await f.service.open({requestId:2,targetId:7,position:[0,0,0]});f.session.examine=async()=>{throw Error('send failed');};await assert.rejects(()=>choose(f,0),/send failed/);assert.equal(f.service.menu.pending,false);f.session.examine=async()=>({sent:true});await choose(f,0);assert.equal(f.service.menu,null);
});
test('native radial preserves all original physical slots and context-specific default interactions',async()=>{
 const f=fixture();await f.service.open({requestId:1,targetId:7,position:[0,0,0]});
 assert.deepEqual(f.sent.at(-1).entries.map(e=>e.slot),[0,1,2,3,4,5,6,7]);assert.equal(f.calls.length,0);
 await choose(f,0);assert.equal(f.calls.at(-1).name,'examine');assert.equal(f.calls.at(-1).request.targetId,7);
 await f.service.defaultInteraction({targetId:7,position:[0,0,0],run:false});assert.equal(f.calls.at(-1).request.action,'conversation.start');assert.equal(f.calls.at(-1).request.run,false);
 f.npc.replicated.reaction=2;await f.service.defaultInteraction({targetId:7,position:[0,0,0]});assert.equal(f.calls.at(-1).request.action,'combat.attack');
 await f.service.defaultInteraction({targetId:8,position:[0,0,0]});assert.equal(f.calls.at(-1).request.action,'door.open');
 f.door.replicated.animation=50;f.door.replicated.hasTransition=1;await f.service.defaultInteraction({targetId:8,position:[0,0,0]});assert.equal(f.calls.at(-1).request.action,'door.transition');
});
test('spell families expose all children, retain target-specific disabling and can never cast the parent',async()=>{
 const f=fixture(),before=structuredClone([...f.world.registry]);await f.service.open({requestId:1,targetId:f.actor.id,position:[0,0,0]});
 await choose(f,1);await choose(f,5);await choose(f,1);
 assert.equal(f.service.menu.view.entries[0].label,'Protection');assert.equal(f.service.menu.view.entries[0].action,undefined);
 await choose(f,0);assert.deepEqual(f.sent.at(-1).entries.map(e=>e.label),['Good','Evil','Law','Chaos']);assert.equal(f.sent.at(-1).entries[3].disabled,true);
 await assert.rejects(()=>choose(f,3),/unavailable/);assert.equal(f.calls.length,0);
 await choose(f,1);assert.equal(f.calls.at(-1).name,'castSpell');assert.equal(f.calls.at(-1).request.spellId,2);assert.equal(f.calls.at(-1).request.targetId,f.actor.id);assert.deepEqual([...f.world.registry],before);
});
test('back navigation regenerates menu identity; stale and forged slots cannot dispatch a replacement menu',async()=>{
 const f=fixture();await f.service.open({requestId:1,targetId:7,position:[0,0,0]});const old=f.service.menu.id;
 await choose(f,1);f.service.back({menuId:f.service.menu.id});assert.notEqual(f.service.menu.id,old);
 await assert.rejects(()=>f.service.select({menuId:old,slot:0}),/no longer/);await assert.rejects(()=>choose(f,99),/unavailable/);assert.equal(f.calls.length,0);
});
test('late icon completion cannot clobber another submenu with the same physical slot',async()=>{
 const f=fixture(),gate=defer();f.service.icon=async()=>gate.promise;await f.service.open({requestId:1,targetId:7,position:[0,0,0]});const old=f.service.menu.id;await choose(f,1);const current=f.service.menu.id;gate.resolve('authored PNG');await tick();
 assert.equal(f.sent.filter(row=>row.kind==='action-icon'&&row.menuId===old).length,0);assert.ok(f.sent.some(row=>row.kind==='action-icon'&&row.menuId===current));
});
test('cancelled or retired async menu preparation never publishes a new native wheel',async()=>{
 for(const retire of [f=>f.service.cancel({requestId:4}),f=>f.session.areaGeneration++,f=>f.session.closed=true,f=>f.world.registry.set(7,{...f.npc})]){
  const f=fixture(),gate=defer();f.service.tables=async()=>{await gate.promise;f.service.rules=f.rules;return f.rules;};const work=f.service.open({requestId:4,targetId:7,position:[0,0,0]});retire(f);gate.resolve();await work;assert.equal(f.sent.filter(row=>row.kind==='action-menu').length,0);
 }
});
test('selected feat uses the original targeter; rejected clicks do not become movement and ground coordinates stay native',async()=>{
 const f=fixture();await f.service.tables();f.service.targetScope=f.service.capture();await f.service.targeter.beginFeat(0);
 const token=f.service.targetToken;f.service.hover({token,targetId:7});assert.equal(f.sent.at(-1).presentation.valid,false);f.service.hover({token,targetId:null});assert.equal(f.sent.at(-1).presentation.valid,true);
 await assert.rejects(()=>f.service.selectTarget({token,targetId:7,position:[4,0,-5]}),/not valid/);assert.equal(f.calls.length,0);assert.ok(f.service.targeter.active);
 await f.service.selectTarget({token,targetId:null,position:[4,2,-5]});assert.equal(f.calls.at(-1).name,'useFeat');assert.deepEqual(f.calls.at(-1).request.position,[4,5,2]);assert.equal(f.calls.at(-1).request.targetId,0x7f000000);assert.equal(f.service.targeter.active,false);
});
test('target selection and menu callbacks are retired when the controlled actor is replaced',async()=>{
 const f=fixture();await f.service.open({requestId:1,targetId:7,position:[0,0,0]});const menuId=f.service.menu.id;f.service.targetScope=f.service.capture();await f.service.targeter.beginFeat(0);const token=f.service.targetToken;f.world.registry.set(f.actor.id,{...f.actor});
 await assert.rejects(()=>f.service.select({menuId,slot:0}),/no longer/);await assert.rejects(()=>f.service.selectTarget({token,targetId:null,position:[0,0,0]}),/no longer/);assert.equal(f.calls.length,0);
});
test('server-script target selection uses its original mask, version and typed submission path',async()=>{
 const f=fixture();f.world.scriptTargeting={version:5,objectMask:1<<9,cursor:29,badCursor:31};await f.service.serverTarget();const token=f.service.targetToken;
 await assert.rejects(()=>f.service.selectTarget({token,targetId:7,position:[0,0,0]}),/not valid/);
 await f.service.selectTarget({token,targetId:null,position:[3,4,-5]});assert.equal(f.calls.at(-1).name,'selectScriptTarget');assert.equal(f.calls.at(-1).request.version,5);assert.deepEqual(f.calls.at(-1).request.position,[3,5,4]);
});
