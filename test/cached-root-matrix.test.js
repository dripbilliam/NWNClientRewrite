import test from 'node:test';
import assert from 'node:assert/strict';
import * as T from 'three';
import {cacheRootMatrix} from '../src/cached_root_matrix.js';
import {manageLocalMatrix,commitLocalMatrix} from '../src/managed_local_matrix.js';

function fixture(cached){const scene=new T.Scene(),a=new T.Group(),b=new T.Group(),root=new T.Group(),node=new T.Group(),leaf=new T.Object3D();manageLocalMatrix(scene);manageLocalMatrix(node);scene.add(a,b);a.add(root);root.add(node);node.add(leaf);a.position.set(3,5,7);b.position.set(-2,4,1);b.scale.set(.7,-1.2,.3);if(cached)scene.traverse(cacheRootMatrix);return{scene,a,b,root,node,leaf};}
function equal(a,b){for(const key of ['scene','a','b','root','node','leaf'])for(const field of ['matrix','matrixWorld'])assert.deepEqual(a[key][field].elements,b[key][field].elements,key+'.'+field);}
test('direct transforms, manual matrix edits, reparenting and queries preserve automatic matrix results',()=>{
 const a=fixture(false),b=fixture(true);
 for(let i=0;i<200;i++){
  for(const f of [a,b]){
   if(i%7===0){f.a.position.x=Math.sin(i*.1);f.a.rotation.z=i*.011;}
   if(i%5===0){f.root.position.y=i*.013;f.root.quaternion.setFromAxisAngle(new T.Vector3(1,0,0),i*.01);f.root.scale.x=i%2?-.8:1.1;}
   if(i%11===0){f.node.rotation.x=i*.017;commitLocalMatrix(f.node);}
   if(i===23)f.root.matrix.elements[12]=999;
   if(i===40)f.b.add(f.root);if(i===80)f.root.removeFromParent();if(i===120)f.a.add(f.root);
   if(i===140)f.root.position.z=-0;if(i===141)f.root.position.z=0;
   f.scene.updateMatrixWorld();f.root.updateMatrixWorld();
   if(i%3===0)f.leaf.updateWorldMatrix(true,false);
   if(i%13===0)f.root.updateWorldMatrix(true,true);
  }equal(a,b);
 }
});
test('unchanged wrappers do not force entire managed subtrees, while changed parents still do',()=>{
 const f=fixture(true);f.scene.updateMatrixWorld();let local=0,world=0;f.scene.traverse(o=>{const compose=o.matrix.compose,multiply=o.matrixWorld.multiplyMatrices;o.matrix.compose=function(...args){local++;return compose.apply(this,args);};o.matrixWorld.multiplyMatrices=function(...args){world++;return multiply.apply(this,args);};});
 for(let i=0;i<100;i++)f.scene.updateMatrixWorld();assert.equal(local,0);assert.equal(world,0);
 f.a.position.x=17;f.scene.updateMatrixWorld();assert.equal(local,1);assert.ok(world>=4);assert.equal(f.leaf.matrixWorld.elements[12],17);
 // A clean destination parent must still invalidate a newly reparented root.
 f.b.add(f.root);f.scene.updateMatrixWorld();assert.equal(f.root.matrixWorld.elements[12],-2);
});
test('custom writers, managed nodes, clones and explicit world-matrix policies keep their own contracts',()=>{
 const object=new T.Object3D(),custom=new T.Object3D(),managed=new T.Object3D();custom.updateMatrix=function(){this.matrix.makeTranslation(11,0,0);this.matrixWorldNeedsUpdate=true;};const writer=custom.updateMatrix;manageLocalMatrix(managed);
 assert.equal(cacheRootMatrix(custom),false);assert.equal(custom.updateMatrix,writer);assert.equal(cacheRootMatrix(managed),false);assert.equal(cacheRootMatrix(object),true);assert.equal(cacheRootMatrix(object),false);
 object.position.x=9;object.updateMatrixWorld();const clone=object.clone();assert.equal(clone.updateMatrix,T.Object3D.prototype.updateMatrix);clone.position.x=13;clone.updateMatrixWorld();assert.equal(clone.matrixWorld.elements[12],13);
 object.matrixWorldAutoUpdate=false;object.matrixWorld.makeTranslation(47,0,0);object.position.x=17;object.updateMatrixWorld();assert.equal(object.matrixWorld.elements[12],47);object.matrixWorldAutoUpdate=true;object.updateMatrixWorld(true);assert.equal(object.matrixWorld.elements[12],17);
});
