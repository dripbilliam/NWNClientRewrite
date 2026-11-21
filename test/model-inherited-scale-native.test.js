import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {inheritAnimations} from '../src/mdl_animation.js';

const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-animation-scale-v1.json',import.meta.url)));
test('inherited position and bezier offsets retain every native child scale',async()=>{
 for(const c of oracle.cases.filter(c=>c.owner!==null)){
  const models=c.factors.map((scale,i)=>({modelName:'model'+i,supermodel:i===2?'null':'model'+(i+1),animationScale:scale,animations:i===c.owner?[{name:'walk',tracks:[{node:'rootdummy',property:'position',frames:[{time:0,value:[1,2,3],in:[2,4,6],out:[3,6,9]}]}]}]:[]}));
  await inheritAnimations(models[0],async name=>models.find(m=>m.modelName===name));
  const frame=models[0].animations[0].tracks[0].frames[0];
  for(const [field,multiple] of [['value',1],['in',2],['out',3]])for(let i=0;i<3;i++)assert.ok(Math.abs(frame[field][i]-(i+1)*multiple*c.result)<2e-6,JSON.stringify(c));
 }
});
