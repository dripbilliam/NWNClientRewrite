import {nativeAtan2f,nativeCosf,nativeSinf} from './native_math.js';
import {normalizeNativeVector} from './native_vector.js';
import {multiplyParticleQuaternion} from './particle_math.js';
const f=Math.fround;
// CNWCAnimBaseProjectile9ddda0 -> Pitch(Vector), Yaw(Vector), YawPitchRoll.
// Native forward is +Y, yaw about +Z, then local pitch about +X; the renderer
// basis transform is separate. Native CRT providers reject unproved branches.
export function clientProjectileModelQuaternion(vector){
 vector=vector.map(f);const [x,y,z]=vector,length=f(Math.sqrt(f(f(f(x*x)+f(y*y))+f(z*z))));
 if(length<=f(.0001))return null;
 return clientProjectileImpactQuaternion(normalizeNativeVector(vector));
}
// AI983860 calls vector Pitch/Yaw directly: no model setter's normalization
// or near-zero cutoff. Even a zero vector writes an identity root quaternion.
export function clientProjectileImpactQuaternion(vector){
 const v=vector.map(f),yaw=v[0]!==0||v[1]!==0?f(nativeAtan2f(f(-v[0]),v[1])*f(57.295776)):0,
  pitch=f(nativeAtan2f(v[2],f(Math.sqrt(f(f(v[1]*v[1])+f(v[0]*v[0])))))*f(57.295776));
 let quaternion=[1,0,0,0];
 if(yaw!==0){const angle=f(f(yaw*f(.017453292))*.5),s=nativeSinf(angle);quaternion=[nativeCosf(angle),f(0*s),f(0*s),s];}
 if(pitch!==0){const angle=f(f(pitch*f(.017453292))*.5),s=nativeSinf(angle),p=[nativeCosf(angle),s,f(0*s),f(0*s)];quaternion=multiplyParticleQuaternion(quaternion,p);}
 return quaternion;
}
