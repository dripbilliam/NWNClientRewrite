import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {selectClientAttackAnimation,clientProjectileTravelTime} from '../src/client_combat_animation.js';
test('1164 original ranged/dispatch executions agree on parry timing, missing objects, side reset and WORD wrap',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-ranged-selection-observations.json',import.meta.url)));
 assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.cases.length,1164);
 for(const row of fixture.cases){
  const c=row.case,render=v=>[v[0],v[2],-v[1]],actor={position:render(c.from_),side:c.side,attackType:65535},target={objectType:5,position:render(c.to)},context={fieldE0:7},record={duration:c.duration,reaction:c.reaction,reactionDelay:123,targetId:0x80000012,attackType:0xabcd,weaponAttackType:7,ranged:c.ranged},commands=[];
  const animation=selectClientAttackAnimation(actor,c.animation,record,{context:()=>context,setBaseAnimation:(_a,animation)=>commands.push({kind:'base',animation}),target:id=>{commands.push({kind:'target',id});return c.missingTarget?null:target;},attackWeapon:(_a,type)=>{commands.push({kind:'weapon',type},{kind:'item',id:0x80000043});return c.baseItem===null?null:{baseItem:c.baseItem};},baseItem:i=>i.baseItem,melee:()=>{commands.push({kind:'classify'},{kind:'melee',branch:c.branch??2});return 204;}});
  assert.deepEqual({animation,reaction:record.reaction,reactionDelay:record.reactionDelay,side:actor.side,contextSide:context.fieldE0,attackType:actor.attackType,commands},{animation:row.animation,reaction:row.reaction,reactionDelay:row.reactionDelay,side:row.side,contextSide:row.contextSide,attackType:row.attackType,commands:row.commands},JSON.stringify(c));
 }
});
test('travel keeps the signed64 conversion boundary explicit and requires positions',()=>{
 assert.equal(clientProjectileTravelTime([0,0,0],[3,4,0],false),90n);assert.equal(clientProjectileTravelTime([0,0,0],[3,4,0],true),125n);
 assert.equal(clientProjectileTravelTime([0,0,0],[3e38,0,0],true),-9223372036854775808n);assert.throws(()=>clientProjectileTravelTime(null,[0,0,0],true),/positions/);
});
