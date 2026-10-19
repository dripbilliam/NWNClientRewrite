import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {animateExternalModel} from '../src/model_external_animation.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-model-external-animation-observations.json',import.meta.url)));
test('native external model animation brackets the lower call with counter increments and re-reads a replaced header',()=>{
 const view=new DataView(new ArrayBuffer(4));for(const row of capture.rows){const c=row.case,head={counter:c.counter},other={counter:50},model={header:c.header?head:null},calls=[];
  animateExternalModel(model,c.delta,{header:o=>o.header,animate:(o,d)=>{view.setFloat32(0,d,true);calls.push({delta:view.getUint32(0,true),head:head.counter,other:other.counter});if(c.replace)o.header=other;}});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(head.counter,row.head,JSON.stringify(c));assert.equal(other.counter,row.other,JSON.stringify(c));
 }assert.equal(capture.rows.length,48);
});
