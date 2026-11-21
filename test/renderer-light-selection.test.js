import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {Scene,PerspectiveCamera,PointLight} from 'three';
import {nativeLightPriority,nativeLightRadius,RendererLightSelection} from '../src/renderer_light_selection.js';
import {RendererLightSlots,prepareRendererLights} from '../src/renderer_light_slots.js';
import {RendererShadowBudget} from '../src/renderer_shadow_budget.js';
import {createModelLight} from '../src/model_light.js';
test('native light priority and adjusted radius match original finite owner cases',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-light-selection-observations.json',import.meta.url)));assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,864);
 for(const row of oracle.rows){const c=row.case,light={...c,owner:7};assert.deepEqual(nativeLightPriority(light,c.focus,{onlyOwner:c.onlyOwner?7:null}),{distance:row.distance,priority:row.priority},JSON.stringify(c));assert.equal(nativeLightRadius(light,c),row.radius,JSON.stringify(c));}
});
function fixture(){const scene=new Scene(),camera=new PerspectiveCamera(45,1,.1,100);camera.position.set(0,0,10);camera.lookAt(0,0,0);return{scene,camera};}
function light(x=0){const l=createModelLight({name:'lamp',properties:{color:[.2,.4,.8],radius:2,multiplier:1,isdynamic:1,affectdynamic:1,lightpriority:4}});l.position.x=x;return l;}
test('view admission preserves source visibility/animated properties and restores original layers after movement and disposal',()=>{
 const {scene,camera}=fixture(),a=light(),b=light(100),plain=new PointLight(),selector=new RendererLightSelection();plain.position.x=100;scene.add(a,b,plain);const original=structuredClone(b.userData);
 assert.deepEqual(selector.update(scene,camera),{total:2,eligible:1,admitted:1,outside:1,disabled:0,limited:0,maxLights:128});assert.equal(a.layers.mask,1);assert.equal(b.layers.mask,0);assert.equal(b.visible,true);assert.deepEqual(b.userData,original);assert.equal(plain.layers.mask,1);
 camera.position.x=100;camera.lookAt(100,0,0);selector.update(scene,camera);assert.equal(a.layers.mask,0);assert.equal(b.layers.mask,1);selector.dispose();assert.equal(a.layers.mask,1);assert.equal(b.layers.mask,1);
});
test('230 in-view native lights are admitted by native score within128 slots before hardware shadow/uniform budgeting',()=>{
 const {scene,camera}=fixture(),lights=Array.from({length:230},(_,i)=>{const l=light(i/100);l.castShadow=true;l.userData.mdlLightShadowRequested=true;return l;});scene.add(...lights);const renderer={capabilities:{maxFragmentUniforms:1024,maxTextures:16}},lightSelection=new RendererLightSelection(),lightSlots=new RendererLightSlots(renderer,()=>{}),shadowBudget=new RendererShadowBudget({renderer,report:()=>{}});
 const first=prepareRendererLights(scene,camera,{lightSelection,lightSlots,shadowBudget,focus:[0,0,0]});assert.equal(first.selection.admitted,128);assert.equal(first.selection.limited,102);assert.equal(first.slots.point.actual,128);assert.equal(first.shadows.admitted,15);assert.ok(first.slots.point.capacity*4+128+15*8<=1024);assert.ok(lights.every(l=>l.parent===scene&&l.visible&&l.userData.mdlLight.radius===2));assert.ok(lights.slice(0,128).every(l=>l.layers.mask===1));
 for(const l of lights)l.castShadow=l.userData.mdlLightShadowRequested;const second=prepareRendererLights(scene,camera,{lightSelection,lightSlots,shadowBudget,focus:[0,0,0]});assert.equal(second.slots.point.capacity,first.slots.point.capacity);assert.equal(second.shadows.admitted,15);lightSelection.dispose();lightSlots.dispose();assert.ok(lights.every(l=>l.layers.mask===1));
});
