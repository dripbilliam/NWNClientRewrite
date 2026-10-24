import test from 'node:test';import assert from 'node:assert/strict';
import * as T from 'three';import {RendererLightUniforms} from '../src/renderer_light_uniforms.js';
function fixture(){
 const scene=new T.Scene(),camera=new T.PerspectiveCamera(),properties=new WeakMap(),programA={},programB={},materials=[new T.MeshLambertMaterial(),new T.MeshLambertMaterial(),new T.MeshLambertMaterial()],objects=materials.map(m=>new T.Mesh(new T.BufferGeometry(),m)),list={opaque:objects.map(o=>({object:o,material:o.material})),transparent:[],transmissive:[]};
 materials.forEach((m,i)=>properties.set(m,{needsLights:true,currentProgram:i===1?programB:programA,uniforms:{pointLights:{value:[]},spotLightMatrix:{value:[]},pointShadowMatrix:{value:[]},directionalShadowMatrix:{value:[]},pointShadowMap:{value:[]}}}));
 const original=()=>{},renderer={properties:{get:m=>properties.get(m)},shadowMap:{render:original},renderLists:{get:()=>list},xr:{enabled:false},domElement:new T.EventDispatcher()};
 const owner=new RendererLightUniforms(renderer),uniforms=materials.map(m=>properties.get(m).uniforms);
 const pass=fn=>owner.render(scene,camera,()=>{renderer.shadowMap.render([],scene,camera);return fn();});return{scene,camera,properties,programA,programB,materials,objects,list,renderer,owner,uniforms,pass,original};
}
test('numeric lights are cached per program and pass, while samplers remain ordinary',()=>{
 const f=fixture();const run=()=>f.pass(()=>{
  const values=[];for(const u of f.uniforms){u.pointShadowMatrix.needsUpdate=true;u.spotLightMatrix.needsUpdate=true;values.push([u.pointShadowMatrix.needsUpdate,u.spotLightMatrix.needsUpdate,u.directionalShadowMatrix.needsUpdate,u.pointShadowMap.needsUpdate]);}return values;
 });
 const expected=[[true,true,undefined,undefined],[true,true,undefined,undefined],[false,false,false,undefined]];
 assert.deepEqual(run(),expected);assert.deepEqual(run(),expected);assert.equal(f.owner.snapshot().skipped,3);
 assert.equal(f.uniforms[2].pointShadowMatrix.needsUpdate,true);assert.equal(Object.getOwnPropertyDescriptor(f.uniforms[0].pointShadowMap,'needsUpdate'),undefined);
 f.owner.dispose();assert.equal(f.owner.records.size,0);assert.equal(Object.getOwnPropertyDescriptor(f.uniforms[0].pointShadowMatrix,'needsUpdate'),undefined);assert.equal(f.renderer.shadowMap.render,f.original);
});
test('false flags do not consume first upload, and a new program receives its own data',()=>{
 const f=fixture();f.pass(()=>{const u=f.uniforms[0];u.pointShadowMatrix.needsUpdate=false;assert.equal(u.pointShadowMatrix.needsUpdate,false);u.pointShadowMatrix.needsUpdate=true;assert.equal(u.pointShadowMatrix.needsUpdate,true);assert.equal(u.pointShadowMatrix.needsUpdate,false);f.properties.get(f.materials[0]).currentProgram={};assert.equal(u.pointShadowMatrix.needsUpdate,true);});f.owner.dispose();
});
test('unknown draw/texture callbacks and unsupported cameras fall back without suppressing uniforms',()=>{
 const f=fixture();f.pass(()=>{});
 const read=()=>{for(const u of f.uniforms){u.pointShadowMatrix.needsUpdate=true;assert.equal(u.pointShadowMatrix.needsUpdate,true);}};
 f.objects[1].onBeforeRender=()=>{};f.pass(read);assert.equal(f.owner.snapshot().fallback,'render-callback');f.objects[1].onBeforeRender=T.Object3D.prototype.onBeforeRender;
 const texture=new T.Texture();texture.onUpdate=()=>{};f.materials[0].map=texture;f.pass(read);assert.equal(f.owner.snapshot().fallback,'render-callback');f.materials[0].map=null;
 f.owner.render(f.scene,new T.ArrayCamera(),read);assert.equal(f.owner.snapshot().fallback,'unsupported-pass');f.owner.dispose();
});
test('uniform replacement, retired materials, exceptions and context loss release descriptors',()=>{
 const f=fixture();f.pass(()=>{});const old=f.uniforms[0];f.properties.get(f.materials[0]).uniforms={pointShadowMatrix:{value:[]}};f.pass(()=>{});assert.equal(Object.getOwnPropertyDescriptor(old.pointShadowMatrix,'needsUpdate'),undefined);
 f.list.opaque.pop();f.pass(()=>{});assert.equal(f.owner.records.size,2);
 assert.throws(()=>f.pass(()=>{throw Error('draw failed');}),/draw failed/);assert.equal(f.owner.active,false);assert.equal(f.renderer.shadowMap.render,f.original);
 f.renderer.domElement.dispatchEvent({type:'webglcontextlost'});assert.equal(f.owner.records.size,0);f.owner.dispose();
});
test('nested rendering bypasses the cache and invalidates the surrounding pass',()=>{
 const f=fixture();f.pass(()=>{const u=f.uniforms[0];u.pointShadowMatrix.needsUpdate=true;assert.equal(u.pointShadowMatrix.needsUpdate,true);assert.equal(u.pointShadowMatrix.needsUpdate,false);f.owner.render(f.scene,f.camera,()=>assert.equal(u.pointShadowMatrix.needsUpdate,true));assert.equal(u.pointShadowMatrix.needsUpdate,true);});f.owner.dispose();
});
