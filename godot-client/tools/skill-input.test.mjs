import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {skillUseRequest,submitNativeSkill} from './skill-input.mjs';
import {NativeSkillTargeting} from './skill-targeting.mjs';
const INVALID=0x7f000000;

test('238 original skill writer/wrapper/full decoder observations retain packed fields, zero vectors and native gates',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../tests/fixtures/native-skill-request-observations-v1.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,238);
 let compared=0;
 for(const row of oracle.cases){const c=row.case;if(c.format!==1)continue;
  if(!row.packet){assert.ok(c.kind==='wrapper'&&(c.targetId===INVALID||c.noMessage));continue;}
  const actual=skillUseRequest({packedSkill:c.packedSkill,targetId:c.targetId,position:c.point}),native=Buffer.from(row.packet,'hex'),mask=row.lastBitOffset?255<<(8-row.lastBitOffset)&255:255;
  assert.equal(actual.length,native.length);assert.deepEqual(Buffer.from(actual.subarray(0,-1)),native.subarray(0,-1),JSON.stringify(c));assert.equal(actual.at(-1)&mask,native.at(-1)&mask);compared++;
  if(c.noActor||c.blocked||c.noArea){assert.equal(row.calls.length,0);continue;}
  assert.equal(row.calls.length,1);const call=row.calls[0];assert.equal(call.skillId,c.packedSkill&255);assert.equal(call.mode,(c.packedSkill>>>16)&255);assert.equal(call.targetId,c.targetId===INVALID?INVALID:c.targetId&0x7fffffff);assert.deepEqual(call.position,c.point);assert.equal(call.areaId,7);assert.equal(call.itemId,INVALID);assert.equal(call.force,0);
 }
 assert.equal(compared,107);
});
function fixture(){const actor={id:9,objectType:5,replicated:{position:[1,2,0]}},world={localObjectId:9,registry:new Map([[9,actor]])},sent=[],changes=[];let generation=1;
 const targeting=new NativeSkillTargeting({world:()=>world,tables:()=>({}),context:()=>({generation}),submit:async r=>{sent.push(r);return{sent:true};},onChange:r=>changes.push(r)});
 return{actor,world,sent,changes,targeting,retire:()=>generation++};}
test('original skill targeting uses door/placeable for unpacked Open Lock and creatures for other packed skills',async()=>{
 const f=fixture(),door={id:11,objectType:10},npc={id:12,objectType:5};await f.targeting.begin({type:3,intParam:9});
 assert.equal(f.targeting.presentation(door).cursor,37);assert.equal(f.targeting.presentation(npc).cursor,39);await assert.rejects(f.targeting.select(npc,[1,2,3]),/not valid/);assert.equal(f.targeting.active,true);
 await f.targeting.select(door,[7,8,9]);assert.deepEqual(f.sent.at(-1),{kind:'skill',packedSkill:9,targetId:11,position:[0,0,0]});
 await f.targeting.begin({type:3,intParam:0x660009});assert.equal(f.targeting.presentation(door).valid,false);assert.equal(f.targeting.presentation(npc).valid,true);await f.targeting.select(npc,[1,2,3]);assert.equal(f.sent.at(-1).packedSkill,0x660009);
});
test('Parry keeps the original mode2 path and Craft Trap targets the controlled actor immediately',async()=>{
 const f=fixture();await f.targeting.begin({type:3,intParam:10});assert.deepEqual(f.sent.at(-1),{kind:'mode',modeId:2,targetId:INVALID});assert.equal(f.targeting.active,false);
 await f.targeting.begin({type:3,intParam:22});assert.deepEqual(f.sent.at(-1),{kind:'skill',packedSkill:22,targetId:9,position:[0,0,0]});assert.equal(f.targeting.active,false);
});
test('retired skill targeting cannot submit, invalid targets do not consume selection, and repeated selection cannot send twice',async()=>{
 const f=fixture();await f.targeting.begin({type:3,intParam:4});await assert.rejects(f.targeting.select(null,[1,2,3]),/not valid/);assert.equal(f.targeting.active,true);f.retire();await assert.rejects(f.targeting.select(f.actor,[1,2,3]),/old area/);assert.equal(f.sent.length,0);
 await f.targeting.begin({type:3,intParam:4});await f.targeting.select(f.actor,[1,2,3]);await assert.rejects(f.targeting.select(f.actor,[1,2,3]));assert.equal(f.sent.length,1);
});
test('native skill adapter validates canonical control and target before sending unchanged bytes',async()=>{
 const actor={id:9},scope={actor,actorId:9,areaId:7,areaGeneration:1},sent=[];
 const session={controlledActor:()=>actor,validateCastTarget:(_area,_actor,id)=>{if(id!==12)throw Error('target missing');},peer:{sendGameMessage:async bytes=>sent.push(bytes)}};
 await submitNativeSkill(session,scope,{packedSkill:4,targetId:12});assert.deepEqual(sent[0],skillUseRequest({packedSkill:4,targetId:12}));
 for(const request of [{packedSkill:4,targetId:INVALID},{packedSkill:4,targetId:13},{packedSkill:NaN,targetId:12}])await assert.rejects(submitNativeSkill(session,scope,request));
 await assert.rejects(submitNativeSkill(session,{...scope,actor:{}},{packedSkill:4,targetId:12}));assert.equal(sent.length,1);
});
