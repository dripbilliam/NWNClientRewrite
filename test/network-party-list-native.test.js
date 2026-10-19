import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {readNetworkParty,applyNetworkParty,networkPartyAssociates} from '../src/network_party.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NativeMessageReader,NativeMessageWriter} from '../src/native_message.js';
import {NetworkWorld} from '../src/network_world.js';
import {networkPartyRows} from '../src/network_party_view.js';
import {networkAssociateShortcutChoices} from '../src/network_associate_input.js';
import {openLocalModule} from '../scripts/local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';

test('630 original party sender/receiver/list-owner cases preserve exclusion, canonical IDs, physical order and stale-entry sweeps',()=>{
 const f=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-party-list-observations.json',import.meta.url)));assert.equal(f.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(f.cases.length,630);
 for(const r of f.cases){const c=r.case,bytes=Buffer.from(r.packet,'hex');let message;
  if(c.format===1){message=decodeServerGameMessage(bytes);for(let i=0;i<bytes.length;i++)assert.throws(()=>decodeServerGameMessage(bytes.subarray(0,i)));}
  else{const reader=new NativeMessageReader(0);assert.equal(reader.setReadMessage(bytes.subarray(3),bytes.length-3,0xffffffff,1),1);message=readNetworkParty(reader,c.minor);assert.equal(reader.messageReadOverflow(),0);assert.equal(reader.messageReadUnderflow(),0);}
  assert.equal(message.operation,({1:'all',3:'add',4:'remove'})[c.minor]);assert.deepEqual(message.ids,c.ids.filter(id=>id!==c.exclude).map(id=>id===0x7f000000?id:(id|0x80000000)>>>0));assert.equal(message.count,message.ids.length);const before=structuredClone(c.prior),actual=applyNetworkParty(c.prior,message);assert.deepEqual(actual,r.entries,JSON.stringify(c));assert.deepEqual(c.prior,before);
 }
});

test('party counts are signed, malformed batches are rejected atomically and membership never creates or deletes game objects',()=>{
 const world=new NetworkWorld(),pc={id:0xffffffff,objectType:5,areaId:0x80000001,replicated:{}};world.registry.addObjectAtPos(pc.id,pc);world.localObjectId=pc.id;
 world.apply({kind:'party-list',operation:'add',ids:[0x80000002,0x80000003]});assert.equal(world.registry.objects.size,1);assert.equal(world.registry.get(0x80000002),undefined);assert.deepEqual(world.party.map(e=>e.id),[0x80000002,0x80000003]);
 const before=structuredClone(world.party);for(const change of [{operation:'bad',ids:[]},{ids:[0x80000004,-1]},{ids:[2**32]}])assert.throws(()=>world.apply({kind:'party-list',operation:'add',...change}));assert.deepEqual(world.party,before);assert.equal(world.registry.get(pc.id),pc);
 world.apply({kind:'party-list',operation:'all',ids:[0x80000003,0x80000002,pc.id]});assert.deepEqual(world.party.map(e=>e.id),[0x80000002,0x80000003,pc.id],'full refresh retains existing physical order');world.apply({kind:'party-list',operation:'remove',ids:[pc.id]});assert.equal(world.registry.get(pc.id),pc,'membership removal is not game-object destruction');
 for(const count of [-2147483648,-1,0,2147483647]){const w=new NativeMessageWriter(1);w.create(128,0xffffffff,1);w.writeInt(count);w.setPrefix(Uint8Array.of(80,14,1));const bytes=w.getWriteMessage().data;if(count>0)assert.throws(()=>decodeServerGameMessage(bytes),/party-list/);else assert.deepEqual(decodeServerGameMessage(bytes),{kind:'party-list',operation:'all',count,ids:[],major:14,minor:1});}
 world.reset();assert.deepEqual(world.party,[]);
});

test('party UI and associate queries resolve only server roster IDs and current canonical proxies without granting ownership',()=>{
 const world=new NetworkWorld(),pc={id:0xffffffff,objectType:5,replicated:{name:{firstName:{text:'Player'},lastName:{text:'One'}},hitPoints:{current:10,fieldE4:99,fieldE8:6,maximum:20}}},familiar={id:0x80000002,objectType:5,replicated:{master:pc.id,field908:3}},stranger={id:0x80000003,objectType:5,replicated:{master:99,field908:3}},henchman={id:0x80000004,objectType:5,replicated:{master:pc.id,field908:1}};for(const o of [pc,familiar,stranger,henchman])world.registry.addObjectAtPos(o.id,o);world.localObjectId=pc.id;world.apply({kind:'party-list',operation:'all',ids:[familiar.id,0x80000005,stranger.id,henchman.id]});
 assert.deepEqual(networkPartyAssociates(world,pc,3),[familiar]);assert.deepEqual(networkPartyAssociates(world,{id:0x7f000000},3),[familiar,stranger]);assert.deepEqual(networkPartyAssociates(world,pc,1),[henchman]);const rows=networkPartyRows(world);assert.deepEqual(rows.map(r=>[r.id,r.self,r.available]),[[pc.id,true,true],[familiar.id,false,true],[0x80000005,false,false],[stranger.id,false,true],[henchman.id,false,true]]);assert.deepEqual(rows[0].health,{current:16,maximum:20});assert.equal(world.registry.objects.size,4);familiar.replicationRemoved=true;assert.deepEqual(networkPartyAssociates(world,pc,3),[]);assert.equal(networkPartyRows(world)[1].available,false);
 assert.deepEqual(networkAssociateShortcutChoices(world,pc).filter(e=>e.binding.type===39).map(e=>[e.binding.associateId,e.binding.intParam]),[[henchman.id,-18],[henchman.id,-19],[henchman.id,-20]]);world.apply({kind:'party-list',operation:'remove',ids:[henchman.id]});assert.equal(networkAssociateShortcutChoices(world,pc).some(e=>e.binding.associateId===henchman.id),false,'henchman command choices follow the real roster, not a registry scan');
});

test('real vanilla party portraits drive commands, spell targeting, possession and roster removal through canonical server records',async()=>{
 const r=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v64.json',import.meta.url))),diagnostics=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v64-diagnostics.json',import.meta.url)));assert.equal(r.failure,undefined);assert.equal(r.sampleFailure,undefined);assert.equal(r.quickbarActions.length,18);assert.ok(r.paintFrames>4000);assert.equal(r.states.at(-1).closed,true);assert.deepEqual(diagnostics.filter(e=>e.severity==='error'||e.code==='network.party-portrait-unavailable'),[]);
 const controls=[],uses=[];for(const s of r.samples){if(controls.at(-1)!==s.server.controlledId)controls.push(s.server.controlledId);if(s.server.controlledId===0xffffffff){const n=Object.values(s.server.spellbooks?.[0]?.memorized??{}).flat().filter(v=>v?.spell===100&&v.ready!==0).length;if(uses.at(-1)!==n)uses.push(n);}}
 const familiarId=controls[2];assert.deepEqual(controls,[0x7f000000,0xffffffff,familiarId,0xffffffff]);assert.deepEqual(uses,[2,1]);assert.ok(r.samples.some(s=>s.party?.members.length===2&&s.party.members.every(m=>m.available&&m.portraitLoaded&&m.health?.maximum>0)));assert.ok(r.samples.some(s=>s.party?.controlledId===familiarId&&s.party.members.some(m=>m.self&&m.id===familiarId&&m.portraitLoaded)));
 assert.deepEqual(r.samples.at(-1).party.members.map(m=>[m.id,m.self,m.portraitLoaded]),[[0xffffffff,true,true]]);assert.deepEqual(r.samples.at(-1).server.party,[]);assert.ok(r.quickbarActions[8].result.target,'actual F-key targeting is pending before clicking the familiar portrait');assert.equal(r.quickbarActions[9].result.targetId,familiarId);
 const spell=r.quickbarRequests.map(p=>Buffer.from(p.packet,'hex')).find(b=>b[1]===6&&b[2]===18),reader=new NativeMessageReader(1);assert.ok(spell);reader.setReadMessage(spell.subarray(3),spell.length-3,0xffffffff,1);assert.equal(reader.readDword(),100);reader.readByte();reader.readByte();reader.readByte();assert.ok(reader.readByte()&1);assert.equal(reader.readObjectIdClient(),familiarId);
 const root='../FullDecomp/NwnRootInstall',rules=await loadNetworkObjectRules(await openLocalModule(root,root+'/data/nwm/Prelude.nwm')),world=new NetworkWorld(),lists=[],refs=new Map();
 for(const hex of r.wireMessages){const message=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(message);if(message.kind==='party-list')lists.push([message.operation,message.ids]);for(const id of [0xffffffff,familiarId]){const object=world.registry.get(id);if(!object)continue;if(refs.has(id))assert.equal(object,refs.get(id));else refs.set(id,object);}}
 assert.deepEqual(lists,[['add',[familiarId]],['remove',[familiarId]]]);assert.deepEqual(world.party,[]);assert.equal(world.localObjectId,0xffffffff);assert.ok(world.registry.get(familiarId).replicationRemoved);assert.equal(world.registry.get(0xffffffff).familiarId,0x7f000000);
});
