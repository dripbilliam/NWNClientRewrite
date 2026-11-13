'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {NativeTextEventScope}=require('../tools/native-text-event-scope.cjs');
const {RawCombatEvents}=require('../tools/raw-combat-events.cjs');

async function fixture(){
 const {EntityDisclosureLifetimes}=await import('../../src/network_entity_lifetimes.js');
 const {GameObjectArray}=await import('../../src/game_object_array.js');
 const registry=new GameObjectArray({clientMode:true});
 const world={areaId:7,registry,entityDisclosures:new EntityDisclosureLifetimes()};
 const identities=new RawCombatEvents();
 // The adapter deliberately has no render service, camera, mesh or stats.
 const object={id:0xffffffff,objectType:5,areaId:7,replicationRemoved:false};
 assert.equal(registry.addObjectAtPos(object.id,object).status,0);
 const scope=new NativeTextEventScope(identities);
 const message={kind:'server-speech',major:9,minor:1,channel:1,objectId:object.id,text:{text:'<c\xff\x01\x01>Hello</c>'}};
 return {world,registry,object,identities,scope,message};
}

test('known received speaker is captured before visuals or first raw snapshot; metadata is detached',async()=>{
 const f=await fixture(),before=structuredClone(f.object),original=structuredClone(f.message);
 assert.equal(f.world.entityDisclosures.identities.has(f.object),false);
 const event=f.scope.capture(f.world,f.message,2,3);
 assert.deepEqual(Object.keys(event),['version','serial','connection','generation','areaId','source']);
 assert.deepEqual(event,{version:1,serial:1,connection:3,generation:2,areaId:7,source:{id:0xffffffff,objectType:5,areaId:7,nativeLifetime:1,knownLifetime:1}});
 const row=f.world.entityDisclosures.transportRow(f.object,f.identities.object(f.object));
 assert.equal(row.nativeLifetime,event.source.nativeLifetime);
 assert.equal(row.clientKnownLifetime,event.source.knownLifetime);
 assert.deepEqual(f.object,before);assert.deepEqual(f.message,original);
 event.source.id=12;event.source.knownLifetime=91;
 assert.equal(f.object.id,0xffffffff);assert.equal(f.world.entityDisclosures.token(f.object),1);
 const wire=JSON.parse(JSON.stringify(f.scope.capture(f.world,f.message,2,3)));
 assert.equal(wire.source.id,0xffffffff);assert.equal(wire.source.knownLifetime,1);
 assert.equal(wire.serial,2);
});

test('accepted D/reuse of retained proxy changes disclosure, replacement proxy changes native identity',async()=>{
 const f=await fixture(),first=f.scope.capture(f.world,f.message,2,3);
 f.object.replicationRemoved=true;
 f.world.entityDisclosures.observeAccepted([{action:'delete',id:f.object.id}],f.registry);
 assert.equal(f.scope.capture(f.world,f.message,2,3).source,null);
 f.object.replicationRemoved=false;
 const redisclosed=f.scope.capture(f.world,f.message,2,3);
 assert.equal(redisclosed.source.nativeLifetime,first.source.nativeLifetime);
 assert.notEqual(redisclosed.source.knownLifetime,first.source.knownLifetime);
 const replacement={...f.object};f.registry.delete(replacement.id);assert.equal(f.registry.addObjectAtPos(replacement.id,replacement).status,0);
 const replaced=f.scope.capture(f.world,f.message,2,3);
 assert.notEqual(replaced.source.nativeLifetime,redisclosed.source.nativeLifetime);
 assert.notEqual(replaced.source.knownLifetime,redisclosed.source.knownLifetime);
 assert.equal(first.source.knownLifetime,1);
});

test('no channel policy: actual system/remote identity captured, missing or retired source preserves packet',async()=>{
 const f=await fixture();
 for(const channel of [1,2,3,4,5,6,8,9,10,11,12,14,15,17,18,19,20,22,30]){
  const message={...f.message,channel,speakerName:{text:'Received name'},position:[1,2,3]};
  assert.equal(f.scope.capture(f.world,message,2,3).source.id,f.object.id);
 }
 for(const objectId of [123,0x7f000000,undefined,null,-1,0x100000000]){
  const message={...f.message,objectId},before=structuredClone(message);
  assert.equal(f.scope.capture(f.world,message,2,3).source,null);assert.deepEqual(message,before);
 }
 const withoutObject={kind:'server-speech',channel:5,text:{text:'System received'}};
 assert.equal(f.scope.capture(f.world,withoutObject,2,3).source,null);
 f.object.areaId=8;assert.equal(f.scope.capture(f.world,f.message,2,3).source,null);
 delete f.object.areaId;assert.equal(f.scope.capture(f.world,f.message,2,3).source.areaId,null);
 delete f.object.objectType;assert.equal(f.scope.capture(f.world,f.message,2,3).source.objectType,null);
 delete f.world.areaId;assert.equal(f.scope.capture(f.world,f.message,2,3).areaId,null);
});

test('separate script93/94 source field selected without changing flags/text; item captions/audio untouched',async()=>{
 const f=await fixture();
 for(const type of [93,94]){
  const message={kind:'combat-feedback',major:18,minor:11,type,data:{objects:{0:f.object.id},integers:type===93?{0:-1,1:0}:{0:1},strings:type===94?{0:{text:'Script text'}}:{}},color:''};
  const before=structuredClone(message);assert.equal(f.scope.capture(f.world,message,2,3).source.id,f.object.id);assert.deepEqual(message,before);
 }
 for(const message of [{kind:'combat-feedback',type:92},{kind:'item-text-bubble-override',itemId:f.object.id},{kind:'script-sound',objectId:f.object.id},{kind:'voice-play',objectId:f.object.id}])assert.equal(f.scope.capture(f.world,message,2,3),null);
 assert.equal(f.scope.serial,2);
});

test('queued event cannot match changed connection/area/disclosure after reconnect or visual delay',async()=>{
 const f=await fixture(),queued=f.scope.capture(f.world,f.message,2,3);
 // Pure transport-consumer comparison, not native renderer/queue acceptance.
 const matches=(event,row,generation,connection)=>event.connection===connection&&event.generation===generation&&event.areaId===f.world.areaId&&event.source.id===row.id&&event.source.areaId===row.areaId&&event.source.nativeLifetime===row.nativeLifetime&&event.source.knownLifetime===row.clientKnownLifetime;
 const snapshot=()=>f.world.entityDisclosures.transportRow(f.object,f.identities.object(f.object));
 assert.ok(matches(queued,snapshot(),2,3));
 assert.equal(matches(queued,snapshot(),2,4),false);assert.equal(matches(queued,snapshot(),3,3),false);
 f.world.entityDisclosures.reset();assert.equal(matches(queued,snapshot(),2,3),false);
 f.world.areaId=8;assert.equal(matches(queued,snapshot(),2,3),false);
});

test('strict scopes, serial exhaustion, malformed identity and accessors never create zero or invented identity',async()=>{
 const f=await fixture();
 for(const [generation,connection] of [[-1,3],[2,-1],[2.5,3],[2,Infinity],[2,'3']])assert.throws(()=>f.scope.capture(f.world,f.message,generation,connection),/Invalid native text event scope/);
 assert.equal(f.scope.serial,0);
 const limited=new NativeTextEventScope(f.identities,{maximumSerial:1});limited.capture(f.world,f.message,2,3);assert.throws(()=>limited.capture(f.world,f.message,2,3),/Invalid native text event scope/);
 let getters=0;const getterMessage={kind:'server-speech'};Object.defineProperty(getterMessage,'objectId',{get(){getters++;throw Error('secret');}});
 assert.equal(f.scope.capture(f.world,getterMessage,2,3).source,null);assert.equal(getters,0);
 const getterKind={};Object.defineProperty(getterKind,'kind',{get(){getters++;return 'server-speech';}});assert.equal(f.scope.capture(f.world,getterKind,2,3),null);assert.equal(getters,0);
 f.object.id=1;assert.equal(f.scope.capture(f.world,f.message,2,3).source,null);f.object.id=0xffffffff;
 const noNative=new NativeTextEventScope({identity(){return 0;}});assert.equal(noNative.capture(f.world,f.message,2,3).source,null);
 f.world.entityDisclosures={token(){return null;}};assert.equal(f.scope.capture(f.world,f.message,2,3).source,null);
 assert.throws(()=>new NativeTextEventScope({identity:1}),/Invalid native text event scope/);
});

test('retained original sender packets decode through actual native reader and keep complete speech payload',async()=>{
 const fs=require('node:fs'),path=require('node:path');
 const {decodeServerGameMessage}=await import('../../src/network_game_messages.js');
 const original=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../../backups/animations/native-network-chat-writer-observations.json')));
 const oneLiners=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../../backups/animations/native-network-speech-observations.json')));
 const packets=original.cases.filter(r=>r.case.format===1).flatMap(r=>r.packets).concat(oneLiners.cases.filter(r=>r.case.format===1).map(r=>r.packet));
 assert.equal(original.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 assert.equal(oneLiners.target,original.target);assert.ok(packets.length>=75);
 const f=await fixture();let remote=0,localized=0;
 for(const hex of packets){
  const decoded=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17}}),before=structuredClone(decoded);
  if(decoded.objectId!==undefined&&decoded.objectId!==0x7f000000&&!f.registry.get(decoded.objectId))assert.equal(f.registry.addObjectAtPos(decoded.objectId,{objectType:5,areaId:7,replicationRemoved:false}).status,0);
  const event=f.scope.capture(f.world,decoded,2,3),wire=JSON.parse(JSON.stringify({...decoded,nativeTextEvent:event}));
  assert.ok(event);assert.deepEqual(decoded,before);delete wire.nativeTextEvent;assert.deepEqual(wire,before);
  assert.equal(event.source===null,decoded.objectId===undefined||decoded.objectId===0x7f000000);
  if(decoded.speakerName)remote++;if(decoded.text.strRef!==undefined)localized++;
 }
 assert.ok(remote>0);assert.ok(localized>0);assert.equal(f.scope.serial,packets.length);
});
