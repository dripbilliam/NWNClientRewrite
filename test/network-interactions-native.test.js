import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {doorActionRequest,talkToRequest,useObjectRequest,attackRequest} from '../src/network_player_requests.js';
import {networkDefaultInteraction,networkRadialActions} from '../src/network_action_menu.js';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-interaction-observations.json',import.meta.url)));
const encode={door:doorActionRequest,talk:talkToRequest,use:useObjectRequest,attack:attackRequest};

test('interaction encoders match original client writers and original server dispatcher action boundaries',()=>{
 for(const row of fixture.cases.filter(r=>r.case.format===1)){
  const c=row.case,packet=encode[c.kind](c),native=Buffer.from(row.packet,'hex'),used=native.at(-1)>>>5,mask=(255<<(8-used))&255;
  assert.equal(packet.length,native.length);assert.deepEqual(Buffer.from(packet.subarray(0,-1)),native.subarray(0,-1));assert.equal(packet.at(-1)&mask,native.at(-1)&mask);
  const calls=row.decoded.calls,targetId=c.targetId&0x7fffffff;
  if(c.noActor||c.blocked){assert.deepEqual(calls,[]);continue;}
  if(c.kind==='door')assert.deepEqual(calls,[['actionManager',2],[c.action===21?'open':'close',targetId,1]]);
  if(c.kind==='attack')assert.deepEqual(calls,[['attack',targetId,0,1,0],['clearSpecial']]);
  if(c.kind==='use'){assert.deepEqual(calls.slice(-2),[['actionManager',2],['use',targetId]]);assert.equal(row.decoded.flag0,c.flag0);assert.equal(calls.some(v=>v[0]==='event'),Boolean(c.flag1));}
  if(c.kind==='talk'&&c.commandable!==0&&c.reaction!==2)assert.deepEqual(calls.at(-1),['addAction',24,65535,3,targetId]);
 }
});

test('door default and radial close actions reflect replicated state and keep unimplemented branches',()=>{
 const actor={id:0xffffffff,objectType:5,replicated:{}},door={id:0x80000002,objectType:10,replicated:{animation:22,field424:0,field428:1}};
 const before=structuredClone(door);assert.equal(networkDefaultInteraction(door),'door.open');assert.deepEqual(door,before);
 for(const animation of [50,51]){door.replicated.animation=animation;assert.equal(networkDefaultInteraction(door),'door.close');assert.equal(networkRadialActions(door,actor).entries.find(e=>e.slot===2).label,'Close');}
 door.replicated.hasTransition=1;assert.equal(networkDefaultInteraction(door),'door.transition');assert.equal(networkRadialActions(door,actor).entries.find(e=>e.slot===2).action,'door.close');
 door.replicated.animation=72;assert.equal(networkDefaultInteraction(door),'door.transition');door.replicated.hasTransition=0;assert.equal(networkDefaultInteraction(door),null);assert.equal(networkRadialActions(door,actor).entries.find(e=>e.slot===2).disabled,true);
 const npc={id:0x80000003,objectType:5,replicated:{reaction:0}};assert.equal(networkDefaultInteraction(npc),'conversation.start');npc.replicated.reaction=2;assert.equal(networkDefaultInteraction(npc),'combat.attack');
 assert.ok(networkRadialActions(npc,actor).entries.some(e=>e.children));
});

test('interaction encoders reject IDs outside uint32 and malformed flags/actions',()=>{
 for(const fn of Object.values(encode))for(const targetId of [-1,0x100000000,NaN])assert.throws(()=>fn({targetId,action:21}));
 assert.throws(()=>doorActionRequest({targetId:1,action:65536}));assert.throws(()=>useObjectRequest({targetId:1,flag0:2}));
});
