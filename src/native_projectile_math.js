import {nativeLogfBranches} from './native_log.js';
const f=Math.fround,view=new DataView(new ArrayBuffer(4));
const bits=v=>{view.setFloat32(0,v,true);return view.getUint32(0,true);},value=b=>{view.setUint32(0,b,true);return view.getFloat32(0,true);};

// Finite acosf140c79a38..c79c86. This CRT uses double PI corrections in
// two branches; replacing it with halfPI-asinf changes native float bits.
export function nativeAcosf(input){
 const x=f(input),a=Math.abs(x),exp=(bits(a)>>>23)&255;
 if(!Number.isFinite(x)||a>1)throw new Error('Native acosf exceptional branch is unavailable');
 if(exp<0x65)return f(Math.PI/2);
 if(x===1)return 0;if(x===-1)return f(Math.PI);
 const z=exp<0x7e?f(a*a):f(f(1-a)*.5),root=exp<0x7e?a:f(Math.sqrt(z));
 let r=f(f(-.013381929136812687)-f(z*f(.003961374517530203)));
 r=f(f(r*z)-f(.05652986839413643));r=f(f(r*z)+f(.18416160345077515));r=f(f(r*z)/f(f(1.1049696207046509)-f(z*f(.8364112973213196))));
 if(exp<0x7e)return f(Math.PI/2-(x-(6.123233995736766e-17-f(r*x))));
 if(x<0)return f(Math.PI-2*((f(r*root)-6.123233995736766e-17)+root));
 const split=value(bits(root)&0xffff0000),correction=f(f(z-f(split*split))/f(split+root));
 return f(f(f(f(root+root)*r)+f(correction+correction))+f(split*2));
}

// Positive logf140c946b0, explicit original SSE/FMA dispatch. FP status and
// exceptional arguments are not implemented. Explicit profile selection avoids
// silently picking the original process's unknown CPU-dispatch state.
export function nativePositiveLogf(input,dispatch){
 const x=f(input);if(!(x>0)||!Number.isFinite(x)||![0,1].includes(dispatch))throw new Error('Native positive logf input/profile is unavailable');
 return nativeLogfBranches(x)[dispatch];
}

// Only the integer speed bound is observable to the initializer. Permit
// differing interior log bits iff BOTH CPU dispatches produce the same bound.
export function nativeProjectileSpeedRange(distance){
 const bucket=dispatch=>{const v=f(nativePositiveLogf(distance,dispatch)*5),i=Number.isFinite(v)&&v>=-2147483648&&v<2147483648?Math.trunc(v):-2147483648;return((Math.abs(i)|0)+1)|0;};
 const sse=bucket(0),fma=bucket(1);if(sse!==fma)throw new Error('Native projectile logf CPU dispatch changes the speed bound');return sse;
}
