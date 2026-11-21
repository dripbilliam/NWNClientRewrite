import test from 'node:test';import assert from 'node:assert/strict';import * as T from 'three';
import {manageLocalMatrix,commitLocalMatrix,setManagedMatrixReuse,managedMatrixReuseSnapshot} from '../src/managed_local_matrix.js';

test('owned commit reuse preserves direct edits, reparenting, clones and custom producers',()=>{
 setManagedMatrixReuse(true);
 try{
  const scene=manageLocalMatrix(new T.Scene()),a=manageLocalMatrix(new T.Group()),b=manageLocalMatrix(new T.Group()),object=manageLocalMatrix(new T.Group());a.position.x=2;b.position.x=5;commitLocalMatrix(a);commitLocalMatrix(b);scene.add(a,b);a.add(object);commitLocalMatrix(object);scene.updateMatrixWorld();
  const before=managedMatrixReuseSnapshot();commitLocalMatrix(object);assert.equal(object.matrixWorldNeedsUpdate,false);assert.equal(managedMatrixReuseSnapshot().reused,before.reused+1);
  object.position.y=4;commitLocalMatrix(object);assert(object.matrixWorldNeedsUpdate);scene.updateMatrixWorld();assert.deepEqual(object.getWorldPosition(new T.Vector3()).toArray(),[2,4,0]);
  object.matrix.elements[12]=999;commitLocalMatrix(object);assert.equal(object.matrix.elements[12],0);scene.updateMatrixWorld();
  b.add(object);commitLocalMatrix(object);scene.updateMatrixWorld();assert.equal(object.matrixWorld.elements[12],5);
  const clone=object.clone();clone.position.z=3;b.add(clone);commitLocalMatrix(clone);scene.updateMatrixWorld();assert.deepEqual(clone.getWorldPosition(new T.Vector3()).toArray(),[5,4,3]);
  object.matrix=new T.Matrix4();commitLocalMatrix(object);assert.equal(object.matrix.elements[13],4);
  let called=0;object.updateMatrix=function(){called++;return T.Object3D.prototype.updateMatrix.call(this);};commitLocalMatrix(object);commitLocalMatrix(object);assert.equal(called,2);
  const ordinary=new T.Group();ordinary.position.x=12;commitLocalMatrix(ordinary);assert(ordinary.matrixAutoUpdate);ordinary.updateMatrixWorld();assert.equal(ordinary.matrixWorld.elements[12],12);
 }finally{setManagedMatrixReuse(false);}
});

test('dirty flags and all local/world matrices match ordinary commits over mixed animated and static subtrees',()=>{
 const make=()=>{const scene=manageLocalMatrix(new T.Scene()),roots=[];for(let i=0;i<20;i++){const root=manageLocalMatrix(new T.Group());root.position.x=i;commitLocalMatrix(root);scene.add(root);for(let j=0;j<8;j++){const o=manageLocalMatrix(new T.Group());o.position.y=j;commitLocalMatrix(o);root.add(o);}roots.push(root);}scene.updateMatrixWorld(true);return{scene,roots};};
 setManagedMatrixReuse(false);const a=make(),b=make();
 const pose=(f,frame)=>{for(const [i,root]of f.roots.entries())for(const [j,o]of root.children.entries()){if(i%3===0&&j%2===0)o.quaternion.setFromAxisAngle(new T.Vector3(0,1,0),frame*.013+i+j);commitLocalMatrix(o);}f.scene.updateMatrixWorld();};
 try{for(let i=0;i<80;i++){setManagedMatrixReuse(false);pose(a,i);setManagedMatrixReuse(true);pose(b,i);const x=[],y=[];a.scene.traverse(o=>x.push(o));b.scene.traverse(o=>y.push(o));for(let j=0;j<x.length;j++){assert.deepEqual(x[j].matrix.elements,y[j].matrix.elements);assert.deepEqual(x[j].matrixWorld.elements,y[j].matrixWorld.elements);}}}finally{setManagedMatrixReuse(false);}
});
