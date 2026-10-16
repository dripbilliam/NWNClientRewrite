import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import * as THREE from 'three';
import { parseBinaryMdl } from '../src/binary_mdl.js';
import { parseAsciiMdl } from '../src/model_parser.js';
import { parseBinaryAnimations } from '../src/mdl_animation.js';
import { createModelHierarchy } from '../src/model_hierarchy.js';
import { ModelAnimator } from '../src/model_animation.js';
import { createModelLight, modelLightAttenuation, setModelLightShadows, setModelLightPriority, installModelLightShaders } from '../src/model_light.js';
import { LIGHT_CHANNELS, BINARY_LIGHT_CHANNELS } from '../src/mdl_light.js';
import { durationVisualProgram, LoopingVisualPresentation } from '../src/looping_visual_presentation.js';
import { parse2da } from '../src/area.js';

function binaryLight(c, animation = false) {
  const buffer=new ArrayBuffer(4096),v=new DataView(buffer),b=new Uint8Array(buffer),u=(o,n)=>v.setUint32(o,n,true),f=(o,n)=>v.setFloat32(o,n,true),s=(o,n)=>b.set(new TextEncoder().encode(n),o);
  u(4,4084);s(20,'sample');u(84,232);u(88,1);f(12+164,1);
  const node=244;s(node+32,'lamp');u(node+108,3);
  f(node+112,c.flareRadius);c.flags.forEach((n,i)=>u(node+176+i*4,n));
  const channels=[[76,[.25,.5,1]],[88,[12]],[96,[4]],[100,[.75]],[140,[2]]];
  u(node+84,1000);u(node+88,channels.length);u(node+96,1200);u(node+100,20);f(1212,0);
  let valueIndex=1;
  for(const [i,[type,values]]of channels.entries()){
    const k=1012+i*12;u(k,type);v.setUint16(k+4,1,true);v.setUint16(k+8,valueIndex,true);b[k+10]=values.length;
    values.forEach(n=>f(1212+valueIndex++*4,n));
  }
  if(animation){
    u(12+120,2000);u(12+124,1);u(2012,2100);const a=2112,n=2412;
    s(a+8,'glow');u(a+72,2400);u(a+76,1);f(a+112,1);s(a+120,'sample');
    s(n+32,'lamp');u(n+108,3);u(n+84,2700);u(n+88,1);u(n+96,2800);u(n+100,4);
    u(2712,100);v.setUint16(2716,2,true);v.setUint16(2720,2,true);b[2722]=1;
    [0,1,0,2].forEach((x,i)=>f(2812+i*4,x));
  }
  return buffer;
}

test('binary light fields and relocated controller IDs agree with twelve complete original reader executions',()=>{
  const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-binary-light-observations.json',import.meta.url)));
  assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,12);
  for(const row of oracle.rows){
    const node=parseBinaryMdl(binaryLight(row.case)).nodes[0],p=node.properties;
    assert.equal(node.type,'light');assert.equal(p.flareradius,row.flareRadius);
    assert.deepEqual(['lightpriority','ambientonly','isdynamic','affectdynamic','shadow','generateflare','fadinglight'].map(k=>p[k]),row.flags);
    for(const [serialized,channel]of Object.entries(BINARY_LIGHT_CHANNELS))assert.deepEqual(LIGHT_CHANNELS[row.controllers[[8,20,36,72,75,76,88,96,100,128,140].indexOf(Number(serialized))]],channel);
    assert.deepEqual(p.color,[.25,.5,1]);assert.equal(p.radius,12);assert.equal(p.shadowradius,4);assert.equal(p.verticaldisplacement,.75);assert.equal(p.multiplier,2);
    assert.deepEqual(node.unsupportedFeatures,[]);
  }
});

test('binary light animation type100 stays displacement and type128 is not mesh alpha on light nodes',()=>{
  const b=binaryLight({flareRadius:0,flags:[3,0,1,1,1,0,1]},true),v=new DataView(b);
  assert.equal(parseBinaryAnimations(b).animations[0].tracks[0].property,'lightVerticalDisplacement');
  v.setUint32(2712,128,true);assert.equal(parseBinaryAnimations(b).animations[0].tracks.length,0);
  v.setUint32(2412+108,0x21,true);assert.equal(parseBinaryAnimations(b).animations[0].tracks[0].property,'alpha');
});

const ascii=`newmodel sample
beginmodelgeom sample
node light lamp
color .2 .3 .4
radius 4
multiplier 1
shadow 1
isdynamic 1
endnode
endmodelgeom sample
newanim glow sample
length 1
node light lamp
colorkey 2
0 0 0 0
1 1 .5 .25
radiuskey 2
0 0
1 12
multiplierkey 2
0 1
1 2
endnode
doneanim glow sample
newanim rest sample
length 0
doneanim rest sample`;

test('authored light curves animate color, radius and intensity independently and restore omitted channels',()=>{
  const model=parseAsciiMdl(ascii),make=()=>{const h=createModelHierarchy(model),l=createModelLight(model.nodes[0]);h.nodeGroups.get(model.nodes[0]).add(l);return{l,a:new ModelAnimator(model,h.root)};},a=make(),b=make();
  a.a.play('glow',{loop:false});a.a.update(.5);
  assert.deepEqual(a.l.userData.mdlLight.color,[.5,.25,.125]);assert.equal(a.l.userData.mdlLight.radius,6);assert.equal(a.l.intensity,1.5*Math.PI);
  assert.equal(a.l.decay,-9/72);assert.equal(b.l.distance,4);
  a.a.update(3);assert.equal(a.l.distance,12);assert.equal(a.a.playing,false);
  a.a.pose('rest');assert.equal(a.l.distance,4);assert.deepEqual(a.l.userData.mdlLight.color,[.2,.3,.4]);
});

test('legacy quadratic attenuation preserves unit center intensity and ambient-only lights remain spatial',()=>{
  assert.equal(modelLightAttenuation(10,0),1);assert.equal(modelLightAttenuation(10,10),1/5.5);assert.equal(modelLightAttenuation(0,1),0);
  const l=createModelLight({name:'local ambient',properties:{ambientonly:1,radius:5,shadow:1,isdynamic:1}});
  assert.equal(l.isPointLight,true);assert.equal(l.distance,-5);assert.equal(l.castShadow,false);
  const root=new THREE.Group();root.add(l);setModelLightShadows(root,true);assert.equal(l.castShadow,false);
  installModelLightShaders();const chunk=THREE.ShaderChunk.lights_pars_begin;installModelLightShaders();assert.equal(THREE.ShaderChunk.lights_pars_begin,chunk);
  assert.match(chunk,/nwnQuadraticAttenuation/);assert.match(THREE.ShaderChunk.lights_fragment_begin,/directLight.direction = geometryNormal/);
});

test('native runtime light priority remains independent of authored property resets',()=>{
 const root=new THREE.Group(),branch=new THREE.Group(),a=createModelLight({name:'a',properties:{radius:3}}),b=createModelLight({name:'b',properties:{radius:4}});root.add(a,branch);branch.add(b);
 setModelLightPriority(root,2);assert.equal(a.userData.mdlLightPriority90,2);assert.equal(b.userData.mdlLightPriority90,2);
 a.userData.mdlLight={radius:1,color:[1,1,1]};assert.equal(a.userData.mdlLightPriority90,2);setModelLightPriority(root,-1);assert.equal(b.userData.mdlLightPriority90,-1);
});

const visuals=parse2da('2DA V2.0\n\nProgFX_Duration\n0 2\n1 ****\n'),programs=parse2da('2DA V2.0\n\nType Param1 Param2 Param3 Param4 Param5 Param6 Param7\n0 5 **** **** **** **** **** **** ****\n1 4 **** **** **** **** **** **** ****\n2 4 custom_glow 1.5 1 276 -7 0 custom_model\n');
test('duration visual configuration is selected through active physical rows and native2DA output conversions',()=>{
  assert.deepEqual(durationVisualProgram(0,visuals,programs),{id:2,type:4,model:'custom_model',animation:'custom_glow',speed:1.5,shadows:true,field10c:20,field110:-7,vision:false});
  assert.equal(durationVisualProgram(1,visuals,programs),null);
});

test('duration instances retain duplicate records and remove only the deleted native record',async()=>{
  const first={visualId:0},second={visualId:0},actor={id:7,nativeLoopingVisuals160:{records:[first,second]}},render={},calls=[];
  const p=new LoopingVisualPresentation({objects:()=>[actor],object:()=>actor,render:()=>render,tables:async()=>({visuals,programs}),create:async(_a,_r,record)=>({attach:()=>calls.push(['attach',record]),update:()=>{},dispose:()=>calls.push(['dispose',record])}),report:()=>assert.fail('Unexpected diagnostic')});
  p.update(0);await Promise.all([...p.entries.values()].map(e=>e.ready));assert.equal(calls.length,2);
  actor.nativeLoopingVisuals160.records.pop();p.update(0);assert.deepEqual(calls.at(-1),['dispose',second]);assert.equal(p.snapshot().length,1);
  p.dispose();p.dispose();assert.deepEqual(calls.at(-1),['dispose',first]);assert.equal(calls.length,4);
});

test('removed effects and rebound actors cannot attach asynchronously completed resources',async()=>{
  for(const reason of ['remove','rebind','destroy','dispose']){
    const record={visualId:0},actor={id:7,nativeLoopingVisuals160:{records:[record]}},oldRender={};let render=oldRender,live=actor,finish,disposed=0;
    const p=new LoopingVisualPresentation({objects:()=>[actor],object:()=>live,render:()=>render,tables:async()=>({visuals,programs}),create:()=>new Promise(resolve=>{finish=()=>resolve({attach:()=>assert.fail('Stale visual attached'),dispose:()=>disposed++});}),report:()=>assert.fail('Unexpected diagnostic')});
    p.update(0);await Promise.resolve();const pending=[...p.entries.values()][0].ready;assert.ok(finish);
    if(reason==='remove')actor.nativeLoopingVisuals160.records=[];
    if(reason==='rebind')render={};if(reason==='destroy')live=null;if(reason==='dispose')p.dispose();
    finish();await pending;assert.equal(disposed,1);p.dispose();assert.equal(disposed,1);
  }
});

test('failed visual playback is disposed once and diagnosed without repeating failures each frame',async()=>{
  const record={visualId:0},actor={id:7,nativeLoopingVisuals160:{records:[record]}},render={},diagnostics=[];let disposed=0;
  const p=new LoopingVisualPresentation({objects:()=>[actor],object:()=>actor,render:()=>render,tables:async()=>({visuals,programs}),create:async()=>({attach:()=>{},update:()=>{throw new Error('Unsupported playback');},dispose:()=>disposed++}),report:(...args)=>diagnostics.push(args)});
  p.update(0);await [...p.entries.values()][0].ready;
  p.update(.1);p.update(.1);p.dispose();assert.equal(disposed,1);assert.equal(diagnostics.length,1);assert.equal(diagnostics[0][0],'visual.update-failed');
});
