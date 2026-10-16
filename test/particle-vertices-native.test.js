import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {buildParticleVertices} from '../src/particle_vertices.js';
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
