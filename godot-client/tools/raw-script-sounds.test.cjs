const test=require('node:test'),assert=require('node:assert/strict');
const {RawScriptSounds}=require('./raw-script-sounds.cjs'),{RawCombatEvents}=require('./raw-combat-events.cjs');
test('script sound transports immutable decoded identity/pose without audio selection or source mutation',()=>{
 const ids=new RawCombatEvents(),transport=new RawScriptSounds(ids),source={id:0xffffffff,objectType:5,areaId:2,replicated:{position:[1,2,3]},staticState:{position:[4,5,6]},appearance:{appearance:99}},world={areaId:2,registry:new Map([[source.id,source]])},before=structuredClone(source);
 const frame=transport.frame(world,{kind:'script-sound',objectId:source.id,sound:'LOUD_NAME_1234567890'},7,4);
 assert.deepEqual(frame,{kind:'raw-script-sounds',connection:4,generation:7,areaId:2,serial:1,events:[{source:{id:source.id,objectType:5,lifetime:ids.identity(source),replicated:{position:[1,2,3]},staticState:{position:[4,5,6]}},sound:'LOUD_NAME_1234567890'}]});
 assert.deepEqual(source,before);source.replicated.position[0]=9;assert.equal(frame.events[0].source.replicated.position[0],1);
 world.registry.set(source.id,{...source});assert.notEqual(transport.frame(world,{kind:'script-sound',objectId:source.id,sound:'next'},7,4).events[0].source.lifetime,frame.events[0].source.lifetime);
});
test('script sound rejects missing/removed/foreign sources but retains current-area and nonrendered proxies',()=>{
 const t=new RawScriptSounds(new RawCombatEvents()),world={areaId:2,registry:new Map()},m={kind:'script-sound',objectId:1,sound:'sound'};
 assert.equal(t.frame(world,m,1,1),null);
 for(const source of [{id:1,objectType:5,areaId:2,replicationRemoved:true},{id:1,objectType:5,areaId:3}]){world.registry.set(1,source);assert.equal(t.frame(world,m,1,1),null);}
 world.registry.set(1,{id:1,objectType:16,areaId:2,state:{position:[2,3,4]}});assert.equal(t.frame(world,m,1,1).events[0].source.objectType,16);
 world.registry.set(2,{id:2,objectType:4});assert.equal(t.frame(world,{...m,objectId:2},1,1).events[0].source.objectType,4);
 assert.equal(t.frame(world,{...m,kind:'server-speech'},1,1),null);assert.equal(t.frame(world,{...m,kind:'voice-play'},1,1),null);
});
test('original9/7 writer packets preserve raw byte strings through the production decoder and direct-native transport',async()=>{
 const {decodeServerGameMessage}=await import('../../src/network_game_messages.js'),fs=require('node:fs');
 const corpus=JSON.parse(fs.readFileSync(require('node:path').join(__dirname,'../../backups/animations/native-network-audio-observations.json'),'utf8'));
 const t=new RawScriptSounds(new RawCombatEvents());let packets=0;
 for(const row of corpus.cases.filter(r=>r.kind==='wire'&&r.format===1))for(const hex of row.packets){
  const message=decodeServerGameMessage(Buffer.from(hex,'hex')),bytes=Array.from(Buffer.from(row.textHex,'hex'));assert.deepEqual(Array.from(message.soundBytes),bytes);
  const world={areaId:2,registry:new Map([[message.objectId,{id:message.objectId,objectType:5,areaId:2,replicated:{position:[1,2,3]}}]])};
  const event=t.frame(world,message,1,1).events[0];assert.deepEqual(event.soundBytes,bytes);assert.equal(event.sound,undefined);packets++;
 }
 assert.equal(packets,15);
});
