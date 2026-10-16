import {multiplyParticleQuaternion,rotateParticleVector,particleRotationArc} from './particle_math.js';
const f=Math.fround,GRAVITY=f(9.8100004196167),EPSILON=f(.019999999552965164),BOUNCE_TIME=f(.032999999821186066);
const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native particle movement provider ${name} is unavailable`);return p[name](...args);};
const add=(a,b)=>a.map((v,i)=>f(f(v)+f(b[i]))),subtract=(a,b)=>a.map((v,i)=>f(f(v)-f(b[i])));

// Complete moveParticleStandard140068010..1400687f9. Wind, client scene
// intersection and chunk hit-ignore lists are lower providers, not synthetic
// substitutes. The loop and every arithmetic/collision branch execute here.
export function moveStandardParticles(e,delta,p){
  delta=f(delta);if(e.active188.records.length===0)return;
  const flags=e.flags,inheritLocal=(flags>>>8)&1,inheritPart=(flags>>>10)&1,inherit=(flags>>>6)&1,bounce=(flags>>>4)&1;
  // Native unary quaternion minus flips W only (negative conjugate).
  const previous=e.previousQuaternion178.map(f);previous[0]=f(previous[0]*-1);
  const rotation=multiplyParticleQuaternion(e.quaternion1d0,previous);
  for(let i=0;i<e.active188.records.length;i++){
    const particle=e.active188.records[i];if(particle.stopped70!==0)continue;
    const old=particle.position10.map(f);let position=[...old];
    if(inherit){
      position=add(rotateParticleVector(rotation,subtract(old,e.previous19c)),e.position1e0);
      particle.velocity58=rotateParticleVector(rotation,particle.velocity58);
    }
    if(inheritLocal&&!inherit&&e.source50){const shift=subtract(e.source50.position,e.reference10c);position=add(position,shift);particle.trail64=add(particle.trail64,shift);}
    if(inheritPart){const shift=subtract(e.position1e0,e.reference10c);position=add(position,shift);particle.trail64=add(particle.trail64,shift);}
    const inherited=f(particle.inheritedSpeed20),velocity=particle.velocity58,direction=particle.inheritedDirection24;
    particle.position10=position.map((v,axis)=>{
      const travel=f(delta*f(velocity[axis])),carried=f(f(inherited*f(direction[axis]))*delta);
      return axis===0?f(f(travel+v)+carried):f(carried+f(travel+v));
    });
    if(e.flags&4){particle.position10=add(particle.position10,call(p,'wind',position,delta));}
    const damped=f(f(1-delta)*f(particle.inheritedSpeed20));particle.inheritedSpeed20=damped;
    particle.velocity58[2]=f(f(particle.velocity58[2])-f(f(f(e.mass)*GRAVITY)*delta));
    if(damped<0)particle.inheritedSpeed20=f(damped*-1);
    call(p,'clearHit',e.hit1f0);
    if(!bounce)continue;
    if(e.chunkName.length){call(p,'resetIgnoredHits',e.hit1f0);if(particle.chunk78)call(p,'addIgnoredHit',e.hit1f0,particle.chunk78);}
    if(!call(p,'collide',old,[...particle.position10],particle.position10,e.hit1f0))continue;
    let speedSquared=0;const normal=e.hit1f0.normal.map(f);
    if(f(e.bounceCoefficient)===0)particle.velocity58=[0,0,0];
    else{
      const v=particle.velocity58.map(f),dot=f(f(f(v[0]*normal[0])+f(v[1]*normal[1]))+f(v[2]*normal[2]));
      particle.velocity58=v.map((value,axis)=>f(f(f(f(normal[axis]*f(-2))*dot)+value)*f(.75)));
      const damp=Math.max(f(.5),Math.min(1,f(BOUNCE_TIME/delta)));
      particle.velocity58[2]=f(f(particle.velocity58[2]*f(e.bounceCoefficient))*damp);
      const [x,y,z]=particle.velocity58;speedSquared=f(f(f(x*x)+f(y*y))+f(z*z));
    }
    if(speedSquared<f(.5)){
      particle.stopped70=1;particle.quaternion34=particleRotationArc([0,0,1],normal);
      particle.position10=add(particle.position10,normal.map(v=>f(v*EPSILON)));particle.direction4c=[...normal];
      if(e.chunkName.length)particle.position10=add(particle.position10,normal.map(v=>f(f(e.sizeStart)*v)));
    }
  }
  if(e.source50&&inheritLocal){e.reference10c=e.source50.position.map(f);e.referenceQuaternion118=e.source50.quaternion.map(f);}
  else if(inheritPart){e.reference10c=e.position1e0.map(f);e.referenceQuaternion118=e.quaternion1d0.map(f);}
}
