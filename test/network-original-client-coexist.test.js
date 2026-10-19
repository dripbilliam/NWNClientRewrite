import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NativeMessageReader} from '../src/native_message.js';
import {NetworkWorld} from '../src/network_world.js';
import {openLocalModule} from '../scripts/local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';

const capture=version=>JSON.parse(fs.readFileSync(new URL(`../backups/animations/local-network-renderer-v${version}.json`,import.meta.url)));
const remoteId=0xfffffff8,localId=0xffffffff;

test('concurrent original-client arrival and walking retain server player identities and canonical proxies',async()=>{
 const report=capture(65);assert.equal(report.connected,true);assert.equal(report.failure,undefined);assert.equal(report.sampleFailure,undefined);assert.equal(report.states.at(-1).closed,true);assert.ok(report.paintFrames>6000);
 const remote=report.samples.flatMap(s=>s.server.objects.filter(o=>o.id===remoteId));assert.ok(new Set(remote.map(o=>JSON.stringify(o.position))).size>=7);assert.ok(remote.some(o=>o.animation===1));assert.ok(remote.some(o=>o.animation===0));assert.equal(report.moves.length,2);
 const root='../FullDecomp/NwnRootInstall',rules=await loadNetworkObjectRules(await openLocalModule(root,root+'/data/nwm/Prelude.nwm')),world=new NetworkWorld();let reference,remotePlayer;
 for(const hex of report.wireMessages){const message=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(message);const object=world.registry.get(remoteId);if(object){if(reference)assert.equal(object,reference);else reference=object;}remotePlayer??=[...world.players.values()].find(p=>p.objectId===remoteId);}
 assert.equal(remotePlayer.playerId,0);assert.equal(remotePlayer.character.firstName.text,'Zachario');assert.equal(world.players.size,2);assert.equal(world.controls.get(0),remoteId);assert.equal(world.controls.get(1),localId);assert.equal(world.localObjectId,localId);assert.equal(world.registry.get(remoteId),reference);assert.notEqual(reference,world.registry.get(localId));assert.deepEqual(reference.replicated.position,remote.at(-1).position);
});

test('replacement reconnect and actual hotbar targeting cast on the original player with server-owned spending',()=>{
 const report=capture(66);assert.equal(report.connected,true);assert.equal(report.failure,undefined);assert.equal(report.sampleFailure,undefined);assert.equal(report.states.at(-1).closed,true);assert.ok(report.paintFrames>3000);assert.equal(report.quickbarActions.length,3);assert.ok(report.quickbarActions[1].result.target);assert.equal(report.quickbarActions[2].result.targetId,remoteId);
 const requests=report.quickbarRequests.map(p=>Buffer.from(p.packet,'hex'));assert.equal(requests.length,1);const packet=requests[0];assert.deepEqual([...packet.subarray(0,3)],[112,6,18]);const r=new NativeMessageReader(1);r.setReadMessage(packet.subarray(3),packet.length-3,0xffffffff,1);assert.equal(r.readDword(),100);r.readByte();r.readByte();r.readByte();assert.ok(r.readByte()&1);assert.equal(r.readObjectIdClient(),remoteId);
 const uses=[];for(const s of report.samples){if(!s.server.spellbooks?.[0])continue;const n=Object.values(s.server.spellbooks[0].memorized??{}).flat().filter(v=>v?.spell===100&&v.ready!==0).length;if(uses.at(-1)!==n)uses.push(n);}
 assert.deepEqual(uses,[2,1]);assert.ok(report.samples.some(s=>s.server.casts.some(o=>o.id===localId&&o.cast?.spell===100&&o.cast.target===remoteId)));assert.deepEqual(new Set(report.samples.at(-1).server.players.map(p=>p.objectId)),new Set([localId,remoteId]));
 for(const version of [65,66]){const diagnostics=JSON.parse(fs.readFileSync(new URL(`../backups/animations/local-network-renderer-v${version}-diagnostics.json`,import.meta.url)));assert.deepEqual(diagnostics.filter(e=>e.severity==='error'),[]);}
});
