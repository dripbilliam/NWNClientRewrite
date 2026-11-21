import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {GameObjectArray} from '../../src/game_object_array.js';
import {EntityDisclosureLifetimes} from '../../src/network_entity_lifetimes.js';
import {actorNameFixture} from '../tools/native-actor-name-fixture.mjs';
const require=createRequire(import.meta.url),{NativeTextEventScope,byteProjection}=require('../tools/native-text-event-scope.cjs'),{RawCombatEvents}=require('../tools/raw-combat-events.cjs');
function fixture(){
 const registry=new GameObjectArray({clientMode:true}),names=actorNameFixture();
 const row={objectType:5,areaId:7,appearance:{name:{text:'P actor name'}},replicated:{name:{text:'U roster label'},stats:{race:1,racialType:2,fieldD20:2,fieldD28:'Moon elf',fieldE58:'Deity',fieldDE4:85,fieldDE6:15,classes:[{id:3,level:2},{id:4,level:20}]}},inventory:{large:'excluded'}};
 assert.equal(registry.addObjectAtPos(names.id,row).status,0);
 const world={registry,areaId:7,entityDisclosures:new EntityDisclosureLifetimes(),time:{year:1372,month:11,day:7,hour:12,dawn:6,dusk:18},players:new Map([[123,{name:'Received player'}]]),playerRosterKnown:true,nativeActorNameTransport:()=>names.cases.literal,nativeActorNameHistory:()=>({version:1,complete:true})};
 const scope=new NativeTextEventScope(new RawCombatEvents()),message={kind:'server-speech',channel:11,objectId:names.id,contextId:names.id,text:{text:'<FullName>/<Race>/<GameYear>'}};
 return {world,row,scope,message,names};
}
test('dispatch freezes source-backed token fields, module time and roster before coalesced snapshots',()=>{
 const f=fixture(),before=structuredClone(f.message),event=f.scope.capture(f.world,f.message,2,3);
 assert.deepEqual(event.nativeWorld,{native160:1372,native164:11,native16c:12,native17c:6,native17d:18});
 assert.equal(event.nativePlayersComplete,true);assert.deepEqual(event.nativePlayers,{123:{known:true,present:true,name:{bytes:[...Buffer.from('Received player')]}}});
 assert.deepEqual(event.contextData.replicated.stats.classes,[{id:3,level:2}]);assert.equal(Object.hasOwn(event.contextData,'inventory'),false);
 assert.deepEqual(event.contextActorName,{version:1,historyComplete:true,state:f.names.cases.literal});
 assert.notEqual(event.contextActorName.state,event.actorName.state);assert.equal(event.contextData.clientKnownLifetime,event.context.knownLifetime);
 f.row.replicated.stats.fieldD28='Future';f.row.replicated.stats.classes[0].level=99;f.world.time.year=9999;f.world.players.get(123).name='Future';f.names.cases.literal.override.text='Mutated';
 assert.equal(Buffer.from(event.contextData.replicated.stats.fieldD28.bytes).toString(),'Moon elf');assert.equal(event.contextData.replicated.stats.classes[0].level,2);assert.equal(event.nativeWorld.native160,1372);assert.equal(Buffer.from(event.nativePlayers[123].name.bytes).toString(),'Received player');assert.equal(event.contextActorName.state.override.text,'');
 assert.deepEqual(f.message,before);
});
test('undisclosed clock/player state never acquires defaults or a guessed native C0',()=>{
 const f=fixture();f.world.time={year:'1372',hour:256,month:null,dawn:-1,dusk:18};f.world.playerRosterKnown=false;
 const event=f.scope.capture(f.world,f.message,2,3);assert.deepEqual(event.nativeWorld,{native17d:18});assert.equal(event.nativePlayersComplete,false);assert.equal(Object.hasOwn(event,'nativeC0'),false);
 f.row.replicationRemoved=true;const removed=f.scope.capture(f.world,f.message,2,3);assert.equal(removed.context,null);assert.equal(removed.contextData,null);assert.equal(Object.hasOwn(removed,'contextActorName'),false);
});
test('ordinary text has no synthetic token actor; Script93 captures the same actual module snapshot',()=>{
 const f=fixture(),ordinary=f.scope.capture(f.world,{...f.message,channel:8},2,3);
 assert.equal(Object.hasOwn(ordinary,'contextData'),false);
 const script=f.scope.capture(f.world,{kind:'combat-feedback',type:93,data:{objects:[f.names.id]}},2,3);
 assert.deepEqual(script.nativeWorld,ordinary.nativeWorld);assert.equal(Object.hasOwn(script,'context'),false);assert.equal(Object.hasOwn(script,'nativeC0'),false);
});

test('native byte projection inverses all 256 original decoder byte values',async()=>{const {decodeGffText}=await import('../../src/gff_text.js');const bytes=Uint8Array.from({length:256},(_,i)=>i);assert.deepEqual(byteProjection(decodeGffText(bytes)),{bytes:[...bytes]});assert.equal(byteProjection('😀'),null);});
