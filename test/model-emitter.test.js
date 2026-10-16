import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import { parseBinaryMdl } from '../src/binary_mdl.js';
import { parseAsciiMdl } from '../src/model_parser.js';
import { createModelHierarchy } from '../src/model_hierarchy.js';
import { ModelAnimator } from '../src/model_animation.js';
import { runtimeEmitterController, BINARY_EMITTER_CHANNELS, EMITTER_FLAGS } from '../src/mdl_emitter.js';

function fixture(c) {
  const b=new ArrayBuffer(8192),v=new DataView(b),bytes=new Uint8Array(b),u=(o,n)=>v.setUint32(o,n,true),f=(o,n)=>v.setFloat32(o,n,true),s=(o,t)=>bytes.set(new TextEncoder().encode(t),o);
  u(4,8180);s(20,'sample');u(84,232);u(88,1);f(176,1);
  const n=244;u(n+108,5);s(n+32,'emitter');
  c.floats.forEach((x,i)=>f(n+112+i*4,x));
  [124,128,132,312,316,324].forEach((o,i)=>u(n+o,c.ints[i]));v.setUint16(n+320,c.order,true);
  [136,168,200,232,296].forEach((o,i)=>s(n+o,c.strings[i]));
  const keys=[[84,[.25]],[88,[4]],[128,[12]],[108,[.2,.4,.8]],[448,[.75]],[452,[.3,.6,.9]]];
  u(n+84,1000);u(n+88,keys.length);u(n+96,1500);u(n+100,24);f(1512,0);let value=1;
  for(const [i,[type,values]]of keys.entries()){
    const k=1012+i*12;u(k,type);v.setUint16(k+4,1,true);v.setUint16(k+8,value,true);bytes[k+10]=values.length;
    for(const x of values)f(1512+value++*4,x);
  }
  return b;
}

test('serialized emitter payload and controller relocation agree with three full original dispatcher/reader runs',()=>{
  const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-binary-emitter-observations.json',import.meta.url)));
  assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,3);
  for(const row of oracle.rows){
    const model=parseBinaryMdl(fixture(row.case)),node=model.nodes[0],p=node.properties;
    assert.equal(node.type,'emitter');assert.deepEqual(['deadspace','blastradius','blastlength'].map(k=>p[k]),row.floats);
    assert.deepEqual(['xgrid','ygrid','spawntype','twosidedtex','loop','flags'].map(k=>p[k]>>>0),row.ints.map(x=>x>>>0));
    assert.equal(p.renderorder,row.order);assert.deepEqual(['update','render','blend','texture','chunkname'].map(k=>p[k]),row.strings);
    assert.deepEqual(row.case.controls.map(runtimeEmitterController),row.controllers);
    for(const [name,mask]of Object.entries(EMITTER_FLAGS))assert.equal(p[name],Number((row.ints[5]&mask)!==0));
    assert.equal(node.alpha,1);assert.equal(p.alphastart,.25);assert.equal(p.birthrate,4);assert.equal(p.fps,12);assert.equal(p.alphamid,.75);
    assert.deepEqual(p.colorstart,[.2,.4,.8].map(Math.fround));assert.deepEqual(p.colormid,[.3,.6,.9].map(Math.fround));
    assert.ok(model.materialNames.includes('synthetic_texture'));assert.ok(node.unsupportedFeatures.includes('Emitter runtime simulation'));
  }
  assert.deepEqual(BINARY_EMITTER_CHANNELS[128],['emitter.fps',1]);
  assert.deepEqual(BINARY_EMITTER_CHANNELS[448],['emitter.alphamid',1]);
  assert.deepEqual(BINARY_EMITTER_CHANNELS[464],['emitter.percentstart',1]);
});

test('ASCII emitter animation updates per-instance parameter state without treating FPS as opacity',()=>{
  const model=parseAsciiMdl(`newmodel sample
beginmodelgeom sample
node emitter particles
birthrate 2
fps 6
endnode
endmodelgeom sample
newanim pulse sample
length 1
node emitter particles
birthratebezierkey 2
0 2 0 0
1 8 0 0
colorstartkey 2
0 0 0 0
1 1 .5 .25
fpskey 2
0 6
1 12
endnode
doneanim pulse sample
newanim rest sample
length 0
doneanim rest sample`);
  const make=()=>{const h=createModelHierarchy(model);return{h,a:new ModelAnimator(model,h.root)};},a=make(),b=make(),group=a.h.groups.get('particles');
  assert.deepEqual(model.unsupportedAnimations,[]);a.a.play('pulse',{loop:false});a.a.update(.5);
  assert.equal(group.userData.mdlEmitterProperties.birthrate,5);assert.equal(group.userData.mdlEmitterProperties.fps,9);
  assert.deepEqual(group.userData.mdlEmitterProperties.colorstart,[.5,.25,.125]);assert.equal(b.h.groups.get('particles').userData.mdlEmitterProperties.birthrate,2);
  assert.equal(model.nodes[0].properties.birthrate,2);a.a.pose('rest');assert.equal(group.userData.mdlEmitterProperties.birthrate,2);assert.equal(group.userData.mdlEmitterProperties.colorstart,undefined);
});
