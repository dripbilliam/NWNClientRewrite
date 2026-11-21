import test from 'node:test';import assert from 'node:assert/strict';import * as THREE from 'three';
import {RendererShadowBudget} from '../src/renderer_shadow_budget.js';import {createModelLight,setModelLightShadows} from '../src/model_light.js';
test('GPU shadow budget accounts for material samplers, restores requests and never removes lighting',()=>{
 const scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(),diagnostics=[],renderer={capabilities:{maxTextures:4}},budget=new RendererShadowBudget({renderer,report:(...r)=>diagnostics.push(r)}),material=new THREE.MeshLambertMaterial({map:new THREE.Texture(),lightMap:new THREE.Texture()}),mesh=new THREE.Mesh(new THREE.BoxGeometry(),material);scene.add(mesh);const lights=[];
 for(let i=0;i<5;i++){const light=createModelLight({name:'light'+i,properties:{color:[1,1,1],radius:10,shadow:1,isdynamic:1}});light.position.x=i;scene.add(light);lights.push(light);}
 const authored=lights.map(l=>({...l.userData.mdlLight})),intensities=lights.map(l=>l.intensity);assert.deepEqual(budget.update(scene,camera),{maxTextures:4,reserved:2,requested:5,admitted:2,limited:3});assert.deepEqual(lights.map(l=>l.castShadow),[true,true,false,false,false]);assert.deepEqual(lights.map(l=>l.intensity),intensities);assert.deepEqual(lights.map(l=>l.userData.mdlLight),authored);
 setModelLightShadows(lights[4],false);renderer.capabilities.maxTextures=8;budget.update(scene,camera);assert.deepEqual(lights.map(l=>l.castShadow),[true,true,true,true,false]);setModelLightShadows(lights[4],true);budget.update(scene,camera);assert.equal(lights[4].castShadow,true);
 renderer.capabilities.maxTextures=4;camera.position.x=4;budget.update(scene,camera);assert.deepEqual(lights.map(l=>l.castShadow),[false,false,false,true,true]);assert.ok(diagnostics.length);for(const l of lights)l.visible=false;assert.equal(budget.update(scene,camera).requested,0);
});
test('cached texture field schemas retain live map and custom uniform sampler accounting',()=>{
 const budget=new RendererShadowBudget({renderer:{},report:()=>{}}),material=new THREE.MeshLambertMaterial(),texture=new THREE.Texture();
 const legacy=m=>Object.values(m).filter(v=>v?.isTexture).length+Object.values(m.uniforms??{}).reduce((n,u)=>n+(u.value?.isTexture?1:Array.isArray(u.value)?u.value.filter(v=>v?.isTexture).length:0),0);
 const check=()=>assert.equal(budget.materialTextures(material),legacy(material));check();material.map=texture;check();material.lightMap=texture;check();material.map=null;check();
 material.uniforms={samplers:{value:[texture,null,texture]}};check();material.uniforms.samplers.value.push(texture);check();material.uniforms.extra={value:texture};check();material.extraTexture=texture;material.needsUpdate=true;check();material.extraTexture=null;check();
});
test('shared materials are scanned once per pass while new frames retain live sampler changes',()=>{
 const scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(),budget=new RendererShadowBudget({renderer:{capabilities:{maxTextures:8}},report:()=>{}}),a=new THREE.MeshLambertMaterial(),b=new THREE.MeshLambertMaterial(),texture=new THREE.Texture(),geometry=new THREE.BufferGeometry();
 for(let i=0;i<24;i++)scene.add(new THREE.Mesh(geometry,i%2?[a,b,a]:a));
 let scans=[];const read=budget.materialTextures.bind(budget);budget.materialTextures=m=>{scans.push(m);return read(m);};
 const check=reserved=>{scans=[];assert.equal(budget.update(scene,camera).reserved,reserved);assert.deepEqual(scans,[a,b]);};check(1);
 a.map=texture;a.lightMap=texture;check(2);a.uniforms={samplers:{value:[texture,texture]}};check(4);a.uniforms.samplers.value.push(texture);check(5);
 a.map=null;a.lightMap=null;a.uniforms.samplers.value=[];scene.environment=texture;check(1);b.envMap=texture;b.lightMap=texture;check(2);
 b.extraTexture=texture;b.needsUpdate=true;check(3);b.extraTexture=null;b.envMap=null;b.lightMap=null;scene.environment=null;check(1);
});
