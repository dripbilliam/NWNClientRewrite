import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import {EventEmitter} from 'node:events';
import {goldTransferRequest} from '../src/network_player_requests.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
test('48 native-format gold packets match the unchanged original sender across destinations/placement/signed amounts',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-gold-transfer-observations-v1.json',import.meta.url)));
 assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,96);
 for(const {case:c,packet}of oracle.cases.filter(row=>row.case.format===1)){
  const actual=Buffer.from(goldTransferRequest(c)),native=Buffer.from(packet,'hex'),used=native.at(-1)>>>5,mask=255<<(8-used)&255;
  assert.equal(actual.length,native.length);assert.deepEqual(actual.subarray(0,-1),native.subarray(0,-1));assert.equal(actual.at(-1)&mask,native.at(-1)&mask);
 }
});
test('108 original native-format barter rejection packets preserve operation/reason/client identity and reject truncation',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-barter-reject-observations-v1.json',import.meta.url)));assert.equal(oracle.cases.length,216);
 for(const {case:c,packet}of oracle.cases.filter(row=>row.case.format===1)){
  const bytes=Buffer.from(packet,'hex'),actual=decodeServerGameMessage(bytes);assert.deepEqual(actual,{kind:'barter-reject',operation:c.operation,reason:c.reason,targetId:c.targetId,major:35,minor:11});
  for(let n=3;n<bytes.length-1;n++)assert.throws(()=>decodeServerGameMessage(bytes.subarray(0,n)));
 }
});
test('gold transport rejects stale actor/balance/context/targets without predicting any balance or ownership change',async()=>{
 const sent=[],peer=new EventEmitter();peer.sendGameMessage=async packet=>sent.push(packet);
 const s=new NetworkGameSession({peer,identity:{},build:{},resources:{}});s.phase='playing';s.areaReadySent=true;s.areaGeneration=3;s.world.areaId=0x80000000;s.world.localObjectId=0xffffffff;
 const actor={id:0xffffffff,areaId:s.world.areaId,objectType:5,playerState:{combat:{field898:27}}},target={id:0x80000002,areaId:s.world.areaId,objectType:5};s.world.registry.addObjectAtPos(actor.id,actor);s.world.registry.addObjectAtPos(target.id,target);
 const input={areaId:s.world.areaId,areaGeneration:3,actorId:actor.id,amount:7,targetId:target.id},before=structuredClone(actor);
 await s.transferGold(input);assert.equal(sent.length,1);assert.deepEqual(actor,before);
 for(const change of [{amount:28},{amount:0},{amount:-1},{amount:NaN},{actorId:target.id},{areaGeneration:2},{areaId:9},{targetId:123},{placement:true}])await assert.rejects(s.transferGold({...input,...change}));
 assert.equal(sent.length,1);assert.deepEqual(actor,before);
 await s.transferGold({...input,targetId:0x7f000000,position:[1.25,-2.5,3.75]});assert.equal(sent.length,2);assert.deepEqual(actor,before);
 await assert.rejects(s.transferGold({...input,targetId:0x7f000000,position:[Infinity,0,0]}));
 const bag={id:0x80000007,objectType:6,areaId:0x7f000000,item:{baseItem:7},inventoryLocation:{channel:'C',ownerId:target.id}};s.world.registry.addObjectAtPos(bag.id,bag);s.world.containers.set('C',target.id);s.objectRules.quickbarItemInfo=id=>({container:id===7?1:0});
 await s.transferGold({...input,targetId:bag.id});assert.equal(sent.length,3);assert.deepEqual(actor,before);
 s.world.containers.set('C',0x7f000000);await assert.rejects(s.transferGold({...input,targetId:bag.id}));assert.equal(sent.length,3);
 delete bag.inventoryLocation;s.world.containers.set('C',bag.id);await s.transferGold({...input,targetId:bag.id});assert.equal(sent.length,4);assert.deepEqual(actor,before);
 s.world.containers.set('C',0x7f000000);await assert.rejects(s.transferGold({...input,targetId:bag.id}));assert.equal(sent.length,4);
});
