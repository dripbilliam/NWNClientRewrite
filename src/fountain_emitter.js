import { scriptFloatToInt } from './script_scalar.js';
import { checkParticleLife } from './particle_lifetime.js';
import { appendEmitterParticle as appendParticle } from './particle_storage.js';
const f=Math.fround,TAU=f(6.2831854820251465);
const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native emitter provider ${name} is unavailable`);return p[name](...args);};

function spawn(e,delta,factor,p){
  const particle=e.free130.records.length?e.free130.records.pop():call(p,'createParticle',e.chunkName.length!==0,delta);
  if(!particle)throw new Error('Native emitter particle allocation failed');
  // New particles are constructed, then initialized through virtual+10 just
  // like recycled particles. Do not combine these two original calls.
  call(p,'initializeParticle',particle,delta,factor);
  appendParticle(e,particle,p);call(p,'randomizeParticle',e,e.active188.records.at(-1));
}

// Complete FountainEmitter::Update140064b30..140065281. The outer
// AnimateParticles owner supplies transforms/time clamp. Particle constructors,
// initialization, randomization and movement remain explicit lower providers.
// No synthetic particle placement/randomness is substituted by this owner.
export function updateFountainEmitter(e,delta,p){
  delta=f(delta);const rate=f(e.birthRate);
  e.enabled23c=Number(!(0>=rate));
  const factor=e.source50?f(call(p,'sourceFactor',e.source50)):1;
  checkParticleLife(e,delta,p);
  const blend=e.renderMode1a8===6?f((delta<=f(e.blurLength)?delta:f(e.blurLength))/f(e.blurLength)):0,remainingBlend=f(1-blend);
  if(e.renderMode1a8===6)for(let i=e.active188.records.length-1;i>=0;i--){
    const particle=e.active188.records[i];
    particle.trail64=particle.position10.map((v,axis)=>f(f(blend*f(v))+f(remainingBlend*f(particle.trail64[axis]))));
  }
  for(let i=e.active188.records.length-1;i>=0;i--){
    const particle=e.active188.records[i];let angle=f(f(delta*f(e.particleRot))+f(particle.rotation1c));
    if(angle>TAU)angle=f(angle-TAU);else if(angle<-TAU)angle=f(angle+TAU);
    particle.rotation1c=angle;
  }
  call(p,'moveParticles',e,delta);
  const rateInt=scriptFloatToInt(rate);if(rateInt<=0)return;
  const interval=f(1/rate);
  if(e.spawnType===0){
    e.accumulator198=f(delta+f(e.accumulator198));
    if(!(e.accumulator198>=interval))return;
    const count=()=>scriptFloatToInt(f(rate*f(e.accumulator198)))%((rateInt+1)|0);
    for(let i=0;i<count();i++)spawn(e,delta,factor,p);
    // Original discards the fractional remainder instead of carrying it.
    e.accumulator198=0;return;
  }
  const displacement=e.position1e0.map((v,axis)=>f(f(f(v)-f(e.previous19c[axis]))+f(e.remaining164[axis])));
  const squared=f(f(f(displacement[1]*displacement[1])+f(displacement[0]*displacement[0]))+f(displacement[2]*displacement[2]));
  const length=f(Math.sqrt(squared)),inverse=length>0?f(1/length):0,direction=displacement.map(v=>f(v*inverse));
  const enabled=e.enabled23c,count=enabled?scriptFloatToInt(f(length*rate)):0;
  for(let i=0;i<count;i++){
    spawn(e,delta,factor,p);
    if(e.active188.records.length<2)e.active188.records[0].position10=e.position1e0.map((v,axis)=>f(f(v)-f(direction[axis]*length)));
    else {
      const distance=f(f(i+1)*interval);
      e.active188.records.at(-1).position10=e.previous19c.map((v,axis)=>f(f(f(v)-f(e.remaining164[axis]))+f(direction[axis]*distance)));
    }
  }
  const emittedDistance=f(f(count)*interval);
  e.remaining164=enabled?displacement.map((v,axis)=>f(v-f(direction[axis]*emittedDistance))):[0,0,0];
}
