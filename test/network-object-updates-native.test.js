import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {NativeMessageReader} from '../src/native_message.js';
import {readObjectUpdates} from '../src/network_object_updates.js';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {decodeServerGameMessage,clientAreaReadyRequest} from '../src/network_game_messages.js';
import {NetworkWorld} from '../src/network_world.js';
import {NetworkMessageAssembler} from '../src/network_messages.js';
import {NetworkMessageInflater} from '../electron/network_message_inflater.mjs';
import {openLocalModule} from '../scripts/local-module.mjs';
const load=name=>JSON.parse(fs.readFileSync(new URL(`../backups/animations/${name}.json`,import.meta.url)));
const build={number:8193,revision:37,postfix:17},target='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
function reader(packet,format){const errors=[],r=new NativeMessageReader(format,{diagnose:e=>errors.push(e)}),b=Buffer.from(packet,'hex').subarray(3);assert.equal(r.setReadMessage(b,b.length,0xffffffff,1),1);return{r,errors};}
async function replay(version){
 const report=load(`local-network-character-v${version}`),module=report.transport.resources.resolved.find(r=>r.kind==='nwm'),install=new URL('../../FullDecomp/NwnRootInstall',import.meta.url).pathname.replace(/^\/([A-Z]:)/i,'$1');
 const rules=await loadNetworkObjectRules(await openLocalModule(decodeURI(install),module.resource)),a=new NetworkMessageAssembler(),inflater=new NetworkMessageInflater(),world=new NetworkWorld(),decoded=[],packets=[];
 for(const hex of report.transport.applicationFrames)a.push(Buffer.from(hex,'hex'));
 try{for(const m of a.drain()){const b=await inflater.decode(m.bytes),d=decodeServerGameMessage(b,{clientBuild:report.clientBuild,objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(d);decoded.push(d);packets.push(b);}}finally{inflater.close();}
 return{report,rules,world,decoded,packets};
}

test('160 unchanged native CHAR/SHORT writer-reader executions preserve signed ABI and negative-zero',()=>{
 const fixture=load('native-network-signed-scalars-observations');assert.equal(fixture.target,target);assert.equal(fixture.cases.length,160);
 for(const c of fixture.cases){const {r,errors}=reader(c.packet,c.format);assert.equal(r[c.kind==='char'?'readChar':'readShort'](c.bits),c.read,JSON.stringify(c));assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);assert.deepEqual(errors,[]);}
});

test('48 original UpdateObject executions decode exactly like native scalar/range readers',()=>{
 const fixture=load('native-network-object-delta-observations');assert.equal(fixture.target,target);assert.equal(fixture.cases.length,48);
 for(const c of fixture.cases){const {r,errors}=reader(c.packet,c.format),d=readObjectUpdates(r,{clientBuild:build});assert.equal(d.complete,true);assert.equal(d.records.length,1);const record=d.records[0];assert.equal(record.action,'update');assert.equal(record.id,0x80123456);assert.equal(record.objectType,9);assert.equal(record.mask,c.mask);
  const observed={...record.state};if(observed.orientation)observed.orientation=observed.orientation.vector;assert.deepEqual(observed,c.observed);assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);assert.deepEqual(errors,[]);
 }
});

test('real server replication imports canonical player, NPC, door, placeable, equipment and FX changes',async()=>{
 const {report,world,decoded}=await replay(5);assert.deepEqual([...clientAreaReadyRequest()],[112,4,3]);assert.deepEqual(report.transport.areaReadyRequests,[0x80000001]);assert.equal(report.disconnectRequested,true);
 assert.equal(world.registry.objects.size,33);assert.equal(world.controls.get(0),0xffffffff);assert.equal(world.players.get(0).character.id,0xffffffff);
 const pc=world.registry.get(0xffffffff);assert.ok(pc);assert.equal(pc.objectType,5);assert.deepEqual(pc.replicated.position.slice(0,2),[6,3]);assert.equal(pc.appearance.appearance,1);assert.equal(pc.replicated.stats.classes[0].id,10);assert.equal(world.registry.get(0x7fffffff),undefined);
 const npc=world.registry.get(0x80000013);assert.equal(npc.appearance.bodyParts.length,19);assert.equal(npc.appearance.equipment.length,2);assert.equal(npc.replicated.stats.classes[0].id,4);
 for(const e of npc.appearance.equipment)assert.equal(world.registry.get(e.id).objectType,6);
 assert.equal(world.registry.get(0x80000002).objectType,10);assert.equal(world.registry.get(0x80000010).objectType,9);
 const messages=decoded.filter(d=>d.kind==='object-updates');assert.equal(messages.filter(d=>d.complete).length,5);assert.ok(messages.some(d=>d.records.some(r=>r.id===0xffffffff&&r.action==='create')));
 assert.deepEqual(messages.filter(d=>!d.complete),[]);assert.ok(messages.some(d=>d.records.some(r=>r.state?.visualEffects)));
});

test('fully known real records reject every truncation and preserve stable proxies across updates',async()=>{
 const {rules,world,decoded,packets}=await replay(4),index=decoded.findIndex(d=>d.kind==='object-updates'&&d.complete),packet=packets[index];assert.ok(packet);
 for(let size=3;size<packet.length;size++)assert.throws(()=>decodeServerGameMessage(packet.subarray(0,size),{clientBuild:build,objectRules:rules}),`size ${size}`);
 const npc=world.registry.get(0x80000013);world.apply({kind:'object-updates',records:[{action:'appearance',objectType:5,id:npc.id,state:{bodyParts:[{index:0,value:123}]}}]});assert.equal(world.registry.get(npc.id),npc);assert.equal(npc.appearance.bodyParts.length,19);assert.equal(npc.appearance.bodyParts[0].value,123);
 const before=structuredClone(npc),objects=world.registry.objects.size;
 assert.throws(()=>world.apply({kind:'object-updates',records:[{action:'update',objectType:5,id:npc.id,state:{animation:321}},{action:'create',objectType:10,id:npc.id,state:{}}]}),/Conflicting/);assert.deepEqual(npc,before);assert.equal(world.registry.objects.size,objects);
});

test('module rule tables determine wire shape including native legacy defaults and exact beam types',async()=>{
 const encoder=new TextEncoder(),sources={baseitems:'2DA V2.0\n\nModelType\n0 2',classes:'2DA V2.0\n\nPickSchool PickDomains\n'+Array.from({length:11},(_,i)=>`${i} ${i===0?'1 1':'**** ****'}`).join('\n'),visualeffects:'2DA V2.0\n\nType_FD\n0 B\n1 P\n2 BP\n3 b\n4 ****',skills:'2DA V2.0\n\nName\n0 1'};
 sources.spells='2DA V2.0\n\nTargetType\n0 9\n1 65535';
 sources.feat='2DA V2.0\n\nFeat\n0 1\n1 ****';
 const metadata=await loadNetworkObjectRules({getResource:async name=>encoder.encode(sources[name])});assert.deepEqual(metadata.featInputInfo(0),{});for(const id of [-1,1,65536])assert.equal(metadata.featInputInfo(id),null);
 const rules=await loadNetworkObjectRules({getResource:async name=>encoder.encode(sources[name])});assert.equal(rules.baseItemModelType(0),2);assert.deepEqual(rules.classInfo(0),{pickSchool:true,pickDomains:true});assert.deepEqual(rules.classInfo(1),{pickSchool:false,pickDomains:false});assert.deepEqual(rules.classInfo(2),{pickSchool:false,pickDomains:true});assert.deepEqual(rules.classInfo(10),{pickSchool:true,pickDomains:false});assert.equal(rules.classInfo(99),null);assert.deepEqual([0,1,2,3,4].map(rules.isBeam),[true,true,false,false,false]);assert.deepEqual(rules.spellInputInfo(0),{targetType:9});assert.deepEqual(rules.spellInputInfo(1),{targetType:65535});assert.equal(rules.spellInputInfo(-1),null);
});
