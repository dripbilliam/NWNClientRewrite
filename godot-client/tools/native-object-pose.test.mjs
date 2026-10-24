import test from 'node:test';import assert from 'node:assert/strict';import {nativeObjectPose} from './native-object-pose.mjs';
test('portal stream retains authoritative polygon origin and raised picking offset instead of generic object position',()=>{
 const o={objectType:7,replicated:{hasTransition:true,position:[900,900,900],orientation:{yaw:90},vertices:[[48,43,0],[52,43,0],[52,45,0],[48,45,0]]}};
 assert.deepEqual(nativeObjectPose(o),{position:[50,.05,-44],rotation:0});o.replicated.vertices=o.replicated.vertices.map(v=>[v[0]+2,v[1],v[2]+1]);assert.deepEqual(nativeObjectPose(o),{position:[52,1.05,-44],rotation:0});o.replicationRemoved=true;assert.equal(nativeObjectPose(o),null);
});
test('creatures and static props retain existing native axis/orientation mapping',()=>{
 assert.deepEqual(nativeObjectPose({objectType:5,replicated:{position:[1,2,3],orientation:{vector:[1,0]}}}),{position:[1,3,-2],rotation:-Math.PI/2});assert.deepEqual(nativeObjectPose({objectType:9,staticState:{position:[4,5,6],orientation:{yaw:90}}}),{position:[4,6,-5],rotation:Math.PI/2});assert.equal(nativeObjectPose({objectType:5}),null);
});
