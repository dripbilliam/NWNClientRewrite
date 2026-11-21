import {PerspectiveCamera} from 'three';import {RendererShadowBudget} from '../src/renderer_shadow_budget.js';
import test from 'node:test';import assert from 'node:assert/strict';import {Scene,PointLight} from 'three';import {RendererLightSlots,prepareRendererLights,renderPreparedScene} from '../src/renderer_light_slots.js';
import {RendererLightSelection} from '../src/renderer_light_selection.js';
import {Group,Mesh,BoxGeometry,MeshLambertMaterial,Texture} from 'three';

test('area capacity is bounded by the selected pool and resets before a smaller area',()=>{
 const scene=new Scene(),camera=new PerspectiveCamera(),renderer={capabilities:{maxFragmentUniforms:1024,maxTextures:16}},slots=new RendererLightSlots(renderer,()=>{}),lights=Array.from({length:63},()=>new PointLight());scene.add(...lights);
 const selection={total:140,disabled:0,admitted:63,maxLights:128},first=slots.update(scene,camera,{lightSelection:selection});assert.equal(first.point.capacity,128);
 scene.remove(...lights.slice(3));assert.equal(slots.update(scene,camera,{lightSelection:{total:3,disabled:0,admitted:3,maxLights:128}}).point.capacity,128);
 slots.reset();assert.equal(slots.update(scene,camera,{lightSelection:{total:3,disabled:0,admitted:3,maxLights:128}}).point.capacity,4);assert.ok(lights.every(l=>l.intensity===1));slots.dispose();
});

test('one frame matrix pass supplies current animated meshes and newly positioned light slots to drawing',()=>{
 const scene=new Scene(),parent=new Group(),mesh=new Mesh(new BoxGeometry(),new MeshLambertMaterial()),light=new PointLight(),camera=new PerspectiveCamera();parent.add(mesh,light);scene.add(parent);
 const renderer={capabilities:{maxFragmentUniforms:1024,maxTextures:16},render(s){if(s.matrixWorldAutoUpdate)s.updateMatrixWorld();assert.equal(mesh.matrixWorld.elements[12],parent.position.x+mesh.position.x);}},lightSlots=new RendererLightSlots(renderer,()=>{}),shadowBudget=new RendererShadowBudget({renderer,report:()=>{}}),lightSelection=new RendererLightSelection();
 const update=scene.updateMatrixWorld;let passes=0;scene.updateMatrixWorld=function(...args){passes++;return update.apply(this,args);};
 for(let i=0;i<4;i++){parent.position.x=i;mesh.position.x=2*i;light.castShadow=true;const p=prepareRendererLights(scene,camera,{lightSlots,shadowBudget,lightSelection});renderPreparedScene(renderer,scene,camera,p);assert.equal(passes,i+1);assert.equal(scene.matrixWorldAutoUpdate,true);const padded=lightSlots.slots.get('point').filter(l=>l.castShadow);assert.ok(padded.length);assert.ok(padded.every(l=>l.matrixWorld.elements[12]===1e6));}
 renderer.render=()=>{throw Error('draw failed');};assert.throws(()=>renderPreparedScene(renderer,scene,camera,{worldMatricesReady:true}),/draw failed/);assert.equal(scene.matrixWorldAutoUpdate,true);scene.matrixWorldAutoUpdate=false;assert.throws(()=>renderPreparedScene(renderer,scene,camera,{worldMatricesReady:true}),/draw failed/);assert.equal(scene.matrixWorldAutoUpdate,false);lightSelection.dispose();lightSlots.dispose();
});

test('shared frame membership observes hidden parents, changed samplers and added/removed lights',()=>{
 const renderer={capabilities:{maxFragmentUniforms:1024,maxTextures:16}},scene=new Scene(),camera=new PerspectiveCamera(),lightSlots=new RendererLightSlots(renderer,()=>{}),shadowBudget=new RendererShadowBudget({renderer,report:()=>{}}),group=new Group(),light=new PointLight(),material=new MeshLambertMaterial();
 light.castShadow=true;group.add(light,new Mesh(new BoxGeometry(),material));scene.add(group);
 const update=()=>prepareRendererLights(scene,camera,{shadowBudget,lightSlots});
 assert.equal(update().shadows.requested,1);
 group.visible=false;assert.equal(update().slots.point.actual,0);
 group.visible=true;material.map=new Texture();material.alphaMap=new Texture();
 assert.equal(update().shadows.reserved,2);
 group.remove(light);assert.equal(update().shadows.requested,0);
 group.add(light);assert.equal(update().shadows.requested,1);lightSlots.dispose();
});

test('prepared light admission matches live world queries for parented moving lights and an external camera',()=>{
 const make=()=>{const scene=new Scene(),parent=new Group(),cameraParent=new Group(),camera=new PerspectiveCamera(60,1,.1,300),renderer={capabilities:{maxFragmentUniforms:1024,maxTextures:8}},lightSlots=new RendererLightSlots(renderer,()=>{}),shadowBudget=new RendererShadowBudget({renderer,report:()=>{}}),lightSelection=new RendererLightSelection(),lights=[];
  cameraParent.add(camera);camera.position.set(0,4,20);camera.lookAt(0,0,0);scene.add(parent);
  for(let i=0;i<24;i++){const l=new PointLight();l.userData.mdlLight={radius:8,multiplier:1,color:[.3,.6,.7],isdynamic:1};l.userData.mdlLightShadowRequested=true;l.castShadow=true;l.position.set(i%6*3-8,0,Math.floor(i/6)*3-5);lights.push(l);parent.add(l);}
  return{scene,parent,cameraParent,camera,renderer,lightSlots,shadowBudget,lightSelection,lights};};
 const ready=make(),reference=make(),pose=(s,i)=>{s.parent.position.set(Math.sin(i)*5,2,-i*.2);s.parent.rotation.y=i*.08;s.parent.scale.set(i%2?-1:1,1.3,.7);s.cameraParent.position.x=Math.sin(i*.3)*10;s.cameraParent.rotation.y=i*.01;for(const [j,l]of s.lights.entries()){l.position.y=Math.sin(i+j);l.castShadow=true;}s.parent.visible=i%7!==0;};
 for(let i=0;i<40;i++){
  pose(ready,i);pose(reference,i);for(const l of ready.lights)l.getWorldPosition=()=>assert.fail('prepared light redundantly updated its ancestor chain');ready.camera.getWorldPosition=()=>assert.fail('prepared camera was redundantly queried');
  const actual=prepareRendererLights(ready.scene,ready.camera,ready),selection=reference.lightSelection.update(reference.scene,reference.camera),shadows=reference.shadowBudget.update(reference.scene,reference.camera),slots=reference.lightSlots.update(reference.scene,reference.camera,{shadowBudget:shadows,lightSelection:selection});
  assert.deepEqual(actual.selection,selection);assert.deepEqual(actual.shadows,shadows);assert.deepEqual(actual.slots,slots);assert.deepEqual(ready.lights.map(l=>[l.layers.mask,l.castShadow]),reference.lights.map(l=>[l.layers.mask,l.castShadow]));
 }
 for(const s of [ready,reference]){s.lightSelection.dispose();s.lightSlots.dispose();}
});
test('transient lights reuse neutral uniform slots without changing actual light colors, priorities or shadows',()=>{
 const scene=new Scene(),lights=Array.from({length:10},()=>new PointLight(0x123456,2));for(const light of lights){light.castShadow=true;light.userData.priority=4;scene.add(light);}const original=lights.map(l=>[l.color.toArray(),l.intensity,l.castShadow,l.userData.priority]),events=[],slots=new RendererLightSlots({capabilities:{maxFragmentUniforms:1024}},(...a)=>events.push(a));
 assert.deepEqual(slots.update(scene).point,{actual:10,capacity:16,padding:6});const fx=[new PointLight(0x123456,2),new PointLight(0x123456,2)];scene.add(...fx);assert.deepEqual(slots.update(scene).point,{actual:12,capacity:16,padding:4});scene.remove(...fx);assert.deepEqual(slots.update(scene).point,{actual:10,capacity:16,padding:6});
 assert.deepEqual(lights.map(l=>[l.color.toArray(),l.intensity,l.castShadow,l.userData.priority]),original);assert.equal(events.length,1);assert.ok([...slots.slots.values()].flat().every(l=>l.intensity===0&&!l.castShadow));slots.dispose();assert.deepEqual(scene.children,lights);
});
test('uniform capacity never drops real lights when hardware has no padding room',()=>{
 const scene=new Scene(),lights=Array.from({length:20},()=>new PointLight());scene.add(...lights);const slots=new RendererLightSlots({capabilities:{maxFragmentUniforms:128}},()=>{});assert.deepEqual(slots.update(scene).point,{actual:20,capacity:20,padding:0});assert.ok(lights.every(l=>l.parent===scene));slots.dispose();
});

test('captured academy-sized light changes retain one profile with separately budgeted shadow uniforms',()=>{
 const scene=new Scene(),lights=Array.from({length:155},(_,i)=>{const l=new PointLight(0x123456,2);l.castShadow=i<15;return l;});scene.add(...lights);const slots=new RendererLightSlots({capabilities:{maxFragmentUniforms:1024}},()=>{}),baseline=slots.update(scene).point;
 assert.equal(baseline.actual,155);assert.ok(baseline.capacity>=178);assert.ok(baseline.capacity*4+128+15*8<=1024);
 const transient=Array.from({length:23},()=>new PointLight(0xff00ff,3));scene.add(...transient);assert.equal(slots.update(scene).point.capacity,baseline.capacity);scene.remove(...transient);assert.equal(slots.update(scene).point.capacity,baseline.capacity);assert.equal(lights.filter(l=>l.castShadow).length,15);assert.ok(lights.every(l=>l.parent===scene&&l.intensity===2));slots.dispose();
});

test('frame integration budgets admitted shadows even when animation restores all authored requests',()=>{
 const scene=new Scene(),camera=new PerspectiveCamera(),renderer={capabilities:{maxFragmentUniforms:1024,maxTextures:16}},lightSlots=new RendererLightSlots(renderer,()=>{}),shadowBudget=new RendererShadowBudget({renderer,report:()=>{}}),lights=Array.from({length:155},(_,i)=>{const l=new PointLight();l.castShadow=i<83;l.userData.mdlLightShadowRequested=l.castShadow;return l;});scene.add(...lights);
 const first=prepareRendererLights(scene,camera,{shadowBudget,lightSlots});assert.equal(first.shadows.admitted,15);assert.ok(first.slots.point.capacity>=178);
 for(const l of lights)l.castShadow=l.userData.mdlLightShadowRequested;const next=prepareRendererLights(scene,camera,{shadowBudget,lightSlots});assert.equal(next.slots.point.capacity,first.slots.point.capacity);assert.equal(lights.filter(l=>l.castShadow).length,15);lightSlots.dispose();
});
test('camera admission changes retain area light and point-shadow shader counts without allocating shadow draws',()=>{
 const renderer={capabilities:{maxFragmentUniforms:1024,maxTextures:16},shadowMap:{type:2}},scene=new Scene(),camera=new PerspectiveCamera(),lightSlots=new RendererLightSlots(renderer,()=>{}),shadowBudget=new RendererShadowBudget({renderer,report:()=>{}}),lights=Array.from({length:77},()=>{const l=new PointLight();l.castShadow=true;scene.add(l);return l;});
 const lightSelection={update(){return{total:77,disabled:0,admitted:lights.filter(l=>l.layers.mask).length,maxLights:128};}};
 const states=[];for(const count of [12,30,4,77,12]){
  lights.forEach((l,i)=>{l.layers.mask=i<count?1:0;l.castShadow=true;});const result=prepareRendererLights(scene,camera,{shadowBudget,lightSlots,lightSelection});states.push(result.slots.point);
  const pads=lightSlots.slots.get('point').filter(l=>l.castShadow);assert.equal(result.shadows.requested,count);assert.equal(pads.length,15-Math.min(15,count));assert.ok(pads.every(l=>l.intensity===0&&!l.shadow.autoUpdate&&!l.shadow.needsUpdate&&l.shadow.map.texture===lightSlots.neutralShadow));assert.ok(lights.every(l=>l.parent===scene));
 }
 assert.ok(states.every(s=>s.capacity===128&&s.shadowCapacity===15));lightSlots.dispose();
});
test('entry reserves authored shadows even before the player camera sees a light',()=>{
 const renderer={capabilities:{maxFragmentUniforms:1024,maxTextures:16},shadowMap:{type:2}},scene=new Scene(),camera=new PerspectiveCamera(),slots=new RendererLightSlots(renderer,()=>{}),light=new PointLight();light.userData.mdlLight={radius:10,multiplier:1,color:[1,1,1]};light.userData.mdlLightShadowRequested=true;light.layers.mask=0;scene.add(light);
 const state=slots.update(scene,camera,{shadowBudget:{maxTextures:16,reserved:1},lightSelection:{total:1,disabled:0,admitted:0,maxLights:128}});assert.equal(state.point.shadowCapacity,15);assert.ok(state.point.capacity>=15);assert.equal(light.layers.mask,0);assert.equal(light.parent,scene);slots.dispose();
});
