import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {deliverObjectVisual,snapshotObjectVisual} from '../src/object_visual_delivery.js';
test('decoded object visual dispatch matches complete original receiver across normal/special types, native999 and failed dummy allocation',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-object-visual-delivery-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,864);
 for(const row of oracle.rows){const c=row.case,calls=[],objects=new Map([[123,{id:123,objectType:c.targetType}],[789,{id:789,objectType:5}]]);
  const result=deliverObjectVisual({...c,position:[1.25,-2,3.5],sourcePosition:[7,8,9],flag:17,missMode:250,transform:{scale:1,translate:[0,0,0],rotate:[0,0,0]}},{visualType:()=>({value:c.kind}),object:id=>{calls.push(['object',id]);return objects.get(id);},renderObject:o=>o,createDummy:role=>{calls.push(['dummy',role]);return null;},
   add:(actor,record)=>{const d=record.delivery;calls.push(['add',actor.id,record.visualId,record.sourceId,d.instant,d.sourcePart,d.targetPart,d.point]);return c.addResult;}});
  assert.deepEqual({calls,result},{calls:row.calls,result:row.result},JSON.stringify(c));
 }
});
test('local semantic sender snapshots real target/source positions before asynchronous scene work without changing IDs',()=>{
 const objects=new Map([[123,{position:[1,2,3]}],[789,{position:[4,5,6]}]]),message={visualId:1,targetId:123,sourceId:789,position:[0,0,0]},snapshot=snapshotObjectVisual(message,objects);objects.get(123).position[0]=99;
 assert.deepEqual(snapshot,{visualId:1,targetId:123,sourceId:789,position:[1,-3,2],sourcePosition:[4,-6,5]});assert.deepEqual(message.position,[0,0,0]);
});
