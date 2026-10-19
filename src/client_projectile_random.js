import {normalizeNativeVector} from './native_vector.js';
import {nativeCosf,nativeSinf} from './native_math.js';
import {nativeAcosf,nativeProjectileSpeedRange} from './native_projectile_math.js';
const f=Math.fround,call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native random projectile provider ${n} is unavailable`);return p[n](...args);};
// Original DAT141428e7c is process-wide, not per projectile/actor/area.
export const clientProjectileRandomState={angleSide:0};
const draw=p=>{const value=call(p,'random');if(!Number.isInteger(value)||value<0||value>32767)throw new Error('Native projectile CRT draw is unavailable');return value;};

// Random mathematical branches of initialize987f10: kinds4/9/12. Model-ref
// parenting for kind12 remains a separate, required lower owner.
export function initializeRandomClientProjectile(state,orientation,delta,time,p){
 const kind=state.node.kind;if(![4,9,12].includes(kind))throw new Error(`Native projectile initialization kind ${kind} is unavailable`);
 const randomState=p.randomState;if(!randomState||!Number.isInteger(randomState.angleSide))throw new Error('Native projectile shared angle state is unavailable');
 orientation.splice(0,3,...normalizeNativeVector(orientation));
 let angle=nativeAcosf(orientation[0]);if(orientation[1]<0)angle=f(f(2*Math.PI)-angle);
 const offset=f(f((draw(p)%900)/10)*f(.017453292));angle=randomState.angleSide!==0?f(angle-offset):f(angle+offset);
 const vector=[nativeCosf(angle),nativeSinf(angle),0];
 if(kind===9){const negative=draw(p)%2===0,value=draw(p);vector[2]=negative?f((value%50)/-100):f((value%100)/100);}
 else vector[2]=f((draw(p)%100)/100);
 randomState.angleSide=randomState.angleSide===0?1:0;
 const length=f(Math.sqrt(f(f(f(f(delta[0])*f(delta[0]))+f(f(delta[1])*f(delta[1])))+f(f(delta[2])*f(delta[2]))))),range=nativeProjectileSpeedRange(length),speed=f((draw(p)%range)+3),normal=normalizeNativeVector(vector);
 state.velocity=normal.map(v=>f(speed*v));
 const scale=f(1/f(time*time));state.acceleration=delta.map((v,i)=>{const remaining=f(f(v)-f(time*state.velocity[i]));return f(f(remaining+remaining)*scale);});
 if(kind===12)state.auxiliaryModel=call(p,'linkRandomModel',state);
}
