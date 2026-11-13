import test from 'node:test';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
import {NetworkWorld} from '../../src/network_world.js';
const require=createRequire(import.meta.url),{RawCombatEvents}=require('./raw-combat-events.cjs'),{RawTileVisibility}=require('./raw-tile-visibility.cjs'),{RawCreatureVisibilityPermission}=require('./raw-creature-visibility-permission.cjs'),{rawEntityLifetime}=require('./raw-entity-lifetime.cjs');
function fixture(){
 const world=new NetworkWorld(),combat=new RawCombatEvents(),actor={id:17,objectType:5,areaId:22,replicated:{position:[5,5,0]}};
 assert.equal(world.registry.addObjectAtPos(17,actor).status,0);world.areaId=22;world.localObjectId=17;
 const projection=(owner,value)=>owner.entityDisclosures.transportRow(value,combat.object(value));
 return{world,combat,actor,projection,tile:new RawTileVisibility(projection),permission:new RawCreatureVisibilityPermission(projection)};
}
const packet={kind:'object-updates',records:[{action:'player-state',id:17,state:{automap:{mode:[1,0],points:[{x:0,y:0}]}}}]};
const permission={kind:'game-master-permission',permission:0,field114:1,parameter:0};
test('actual registry actors have no transport identities; fresh events match the existing snapshot projection',()=>{
 const f=fixture();assert.equal(Object.hasOwn(f.actor,'nativeLifetime'),false);assert.equal(Object.hasOwn(f.actor,'clientKnownLifetime'),false);
 const event=f.tile.frames(f.world,packet,2,9)[0],received=f.permission.frames(f.world,permission,2,9)[0],snapshot=f.projection(f.world,f.actor);
 assert.deepEqual(event.lifetime,[['nativeLifetime',true,snapshot.nativeLifetime],['disclosureLifetime',true,snapshot.clientKnownLifetime]]);assert.deepEqual(received.lifetime,event.lifetime);
 assert.equal(Object.hasOwn(f.actor,'nativeLifetime'),false);assert.equal(Object.hasOwn(f.actor,'clientKnownLifetime'),false);
 event.lifetime[1][2]=99;assert.equal(f.projection(f.world,f.actor).clientKnownLifetime,snapshot.clientKnownLifetime);
});
test('retained physical object acquires a new known-run identity without a second native identity store',()=>{
 const f=fixture(),first=f.tile.frames(f.world,packet,2,9)[0];
 f.world.entityDisclosures.observeAccepted([{action:'delete',id:17}],f.world.registry);
 const next=f.tile.frames(f.world,packet,2,9)[0];assert.equal(next.lifetime[0][2],first.lifetime[0][2]);assert.notEqual(next.lifetime[1][2],first.lifetime[1][2]);
 assert.equal(first.lifetime[1][2],1);assert.equal(next.serial,first.serial+1);
});
test('real registry removal and same-ID replacement cannot inherit either event identity',()=>{
 const f=fixture(),old=f.permission.frames(f.world,permission,2,9)[0];f.world.registry.delete(17);
 const replacement={id:17,objectType:5,areaId:22,replicated:{}};f.world.registry.addObjectAtPos(17,replacement);
 const next=f.permission.frames(f.world,permission,2,9)[0];assert.notEqual(next.lifetime[0][2],old.lifetime[0][2]);assert.notEqual(next.lifetime[1][2],old.lifetime[1][2]);
 assert.deepEqual(next.lifetime,rawEntityLifetime(f.projection(f.world,replacement)));
});
test('canonical known-run carrier takes precedence, including explicit unavailable; old DTOs remain readable',()=>{
 assert.deepEqual(rawEntityLifetime({nativeLifetime:3,clientKnownLifetime:8,disclosureLifetime:4}),[['nativeLifetime',true,3],['disclosureLifetime',true,8]]);
 assert.deepEqual(rawEntityLifetime({nativeLifetime:3,clientKnownLifetime:null,disclosureLifetime:4}),[['nativeLifetime',true,3],['disclosureLifetime',false,null]]);
 assert.deepEqual(rawEntityLifetime({nativeLifetime:3,disclosureLifetime:4}),[['nativeLifetime',true,3],['disclosureLifetime',true,4]]);
 assert.deepEqual(rawEntityLifetime(null),[['nativeLifetime',false,null],['disclosureLifetime',false,null]]);
});
