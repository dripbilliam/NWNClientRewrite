import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {actionParameter,addObjectAction,createObjectActionState} from '../src/object_actions.js';
import {scriptMoveToObject,scriptMoveToLocation} from '../src/script_movement.js';
import {scriptStringRight,scriptSubString,scriptStringCase} from '../src/script_string.js';
import {associateListenPatterns} from '../src/associate_listen_patterns.js';
import {scriptFloatToInt} from '../src/script_scalar.js';

test('dawn and dusk use cached native byte3/4, including truncation and absent-module behavior',()=>{
  const s=new ModuleSession(null);assert.equal(s.commands.GetIsDawn(),0);assert.equal(s.commands.GetIsDusk(),0);
  s.module={};assert.throws(()=>s.commands.GetIsDawn(),/unavailable/);
  for(const value of [0,1,2,3,4,259,260]){
    s.module.nativeTimeOfDay3d4=value;
    assert.equal(s.commands.GetIsDawn(),Number((value&255)===3));
    assert.equal(s.commands.GetIsDusk(),Number((value&255)===4));
  }
});
test('Right preserves native negative, zero and over-length semantics for Windows-1252 text',()=>{
  for(const [n,result] of [[-1,''],[0,''],[1,'€'],[2,'é€'],[3,'aé€'],[99,'aé€'],[0x80000000,'']])assert.equal(scriptStringRight('aé€',n),result);
  assert.equal(scriptStringRight('',3),'');assert.throws(()=>scriptStringRight('😊',1),/encoding/);
});
test('SubString clamps count to remainder, accepts negative count as remainder, and rejects negative offsets',()=>{
  for(const [start,count,result] of [[0,0,''],[1,2,'bc'],[1,-1,'bcde'],[1,99,'bcde'],[-1,3,''],[5,1,''],[6,-1,''],[0,0x80000000,'abcde']])assert.equal(scriptSubString('abcde',start,count),result);
});
test('FloatToInt truncates native f32 values and preserves x64 invalid conversion result',()=>{
  for(const [value,result] of [[1.9,1],[-1.9,-1],[2147483584,-2147483648],[2147483520,2147483520],[-2147483648,-2147483648],[NaN,-2147483648],[Infinity,-2147483648],[1.99999999,2]])assert.equal(scriptFloatToInt(value),result);
});
test('script case conversion follows CRT ASCII ranges, preserves punctuation and rejects unmapped locale bytes',()=>{
  assert.equal(scriptStringCase('Az[Z]09_\0'),'az[z]09_\0');
  assert.equal(scriptStringCase('az{z}09_',true),'AZ{Z}09_');
  assert.throws(()=>scriptStringCase('Éé'),/locale/);
});
test('authored patterns and associate commands retain object-owned IDs; VM pattern tests do not mutate owners',()=>{
  const s=new ModuleSession(null),o=s.register('creature','o',{authored:{ExpressionList:[{ExpressionId:17,ExpressionString:'Hello'}]}});
  const expressions=o.nativeListenExpressions;assert.equal(expressions.count,1);assert.equal(expressions.entries[0].id,17);
  assert.equal(s.commands.TestStringAgainstPattern(['hello','HELLO']),1);assert.deepEqual(expressions.entries[0].matches,[]);
  s.commands.SetAssociateListenPatterns([],{self:o.id});
  for(const command of associateListenPatterns){const e=expressions.entries.find(e=>e.id===command.id);assert.ok(e);assert.equal(e.pattern,command.pattern.toLowerCase());}
  s.commands.SetListenPattern([o.id,'** follow **',17]);assert.equal(expressions.entries[0].id,17);
  assert.equal(expressions.entries[0].test('please follow me'),1);
  const before=expressions.count;s.commands.SetAssociateListenPatterns([OBJECT_INVALID]);assert.equal(expressions.count,before);
});
test('script object movement appends move/radius actions in a shared group and uses target position with use-range floor',async()=>{
  const actor={id:1,objectType:5,nativeFieldEc:2,objectActionState:createObjectActionState()},target={id:2,objectType:10,position:[8,3,-7]},area={id:3,objectType:4},locks=[];
  addObjectAction(actor.objectActionState,30,65535,[]);
  const p={area:()=>area,useRange:(_a,_t,out)=>{out.point=[999,999,999];out.range=2.25;},setLock:(_a,id)=>locks.push(id)};
  await scriptMoveToObject(actor,target,1,.5,30,p);
  const actions=[...actor.objectActionState.list];assert.deepEqual(actions.map(n=>n.actionId),[30,1,17]);
  assert.equal(actions[1].groupId,1);assert.equal(actions[2].groupId,1);
  assert.deepEqual(Array.from({length:9},(_,i)=>actionParameter(actions[1],i)),[8,7,3,3,2,5,2.25,0,30]);
  assert.deepEqual(Array.from({length:5},(_,i)=>actionParameter(actions[2],i)),[2,1,2.25,2.25,1]);
  assert.deepEqual(locks,[OBJECT_INVALID]);actor.nativeFieldEc=0;await scriptMoveToObject(actor,target,0,1,0,p);assert.equal(actor.objectActionState.list.count,3);
});
test('script location movement keeps original area ID on fallback and accepts commandable zero',async()=>{
  const actor={id:1,objectType:5,nativeFieldEc:0,objectActionState:createObjectActionState()},location={areaId:OBJECT_INVALID,position:[2,4,6]};
  const p={object:()=>null,area:()=>({id:7,objectType:4}),setLock:()=>{}};
  await scriptMoveToLocation(actor,location,0,0,p);
  const n=actor.objectActionState.list.head.action;
  assert.deepEqual(Array.from({length:9},(_,i)=>actionParameter(n,i)),[2,4,6,OBJECT_INVALID,OBJECT_INVALID,0,0,0,0]);
  await scriptMoveToLocation(actor,location,0,0,{...p,object:()=>({objectType:5})});assert.equal(actor.objectActionState.list.count,1);
});
