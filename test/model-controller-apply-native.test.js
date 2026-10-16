import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applyModelControllers} from '../src/model_controller_apply.js';
test('generic controller blends compose native samplers and match original including duplicate writes, motion callback order and live count mutation',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-model-controller-apply-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,480);
 for(const row of oracle.rows){
  const c=row.case,calls=[],values88=Array(64).fill(0);values88.splice(0,2,0,1);values88.splice(16,2,2,4);values88.splice(32,6,1,2,3,4,5,6);values88.splice(48,8,0,0,0,1,.5,.5,.5,.5);
  const controllers78=[[44,1,16],[16,3,32],[28,4,48],[44,1,16],[60,2,16]].map(([displacement0,columnsA,valueIndex8])=>({displacement0,columnsA,valueIndex8,rows4:2,timeIndex6:0})),node={controllers78,controllerCount80:c.count,values88},part=new Map([[16,[2,-1,3]],[28,[...c.quaternion]],[44,[7]]]);
  applyModelControllers(node,part,c.previous,c.time,c.weight,{read:(part,offset)=>part.get(offset),write:(part,offset,values)=>part.set(offset,values),positionScale:()=>c.scale,math:{acos:Math.acos,sin:Math.sin},activeMotionRun:()=>c.motion,
   motion:(controller,_part,_node,previous,time)=>{calls.push(['motion',controllers78.indexOf(controller),previous,time]);if(c.truncate)node.controllerCount80=1;}});
  assert.deepEqual({calls,count:node.controllerCount80,position:part.get(16),quaternion:part.get(28),scalar:part.get(44)[0]},Object.fromEntries(Object.entries(row).filter(([key])=>key!=='case')),JSON.stringify(c));
 }
});
