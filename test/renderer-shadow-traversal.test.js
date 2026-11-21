import test from 'node:test';import assert from 'node:assert/strict';
import {Scene,Group,Mesh,BoxGeometry,MeshLambertMaterial,PointLight,DirectionalLight,PerspectiveCamera,PCFSoftShadowMap,VSMShadowMap} from 'three';
import {RendererShadowTraversal} from '../src/renderer_shadow_traversal.js';
function fixture(){
 const calls=[],map={enabled:true,autoUpdate:true,needsUpdate:false,type:PCFSoftShadowMap,render(lights,scene){calls.push({lights:[...lights],scene,children:[...scene.children]});this.needsUpdate=false;}},adapter=new RendererShadowTraversal({shadowMap:map}),scene=new Scene(),camera=new PerspectiveCamera(),light=new PointLight(0xffffff,1,10);light.castShadow=true;scene.add(light);
 const mesh=x=>{const m=new Mesh(new BoxGeometry(),new MeshLambertMaterial());m.castShadow=true;m.position.x=x;scene.add(m);return m;};
 function render(lights=[light]){scene.updateMatrixWorld(true);map.render(lights,scene,camera);return calls.at(-1);}
 render();calls.length=0;return{calls,map,adapter,scene,camera,light,mesh,render};
}
test('conservative point shadow lists preserve parents and cube corners, skip distant casters',()=>{
 const f=fixture(),near=f.mesh(2),far=f.mesh(100),corner=f.mesh(9),unbounded=f.mesh(200);corner.position.set(9,9,9);unbounded.frustumCulled=false;
 const parent=near.parent,children=[...f.scene.children],result=f.render();assert.deepEqual(result.children,[near,corner,unbounded]);assert.equal(near.parent,parent);assert.deepEqual(f.scene.children,children);assert.equal(f.adapter.proxy.children.length,0);assert.equal(f.adapter.snapshot().casters,4);assert.equal(f.adapter.snapshot().admitted,3);
 far.position.set(0,0,0);near.position.x=100;assert.deepEqual(f.render().children,[far,corner,unbounded]);f.scene.remove(far);assert.deepEqual(f.render().children,[corner,unbounded]);
});
test('visibility, layers, nonleaf meshes and changing geometry follow current scene state',()=>{
 const f=fixture(),hidden=f.mesh(0),excluded=f.mesh(0),branch=f.mesh(100),child=f.mesh(0),deforming=f.mesh(100);hidden.visible=false;excluded.layers.set(1);branch.add(child);const invisible=new Group();invisible.visible=false;invisible.add(f.mesh(0));f.scene.add(invisible);
 assert.deepEqual(f.render().children,[branch]);deforming.geometry.attributes.position.array.fill(-100);deforming.geometry.computeBoundingSphere();assert.deepEqual(f.render().children,[branch]);
 deforming.position.set(100,100,100);assert.deepEqual(f.render().children,[branch,deforming]);assert.equal(child.parent,branch);
});
test('type transitions, VSM and directional lights retain the original path; explicit update covers all lights',()=>{
 const f=fixture(),second=new PointLight(0xffffff,1,10),directional=new DirectionalLight();f.scene.add(second,directional);f.mesh(0);
 f.map.type=VSMShadowMap;assert.equal(f.render([f.light,second]).scene,f.scene);assert.equal(f.render().scene,f.scene);f.map.type=PCFSoftShadowMap;assert.equal(f.render().scene,f.scene);assert.equal(f.render([directional]).scene,f.scene);
 f.map.autoUpdate=false;f.map.needsUpdate=true;f.calls.length=0;f.render([f.light,second]);assert.equal(f.calls.length,2);assert.equal(f.map.needsUpdate,false);
 const original=f.adapter.original;f.adapter.dispose();assert.equal(f.map.render,original);
});
test('a failed shadow draw releases proxy references and retains an explicitly requested retry',()=>{
 const f=fixture();f.mesh(0);f.map.needsUpdate=true;f.adapter.original=()=>{throw Error('test draw failure');};assert.throws(()=>f.render(),/test draw failure/);assert.equal(f.map.needsUpdate,true);assert.equal(f.adapter.proxy.children.length,0);
});
test('context restoration attaches to Three replacement shadow owner and disposal restores it',()=>{
 const canvas=new EventTarget(),oldRender=()=>{},newRender=()=>{},oldMap={render:oldRender},newMap={render:newRender},renderer={shadowMap:oldMap,domElement:canvas};const adapter=new RendererShadowTraversal(renderer);renderer.shadowMap=newMap;canvas.dispatchEvent(new Event('webglcontextrestored'));assert.equal(oldMap.render,oldRender);assert.equal(newMap.render,adapter.wrapper);assert.equal(adapter.original,newRender);assert.equal(adapter.type,null);adapter.dispose();assert.equal(newMap.render,newRender);
});
