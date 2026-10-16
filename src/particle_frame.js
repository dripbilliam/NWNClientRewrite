import {particleQuaternionBasis} from './particle_math.js';
const f=Math.fround;
const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native particle frame provider ${name} is unavailable`);return p[name](...args);};
function transform(e,p){
  const pose=call(p,'globalTransform',e);
  e.position1e0=pose.position.map(f);e.quaternion1d0=pose.quaternion.map(f);
}
// Complete PartEmitter::AnimateParticles140061210..1400615ec. Render
// visibility gates stop simulation as in the original, rather than merely
// hiding newly emitted quads. The virtual Update and world transform remain
// explicit providers so the same frame owner can serve every emitter class.
export function animateEmitterParticles(e,delta,p){
  delta=f(Math.min(f(.5),f(delta)));
  if(e.source50?.instance&&1>f(e.source50.instance.fade))return;
  if(e.instance100&&1>f(e.instance100.fade))return;
  let shift=[0,0,0];
  if(e.flags&256&&e.source50&&e.initialized208)shift=e.source50.position.map((v,i)=>f(f(v)-f(e.reference10c[i])));
  if(!e.initialized208){
    transform(e,p);
    if(e.source50&&(e.flags&0x500)){e.reference10c=e.source50.position.map(f);e.referenceQuaternion118=e.source50.quaternion.map(f);}
    if(e.flags&1024){e.reference10c=e.position1e0.slice();e.referenceQuaternion118=e.quaternion1d0.slice();}
    e.initialized208=1;
  }
  e.previous19c=e.position1e0.map((v,i)=>e.flags&256?f(shift[i]+f(v)):f(v));
  e.previousQuaternion178=e.quaternion1d0.map(f);
  if(e.source50)transform(e,p);
  e.basis140=particleQuaternionBasis(e.quaternion1d0);
  call(p,'updateEmitter',e,delta);
}
