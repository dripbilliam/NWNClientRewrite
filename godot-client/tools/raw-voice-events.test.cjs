const test=require('node:test'),assert=require('node:assert/strict');
const {RawVoiceEvents}=require('./raw-voice-events.cjs'),{RawCombatEvents}=require('./raw-combat-events.cjs');
test('voice transport preserves canonical identity/generation and masks the original BYTE/WORD without asset work',()=>{
 const identities=new RawCombatEvents(),voices=new RawVoiceEvents(identities),object={id:0xffffffff,objectType:5,areaId:0x80000001,appearance:{field8A0:65537}},world={areaId:object.areaId,registry:new Map([[object.id,object]])},message={kind:'voice-play',objectId:object.id,voiceCode:0x1234};
 const before=structuredClone(object),frame=voices.frame(world,message,9,3);
 assert.deepEqual(frame,{kind:'raw-voice-events',connection:3,generation:9,areaId:0x80000001,serial:1,events:[{objectId:0xffffffff,voiceCode:0x34,lifetime:identities.object(object).nativeLifetime,soundsetId:1}]});assert.deepEqual(object,before);
 object.appearance.field8A0=7;assert.equal(frame.events[0].soundsetId,1);assert.equal(voices.frame(world,message,9,3).events[0].soundsetId,7);
 world.registry.set(object.id,{...object});assert.notEqual(voices.frame(world,message,9,3).events[0].lifetime,frame.events[0].lifetime);
});
test('voice transport rejects absent/removed/foreign-area/non-creature sources and leaves other audio kinds separate',()=>{
 const voices=new RawVoiceEvents(new RawCombatEvents()),object={id:1,objectType:5,areaId:2},world={areaId:2,registry:new Map([[1,object]])},message={kind:'voice-play',objectId:1,voiceCode:255};
 assert.equal(voices.frame(world,{...message,objectId:9},1,1),null);
 for(const patch of [{replicationRemoved:true},{areaId:3},{objectType:9}]){world.registry.set(1,{...object,...patch});assert.equal(voices.frame(world,message,1,1),null);}
 world.registry.set(1,object);for(const kind of ['quick-chat','script-sound','unsupported'])assert.equal(voices.frame(world,{...message,kind},1,1),null);
 assert.equal(voices.frame(world,message,1,1).events[0].soundsetId,65535);
});
