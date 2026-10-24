import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {NativeMessageReader} from '../src/native_message.js';
import {readObjectUpdates} from '../src/network_object_updates.js';
import {networkAttackAnimationRecords} from '../src/network_attack_animation.js';
import {ClientAnimationQueue} from '../src/client_animation_queue.js';
import {NetworkWorld} from '../src/network_world.js';
import path from 'node:path';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {openLocalModule} from '../scripts/local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
const load=name=>JSON.parse(fs.readFileSync(new URL(`../backups/animations/${name}.json`,import.meta.url)));
const target='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';

test('96 original server/client attack updates preserve wire layout and native client action projection',()=>{
 const fixture=load('native-network-attack-record-observations');assert.equal(fixture.target,target);assert.equal(fixture.cases.length,96);
 for(const c of fixture.cases){
  const errors=[],r=new NativeMessageReader(c.case.format,{diagnose:e=>errors.push(e)}),bytes=Buffer.from(c.packet,'hex').subarray(3);r.setReadMessage(bytes,bytes.length,0xffffffff,1);
  const d=readObjectUpdates(r,{clientBuild:{number:8193,revision:37,postfix:17}});assert.equal(d.complete,true);assert.equal(d.records.length,1);
  const record=d.records[0];assert.equal(record.id,0x80fedcba);assert.equal(record.state.animationTime,1.75);assert.equal(record.state.animation,9);
  const projected=networkAttackAnimationRecords(record.id,record.state.attacks);
  if(c.case.present){assert.deepEqual(projected,c.calls[0].records);assert.equal(c.speed,1.75);}else assert.deepEqual(c.calls,[]);
  assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);assert.deepEqual(errors,[]);
 }
});

test('actual vanilla-server attack projects 916ms,24 damage and killing blow without running local combat',async()=>{
 const report=load('local-network-renderer-v34'),install=path.resolve('../FullDecomp/NwnRootInstall'),res=installedNetworkResources({install}),rules=await loadNetworkObjectRules(await openLocalModule(install,await res.findFile('nwm','Prelude','nwm'))),world=new NetworkWorld(),events=[];
 assert.equal(report.connected,true);assert.equal(report.failure,undefined);assert.equal(report.sampleFailure,undefined);assert.equal(report.states.at(-1).phase,'closed');
 assert.deepEqual(report.interactions.map(v=>v.action),['combat.attack','combat.attack']);
 for(const hex of report.wireMessages){const m=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},serverBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(m);if(m.kind==='object-updates'){assert.equal(m.complete,true);events.push(...world.presentationChanges.filter(e=>e.action==='attack-animation'));}}
 assert.equal(events.length,1);const e=events[0];assert.equal(e.id,0xffffffff);assert.equal(e.speed,1);assert.equal(e.records.length,1);
 assert.deepEqual(e.records[0],{type:1,sourceId:0xffffffff,duration:916,damage:24,result:3,targetId:0x80000012,reactionDelay:0,reaction:14,reactionDuration:0,attackType:0,ranged:0,killingBlow:1,weaponAttackType:1});
 assert.equal(world.registry.get(e.id).replicated.attacks,undefined);assert.equal(world.localObjectId,0xffffffff);
});

test('identical attack groups remain distinct events; failed imports publish no partial combat state',()=>{
 const fixture=load('native-network-attack-record-observations').cases.find(c=>c.case.present&&c.case.groups.length===3),r=new NativeMessageReader(fixture.case.format),bytes=Buffer.from(fixture.packet,'hex').subarray(3);r.setReadMessage(bytes,bytes.length,0xffffffff,1);
 const d={kind:'object-updates',...readObjectUpdates(r,{clientBuild:{number:8193,revision:37,postfix:17}})},world=new NetworkWorld({onDiagnostic:()=>{}}),source=structuredClone(d);
 world.apply(d);const actor=world.registry.get(d.records[0].id),first=world.presentationChanges[0];
 assert.equal(first.action,'attack-animation');assert.equal(first.speed,1.75);assert.deepEqual(first.records,fixture.calls[0].records);assert.equal(actor.replicated.animationSpeed,1.75);assert.equal(actor.replicated.attacks,undefined);
 world.apply(d);const second=world.presentationChanges[0];assert.deepEqual(second,first);assert.notEqual(second.records[0],first.records[0]);assert.equal(world.registry.get(actor.id),actor);
 const q=new ClientAnimationQueue(7200000);for(const e of [first,second])q.insert({animation:200,duration:e.records[0].duration,speed:1,record:e.records[0]},{day:7,time:100});assert.equal(q.count,2);
 const before=structuredClone(actor);assert.throws(()=>world.apply({kind:'object-updates',records:[...d.records,{action:'create',objectType:10,id:actor.id,state:{}}]}),/Conflicting/);assert.deepEqual(actor,before);assert.equal(world.presentationChanges[0],second);assert.deepEqual(d,source);
 world.apply({kind:'object-updates',records:[{action:'update',id:actor.id,objectType:5,state:{position:[1,2,3]}}]});assert.deepEqual(world.presentationChanges.filter(e=>e.action==='attack-animation'),[]);assert.equal(world.presentationChanges[0].action,'movement');assert.deepEqual(actor.replicated.position,[1,2,3]);
});

test('60 original queue sequences verify stable ordering, pointer duplication, growth, removal and exact FLOAT timing',()=>{
 const fixture=load('native-animation-queue-observations');assert.equal(fixture.target,target);assert.equal(fixture.cases.length,60);
 for(const c of fixture.cases){
  const q=new ClientAnimationQueue(c.length);
  for(const op of c.operations){
   if(op.kind==='insert'){q.insert({...op,record:op.record||null},c.now);const state=q.snapshot();state.entries.forEach(e=>e.record??=0);assert.deepEqual(state,op.state);}
   else if(op.kind==='remove'){q.remove();const state=q.snapshot();state.entries.forEach(e=>e.record??=0);assert.deepEqual(state,op.state);}
   else{const next=q.next(op.now??c.now);next.record??=0;assert.deepEqual(next,op.observed,JSON.stringify({c:c.now,op}));}
  }
 }
});
