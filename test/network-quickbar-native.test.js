import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeMessageReader} from '../src/native_message.js';
import {readNetworkQuickbar,quickbarAssignmentRequest} from '../src/network_quickbar.js';
import {NetworkWorld} from '../src/network_world.js';
import {openLocalModule} from '../scripts/local-module.mjs';
import {parse2da} from '../src/area.js';
import {decodeResourceText} from '../src/resource_archive.js';
import {configureNetworkItemShortcut,networkItemQuickbarProviders} from '../src/network_quickbar_items.js';
import {emptyQuickbarButton} from '../src/quickbar.js';
const f=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-quickbar-observations.json',import.meta.url)));
test('replicated numeric CanUseItem and actual module tables configure item shortcuts without mutating canonical items',async()=>{
 const root='../FullDecomp/NwnRootInstall',resolver=await openLocalModule(root,root+'/data/nwm/Prelude.nwm'),names=['baseitems','appearance','iprp_spells','spells'],tables=Object.fromEntries(await Promise.all(names.map(async n=>[n,parse2da(decodeResourceText(await resolver.getResource(n,2017)))]))),replay=JSON.parse(fs.readFileSync(new URL('../backups/animations/network-item-use-replay-v43.json',import.meta.url))),world=new NetworkWorld();
 for(const o of replay.items)world.registry.addObjectAtPos(o.id,{...o,objectType:6});world.localObjectId=0xffffffff;world.registry.addObjectAtPos(world.localObjectId,{id:world.localObjectId,objectType:5,appearance:{appearance:0}});const before=structuredClone([...world.registry.objects]),p=networkItemQuickbarProviders(world,tables,{});
 for(const binding of replay.quickbar.filter(b=>b.type===1)){const result=configureNetworkItemShortcut(world,tables,emptyQuickbarButton(),binding);assert.equal(result.button.type,1);assert.equal(result.button.itemId,binding.itemId);assert.equal(result.button.intParam,binding.intParam);assert.equal(p.canUse(p.item(binding.itemId)),1);}
 assert.throws(()=>p.canUse({}),/unavailable/);assert.deepEqual([...world.registry.objects],before);
});
test('368 original full/single quickbar sender/reader cases agree on all current non-item and absent-item field layouts',()=>{
 assert.equal(f.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(f.cases.length,368);
 for(const row of f.cases){const c=row.case,bytes=Buffer.from(row.packet,'hex'),r=new NativeMessageReader(c.format);r.setReadMessage(bytes.subarray(3),bytes.length-3,0xffffffff,1);const result=readNetworkQuickbar(r,bytes[2],{number:8193,revision:37,postfix:17},{});assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);assert.equal(result.entries.length,c.full?36:1);assert.deepEqual(result.entries.map(e=>e.index),row.calls.map(e=>e.index));
  for(const [i,entry]of result.entries.entries()){const b=entry.button,n=row.calls[i];assert.equal(b.type,c.type);if(c.type===1){assert.equal(b.itemId,n.itemId);assert.equal(b.secondaryItemId,n.secondId);assert.equal(b.intParam>>>0,n.intParam);}
   else if(c.type===2){assert.equal(b.classIndex,n.classIndex);assert.equal(b.intParam,n.spellId);assert.equal(b.metamagic,n.field54);assert.equal(b.domainLevel,n.field55);}
   else if(c.type===44){assert.equal(b.intParam,n.spellId);assert.equal(b.domainLevel,n.domainLevel);}
   else if(c.type===39){assert.equal(b.intParam>>>0,n.intParam);assert.equal(b.associateType,n.associateType);assert.equal(b.associateId,n.associateId);}
   else if(c.type===18){assert.equal(b.commandLabel,n.commandLabel);assert.equal(b.commandLine,n.commandLine);}
   else if(c.type>=11&&c.type<=17){assert.equal(b.resRef,n.resRef);assert.equal(b.toolTip,n.toolTip);}
   else if(c.type===29||c.type===30)assert.equal(b.resRef,n.resRef);
   else if(b.intParam!==undefined)assert.equal(b.intParam>>>0,n.intParam);
  }
 }
});
test('216 original client assignment packets match the encoder and complete original server field writes',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-quickbar-request-observations.json',import.meta.url)));assert.equal(fixture.cases.length,216);assert.equal(fixture.target,f.target);
 for(const row of fixture.cases){const c=row.case;if(c.format!==1)continue;const button={...c,intParam:[2,44].includes(c.type)?c.intParam>>>0:c.intParam},actual=quickbarAssignmentRequest({index:c.index,button}),native=Buffer.from(row.packet,'hex'),used=native.at(-1)>>>5,mask=255<<(8-used)&255;assert.equal(actual.length,native.length,JSON.stringify(c));assert.deepEqual(Buffer.from(actual.subarray(0,-1)),native.subarray(0,-1),JSON.stringify(c));assert.equal(actual.at(-1)&mask,native.at(-1)&mask,JSON.stringify(c));assert.equal(row.result.type,c.type);if(c.type===2){assert.equal(row.result.metamagic,c.metamagic);assert.equal(row.result.domainLevel,c.domainLevel);}}
 for(const index of [-1,36,NaN])assert.throws(()=>quickbarAssignmentRequest({index,button:{type:0}}));assert.throws(()=>quickbarAssignmentRequest({index:0,button:{type:2,intParam:1,classIndex:8,metamagic:0,domainLevel:-1}}));
});
test('real server quickbar supplies embedded item identities and paired shortcuts without inventing inventory locations',()=>{
 const replay=JSON.parse(fs.readFileSync(new URL('../backups/animations/network-item-use-replay-v43.json',import.meta.url)));assert.equal(replay.quickbar.length,36);const b=replay.quickbar[2];assert.equal(b.type,1);assert.equal(b.itemId,0x80000297);assert.equal(b.secondaryItemId,0x80000296);assert.equal(replay.quickbar[6].intParam,452);
 for(const id of [b.itemId,b.secondaryItemId]){const item=replay.items.find(o=>o.id===id);assert.ok(item);assert.equal(item.inventoryLocation,undefined);assert.equal(item.areaId,0x7f000000);}
 const world=new NetworkWorld(),item={id:0x80000005,objectType:6,item:{baseItem:8},inventoryLocation:{ownerId:0xffffffff,channel:'I',slot:16},areaId:0x7f000000};world.registry.addObjectAtPos(item.id,item);world.apply({kind:'quickbar',entries:[{index:3,button:{type:1,itemId:item.id,intParam:0xff00ff},items:[{id:item.id,item:{baseItem:8,field454:1}}]}]});assert.equal(world.registry.get(item.id),item);assert.equal(item.inventoryLocation.slot,16);assert.equal(world.quickbar[3].itemId,item.id);
 assert.throws(()=>world.apply({kind:'quickbar',entries:[{index:0,button:{type:4,intParam:1},items:[]},{index:1,button:{type:1},items:[{id:123,item:{}}]}]}));assert.equal(world.quickbar[0].type,0);
});
test('final real renderer drives menus, shortcut and inventory drags, keys and server-owned equipment changes',()=>{
 const r=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v46.json',import.meta.url))),replay=JSON.parse(fs.readFileSync(new URL('../backups/animations/network-item-use-replay-v46.json',import.meta.url))),diagnostics=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v46-diagnostics.json',import.meta.url)));
 assert.equal(r.failure,undefined);assert.equal(r.sampleFailure,undefined);assert.equal(r.renderer.state.phase,'playing');assert.equal(r.states.at(-1).closed,true);assert.ok(r.paintFrames>1000);assert.equal(r.quickbarActions.length,16);assert.equal(r.quickbarRequests.length,10);assert.deepEqual(diagnostics.filter(d=>d.severity==='error'),[]);assert.deepEqual(replay.unhandled,[]);
 const first=r.samples.find(s=>s.quickbar?.buttons[2]?.type===1)?.quickbar.buttons,last=r.samples.at(-1).quickbar.buttons;assert.ok(first,'Initial shortcut replication must arrive before testing moves');assert.deepEqual(last[10],first[2]);assert.equal(last[2].type,0);assert.equal(last[11].type,2);assert.equal(last[12].type,1);const dropped=r.quickbarActions.find(a=>a.step.mode==='inventoryDrop').result.itemId;assert.equal(last[1].itemId,dropped);
 for(const index of [10,12,1])assert.ok(replay.uses.some(group=>group.entries.some(e=>e.index===index&&e.id===last[index].itemId)),'The real server must report the newly assigned slot');
 const equipment=r.samples.map(s=>s.server.equipment).filter(Boolean),hasSlots=slots=>equipment.some(e=>slots.every(([slot,id])=>e.some(v=>v.slot===slot&&v.id===id)));assert.ok(hasSlots([[16,first[2].itemId],[32,first[2].secondaryItemId]]));assert.ok(equipment.some(e=>!e.some(v=>[16,32].includes(v.slot))));assert.ok(hasSlots([[16,first[3].itemId]]));assert.ok(hasSlots([[16,dropped]]));
});
