import test from 'node:test';import assert from 'node:assert/strict';
import {createModelHierarchy} from '../src/model_hierarchy.js';import {ModelNativePose} from '../src/model_native_pose.js';
export function poseFixture(scalarTransfer,count=64){
 const native=Array.from({length:count},(_,i)=>({id34:i,flags98:1,controllerCount80:0,controllers78:[],children68:[],childCount70:0}));
 for(let i=1;i<count;i++){const p=native[Math.floor((i-1)/2)];p.children68.push(native[i]);p.childCount70++;}
 const model={modelName:'authored_pose',nativeRoot:native[0],nodes:native.map((nativeNode,i)=>({name:'part'+i,type:'dummy',parentIndex:i?Math.floor((i-1)/2):-1,position:[0,0,0],orientation:[0,0,0,1],nativeNode,properties:{}}))};
 const {root}=createModelHierarchy(model,{managedMatrices:true}),pose=new ModelNativePose(model,root,()=>{},{scalarTransfer});return{root,pose};
}
export function writePose(pose,frame){for(let i=0;i<pose.parts.length;i++){const part=pose.parts[i],t=frame*.01+i*.05;pose.write(part,16,[Math.sin(t),Math.cos(t)*.2,i*.001]);pose.write(part,28,[Math.cos(t*.5),0,Math.sin(t*.5),0]);pose.write(part,44,[1+Math.sin(t)*.01]);}}
test('scalar transfer preserves every local/world matrix over moving native Part fields',()=>{
 const a=poseFixture(false),b=poseFixture(true);for(let frame=0;frame<80;frame++){for(const f of [a,b]){writePose(f.pose,frame);f.root.position.set(frame*.001,0,0);f.pose.flush();}for(let i=0;i<a.pose.parts.length;i++){const x=a.pose.parts[i].object,y=b.pose.parts[i].object;assert.deepEqual(y.matrix.elements,x.matrix.elements);assert.deepEqual(y.matrixWorld.elements,x.matrixWorld.elements);}}
});
test('scalar transfer rejects unavailable fields and nonfinite channels with the same errors',()=>{
 for(const scalar of [false,true])for(const [offset,count]of [[16,3],[28,4],[44,1]]){const {pose}=poseFixture(scalar,1);pose.parts[0].fields.delete(offset);assert.throws(()=>pose.flush(),new RegExp(`field ${offset}/${count} is unavailable`));}
 for(const scalar of [false,true])for(const offset of [16,20,24,28,32,36,40,44]){const {pose}=poseFixture(scalar,1);pose.parts[0].view.setFloat32(offset,NaN,true);assert.throws(()=>pose.flush(),/non-finite scene pose/);}
});
