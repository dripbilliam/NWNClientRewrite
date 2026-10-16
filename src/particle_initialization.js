import {scriptFloatToInt as cvtt} from './script_scalar.js';
import {nativeCosf,nativeSinf} from './native_math.js';
import {normalizeParticleVector,multiplyParticleQuaternion,crossParticleVector,particleQuaternionZ,particleQuaternionY} from './particle_math.js';
const f=Math.fround,STEP=f(.01),POSITION_STEP=f(.0001),PI2=f(1.5707963705062866);
const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native particle provider ${name} is unavailable`);return p[name](...args);};
const rand=p=>call(p,'random')|0;
const remainder=(value,count)=>{if(!count)throw new Error('Native particle resource causes integer division by zero');return(value%count)|0;};

// Particle::randomPosition140068d80..140068ed2. Small dimensions still
// consume the two sign draws. A negative extent is not clamped to positive.
export function randomParticlePosition(particle,xSize,ySize,p){
  xSize|=0;ySize|=0;
  let x=xSize>3?remainder(rand(p),cvtt(f(f(xSize)*f(.5)))):0;
  let y=ySize>3?remainder(rand(p),cvtt(f(f(ySize)*f(.5)))):0;
  const flipX=rand(p)%2,flipY=rand(p)%2;if(flipX>0)x=-x;if(flipY>0)y=-y;
  x=f(f(x)*POSITION_STEP);y=f(f(y)*POSITION_STEP);
  const e=particle.emitter8;
  particle.position10=e.position1e0.map((v,i)=>f(f(f(x*f(e.basis140[i]))+f(v))+f(y*f(e.basis140[i+3]))));
}

// PartEmitter::chkRandom1400660c0..14006613a chooses the initial atlas frame.
export function randomizeParticleFrame(e,particle,p){
  if(!(e.flags&32))return;
  const difference=cvtt(f(f(e.frameEnd)-f(e.frameStart))),plus=(difference+1)|0,count=plus>=0?plus:~difference;
  if(count!==0)particle.frame44=cvtt(f(f(remainder(rand(p),count))+f(e.frameStart)));
}

// Particle::inheritVelocity140066140..1400663c4; magnitude at20 and
// normalized direction at24 are stored separately from velocity58.
export function inheritParticleVelocity(particle,delta){
  const e=particle.emitter8,direction=particleQuaternionZ(e.previousQuaternion178),inverse=f(delta)>0?f(1/f(delta)):STEP;
  const d=e.position1e0.map((v,i)=>f(f(v)-f(particle.position10[i])));
  const length=f(Math.sqrt(f(f(f(d[1]*d[1])+f(d[0]*d[0]))+f(d[2]*d[2]))));
  const velocity=e.position1e0.map((v,i)=>{
    const rotational=f(f(length*f(f(e.basis140[6+i])-direction[i]))*inverse),translation=f(f(f(v)-f(e.previous19c[i]))*inverse);
    return i===0?f(rotational+translation):f(translation+rotational);
  });
  const magnitude=f(Math.sqrt(f(f(f(velocity[0]*velocity[0])+f(velocity[1]*velocity[1]))+f(velocity[2]*velocity[2]))));
  particle.inheritedSpeed20=magnitude;const scale=magnitude===0?0:f(1/magnitude);
  particle.inheritedDirection24=magnitude===0?[0,0,0]:velocity.map(v=>f(v*scale));
}

function rotation(axis,angle,p){
  axis=normalizeParticleVector(axis);const cosine=p.cosineFloat??nativeCosf,sine=p.sineFloat??nativeSinf,c=cosine(angle),s=sine(angle);
  return[c,...axis.map(v=>f(v*s))];
}

// Particle::randomDirection140068800..140068d73, including the camera
// dead-space correction. The latter calls the separate DOUBLE cosine owner;
// providers must supply it explicitly until that CRT branch is validated.
export function randomParticleDirection(particle,_xSize,_ySize,p){
  const camera=call(p,'cameraPosition'),cam=normalizeParticleVector(particle.position10.map((v,i)=>f(f(v)-f(camera[i]))));
  const spread=f(f(particle.emitter8.spread)*f(.5)),count=(1-cvtt(f(spread*f(-100))))|0;
  const first=f(f(f(remainder(rand(p),count))*STEP)*f(.5));
  let e=particle.emitter8;
  particle.quaternion34=multiplyParticleQuaternion(rotation(e.basis140.slice(0,3),first,p),particle.quaternion34);
  const second=f(f(f(remainder(rand(p),628))*STEP)*f(.5));e=particle.emitter8;
  particle.quaternion34=multiplyParticleQuaternion(rotation(e.basis140.slice(6,9),second,p),particle.quaternion34);
  e=particle.emitter8;
  if(f(e.deadspace)===0)return;
  const original=[...particle.quaternion34],direction=particleQuaternionY(original);
  let dot=f(f(f(direction[1]*cam[1])+f(direction[0]*cam[0]))+f(direction[2]*cam[2]));
  const limit=()=>call(p,'cosineDouble',1.57079632-f(particle.emitter8.deadspace));
  let candidate=original,iterations=0;
  while(Math.abs(dot)<limit()){
    if(++iterations>4096)throw new Error('Native particle camera dead-space correction did not converge');
    const dead=f(particle.emitter8.deadspace),angle=dot>=0?f(f(dot-PI2)+dead):f(f(dead+PI2)-dot);
    candidate=multiplyParticleQuaternion(rotation(crossParticleVector(cam,direction),f(angle*f(.5)),p),original);
    const y=particleQuaternionY(candidate);
    dot=Math.abs(f(f(f(cam[0]*y[0])+f(cam[1]*y[1]))+f(cam[2]*y[2])));
  }
  particle.quaternion34=candidate;
}

// Full Particle::initialize140066450..140066685. New constructor calls
// this with factor1; Fountain subsequently calls the virtual owner again.
export function initializeParticle(particle,delta,factor,p){
  let e=particle.emitter8;
  particle.stopped70=0;particle.rotation1c=0;particle.field48=0;particle.age=0;
  particle.quaternion34=e.quaternion1d0.map(f);particle.inheritedSpeed20=0;particle.inheritedDirection24=[0,0,0];
  particle.frame44=cvtt(e.frameStart);let jitter=0,randomVelocity=f(e.randomVelocity);
  if(randomVelocity>.01){jitter=remainder(rand(p),cvtt(f(randomVelocity*100)));if(rand(p)%2>0)jitter=-jitter;}
  e=particle.emitter8;
  const xSize=cvtt(f(f(f(e.xSize)*100)*f(factor))),ySize=cvtt(f(f(f(e.ySize)*100)*f(factor)));
  if(xSize===0&&ySize===0)particle.position10=e.position1e0.map(f);else randomParticlePosition(particle,xSize,ySize,p);
  particle.trail64=[...particle.position10];e=particle.emitter8;
  if(e.flags&128)inheritParticleVelocity(particle,delta);
  e=particle.emitter8;if(f(e.spread)!==0)randomParticleDirection(particle,xSize,ySize,p);
  e=particle.emitter8;particle.direction4c=particleQuaternionZ(particle.quaternion34);
  const speed=f(f(f(jitter)*STEP)+f(e.velocity));particle.velocity58=particle.direction4c.map(v=>f(speed*v));
}

export function createParticle(e,delta,p){
  const particle={emitter8:e,position10:[0,0,0],quaternion34:[1,0,0,0],inheritedSpeed20:0,inheritedDirection24:[0,0,0],direction4c:[0,0,0],velocity58:[0,0,0],trail64:[0,0,0]};
  initializeParticle(particle,delta,1,p);return particle;
}
