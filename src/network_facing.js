import {nativeSinf,nativeCosf} from './native_math.js';
const f=Math.fround;
const normalize=v=>{const n=f(Math.sqrt(f(f(f(v[0]*v[0])+f(v[1]*v[1]))+f(v[2]*v[2]))));return n>0?v.map(x=>f(x/n)):[0,0,0];};

// Full finite-vector client807690 policy. Target direction is distinct from
// displayed facing; native turns run every elapsed frame, not every packet.
export function stepClientFacing(orientation,target,animation,dt,{model=true,modelType=1,restored=0}={}){
 const desired=normalize([f(target[0]),f(target[1]),0]),old=orientation.map(f),id=animation&65535;
 const dot=f(f(f(old[1]*desired[1])+f(old[0]*desired[0]))+f(old[2]*desired[2]));
 const sign=f(f(old[0]*desired[1])-f(old[1]*desired[0]))<0?-1:1,requests=[];
 if(dot<1&&(id<=1||id===53||id===54)){
  if(dot>=f(.99))return{orientation:old,target:desired,requests};
  const base=id===53||id===54?restored:id;
  if(base===0&&model&&modelType===1)requests.push(sign<0?80:81);
  else if(base===1)requests.push(sign<0?82:83);
 }
 let speed=f(f(1-dot)*3);if(id===4)speed=f(speed+speed);speed=speed<=f(.55)?f(.55):Math.min(f(1.55),speed);
 const angle=f(f(f(f(dt>>>0)*speed)*4000)/f(1e6));
 let next=desired;
 if(dot<nativeCosf(angle)){const signed=f(angle*sign),c=nativeCosf(signed),s=nativeSinf(signed);next=[f(f(old[0]*c)-f(old[1]*s)),f(f(old[0]*s)+f(old[1]*c)),0];}
 return{orientation:normalize(next),target:desired,requests};
}
