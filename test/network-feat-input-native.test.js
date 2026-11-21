import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {featUseRequest,modeChangeRequest,networkFeatUses} from '../src/network_feat_input.js';
import {NetworkSpellTargeting} from '../src/network_spell_targeting.js';
import {NetworkWorld} from '../src/network_world.js';
import {parse2da} from '../src/area.js';
import {networkFamiliar} from '../src/network_associates.js';
import {openLocalModule} from '../scripts/local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';

test('1710 native feat/server and mode sender cases match WORDs, raw IDs, object/location routing and mode5 target encoding',()=>{
 const f=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-feat-request-observations.json',import.meta.url)));assert.equal(f.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(f.cases.length,1710);
 for(const row of f.cases){const c=row.case;if(c.format!==1)continue;const request=()=>c.kind==='mode'?modeChangeRequest({modeId:c.mode,targetId:c.targetId}):featUseRequest({...c,position:c.point});if(!row.packet){assert.throws(request);continue;}
  const actual=request(),native=Buffer.from(row.packet,'hex'),used=native.at(-1)>>>5,mask=255<<(8-used)&255;assert.equal(actual.length,native.length);assert.deepEqual(Buffer.from(actual.subarray(0,-1)),native.subarray(0,-1),JSON.stringify(c));assert.equal(actual.at(-1)&mask,native.at(-1)&mask);
  const use=row.calls.find(v=>v.kind==='feat');if(use){assert.equal(use.featId,c.featId);assert.equal(use.auxiliary,c.auxiliary);assert.equal(use.areaId,7);assert.equal(use.targetId,c.targetId===0x7f000000?c.targetId:(c.targetId&0x7fffffff)>>>0);assert.deepEqual(use.position,c.targetId===0x7f000000?c.point.map(Math.fround):[0,0,0]);}
 }
 for(const flag of ['noActor','blocked','noArea'])assert.ok(f.cases.filter(r=>r.case[flag]).every(r=>!r.calls.some(v=>v.kind==='feat')));
 for(const change of [{featId:65536},{auxiliary:-1},{targetId:-1},{position:[0,0,NaN]},{position:null}])assert.throws(()=>featUseRequest({featId:303,targetId:0x7f000000,position:[0,0,0],...change}));
 for(const change of [{modeId:-1},{modeId:256},{modeId:5,targetId:-1}])assert.throws(()=>modeChangeRequest(change));
});

test('real vanilla feat cast spawns a canonical familiar and possession transfers authority to its replicated innate pool',async()=>{
 const root='../FullDecomp/NwnRootInstall',rules=await loadNetworkObjectRules(await openLocalModule(root,root+'/data/nwm/Prelude.nwm'));
 for(const version of [57,58]){const r=JSON.parse(fs.readFileSync(new URL(`../backups/animations/local-network-renderer-v${version}.json`,import.meta.url))),d=JSON.parse(fs.readFileSync(new URL(`../backups/animations/local-network-renderer-v${version}-diagnostics.json`,import.meta.url))),world=new NetworkWorld(),uses=[];assert.equal(r.failure,undefined);assert.equal(r.sampleFailure,undefined);assert.equal(r.renderer.state.phase,'playing');assert.equal(r.states.at(-1).closed,true);assert.ok(r.paintFrames>1500);assert.deepEqual(d.filter(e=>e.severity==='error'),[]);
  for(const hex of r.wireMessages){const m=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(m);const count=world.registry.get(0xffffffff)?.playerState?.featUses?.[303];if(count!==undefined&&uses.at(-1)!==count)uses.push(count);}
  assert.deepEqual(uses,[1,0]);const pc=world.registry.get(0xffffffff),familiar=networkFamiliar(world,pc);assert.ok(familiar);assert.notEqual(familiar.id,pc.id);assert.equal(familiar.replicated.master,pc.id);assert.equal(familiar.replicated.field908,3);assert.equal(pc.replicated.stats.racialType,1);assert.equal(familiar.replicated.stats.racialType,7);
  assert.equal(r.quickbarRequests.filter(p=>p.packet.startsWith('700606')).length,1);if(version===58){assert.equal(r.quickbarRequests.filter(p=>p.packet==='700613').length,1);assert.equal(world.localObjectId,familiar.id);assert.equal(world.controls.get(0),familiar.id);assert.equal(familiar.playerState.specialAbilities.length,60);assert.equal(familiar.playerState.specialAbilities.filter(a=>a?.spell===710&&a.state!==0).length,24);}
 }
});

test('native associate update links only existing creature masters, preserves canonical IDs and rolls back a rejected batch',()=>{
 const w=new NetworkWorld(),master={id:0xffffffff,objectType:5,areaId:1,replicated:{}},pet={id:0x80000002,objectType:5,areaId:1,replicated:{}};w.registry.addObjectAtPos(master.id,master);w.registry.addObjectAtPos(pet.id,pet);
 const update=state=>({action:'update',objectType:5,id:pet.id,state});w.applyObjectUpdates([update({master:master.id,field908:3,field910:0,field914:0})]);assert.equal(master.familiarId,pet.id);assert.equal(networkFamiliar(w,master),pet);assert.equal(pet.familiarId,0x7f000000);
 const before=structuredClone(master);assert.throws(()=>w.applyObjectUpdates([update({master:master.id,field908:2,field910:0,field914:0}),{action:'create',id:master.id,objectType:10,state:{}}]),/Conflicting/);assert.deepEqual(master,before);
 w.applyObjectUpdates([update({master:0x80000003,field908:3,field910:0,field914:0})]);assert.equal(w.registry.get(0x80000003),undefined);assert.equal(master.familiarId,pet.id);pet.replicationRemoved=true;assert.equal(networkFamiliar(w,master),null);
});

test('feat targeter distinguishes native self, mode, radial and manual masks and preserves authoritative pools',async()=>{
 const w=new NetworkWorld(),actor={id:0xffffffff,objectType:5,areaId:0x80000001,replicated:{position:[1,2,3]},playerState:{feats:[0,1,2,28],featUses:{0:1}}};w.localObjectId=actor.id;w.areaId=actor.areaId;w.registry.addObjectAtPos(actor.id,actor);const before=structuredClone(actor),sent=[],feat=parse2da('2DA V2.0\n\nFEAT UsesPerDay TargetSelf SpellId\n0 1 1 1 ****\n1 2 0 0 ****\n2 3 0 0 0\n'+Array.from({length:26},(_,i)=>`${i+3} ${i+4} 0 0 ****`).join('\n')),spells=parse2da('2DA V2.0\n\nName TargetType Master FeatID\n0 1 1 0 0\n');let generation=1;
 const t=new NetworkSpellTargeting({world:()=>w,tables:()=>({feat,spells}),context:()=>({generation}),submit:async r=>sent.push(r)});
 assert.equal(networkFeatUses(actor,{feat},0),1);assert.equal(networkFeatUses(actor,{feat},1),100);assert.equal(networkFeatUses(actor,{feat},3),0);
 await t.begin({type:4,intParam:0});assert.deepEqual(sent[0],{kind:'feat',featId:0,auxiliary:0,targetId:actor.id,position:null});assert.equal(t.active,false);
 await t.begin({type:4,intParam:28});assert.deepEqual(sent[1],{kind:'mode',modeId:3});
 await t.begin({type:4,intParam:2});assert.equal(t.active,true);await t.select({id:123,objectType:5},[4,5,6]);assert.equal(sent.at(-1).targetId,123,'native feat targeter accepts either creature when either creature bit is set');
 await t.begin({type:4,intParam:1});await assert.rejects(t.select(null,[1,2,3]),/not valid/);generation++;await assert.rejects(t.select(actor,[1,2,3]),/old area/);
 await t.radialFeat({featId:1,auxiliary:99},actor,[1,2,3]);assert.equal(t.active,true);assert.equal(t.pending.request.auxiliary,0);t.reset();
 await t.radialFeat({featId:1,auxiliary:65001},{id:123,objectType:5},[4,5,6]);assert.equal(sent.at(-1).auxiliary,65001);assert.deepEqual(actor,before);
 await t.begin({type:4,intParam:1});w.localObjectId=123;await assert.rejects(t.select(actor,[1,2,3]),/controlled creature/);assert.equal(t.active,false);
});

test('real server-issued innate wheel/hotbar casts spend only server records and render static projectiles through impact/cleanup',()=>{
 const r=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v60.json',import.meta.url))),d=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v60-diagnostics.json',import.meta.url))),last=r.samples.at(-1),counts=[];assert.equal(r.failure,undefined);assert.equal(r.sampleFailure,undefined);assert.equal(r.quickbarActions.length,15);assert.equal(r.states.at(-1).closed,true);assert.ok(r.paintFrames>3000);assert.deepEqual(d.filter(e=>e.severity==='error'||/projectile-(receiver|update|model)-failed/.test(e.code)),[]);
 for(const s of r.samples){const pool=s.server.innateAbilities;if(!pool?.length)continue;const n=pool.filter(a=>a?.spell===710&&a.state!==0).length;if(counts.at(-1)!==n)counts.push(n);}assert.deepEqual(counts,[24,23,22]);assert.equal(r.quickbarRequests.filter(p=>p.packet.startsWith('700623')).length,2);assert.equal(last.quickbar.buttons[10].type,44);assert.equal(last.quickbar.buttons[10].intParam,710);
 for(const field of ['received','spawned','loaded','impacts','destroyed'])assert.equal(last.projectiles[field],2);assert.equal(last.projectiles.failed,0);assert.deepEqual(last.projectiles.active,[]);assert.deepEqual(last.projectiles.casts.active,[]);assert.equal(last.projectiles.events.filter(e=>e.kind==='impactAttach'&&e.attached).length,2);
 const events=last.combat.events.filter(e=>e.objectId===last.server.controlledId);assert.equal(events.filter(e=>e.clip==='ccastout').length,2);assert.equal(events.filter(e=>e.clip==='ccastoutlp').length,2);assert.ok(r.samples.some(s=>s.scene?.objects.some(o=>o.id===last.server.controlledId&&o.clip==='cconjure1')));
});

test('real feat shortcut assignment and F-key activation consume one server use and disable a spent input',()=>{
 const r=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v61.json',import.meta.url))),d=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v61-diagnostics.json',import.meta.url))),counts=[];assert.equal(r.failure,undefined);assert.equal(r.sampleFailure,undefined);assert.equal(r.quickbarActions.length,6);assert.ok(r.paintFrames>1000);assert.equal(r.states.at(-1).closed,true);assert.deepEqual(d.filter(e=>e.severity==='error'),[]);
 for(const s of r.samples){const n=s.server.featUses?.[303];if(n!==undefined&&counts.at(-1)!==n)counts.push(n);}assert.deepEqual(counts,[1,0]);assert.equal(r.quickbarRequests.filter(p=>p.packet.startsWith('701e02')).length,1);assert.equal(r.quickbarRequests.filter(p=>p.packet.startsWith('700606')).length,1);assert.equal(r.samples.at(-1).quickbar.buttons[10].type,4);assert.equal(r.samples.at(-1).quickbar.buttons[10].intParam,303);
});
