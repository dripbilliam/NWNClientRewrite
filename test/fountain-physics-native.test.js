import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {NativeRandom} from '../src/native_random.js';
import {updateFountainEmitter} from '../src/fountain_emitter.js';
import {fountainParticleProviders} from '../src/fountain_particle_providers.js';
const f=Math.fround;

test('coupled Fountain physics matches27 original frames with real particle birth/motion/recycling and independent RNG',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-fountain-physics-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,3);
 for(const row of oracle.rows){
  const rng=new NativeRandom(row.seed),draws=[],all=[];let constructors=0,initializations=0,clearHits=0;
  const e={flags:32,deadspace:0,chunkName:'',lifeExp:f(.2),particleRot:1,randomVelocity:f(.5),velocity:2,xSize:30,ySize:25,spread:f(.872665),frameStart:0,frameEnd:3,mass:f(.2),blurLength:1,spawnType:0,renderMode1a8:0,accumulator198:0,remaining164:[0,0,0],source50:{adjustedScale:f(.75)},position1e0:[4,-3,2],previous19c:[4,-3,2],quaternion1d0:[1,0,0,0],previousQuaternion178:[1,0,0,0],basis140:[1,0,0,0,1,0,0,0,1],active188:{records:[],capacity:0},free130:{records:[],capacity:0},hit1f0:{normal:[0,0,0]}};
  const p=fountainParticleProviders(e,{random:()=>{const v=rng.next();draws.push(v);return v;},cameraPosition:()=>[10,20,30],cosineDouble:Math.cos,clearHit:()=>clearHits++});
  const create=p.createParticle,initialize=p.initializeParticle;
  p.createParticle=(...args)=>{constructors++;initializations++;const particle=create(...args);particle.id=all.length;all.push(particle);return particle;};
  p.initializeParticle=(...args)=>{initializations++;return initialize(...args);};
  for(const expected of row.frames){
    e.birthRate=expected.rate;updateFountainEmitter(e,.1,p);
    const out={rate:expected.rate,active:e.active188.records.map(p=>p.id),free:e.free130.records.map(p=>p.id),activeCapacity:e.active188.capacity,freeCapacity:e.free130.capacity,rng:rng.state,drawCount:draws.length,constructors,initializations,clearHits,particles:all.map(p=>({id:p.id,position:p.position10,velocity:p.velocity58,quaternion:p.quaternion34,direction:p.direction4c,trail:p.trail64,age:p.age,frame:p.frame44,field48:p.field48,rotation:p.rotation1c,stopped:p.stopped70}))};
    assert.deepEqual(out,expected,`seed${row.seed}, frame${row.frames.indexOf(expected)}`);
  }
  assert.deepEqual(draws,row.draws);assert.equal(e.active188.records.length,0);assert.equal(e.free130.records.length,constructors);
 }
});
