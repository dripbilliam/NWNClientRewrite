import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {buildParticleVertices} from '../src/particle_vertices.js';
import {nativeSinf,nativeCosf} from '../src/native_math.js';
const f=Math.fround;
test('all seven particle draw modes match245 original generated vertex streams and atlas mutations',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-particle-vertices-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,245);
 for(const row of oracle.rows){
  const c=row.case,calls=[],instance={fade:f(c.fade),height50:f(c.height),opacity70:f(c.elevationOpacity)},sourceInstance={...instance,fade:f(c.sourceFade)};
  const list=Array.from({length:c.count},(_,i)=>({position10:[1+i,2+i*2,3-i],trail64:[-1+i,1+i*2,2-i],quaternion34:[.5,-.5,.5,.5],direction4c:[0,0,1],rotation1c:f(c.rotation+i*.125),age:f(c.age+i*.125),field48:f(c.frameTime),frame44:c.initialFrame,stopped70:c.stopped}));
  const e={renderMode1a8:c.mode,active188:{records:list},lifeExp:f(c.life),source50:c.source?{opacity108:f(c.opacity),instance:c.sourceInstance?sourceInstance:null}:null,instance100:c.instance?instance:null,flags:c.flags,position1e0:[1,2,3],quaternion1d0:[.5,.5,.5,.5],ageMode1cc:c.ageMode,xGrid:c.grid[0],yGrid:c.grid[1],elevationThreshold:oracle.elevationThreshold,colorStart:c.colorStart.map(f),colorEnd:c.colorEnd.map(f),alphaStart:f(c.alphaStart),alphaEnd:f(c.alphaEnd),sizeStart:f(c.sizes[0]),sizeEnd:f(c.sizes[1]),sizeStartY:f(c.sizes[2]),sizeEndY:f(c.sizes[3]),fps:f(c.fps),frameStart:f(c.frameStart),frameEnd:f(c.frameEnd),blendMode68:c.blend,twoSided:c.twoSided};
  const providers={sourceFactor:()=>{calls.push(['source',c.factor]);return c.factor;},cameraQuaternion:()=>c.camera,lightColor:position=>{calls.push(['tint',position]);return c.tint;}};
  const out=buildParticleVertices(e,providers),actual={calls,committed:out?.count??0,drawn:out?.count??0,soft:out?.softInverse??null,words:out?[...new Uint32Array(out.buffer)]:[],particles:list.map(p=>({frame:p.frame44,frameTime:p.field48}))};
  const {case:_case,...expected}=row;assert.deepEqual(actual,expected,JSON.stringify(c));
 }
});

test('shared zero-spin axes preserve exact streams across mixed rotations, signed zeros, splats and custom math callbacks',()=>{
 for(const mode of [0,1,2,3,4,5,6])for(const splat of [0,512]){
  const e={renderMode1a8:mode,active188:{records:Array.from({length:16},(_,i)=>({position10:[i,.25,3],trail64:[i-1,.5,2],quaternion34:[.5,-.5,.5,.5],direction4c:[0,0,1],rotation1c:[0,-0,0,.125][i%4],age:f(i*.03),field48:0,frame44:0,stopped70:i===9?1:0}))},lifeExp:2,source50:{opacity108:.5},instance100:null,flags:splat,position1e0:[0,0,0],quaternion1d0:[.5,.5,.5,.5],ageMode1cc:1,xGrid:2,yGrid:2,elevationThreshold:5,colorStart:[1,.5,.25],colorEnd:[.2,.4,.1],alphaStart:.8,alphaEnd:0,sizeStart:.3,sizeEnd:.6,sizeStartY:0,sizeEndY:0,fps:10,frameStart:0,frameEnd:3,blendMode68:2,twoSided:false};
  const reference=structuredClone(e),providers={sourceFactor:()=>1,cameraQuaternion:()=>[f(.8),f(.6),0,0]};let calls=0;
  const expected=buildParticleVertices(reference,{...providers,sineFloat:value=>{calls++;return nativeSinf(value);},cosineFloat:nativeCosf}),actual=buildParticleVertices(e,providers);
  assert.deepEqual(new Uint32Array(actual.buffer),new Uint32Array(expected.buffer),JSON.stringify({mode,splat}));assert.deepEqual(e.active188,reference.active188);
  assert.equal(calls,[3,5,6].includes(mode)?0:16,'custom callbacks retain one evaluation per particle');
 }
});
