import {test} from 'node:test';
import assert from 'node:assert/strict';
import * as T from 'three';
import {NullEngine} from '@babylonjs/core/Engines/nullEngine.js';
import {WebGPUShaderProcessorWGSL} from '@babylonjs/core/Engines/WebGPU/webgpuShaderProcessorsWGSL.js';
import {WebGPUShaderProcessingContext} from '@babylonjs/core/Engines/WebGPU/webgpuShaderProcessingContext.js';
import {Initialize,Process,Finalize} from '@babylonjs/core/Engines/Processors/shaderProcessor.js';
import {BabylonRoomAdapter,roomDrawRange,roomTexturePixels} from '../performance-candidates/babylon-room-adapter.mjs';
import {capturePreparedRoomLights} from '../performance-candidates/babylon-room-audit.mjs';

function sample(){const geometry=new T.BoxGeometry(),material=new T.MeshLambertMaterial({color:0x987654}),object=new T.Mesh(geometry,material);object.position.set(3,4,-2);object.scale.set(1,2,3);object.updateMatrixWorld(true);return{object,geometry,material,group:null};}
function camera(){const camera=new T.PerspectiveCamera(60,1,.1,100);camera.position.set(0,3,12);camera.lookAt(0,0,0);camera.updateMatrixWorld(true);return camera;}
function engine(){return new NullEngine({renderWidth:64,renderHeight:64,textureSize:64,deterministicLockstep:false,lockstepMaxSteps:4});}
test('Babylon adapter preserves shared geometry, draw groups, source ownership and mutable world poses',()=>{
 const native=engine(),first=sample(),second={...first,object:first.object.clone(),group:first.geometry.groups[1]};second.object.updateMatrixWorld(true);
 const adapter=new BabylonRoomAdapter({engine:native,items:[first,second]});try{
  const view=camera();adapter.update(view);assert.equal(adapter.snapshot().draws,2);assert.equal(adapter.snapshot().geometries,1);
  assert.equal(adapter.rows[0].mesh.geometry,adapter.rows[1].mesh.geometry);assert.equal(adapter.rows[1].mesh.subMeshes[0].indexStart,6);
  assert.deepEqual(Array.from(adapter.rows[0].world.m),first.object.matrixWorld.elements);
  first.object.position.x=8;first.object.updateMatrixWorld(true);adapter.update(view);assert.equal(adapter.rows[0].world.m[12],8);
  first.geometry.attributes.position.setX(0,12);first.geometry.attributes.position.needsUpdate=true;adapter.update(view);
  assert.equal(adapter.rows[0].mesh.getVerticesData('position')[0],12);
  assert.equal(first.geometry.index.count,36);assert.equal(first.material.disposed,undefined);assert.equal(adapter.snapshot().fullGameParity,false);
 }finally{adapter.dispose();adapter.dispose();assert.throws(()=>adapter.update(camera()),/disposed/);assert.equal(first.geometry.attributes.position.count,24);native.dispose();}
});
test('Babylon adapter keeps camera matrices and native negative light decay without reinterpretation',()=>{
 const native=engine(),item=sample(),point={position:new T.Vector3(2,3,4),color:new T.Color(.5,.25,.75),decay:-.125,distance:-6},lightState={point:[point],ambient:[.1,.2,.3]};
 const adapter=new BabylonRoomAdapter({engine:native,items:[item],lightState});try{const view=camera();adapter.update(view);assert.deepEqual(Array.from(adapter.view.m),Array.from(Float32Array.from(view.matrixWorldInverse.elements)));assert.equal(adapter.lightData[3],-.125);assert.equal(adapter.lightData[7],-6);assert.equal(adapter.ambient.w,1);assert.throws(()=>adapter.update(view,{point:[point,point],ambient:[0,0,0]}),/topology/);}finally{adapter.dispose();native.dispose();}
});
test('Texture decode copies data and draw ranges intersect groups instead of drawing extra triangles',()=>{
 const source=new T.DataTexture(Uint8Array.of(1,2,3,4,5,6,7,8),2,1);const pixels=roomTexturePixels(source);pixels.data[0]=255;assert.equal(source.image.data[0],1);assert.deepEqual(roomTexturePixels(null).data,Uint8Array.of(255,255,255,255));
 const item=sample();item.geometry.setDrawRange(4,10);assert.deepEqual(roomDrawRange(item.geometry,{start:6,count:12}),{begin:6,count:8});assert.throws(()=>roomTexturePixels(new T.Texture()),/unsupported/);
});
test('Unknown materials are reported; geometry capacity changes fail explicitly',()=>{
 const native=engine(),item=sample(),unsupported={...item,material:new T.MeshPhongMaterial()};const adapter=new BabylonRoomAdapter({engine:native,items:[item,unsupported]});try{assert.equal(adapter.snapshot().excluded['unsupported-material'],1);item.geometry.setAttribute('position',new T.Float32BufferAttribute([0,0,0],3));assert.throws(()=>adapter.update(camera()),/topology/);}finally{adapter.dispose();native.dispose();}
});
test('Native WGSL runs through Babylon shader preprocessing without a GPU or remote compiler',()=>{
 const native=engine(),adapter=new BabylonRoomAdapter({engine:native,items:[sample()]}),oldStages=globalThis.GPUShaderStage;
 try{
  globalThis.GPUShaderStage={VERTEX:1,FRAGMENT:2,COMPUTE:4};
  const processor=new WebGPUShaderProcessorWGSL(),processingContext=new WebGPUShaderProcessingContext(1),options={defines:[],indexParameters:{},isFragment:false,shouldUseHighPrecisionShader:true,supportsUniformBuffers:true,shadersRepository:'',includesShadersStore:{},processor,version:'300',platformName:'WEBGPU',processingContext,isNDCHalfZRange:true,useReverseDepthBuffer:false};
  Initialize(options);const path=adapter.rows[0].material.shaderPath;let vertex,fragment;Process(path.vertexSource,options,code=>vertex=code,native);Process(path.fragmentSource,{...options,isFragment:true},code=>fragment=code,native);const compiled=Finalize(vertex,fragment,options);
  assert.match(compiled.vertexCode,/@builtin\(position\)/);assert.match(compiled.fragmentCode,/@group\(/);assert.match(compiled.fragmentCode,/return fragmentOutputs/);assert.ok(processingContext.availableBuffers.nwnFrame);assert.ok(!processingContext.leftOverUniforms.some(v=>v.name==='lightData'));assert.ok(!compiled.vertexCode.includes('uniform sourceView:'));
 }finally{if(oldStages===undefined)delete globalThis.GPUShaderStage;else globalThis.GPUShaderStage=oldStages;adapter.dispose();native.dispose();}
});
test('Replacement attributes are uploaded and changed index topology is rejected',()=>{
 const native=engine(),item=sample(),adapter=new BabylonRoomAdapter({engine:native,items:[item]});try{
  adapter.update(camera());const replacement=item.geometry.attributes.position.clone();replacement.setX(0,7);item.geometry.setAttribute('position',replacement);adapter.update(camera());assert.equal(adapter.rows[0].mesh.getVerticesData('position')[0],7);
  item.geometry.index.needsUpdate=true;assert.throws(()=>adapter.update(camera()),/index topology/);
 }finally{adapter.dispose();native.dispose();}
});
test('Stable poses are reused while camera and mirrored world changes invalidate the correct owners',()=>{
 const native=engine(),item=sample(),view=camera(),adapter=new BabylonRoomAdapter({engine:native,items:[item]});try{
  adapter.update(view);assert.equal(adapter.rows[0].mesh._getWorldMatrixDeterminant(),6);adapter.update(view);assert.deepEqual(adapter.poseStats,{worldUpdates:0,normalUpdates:0,worldReused:1,normalReused:1});
  item.object.scale.x=-1;item.object.updateMatrixWorld(true);adapter.update(view);assert.equal(adapter.rows[0].mesh._getWorldMatrixDeterminant(),-6);assert.equal(adapter.poseStats.worldUpdates,1);assert.equal(adapter.poseStats.normalUpdates,1);
  view.rotation.y=.2;view.updateMatrixWorld(true);adapter.update(view);assert.equal(adapter.poseStats.worldUpdates,0);assert.equal(adapter.poseStats.normalUpdates,1);
 }finally{adapter.dispose();native.dispose();}
});
test('Prepared lights are copied during the owned pass and the prior hook survives success and failure',()=>{
 const scene={},view={},point={position:new T.Vector3(2,3,4),color:new T.Color(.1,.2,.3),decay:-.25,distance:5};let state=null,calls=0;const previous=()=>calls++,api={afterPass:previous,getState:()=>state},renderer={nwnDrawAPI:api};
 const draw=()=>{state={lights:{state:{point:[point],ambient:[.1,.2,.3]}}};api.afterPass(scene,view);state=null;};const copy=capturePreparedRoomLights({renderer,scene,camera:view,draw});point.position.x=9;assert.equal(copy.point[0].position.x,2);assert.equal(api.afterPass,previous);assert.equal(calls,1);
 assert.throws(()=>capturePreparedRoomLights({renderer,scene,camera:view,draw:()=>{throw Error('draw failed');}}),/draw failed/);assert.equal(api.afterPass,previous);
});
