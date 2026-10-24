import test from 'node:test';import assert from 'node:assert/strict';import * as T from 'three';
import {RendererFlatScene} from '../src/renderer_flat_scene.js';
function fixture(){const renderer={shadowMap:{render(){}},renderBufferDirect(){},xr:{enabled:false}},scene=new T.Scene(),camera=new T.PerspectiveCamera();scene.matrixWorldAutoUpdate=false;return {renderer,scene,camera,owner:new RendererFlatScene(renderer)};}
const mesh=()=>new T.Mesh(new T.BufferGeometry(),new T.MeshBasicMaterial());
test('compiled projection retains object identity, original parents, order, and full shadow/draw hierarchy',()=>{
 const {renderer,scene,camera,owner}=fixture(),a=new T.Group(),b=new T.Group(),one=mesh(),two=mesh();a.renderOrder=4;b.renderOrder=2;scene.add(a);a.add(one,b);b.add(two);const original=scene.children,shadow=renderer.shadowMap.render,direct=renderer.renderBufferDirect;
 renderer.shadowMap.render=()=>assert.equal(scene.children,original);renderer.renderBufferDirect=()=>assert.equal(scene.children,original);
 owner.render(scene,camera,()=>{assert.deepEqual(scene.children.map(g=>g.renderOrder),[4,2]);assert.deepEqual(scene.children.flatMap(g=>g.children),[one,two]);assert.equal(one.parent,a);renderer.shadowMap.render();renderer.renderBufferDirect();assert.notEqual(scene.children,original);});
 assert.equal(scene.children,original);assert.equal(owner.snapshot().submittedObjects,2);renderer.shadowMap.render=shadow;renderer.renderBufferDirect=direct;owner.dispose();assert.equal(owner.records.length,0);
});
test('direct visibility, layers and group order edits stay live without topology rebuilding',()=>{
 const {scene,camera,owner}=fixture(),a=new T.Group(),b=new T.Group(),one=mesh(),two=mesh();a.renderOrder=5;b.renderOrder=9;scene.add(a);a.add(one,b);b.add(two);owner.prepare(scene,camera);const revision=owner.revision;
 a.visible=false;assert.equal(owner.prepare(scene,camera).length,0);a.visible=true;b.layers.set(2);assert.deepEqual(owner.prepare(scene,camera).map(g=>g.renderOrder),[5]);b.layers.set(0);b.renderOrder=11;assert.deepEqual(owner.prepare(scene,camera).map(g=>g.renderOrder),[5,11]);assert.equal(owner.revision,revision);owner.dispose();
});
test('topology add/remove and reparent rebuild the compiled ancestry',()=>{
 const {scene,camera,owner}=fixture(),a=new T.Group(),b=new T.Group(),one=mesh(),two=mesh();scene.add(a,b);a.add(one);owner.prepare(scene,camera);const revision=owner.revision;b.add(two);assert.equal(owner.prepare(scene,camera).flatMap(g=>g.children).length,2);assert.ok(owner.revision>revision);one.removeFromParent();b.add(one);assert.deepEqual(owner.prepare(scene,camera).flatMap(g=>g.children),[two,one]);owner.dispose();
});
test('renderable subtrees are retained once and unsupported LOD/callback passes use ordinary traversal',()=>{
 const {scene,camera,owner}=fixture(),one=mesh(),two=mesh();one.add(two);scene.add(one);assert.deepEqual(owner.prepare(scene,camera).flatMap(g=>g.children),[one]);two.onBeforeRender=()=>{};assert.equal(owner.prepare(scene,camera),null);two.onBeforeRender=T.Object3D.prototype.onBeforeRender;scene.add(new T.LOD());assert.equal(owner.prepare(scene,camera),null);scene.children.at(-1).removeFromParent();one.onBeforeRender=()=>{};assert.equal(owner.prepare(scene,camera),null);owner.dispose();
});
test('exceptions and nested draws restore hierarchy and renderer methods',()=>{
 const {renderer,scene,camera,owner}=fixture();scene.add(mesh());const children=scene.children,shadow=renderer.shadowMap.render,direct=renderer.renderBufferDirect;
 assert.throws(()=>owner.render(scene,camera,()=>{owner.render(scene,camera,()=>{});throw Error('draw failure');}),/draw failure/);assert.equal(scene.children,children);assert.equal(renderer.shadowMap.render,shadow);assert.equal(renderer.renderBufferDirect,direct);assert.equal(owner.running,false);owner.dispose();
});
