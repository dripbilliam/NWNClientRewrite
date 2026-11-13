import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const {RawCreatureVisibilityPermission:Owner}=createRequire(import.meta.url)('./raw-creature-visibility-permission.cjs');
const actor={id:17,objectType:5,areaId:22,nativeLifetime:3,disclosureLifetime:5};
const world={areaId:22,localObjectId:17,registry:new Map([[17,actor]])};
const packet={kind:'game-master-permission',permission:0,field114:1,parameter:-4};
test('fresh permission preserves current recipient, scope and detached lifetime',()=>{
 const owner=new Owner(),result=owner.frames(world,packet,2,9)[0];
 assert.deepEqual(result,{kind:'raw-creature-visibility-permission',connection:9,generation:2,areaId:22,actorId:17,lifetime:[['nativeLifetime',true,3],['disclosureLifetime',true,5]],recipientOwner:null,serial:1,permission:false,field114:true,parameter:-4,source:'received_game_master_permission_31_22'});
 result.lifetime[0][2]=99;assert.equal(actor.nativeLifetime,3);
 assert.deepEqual(JSON.parse(JSON.stringify(result)),result);
});
test('sticky snapshots never replay a permission write; repeated real writes stay ordered',()=>{
 const owner=new Owner();assert.deepEqual(owner.frames({...world,gameMasterPermission:packet},{kind:'snapshot'},2,9),[]);
 assert.equal(owner.frames(world,packet,2,9)[0].serial,1);assert.equal(owner.frames(world,packet,2,9)[0].serial,2);
});
test('physical recipient proof is detached and independent of later area/control changes',()=>{
 const proof={version:1,source:'native-client-clock-owner-v1',connection:9,physicalCurrent:true,physicalToken:'physical-1',epoch:2};
 const owner=new Owner(),frame=owner.frames({...world,nativeClockOwnerTransport:value=>{assert.equal(value,actor);return proof;}},packet,2,9)[0];
 proof.physicalToken='later-physical';assert.equal(frame.recipientOwner.physicalToken,'physical-1');
 frame.recipientOwner.physicalCurrent=false;assert.equal(proof.physicalCurrent,true);
});
test('no controlled creature and retirement stay explicit without migrating writes',()=>{
 const owner=new Owner();for(const candidate of [undefined,{...actor,objectType:9},{...actor,replicationRemoved:true}]){
  const value=owner.frames({...world,registry:new Map([[17,candidate]])},packet,2,9)[0];assert.equal(value.actorId,null);assert.equal(value.lifetime,null);
 }
 assert.equal(owner.frames(world,{kind:'snapshot'},2,9).length,0);
 const unknown={...actor};delete unknown.nativeLifetime;delete unknown.disclosureLifetime;
 assert.deepEqual(owner.frames({...world,registry:new Map([[17,unknown]])},packet,2,9)[0].lifetime,[['nativeLifetime',false,null],['disclosureLifetime',false,null]]);
});
test('reconnect, possession and ID reuse capture only the current physical lifetime',()=>{
 const owner=new Owner(),first=owner.frames(world,packet,2,9)[0];
 const possessed={...actor,id:21,nativeLifetime:100};
 const next=owner.frames({...world,localObjectId:21,registry:new Map([[21,possessed]])},packet,4,10)[0];
 assert.equal(first.connection,9);assert.equal(first.actorId,17);assert.equal(next.connection,10);assert.equal(next.actorId,21);assert.equal(next.lifetime[0][2],100);
 const reused=owner.frames({...world,registry:new Map([[17,{...actor,nativeLifetime:4}]])},packet,2,9)[0];assert.equal(reused.lifetime[0][2],4);assert.equal(first.lifetime[0][2],3);
});
test('malformed deliveries do not fabricate local fields or consume serials',()=>{
 const owner=new Owner();for(const change of [{permission:2},{field114:null},{parameter:0.5},{parameter:2147483648}])assert.deepEqual(owner.frames(world,{...packet,...change},2,9),[]);
 assert.deepEqual(owner.frames(world,packet,-1,9),[]);assert.equal(owner.frames(world,packet,2,9)[0].serial,1);
});
