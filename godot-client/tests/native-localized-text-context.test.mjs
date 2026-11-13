import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
import {decodeServerGameMessage} from '../../src/network_game_messages.js';
import {GameObjectArray} from '../../src/game_object_array.js';
import {EntityDisclosureLifetimes} from '../../src/network_entity_lifetimes.js';
const require=createRequire(import.meta.url);
const {NativeTextEventScope}=require('../tools/native-text-event-scope.cjs');
const {RawCombatEvents}=require('../tools/raw-combat-events.cjs');
const original=JSON.parse(fs.readFileSync(new URL('../../backups/animations/native-network-speech-observations.json',import.meta.url)));
assert.equal(original.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
const hex=original.cases.filter(row=>row.case.format===1).map(row=>row.packet).find(value=>{const bytes=Buffer.from(value,'hex');return bytes[1]===9&&bytes[2]===11;});
assert.ok(hex,'retained original localized packet exists');
const wire11=Buffer.from(hex,'hex'),wire12=Buffer.from(wire11);wire12[2]=12;
const build={clientBuild:{number:8193,revision:37,postfix:17}};
const decoded11=decodeServerGameMessage(wire11,build),decoded12=decodeServerGameMessage(wire12,build);
function setup(){
 const registry=new GameObjectArray({clientMode:true}),speaker={objectType:5,areaId:7,replicationRemoved:false},context={objectType:5,areaId:7,replicationRemoved:false};
 assert.notEqual(decoded12.objectId,decoded12.contextId);
 assert.equal(registry.addObjectAtPos(decoded12.objectId,speaker).status,0);assert.equal(registry.addObjectAtPos(decoded12.contextId,context).status,0);
 const identities=new RawCombatEvents(),disclosures=new EntityDisclosureLifetimes(),world={areaId:7,registry,entityDisclosures:disclosures};
 return{world,context,speaker,identities,disclosures,scope:new NativeTextEventScope(identities)};
}
test('synthetic channel12 variant retains original localized11 wire body exactly',()=>{
 assert.equal(decoded11.channel,11);assert.equal(decoded12.channel,12);
 assert.deepEqual({...decoded12,channel:11,minor:11},decoded11);
 assert.deepEqual(wire12.subarray(3),wire11.subarray(3));
});
test('both localized channels use the same actual canonical/disclosure context owner',()=>{
 const s=setup(),before=JSON.stringify(decoded12),a=s.scope.capture(s.world,decoded11,2,3),b=s.scope.capture(s.world,decoded12,2,3);
 assert.deepEqual(a.context,b.context);assert.equal(b.context.id,decoded12.contextId);assert.notEqual(b.context.id,b.source.id);
 assert.equal(b.context.nativeLifetime,s.identities.identity(s.context));assert.equal(b.context.knownLifetime,s.disclosures.token(s.context));
 assert.equal(JSON.stringify(decoded12),before);assert.equal(b.serial,a.serial+1);
});
test('channel12 context is detached and retained-proxy redisclosure changes its witness',()=>{
 const s=setup(),a=s.scope.capture(s.world,decoded12,2,3),known=a.context.knownLifetime;
 a.context.knownLifetime=999999;assert.equal(s.disclosures.token(s.context),known);
 s.context.replicationRemoved=true;s.disclosures.observeAccepted([{action:'delete',id:s.context.id}],s.world.registry);
 assert.equal(s.scope.capture(s.world,decoded12,2,3).context,null);
 s.context.replicationRemoved=false;const b=s.scope.capture(s.world,decoded12,2,3);
 assert.notEqual(b.context.knownLifetime,known);assert.equal(b.context.nativeLifetime,s.identities.identity(s.context));
});
test('missing/out-of-area localized context stays explicit null and ordinary text adds none',()=>{
 const s=setup();s.context.areaId=8;assert.equal(s.scope.capture(s.world,decoded12,2,3).context,null);
 const literal={kind:'server-speech',channel:1,objectId:s.speaker.id,text:{text:'<CUSTOM12> <<literal>'},contextId:s.context.id},before=JSON.stringify(literal);
 assert.equal(Object.hasOwn(s.scope.capture(s.world,literal,2,3),'context'),false);assert.equal(JSON.stringify(literal),before);
});
