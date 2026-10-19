import {scriptFloatToInt as cvtt} from './script_scalar.js';
import {appendEmitterParticle} from './particle_storage.js';
import {normalizeParticleVector,crossParticleVector,particleRotationArc,rotateParticleVector} from './particle_math.js';
const f=Math.fround,STEP=f(.01),call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native Lightning provider ${n} is unavailable`);return p[n](...args);};
const at=(e,index)=>{const particle=e.active188.records[index];if(!particle)throw new Error('Native Lightning subdivision addresses an unavailable particle');return particle;};
const random=p=>call(p,'random')|0;
function releaseLast(e,p){
 const particle=e.active188.records.pop(),free=e.free130;if(free.records.length===free.capacity){const next=free.capacity===0?16:Math.imul(free.capacity,2);if(next<=free.capacity)throw new Error('Native Lightning free-list capacity overflow');free.capacity=next;call(p,'reserveFree',next);}free.records.push(particle);
}
// Full RecursiveFractal140062460..14006280a, including duplicate zero-span
// calls and sign draws even when radius is below the DOUBLE .01 threshold.
export function recursiveLightningFractal(e,middle,span,depth,first,second,factor,p){
 const sign=(random(p)&1)?1:-1,left=at(e,middle-span),right=at(e,middle+span);
 let position=right.position10.map((v,i)=>f(f(f(v)+f(left.position10[i]))*.5));
 if(f(e.lightningRadius)>=.01){const count=cvtt(f(f(e.lightningRadius)*100));if(!count)throw new Error('Native Lightning radius causes integer division by zero');const distance=f(f(random(p)%count)*STEP);position=position.map((v,i)=>f(f(f(f(sign*first[i])*distance)*f(factor))+v));}
 const secondSign=(random(p)&1)?1:-1;
 if(f(e.lightningRadius)>=.01){const count=cvtt(f(f(e.lightningRadius)*100));if(!count)throw new Error('Native Lightning radius causes integer division by zero');const distance=f(f(random(p)%count)*STEP);position=position.map((v,i)=>f(f(f(f(secondSign*second[i])*distance)*f(factor))+v));}
 at(e,middle).position10=position;
 if(span!==0){const half=Math.trunc(span*.5);recursiveLightningFractal(e,middle-half,half,depth+1,first,second,factor,p);recursiveLightningFractal(e,middle+half,half,depth+1,first,second,factor,p);}
}
// Complete LightningEmitter::Update140065290..140065cca. Fixed chain length,
// no particle-life pass or movement call, reused particles NOT reinitialized.
export function updateLightningEmitter(e,delta,p){
 delta=f(delta);const count=cvtt(f(e.birthRate)),factor=e.source50?f(call(p,'sourceFactor',e.source50)):1;
 e.lightningElapsed=f(delta+f(e.lightningElapsed));
 if(count===0||!e.target1c0){while(e.active188.records.length)releaseLast(e,p);return;}
 if(count<0)throw new Error('Native Lightning negative chain count would address invalid particle storage');
 // The original caches the INITIAL free count/index across this entire loop.
 // Multiple additions can therefore reuse the SAME stale last pointer. Keep
 // physical aliases rather than silently regularizing this into repeated pop.
 const freeCount=e.free130.records.length,reused=freeCount?e.free130.records[freeCount-1]:null;
 while(e.active188.records.length<count){
  let particle;if(freeCount){particle=reused;if(freeCount-1<e.free130.records.length)e.free130.records.splice(freeCount-1,1);}else particle=call(p,'createParticle',false,delta);if(!particle)throw new Error('Native Lightning particle allocation failed');
  if(e.flags&32){const difference=cvtt(f(f(e.frameEnd)-f(e.frameStart))),plus=(difference+1)|0,size=plus>=0?plus:~difference;if(size!==0)particle.frame44=cvtt(f(f(random(p)%size)+f(e.frameStart)));}
  appendEmitterParticle(e,particle,p);
 }
 while(e.active188.records.length>count)releaseLast(e,p);
 for(const particle of e.active188.records){if(f(particle.age)===f(particle.field48)){particle.field48=0;particle.age=0;}particle.age=f(f(particle.age)+delta);if(e.renderMode1a8===6){const blend=f((f(e.blurLength)<delta?f(e.blurLength):delta)/f(e.blurLength)),rest=f(1-blend);particle.trail64=particle.position10.map((v,i)=>f(f(blend*f(v))+f(rest*f(particle.trail64[i]))));}}
 if(!(f(e.lightningElapsed)>f(e.lightningDelay))){
  const difference=call(p,'targetPosition',e.target1c0).map((v,i)=>f(f(v)-f(e.position1e0[i]))),q=particleRotationArc(e.lightningPreviousDirection,difference);
  for(const particle of e.active188.records){const relative=particle.position10.map((v,i)=>f(f(v)-f(e.lightningPreviousPosition[i]))),rotated=rotateParticleVector(q,relative);particle.position10=rotated.map((v,i)=>f(v+f(e.position1e0[i])));}
  e.lightningPreviousDirection=difference;e.lightningPreviousPosition=e.position1e0.map(f);return;
 }
 const first=at(e,0);if(f(e.xSize)===0&&f(e.ySize)===0)first.position10=e.position1e0.map(f);else call(p,'randomPosition',first,cvtt(f(f(f(e.xSize)*100)*factor)),cvtt(f(f(f(e.ySize)*100)*factor)));
 at(e,count-1).position10=call(p,'targetPosition',e.target1c0).map(f);
 const difference=first.position10.map((v,i)=>f(f(v)-f(at(e,count-1).position10[i])));if(difference.every(v=>v===0))return;
 e.lightningElapsed=0;
 const direction=normalizeParticleVector(difference),basis=[f(-direction[1]),direction[2],f(-direction[0])],other=crossParticleVector(direction,basis),half=Math.trunc(count*.5);
 recursiveLightningFractal(e,half,half,1,basis,other,factor,p);
 const squared=f(f(f(difference[1]*difference[1])+f(difference[0]*difference[0]))+f(difference[2]*difference[2])),extent=f(f(f(Math.sqrt(squared))/f(e.active188.records.length))*.5);
 for(let i=1;i<e.active188.records.length-1;i++){
  if(extent<.01)return;const sign=(random(p)&1)?1:-1,divisor=cvtt(f(extent*100));if(!divisor)throw new Error('Native Lightning jitter causes integer division by zero');
  // This owner uses DOUBLE *.01 before CVTPD2PS, unlike RecursiveFractal.
  const distance=f((random(p)%divisor)*.01),scale=f(e.lightningScale),partScale=f(e.partScale),particle=at(e,i);
  particle.position10=particle.position10.map((v,axis)=>f(f(f(f(f(sign*direction[axis])*distance)*scale)*partScale)+f(v)));
 }
}
