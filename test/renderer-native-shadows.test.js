import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {Scene,PerspectiveCamera,Mesh,BoxGeometry,MeshLambertMaterial} from 'three';
import {selectNativeShadows} from '../src/renderer_native_shadows.js';
import {RendererShadowBudget} from '../src/renderer_shadow_budget.js';
import {RendererLightSlots,prepareRendererLights} from '../src/renderer_light_slots.js';
import {createModelLight} from '../src/model_light.js';

test('normal/dynamic shadow selection and shared fade order match 500 original machine-code cases',()=>{
 const report=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-shadow-selection-observations-v1.json',import.meta.url)));
 assert.equal(report.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 assert.equal(report.rows.length,500);
 for(const [index,{case:c,lists,fades:expected}]of report.rows.entries()){
  const fades=new Map(c.fades.map((v,i)=>[i,Math.fround(v)])),records=c.candidates.map(i=>({light:i,distance:Math.fround(c.lights[i].distance),radius:Math.fround(c.lights[i].shadowRadius>0?c.lights[i].shadowRadius:c.lights[i].radius),dynamic:Boolean(c.lights[i].dynamic)}));
  for(const mode of [1,0])assert.deepEqual(selectNativeShadows(records,c.previous[mode],fades,c.maximum,mode,c.delta),lists[mode],`case ${index} mode ${mode}`);
  for(let i=0;i<expected.length;i++)assert.equal(fades.get(i),expected[i],`case ${index} fade ${i}`);
 }
});

function fixture(){
 const scene=new Scene(),camera=new PerspectiveCamera(),renderer={capabilities:{maxTextures:16,maxFragmentUniforms:1024},shadowMap:{type:2}},budget=new RendererShadowBudget({renderer,nativeSelection:true}),slots=new RendererLightSlots(renderer,()=>{}),lights=[];
 scene.add(new Mesh(new BoxGeometry(),new MeshLambertMaterial()));
 for(let i=0;i<30;i++){const light=createModelLight({name:'native'+i,properties:{color:[1,1,1],radius:30,shadowradius:30,shadow:1,isdynamic:i===9?1:0,lightpriority:i===9?0:4}});light.position.set(i*.1,1,0);light.shadow.intensity=.7;scene.add(light);lights.push(light);}
 const update=(delta=.05,focus=[0,0,0])=>prepareRendererLights(scene,camera,{shadowBudget:budget,lightSlots:slots,focus,delta});
 return{scene,camera,renderer,budget,slots,lights,update};
}
test('native priority, RGB threshold, radius and dynamic list precede the GPU guard; all illumination survives',()=>{
 const s=fixture(),source=s.lights.map(l=>[l.intensity,l.color.toArray(),{...l.userData.mdlLight}]);
 s.lights[0].userData.mdlLight.color=[.1,.1,.1];s.lights[1].userData.mdlLight.ambientonly=1;s.lights[2].userData.mdlLight.shadowradius=.1;
 const p=s.update(.3);assert.equal(p.shadows.native.maximum,3);assert.equal(p.shadows.native.normal,3);assert.equal(p.shadows.native.dynamic,1);assert.equal(p.shadows.admitted,3);assert(s.lights[9].castShadow);
 assert(s.lights.slice(0,3).every(l=>!l.castShadow));assert.equal(p.slots.point.shadowCapacity,6);
 assert.deepEqual(s.lights.map(l=>[l.intensity,l.color.toArray()]),source.map(v=>v.slice(0,2)));
 // No sampler-only expansion back to fifteen after authored animation resets.
 for(let i=0;i<8;i++){for(const l of s.lights)l.castShadow=true;assert(s.update().shadows.admitted<=6);}
 s.renderer.capabilities.maxTextures=2;assert(s.update().shadows.admitted<=1);
 s.budget.reset();s.slots.dispose();assert(s.lights.every(l=>l.castShadow&&l.shadow.intensity===.7));assert.equal(s.budget.states.size,0);assert.equal(s.budget.native.fades.size,0);
});
test('fades, removal, scene reset and user limit changes release retained lights without dimming authored light colors',()=>{
 const s=fixture();s.update(.3);const old=s.lights.filter(l=>l.castShadow);s.update(.016,[2.5,0,0]);assert(s.lights.some(l=>l.castShadow&&l.shadow.intensity>0&&l.shadow.intensity<.7));
 const removed=old[0];s.scene.remove(removed);s.update();assert(!s.budget.states.has(removed));assert(!s.budget.native.fades.has(removed));assert.equal(removed.shadow.intensity,.7);
 s.budget.maximum=1;for(let i=0;i<20;i++)s.update(.05);assert(s.update().shadows.admitted<=2);assert.equal(s.update().slots.point.shadowCapacity,6);
 s.budget.reset();assert.equal(s.budget.native.previous.flat().length,0);assert.equal(s.budget.states.size,0);s.slots.dispose();
});
test('shadow settings share one reserved profile while selected lights follow the requested limit',()=>{
 const s=fixture();s.budget.maximum=1;const first=s.update(.3).slots.point;
 assert.equal(first.shadowCapacity,6);
 for(const maximum of [3,2,1,3,1]){s.budget.maximum=maximum;for(let i=0;i<20;i++)s.update(.05);const p=s.update();assert(p.shadows.native.normal<=maximum&&p.shadows.native.dynamic<=maximum);assert.equal(p.slots.point.capacity,first.capacity);assert.equal(p.slots.point.shadowCapacity,first.shadowCapacity);}
 s.budget.reset();s.slots.dispose();
});
