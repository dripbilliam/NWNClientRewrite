'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {NativeTextEventScope}=require('../tools/native-text-event-scope.cjs');
const {RawCombatEvents}=require('../tools/raw-combat-events.cjs');
async function fixture(){
 const {GameObjectArray}=await import('../../src/game_object_array.js');
 const {EntityDisclosureLifetimes}=await import('../../src/network_entity_lifetimes.js');
 const world={areaId:7,registry:new GameObjectArray({clientMode:true}),entityDisclosures:new EntityDisclosureLifetimes()},identities=new RawCombatEvents();
 const speaker={objectType:5,areaId:7,replicationRemoved:false},context={objectType:5,areaId:7,replicationRemoved:false};
 assert.equal(world.registry.addObjectAtPos(0x80000013,speaker).status,0);assert.equal(world.registry.addObjectAtPos(0xffffffff,context).status,0);
 return {world,identities,speaker,context,scope:new NativeTextEventScope(identities)};
}
const message=f=>({kind:'server-speech',channel:11,objectId:f.speaker.id,contextId:f.context.id,text:{strRef:57779},sound:'',soundFlag:0,soundObjectId:0xffffffff});

test('channel11 captures distinct current context with shared snapshot owners; same-ID context is detached',async()=>{
 const f=await fixture(),packet=message(f),before=structuredClone(packet),event=f.scope.capture(f.world,packet,2,3);
 assert.equal(event.source.id,f.speaker.id);assert.equal(event.context.id,f.context.id);assert.notEqual(event.source.nativeLifetime,event.context.nativeLifetime);assert.notEqual(event.source.knownLifetime,event.context.knownLifetime);
 const row=f.world.entityDisclosures.transportRow(f.context,f.identities.object(f.context));
 assert.deepEqual(event.context,{id:row.id,objectType:row.objectType,areaId:row.areaId,nativeLifetime:row.nativeLifetime,knownLifetime:row.clientKnownLifetime});assert.deepEqual(packet,before);
 const same=f.scope.capture(f.world,{...packet,contextId:f.speaker.id},2,3);assert.deepEqual(same.context,same.source);assert.notEqual(same.context,same.source);same.context.id=17;assert.equal(same.source.id,f.speaker.id);
 for(const channel of [1,8,9,10,15])assert.equal(Object.hasOwn(f.scope.capture(f.world,{...packet,channel},2,3),'context'),false);
});

test('delayed context lookup cannot match a retained-proxy redisclosure or replacement; unavailable never borrows speaker',async()=>{
 const f=await fixture(),packet=message(f),first=f.scope.capture(f.world,packet,2,3),match=(witness,row)=>witness!==null&&witness.id===row.id&&witness.nativeLifetime===row.nativeLifetime&&witness.knownLifetime===row.clientKnownLifetime;
 const raw=()=>f.world.entityDisclosures.transportRow(f.context,f.identities.object(f.context));assert.ok(match(first.context,raw()));
 f.context.replicationRemoved=true;f.world.entityDisclosures.observeAccepted([{action:'delete',id:f.context.id}],f.world.registry);assert.equal(f.scope.capture(f.world,packet,2,3).context,null);
 f.context.replicationRemoved=false;const redisclosed=f.scope.capture(f.world,packet,2,3);assert.equal(redisclosed.context.nativeLifetime,first.context.nativeLifetime);assert.notEqual(redisclosed.context.knownLifetime,first.context.knownLifetime);assert.equal(match(first.context,raw()),false);assert.deepEqual(redisclosed.source,first.source);
 const replaced={...f.context};f.world.registry.delete(replaced.id);assert.equal(f.world.registry.addObjectAtPos(replaced.id,replaced).status,0);const replacement=f.scope.capture(f.world,packet,2,3);assert.notEqual(replacement.context.nativeLifetime,redisclosed.context.nativeLifetime);
 for(const contextId of [null,undefined,-1,0x7f000000,99]){const event=f.scope.capture(f.world,{...packet,contextId},2,3);assert.ok(Object.hasOwn(event,'context'));assert.equal(event.context,null);assert.deepEqual(event.source,first.source);}
 replaced.areaId=8;assert.equal(f.scope.capture(f.world,packet,2,3).context,null);delete replaced.areaId;assert.equal(f.scope.capture(f.world,packet,2,3).context.areaId,null);
});

test('actual retained channel11 packet gains context in bounded current Host dispatch without modifying log payload',async()=>{
 const f=await fixture(),{decodeServerGameMessage}=await import('../../src/network_game_messages.js');
 const original=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../../backups/animations/native-network-speech-observations.json'))),native=original.cases.find(row=>row.case.format===1&&!row.case.oneLiner);
 const packet=decodeServerGameMessage(Buffer.from(native.packet,'hex'),{clientBuild:{number:8193,revision:37,postfix:17}});assert.equal(packet.channel,11);assert.equal(packet.contextId,f.context.id);const before=structuredClone(packet);
 const source=fs.readFileSync(path.resolve(__dirname,'../tools/native-session-host.cjs'),'utf8'),first='if(current!==session||connection!==lobby.connection||ending)return;',last="if(message.kind==='object-updates'){const frame=rawCombat.frame",start=source.indexOf(first),end=source.indexOf(last,start);assert.ok(start>=0&&end>start);
 const dispatch=new Function('current','session','connection','lobby','ending','message','areaGeneration','nativeTextEvents','rawTileVisibility','rawCreatureVisibilityPermission','rawVoice','rawScriptSounds','rawVisual','guiPanelEventForHost','send','report',source.slice(start,end)),session={world:f.world},empty={frame(){return null;}},sent=[],report={};
 dispatch(session,session,3,{connection:3},false,packet,2,f.scope,{frames:()=>[]},{frames:()=>[]},empty,empty,empty,()=>null,row=>sent.push(row),report);
 assert.equal(sent.length,1);assert.equal(sent[0].message.nativeTextEvent.context.id,f.context.id);const wire=JSON.parse(JSON.stringify(sent[0].message));delete wire.nativeTextEvent;assert.deepEqual(wire,before);assert.deepEqual(packet,before);assert.deepEqual(report,{});
});
