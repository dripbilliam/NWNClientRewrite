import {scriptFloatToInt as cvtt} from './script_scalar.js';
import {checkParticleLife} from './particle_lifetime.js';
import {appendEmitterParticle} from './particle_storage.js';
const f=Math.fround,TAU=f(6.2831854820251465);
const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native emitter provider ${name} is unavailable`);return p[name](...args);};
function rotate(particle,e,delta){
  let angle=f(f(delta*f(e.particleRot))+f(particle.rotation1c));
  if(angle>TAU)angle=f(angle-TAU);else if(angle<-TAU)angle=f(angle+TAU);
  particle.rotation1c=angle;
}
function blur(particle,blend){
  const rest=f(1-blend);
  particle.trail64=particle.position10.map((v,i)=>f(f(blend*f(v))+f(rest*f(particle.trail64[i]))));
}
function create(e,delta,p){
  const particle=call(p,'createParticle',e.chunkName.length!==0,delta);
  if(!particle)throw new Error('Native emitter particle allocation failed');
  return particle;
}

// Complete ExplosionEmitter::Update1400647c0..140064b29. Detonate is a
// one-frame BYTE command, not a continuous floating-point birth-rate value.
export function updateExplosionEmitter(e,delta,p){
  delta=f(delta);const count=cvtt(f(e.birthRate)),factor=e.source50?f(call(p,'sourceFactor',e.source50)):1;
  checkParticleLife(e,delta,p);
  const blend=e.renderMode1a8===6?f((!(delta>f(e.blurLength))?delta:f(e.blurLength))/f(e.blurLength)):0;
  for(let i=e.active188.records.length-1;i>=0;i--){
    const particle=e.active188.records[i];if(e.renderMode1a8===6)blur(particle,blend);rotate(particle,e,delta);
  }
  call(p,'moveParticles',e,delta);
  if(count!==0&&e.detonate108&&1>f(e.blastLatch1c8)){
    if(f(e.blastRadius)!==0)call(p,'addPointSourceWind',e.position1e0.slice(),f(e.blastRadius),f(e.blastLength),1);
    for(let i=0;i<count;i++){
      const reuse=e.free130.records.length!==0,particle=reuse?e.free130.records.pop():create(e,delta,p);
      // Unlike Fountain, recycled Explosion particles use factor1 even when
      // the current source has a different adjusted scale.
      call(p,'initializeParticle',particle,delta,reuse?1:factor);
      appendEmitterParticle(e,particle,p);call(p,'randomizeParticle',e,e.active188.records.at(-1));
    }
  }
  e.blastLatch1c8=e.detonate108?1:0;e.detonate108=0;
}

// Complete SingleEmitter::Update140065cd0..140065f05. A newly constructed
// particle is NOT initialized a second time and never comes from the free list.
export function updateSingleEmitter(e,delta,p){
  delta=f(delta);const active=e.active188.records;
  if(cvtt(f(e.birthRate))===0){
    if(active.length){const particle=active.shift();if(particle)call(p,'destroyParticle',particle,1);}
    return;
  }
  if(active.length===0){
    appendEmitterParticle(e,create(e,delta,p),p);call(p,'randomizeParticle',e,active[0]);return;
  }
  const particle=active[0],age=f(delta+f(particle.age)),life=f(e.lifeExp);particle.age=age;
  // COMISS/JBE's unordered branch uses the nonpositive-life path too.
  if(!(life>0)){if(age<0)particle.age=0;}
  else if(age>life&&e.loop)particle.age=0;
  rotate(particle,e,delta);
  if(e.renderMode1a8===6)blur(particle,f((!(delta>f(e.blurLength))?delta:f(e.blurLength))/f(e.blurLength)));
  call(p,'moveParticles',e,delta);
}
