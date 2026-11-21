import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {itemUseRequest} from '../src/network_item_input.js';
import {NetworkSpellTargeting} from '../src/network_spell_targeting.js';
import {NetworkWorld} from '../src/network_world.js';import {parse2da} from '../src/area.js';
import {inventoryPanelRequest} from '../src/network_player_requests.js';
import {openLocalModule} from '../scripts/local-module.mjs';import {loadNetworkObjectRules} from '../src/network_object_rules.js';import {decodeServerGameMessage} from '../src/network_game_messages.js';

test('original item sender/server route preserves BYTE property/variant, exact nonzero points and client IDs',()=>{
 const f=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-item-use-observations.json',import.meta.url)));assert.equal(f.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(f.cases.length,435);
 for(const row of f.cases){const c=row.case;if(c.format===1){const actual=itemUseRequest(c),native=Buffer.from(row.packet,'hex'),used=native.at(-1)>>>5,mask=255<<(8-used)&255;assert.equal(actual.length,native.length);assert.deepEqual(Buffer.from(actual.subarray(0,-1)),native.subarray(0,-1));assert.equal(actual.at(-1)&mask,native.at(-1)&mask);}
  const use=row.calls.find(v=>v.kind==='use');if(c.noActor||c.noArea||c.blocked){assert.equal(use,undefined);continue;}assert.ok(use);assert.equal(use.itemId,(c.itemId&0x7fffffff)>>>0);assert.equal(use.propertyIndex,c.propertyIndex);assert.equal(use.variant,c.variant===255?0:c.variant);assert.equal(use.targetId,c.targetId===0x7f000000?c.targetId:(c.targetId&0x7fffffff)>>>0);assert.deepEqual(use.position,c.position.map(v=>Math.fround(v)||0));assert.equal(use.areaId,7);assert.equal(use.flag,1);
 }
 for(const change of [{itemId:-1},{propertyIndex:256},{variant:-1},{variant:256},{targetId:2**32},{position:null},{position:[0,0,NaN]},{position:[1e40,0,0]}])assert.throws(()=>itemUseRequest({itemId:1,propertyIndex:0,...change}));
 assert.notDeepEqual(itemUseRequest({itemId:1,propertyIndex:0,position:[1e-8,0,0]}),itemUseRequest({itemId:1,propertyIndex:0}));
});

test('item targeter uses replicated metadata, native item auto-self/creature veto and possessor coordinates without consuming charges',async()=>{
 const w=new NetworkWorld(),actor={id:0xffffffff,objectType:5,areaId:0x80000001,replicated:{position:[1,2,3]}},item={id:0x80000002,objectType:6,item:{baseItem:0,properties:[{type:15,subtype:0,costValue:1,remaining:1}],propertyUses:[2]},inventoryLocation:{ownerId:actor.id,channel:'R'}},other={id:0x80000003,objectType:5,areaId:actor.areaId,replicated:{position:[4,5,6]}};for(const o of [actor,item,other])w.registry.addObjectAtPos(o.id,o);w.localObjectId=actor.id;w.areaId=actor.areaId;
 const tables={baseitems:parse2da('2DA V2.0\n\nQBBehaviour\n0 2\n'),iprp_spells:parse2da('2DA V2.0\n\nSpellIndex\n0 0\n'),spells:parse2da('2DA V2.0\n\nTargetType SubRadSpell1\n0 1 ****\n')},sent=[],before=structuredClone([...w.registry.objects]);let generation=1;
 const targeter=new NetworkSpellTargeting({world:()=>w,tables:()=>tables,context:()=>({generation}),submit:async r=>sent.push(r)});
 await targeter.begin({type:1,itemId:item.id,intParam:0xff0000});assert.deepEqual(sent[0],{kind:'item',itemId:item.id,propertyIndex:0,variant:255,targetId:actor.id,position:[0,0,0]});assert.equal(targeter.active,false);
 tables.baseitems=parse2da('2DA V2.0\n\nQBBehaviour\n0 0\n');tables.spells=parse2da('2DA V2.0\n\nTargetType SubRadSpell1\n0 10 ****\n');await targeter.beginItem(item.id,0xff0000);assert.equal(targeter.active,true);await assert.rejects(targeter.select(actor,[1,2,3]),/not valid/);await targeter.select(item,[0,0,0]);assert.deepEqual(sent.at(-1).position,[1,2,3],'inventory item target inherits its possessing creature position');
 await targeter.beginItem(item.id,0xff0000);generation++;await assert.rejects(targeter.select(other,[4,5,6]),/old area/);assert.equal(targeter.active,false);assert.deepEqual([...w.registry.objects],before);
});

test('native repository panel reset removes stale GUI membership while preserving canonical item metadata and other channels',()=>{
 const w=new NetworkWorld(),item={id:0x80000002,objectType:6,item:{stackSize:1},inventoryLocation:{channel:'R',ownerId:0xffffffff}};w.registry.addObjectAtPos(item.id,item);w.inventories.set('R',{entries:[{id:item.id,x:1,y:4}]});w.inventories.set('I',{entries:[{id:0x80000003,slot:2}]});w.inventories.set('r',{entries:[{id:0x80000004,x:0,y:0}]});const before=structuredClone(item);w.clearRepositoryView();assert.deepEqual(w.inventories.get('R').entries,[]);assert.equal(w.inventories.get('I').entries.length,1);assert.equal(w.inventories.get('r').entries.length,1);assert.deepEqual(item,before);assert.equal(w.registry.get(item.id),item);
});

test('original inventory panel owner clears its GUI before transport lookup and sends the selected BYTE panel',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-inventory-panel-reset-observations.json',import.meta.url)));assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.cases.length,40);
 for(const row of fixture.cases){assert.deepEqual(row.events[0],{kind:'gridClear',panel:row.case.panel});assert.equal(row.events[1].kind,'transport');if(row.case.transport&&row.case.format===1&&row.case.panel<256){const a=inventoryPanelRequest({panel:row.case.panel,self:row.case.self}),n=Buffer.from(row.events[2].packet,'hex'),used=n.at(-1)>>>5,mask=255<<(8-used)&255;assert.deepEqual(Buffer.from(a.subarray(0,-1)),n.subarray(0,-1));assert.equal(a.at(-1)&mask,n.at(-1)&mask);}else if(!row.case.transport)assert.equal(row.events.length,2);}
});

test('actual vanilla item cycle uses radial-power drag, double-click, hotbar and F-key, and refresh removes the consumed inventory row',async()=>{
 const r=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v80.json',import.meta.url))),diagnostics=JSON.parse(fs.readFileSync(new URL('../backups/animations/network-native-item-diagnostics-v80.json',import.meta.url)));assert.equal(r.failure,undefined);assert.equal(r.sampleFailure,undefined);assert.equal(r.renderer.state.phase,'playing');assert.equal(r.states.at(-1).closed,true);assert.deepEqual(diagnostics.errors,[]);assert.ok(r.paintFrames>1000);assert.equal(r.quickbarActions[0].result.powerDropped,true);assert.equal(r.itemActions[0].result.doubleclicked,true);
 const itemId=r.itemActions[0].itemId,actorId=r.renderer.world.localObjectId,requests=r.quickbarRequests.filter(v=>v.packet.startsWith('700609'));assert.equal(requests.length,3);for(const request of requests)assert.deepEqual(Buffer.from(request.packet,'hex'),Buffer.from(itemUseRequest({itemId,propertyIndex:0,variant:255,targetId:actorId,position:[0,0,0]})));
 const root='../FullDecomp/NwnRootInstall',rules=await loadNetworkObjectRules(await openLocalModule(root,root+'/data/nwm/Prelude.nwm')),w=new NetworkWorld(),panels=r.quickbarRequests.filter(p=>p.packet.startsWith('700d02')),stacks=[];let panel=0;
 assert.equal(r.wireTimes.length,r.wireMessages.length);for(const [i,hex]of r.wireMessages.entries()){
  while(panel<panels.length&&panels[panel].at<=r.wireTimes[i]){w.clearRepositoryView();panel++;}
  w.apply(decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>w.registry.get(id)?.replicated}}));const item=w.registry.get(itemId),stack=item?.item?.stackSize??item?.item?.field454;if(stack!==undefined&&stacks.at(-1)!==stack)stacks.push(stack);
 }
 assert.deepEqual(stacks,[3,2,1]);assert.equal(w.quickbar[0].type,0);assert.equal(w.inventories.get('R').entries.length,4);assert.ok(w.inventories.get('R').entries.every(e=>e.id!==itemId));assert.ok(w.registry.get(itemId),'native grid reset preserves the canonical cached object');assert.equal(r.samples.at(-1).inventory.backpack.length,4);assert.ok(r.samples.at(-1).inventory.backpack.every(e=>e.id!==itemId));
 const drinks=r.samples.filter(s=>s.scene?.objects?.some(o=>o.id===actorId&&o.animation===70&&o.clip==='drink'));assert.ok(drinks.length>=3);for(const request of requests)assert.ok(drinks.some(s=>s.at>=request.at&&s.at-request.at<6000),'each native use produces a displayed drink animation');
});
