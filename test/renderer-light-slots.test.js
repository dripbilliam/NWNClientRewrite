import test from 'node:test';import assert from 'node:assert/strict';import {Scene,PointLight} from 'three';import {RendererLightSlots} from '../src/renderer_light_slots.js';
test('transient lights reuse neutral uniform slots without changing actual light colors, priorities or shadows',()=>{
 const scene=new Scene(),lights=Array.from({length:10},()=>new PointLight(0x123456,2));for(const light of lights){light.castShadow=true;light.userData.priority=4;scene.add(light);}const original=lights.map(l=>[l.color.toArray(),l.intensity,l.castShadow,l.userData.priority]),events=[],slots=new RendererLightSlots({capabilities:{maxFragmentUniforms:1024}},(...a)=>events.push(a));
 assert.deepEqual(slots.update(scene).point,{actual:10,capacity:16,padding:6});const fx=[new PointLight(0x123456,2),new PointLight(0x123456,2)];scene.add(...fx);assert.deepEqual(slots.update(scene).point,{actual:12,capacity:16,padding:4});scene.remove(...fx);assert.deepEqual(slots.update(scene).point,{actual:10,capacity:16,padding:6});
 assert.deepEqual(lights.map(l=>[l.color.toArray(),l.intensity,l.castShadow,l.userData.priority]),original);assert.equal(events.length,1);assert.ok([...slots.slots.values()].flat().every(l=>l.intensity===0&&!l.castShadow));slots.dispose();assert.deepEqual(scene.children,lights);
});
test('uniform capacity never drops real lights when hardware has no padding room',()=>{
 const scene=new Scene(),lights=Array.from({length:20},()=>new PointLight());scene.add(...lights);const slots=new RendererLightSlots({capabilities:{maxFragmentUniforms:128}},()=>{});assert.deepEqual(slots.update(scene).point,{actual:20,capacity:20,padding:0});assert.ok(lights.every(l=>l.parent===scene));slots.dispose();
});
