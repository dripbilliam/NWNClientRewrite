import test from 'node:test';
import assert from 'node:assert/strict';
import {receivedScriptFloatingFixture} from '../tools/native-script-floating-received-fixture.mjs';

test('all16 original receiver field traces cross codec and actual Host without mutation or provenance inflation',()=>{
 const fixture=receivedScriptFloatingFixture();assert.equal(fixture.messages.length,16);assert.equal(fixture.packets.length,16);assert.equal(fixture.provenance.nativeWriterCapture,false);assert.equal(fixture.provenance.originalReceiverTraces,16);
 for(let i=0;i<16;i++){
  const frame=fixture.messages[i],packet=fixture.packets[i],message=frame.message,meta=message.nativeTextEvent;
  assert.equal(frame.kind,'ui-protocol');assert.equal(frame.generation,2);assert.equal(message.type,packet.type);assert.equal(message.kind,'combat-feedback');
  assert.equal(meta.connection,3);assert.equal(meta.generation,2);assert.equal(meta.areaId,7);assert.equal(meta.serial,i+1);assert.equal(Object.hasOwn(meta,'context'),false);
  assert.deepEqual(meta.source,{id:fixture.target.id,objectType:5,areaId:7,nativeLifetime:fixture.target.nativeLifetime,knownLifetime:fixture.target.clientKnownLifetime});
  assert.equal(Object.hasOwn(fixture.target,'model'),false);assert.equal(Object.hasOwn(fixture.target,'visual'),false);
  assert.equal(message.data.objects['0'],0x80000000);assert.equal(packet.major,18);assert.equal(packet.minor,11);
  const echo=message.data.integers[message.type===93?'1':'0'];assert.equal(echo,packet.buildOk?packet.mode&1:1);
  if(message.type===93)assert.equal(message.data.integers['0'],11);else assert.equal(message.data.strings['0'].text,'S11');
 }
});
test('missing/removed/out-of-area targets retain decoded log packet with explicit null source, never player fallback',()=>{
 const base=receivedScriptFloatingFixture();
 for(const targetState of ['missing','removed','other-area']){
  const fixture=receivedScriptFloatingFixture({targetState});
  for(let i=0;i<16;i++){const message=structuredClone(fixture.messages[i].message),original=structuredClone(base.messages[i].message);assert.equal(message.nativeTextEvent.source,null);delete message.nativeTextEvent;delete original.nativeTextEvent;assert.deepEqual(message,original);}
 }
});
test('transport keeps actual noncreature/unknown-area identity; Godot owns eligibility and eventual membership',()=>{
 for(const [targetState,objectType,areaId]of [['noncreature',9,7],['unknown-area',5,null]]){
  const fixture=receivedScriptFloatingFixture({targetState});for(const frame of fixture.messages){assert.equal(frame.message.nativeTextEvent.source.objectType,objectType);assert.equal(frame.message.nativeTextEvent.source.areaId,areaId);}
 }
});
test('separate fixture scopes are detached and cannot mutate canonical/output metadata in later captures',()=>{
 const first=receivedScriptFloatingFixture(),second=receivedScriptFloatingFixture();first.messages[0].message.nativeTextEvent.source.nativeLifetime=999;first.target.id=123;first.messages[0].message.data.integers['0']=999;
 assert.equal(second.messages[0].message.nativeTextEvent.source.id,0x80000000);assert.notEqual(second.messages[0].message.nativeTextEvent.source.nativeLifetime,999);assert.equal(second.messages[0].message.data.integers['0'],11);assert.equal(first.messages[1].message.nativeTextEvent.source.id,0x80000000);
});
test('accepted D/re-A produces actual monotonic known-lifetime witnesses and detached prior raw publication',()=>{
 const fixture=receivedScriptFloatingFixture({disclosure:'redisclosed'});assert.equal(fixture.disclosure,'redisclosed');assert.equal(fixture.previousTarget.id,fixture.target.id);assert.equal(fixture.previousTarget.nativeLifetime,fixture.target.nativeLifetime);assert.ok(fixture.previousTarget.clientKnownLifetime<fixture.target.clientKnownLifetime);
 assert.equal(fixture.previousMessages.length,1);assert.equal(fixture.previousMessages[0].message.nativeTextEvent.source.knownLifetime,fixture.previousTarget.clientKnownLifetime);assert.ok(fixture.previousMessages[0].message.nativeTextEvent.serial<fixture.messages[0].message.nativeTextEvent.serial);
 for(const frame of fixture.messages){assert.equal(frame.message.nativeTextEvent.source.knownLifetime,fixture.target.clientKnownLifetime);assert.notEqual(frame.message.nativeTextEvent.source.knownLifetime,fixture.previousTarget.clientKnownLifetime);}
 const saved=fixture.target.clientKnownLifetime;fixture.previousTarget.clientKnownLifetime=999;assert.equal(fixture.target.clientKnownLifetime,saved);assert.throws(()=>receivedScriptFloatingFixture({targetState:'missing',disclosure:'redisclosed'}));
});
test('unknown active world area stays null on actual Host metadata and never borrows canonical target area',()=>{
 const fixture=receivedScriptFloatingFixture({worldAreaAvailable:false});assert.equal(fixture.scope.areaId,null);assert.equal(fixture.target.areaId,7);for(const frame of fixture.messages){assert.equal(frame.message.nativeTextEvent.areaId,null);assert.equal(frame.message.nativeTextEvent.source.areaId,7);}assert.throws(()=>receivedScriptFloatingFixture({worldAreaAvailable:0}));
});
