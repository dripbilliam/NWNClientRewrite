import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {selectClientBloodVisual,clientBloodSlot,clientBloodQuaternion,bloodAcos} from '../src/client_blood_visual.js';
import {modelAnimationTime} from '../src/model_animation_query.js';
test('blood model selection and three-slot reuse match1020 complete original mode1 executions with model-allocation failure',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-blood-visual-observations.json',import.meta.url)));assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,1020);
 for(const {case:c,calls:expected,result}of oracle.cases){const calls=[],p={kind:()=>c.kind??0,violence:()=>c.violence,blood:()=>{calls.push(['string','appearance',2,'bloodcolr']);return c.blood;},warning:()=>calls.push(['warning']),maximum:()=>{calls.push(['maximum']);return c.maximum??100;},whiteOverride:()=>Boolean(c.white),lowViolence:row=>{calls.push(['int',row,'LowViolence']);return{found:c.lowViolence??true,value:row+1000};},modelName:row=>{calls.push(['string','visualeffects',row,'imp_impact_node']);return'blood_'+row;}};
  const model=selectClientBloodVisual({}, {result:c.result,damage:c.damage,attackType:c.attackType??0,killingBlow:c.killing??0,weaponAttackType:c.weaponAttackType??1},p);let value=0;
  if(model!==null){const slots=Array.from({length:3},(_,i)=>i<(c.slots??0)?{i}:null),index=clientBloodSlot(slots,{playInfo:o=>{calls.push(['info',o.i]);return c.finished===o.i?-1:.25;},destroy:o=>calls.push(['destroy',o.i])});if(index>=0)calls.push(['create',model]);else value=1;}
  assert.equal(value,result,JSON.stringify(c));assert.deepEqual(calls,expected,JSON.stringify(c));
 }
});
test('2015 native float acos results and18 native first-run time queries agree',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-blood-helper-observations.json',import.meta.url))),f32=new Float32Array(1),u32=new Uint32Array(f32.buffer);assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.acos.length,2015);assert.equal(oracle.queries.length,18);
 for(const c of oracle.acos){u32[0]=c.input;const input=f32[0];u32[0]=c.output;const expected=f32[0],actual=bloodAcos(input);if(Number.isNaN(expected))assert.ok(Number.isNaN(actual));else assert.equal(actual,expected,JSON.stringify({input,actual,expected}));}
 for(const c of oracle.queries)assert.equal(modelAnimationTime(c.runs.map(([name,time14])=>({clip0:{name},time14})),c.name),c.time);
});
test('blood orientation matches380 original success paths across directions, clips and weapon types',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-blood-visual-success-observations.json',import.meta.url)));assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,380);
 for(const {case:c,calls,result}of oracle.cases){assert.equal(result,1);const expected=calls.find(x=>x[0]==='orientation')[1],actual=clientBloodQuaternion(c.orientation??[1,0,0],c.direction??[1,0,0],c.animation??200,c.weapon===false?null:c.weaponType??1);for(let i=0;i<4;i++)assert.ok(Math.abs(actual[i]-expected[i])<1e-6,JSON.stringify({c,actual,expected}));assert.deepEqual(calls.find(x=>x[0]==='parent'),['parent',c.part||'impact',3]);assert.deepEqual(calls.find(x=>x[0]==='play'),['play','impact',1,1]);}
});
