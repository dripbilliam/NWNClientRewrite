import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {NativeMessageReader} from '../src/native_message.js';
import {readObjectUpdates} from '../src/network_object_updates.js';
import {applyPlayerState} from '../src/network_player_state_store.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NetworkWorld} from '../src/network_world.js';
import {NetworkMessageAssembler} from '../src/network_messages.js';
import {NetworkMessageInflater} from '../electron/network_message_inflater.mjs';
import {openLocalModule} from '../scripts/local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-player-state-observations.json',import.meta.url)));
function decode(row){const {case:c}=row,bytes=Buffer.from(row.packet,'hex').subarray(3),errors=[],r=new NativeMessageReader(c.format,{diagnose:e=>errors.push(e)});assert.equal(r.setReadMessage(bytes,bytes.length,0xffffffff,1),1);const result=readObjectUpdates(r,{clientBuild:c.build,skillCount:c.skillCount});assert.equal(result.complete,true);assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);assert.deepEqual(errors,[]);assert.equal(result.records.length,1);return result.records[0];}

test('198 original PlayerUpdate executions cover masks, native difference loops and build-dependent layouts',()=>{
 assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.cases.length,198);
 for(const row of fixture.cases){const c=row.case,d=decode(row),s=d.state;assert.equal(d.action,'player-state');assert.equal(d.id,0xffffffff);assert.equal(d.mask,c.mask);
  if(c.mask&1){assert.deepEqual(s.combat,{armorClass:17,field898:1529,field978:95,canLevelUp:c.levelUp});if(c.levelUp){assert.deepEqual(s.levelUp.skills,[-2,-1,0,1,2]);assert.equal(s.levelUp.fieldD4,c.build.revision===34||c.build.revision===36&&c.build.postfix<4?255:123456);assert.equal(s.levelUp.fieldE48,'fixture-a');assert.equal(s.levelUp.fieldE38,'fixture-b');}}
  if(c.mask&128)assert.deepEqual(s.memorizedSlotCounts,[{position:0,levels:[{level:1,count:3}]}]);
  if(c.mask&16){assert.equal(s.knownSpellChanges.length,c.build.revision<35?3:8);assert.deepEqual(s.knownSpellChanges[0],{position:0,removed:[100,101],added:[37,100,0xfffffffe]});}
  if(c.mask&32){const change=s.memorizedSpellChanges[0];assert.equal(s.memorizedSpellChanges.length,c.build.revision<35?3:8);assert.deepEqual(change,c.memorizes?{position:0,removed:[{level:1,index:2}],added:[{spell:37,index:1,level:1,ready:1,domain:1,metamagic:2}]}:{position:0,removed:[],added:[]});}
  if(c.mask&64)assert.deepEqual(s.spontaneousUses,c.memorizes?[]:[{position:0,levels:[{level:1,count:7}]}]);
  if(c.mask&1024)assert.deepEqual(s.effectIcons,{removed:[1,2],added:[{icon:1,state:1},{icon:c.build.revision===37?256:0,state:0},{icon:c.build.revision===37?900:132,state:1}]});
  if(c.mask&4){assert.deepEqual(s.featChanges,[{action:'A',feat:945},{action:'D',feat:100},{action:'B',feat:900},{action:'X',feat:901}]);assert.deepEqual(s.featUses,[{feat:945,uses:4}]);}
  if(c.mask&2048)assert.deepEqual(s.abilities,{base:[9,11,13,15,17,19],current:[10,12,14,16,18,20]});
  if(c.mask&16384)assert.deepEqual(s.specialAbilityChanges,[{action:'S',size:2},{action:'U',index:0,state:1,level:2,spell:37},{action:'U',index:1,state:0,level:9,spell:65535}]);
  if(c.mask&256){
   const type=c.queueType??0;let expected;
   if(c.queue==='D')expected={action:'D',type:4,group:321};
   else if(type===65535)expected={action:'S',type:7,group:123,target:0x80123456};
   else{expected={action:'A',type,group:123};if(type!==0&&type!==2)expected.target=0x80123456;if([0,2,4,12,19].includes(type))expected.position=[1.25,2.5,3.75];if(type===4||type===19)expected.field5A4=0x789abc;}
   assert.deepEqual(s.actionQueueChanges,[expected]);
  }
  if(c.map){
   const expected=c.map==='dense'?{mode:[0,1],bytes:Uint8Array.from([255,255,0,0,0,0,0,0])}:['full','clear','reset-sparse'].includes(c.map)?{mode:[1,0],points:c.map==='reset-sparse'?Array.from({length:4},(_,x)=>({x,y:0})):[]}:{mode:[0,0],points:c.map==='sparse'?[{state:1,x:0,y:0}]:[]};assert.deepEqual(s.automap,expected);
  }
 }
});

test('player spell/feat/icon/ability deltas apply without replacing prior unaffected server state',()=>{
 const row=fixture.cases.find(r=>r.case.format===1&&r.case.build.revision===37&&r.case.mask===0xd5ff&&r.case.memorizes===1),record=decode(row);
 const before={spellbooks:{0:{known:[100,101,999],memorized:{1:[null,null,{spell:102}]},slots:{1:3},usesLeft:{}}},feats:[25,100],bonusFeats:[901],effectIcons:{1:0,2:1,3:1}},snapshot=structuredClone(before),next=applyPlayerState(before,record.state);
 assert.deepEqual(before,snapshot);assert.deepEqual(next.spellbooks[0].known,[999,37,100,0xfffffffe]);assert.deepEqual(next.spellbooks[0].memorized[1],[null,{spell:37,index:1,level:1,ready:1,domain:1,metamagic:2},null]);assert.deepEqual(next.feats,[25,945]);assert.deepEqual(next.bonusFeats,[900]);assert.deepEqual(next.effectIcons,{1:1,3:1,256:0,900:1});assert.equal(next.featUses[945],4);assert.equal(next.specialAbilities[1].spell,65535);
 const world=new NetworkWorld();world.apply({kind:'object-updates',records:[record]});assert.equal(world.localObjectId,0xffffffff);assert.equal(world.registry.get(0xffffffff).playerState.spellbooks[0].known.length,3);
 const beforeWorld=world.snapshot(),old=structuredClone(world.registry.get(0xffffffff));
 assert.throws(()=>world.apply({kind:'object-updates',records:[{...record,state:{memorizedSpellChanges:[{position:0,removed:[],added:[{spell:1,index:99,level:1}]}]}}]}),/slot count/);assert.deepEqual(world.snapshot(),beforeWorld);assert.deepEqual(world.registry.get(0xffffffff),old);
 const shrunk=applyPlayerState(next,{memorizedSlotCounts:[{position:0,levels:[{level:1,count:1}]}],memorizedSpellChanges:[{position:0,removed:[{level:1,index:2}],added:[]}]});assert.equal(shrunk.spellbooks[0].memorized[1].length,1);
});

test('real vanilla server player-state packets fully decode and assemble caster spellbooks',async()=>{
 const report=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-character-v5.json',import.meta.url))),install=new URL('../../FullDecomp/NwnRootInstall',import.meta.url).pathname.replace(/^\/([A-Z]:)/i,'$1'),module=report.transport.resources.resolved.find(r=>r.kind==='nwm'),rules=await loadNetworkObjectRules(await openLocalModule(decodeURI(install),module.resource)),assembler=new NetworkMessageAssembler(),inflater=new NetworkMessageInflater(),world=new NetworkWorld(),messages=[];
 for(const hex of report.transport.applicationFrames)assembler.push(Buffer.from(hex,'hex'));
 try{for(const frame of assembler.drain()){const b=await inflater.decode(frame.bytes),m=decodeServerGameMessage(b,{clientBuild:report.clientBuild,objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});messages.push(m);world.apply(m);}}finally{inflater.close();}
 assert.ok(messages.filter(m=>m.kind==='object-updates').every(m=>m.complete));assert.equal(world.localObjectId,0xffffffff);const p=world.registry.get(world.localObjectId).playerState;
 assert.equal(p.combat.armorClass,17);assert.equal(p.spellbooks[0].known.length,43);assert.equal(Object.values(p.spellbooks[0].memorized).flat().filter(Boolean).length,34);assert.equal(p.spellbooks[0].memorized[1][4].spell,107);assert.equal(p.spellbooks[0].memorized[1][4].ready,1);assert.equal(p.featUses[303],1);assert.deepEqual(p.abilities.current,[10,16,12,19,10,12]);assert.equal(world.controls.get(0),world.localObjectId);
});

test('truncated native I records and unavailable level-up skill schema fail explicitly',()=>{
 const row=fixture.cases.find(r=>r.case.format===1&&r.case.build.revision===37&&r.case.mask===0xd5ff&&r.case.levelUp===1),packet=Buffer.from(row.packet,'hex');packet.set([80,5,1]);
 for(let n=3;n<packet.length;n++)assert.throws(()=>decodeServerGameMessage(packet.subarray(0,n),{clientBuild:row.case.build,objectRules:{skillCount:5}}));
 const missing=decodeServerGameMessage(packet,{clientBuild:row.case.build});assert.equal(missing.complete,false);assert.equal(missing.unhandled.tag,'I');assert.match(missing.unhandled.reason,/skill-count/);
});
