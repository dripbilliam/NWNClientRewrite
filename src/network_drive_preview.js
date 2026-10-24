import {nativeSinf,nativeCosf} from './native_math.js';
import {normalizeNativeVector} from './native_vector.js';
import {resourceFlow} from './resource_flow.js';
const f=Math.fround;
const normalize=v=>{const n=f(Math.sqrt(f(f(f(v[0]*v[0])+f(v[1]*v[1]))+f(v[2]*v[2]))));return n>0?v.map(x=>f(x/n)):[0,0,0];};
//6f1e40 reapplies the transmitted tenth-degree heading before local preview.
// Its double-radian constant precedes CRT cos/sin and float-vector storage.
export function driveWireFacing(heading){const angle=(heading/10)*0.01745329238474369;return normalize([f(Math.cos(angle)),f(Math.sin(angle)),0]);}
export function driveTurnFacing(orientation,flags){
 const turn=flags&16?1:flags&32?-1:0;if(!turn)return orientation.map(f);
 const angle=f(f(turn*30)*f(.017453292)),c=nativeCosf(angle),s=nativeSinf(angle),[x,y]=orientation;
 return normalize([f(f(x*c)-f(y*s)),f(f(x*s)+f(y*c)),0]);
}
// Complete6ea9e0 finite-vector plan. Local path refresh250ms is distinct
// from drive packet refresh500ms. Rates are server millimetres/second.
export function drivePreviewPlan({position,orientation,walkRate,runRate},flags){
 if(![...position,...orientation,walkRate,runRate].every(Number.isFinite))throw Error('Native drive preview pose/rates unavailable');
 let vector=[0,0,0],distance=0,animation=2,run=false;const add=(v,sign=1)=>vector=vector.map((x,i)=>f(x+f(sign*v[i])));
 if(flags&4){add([-orientation[1],orientation[0],0]);distance=f(.8);animation=78;}
 else if(flags&8){add([orientation[1],-orientation[0],0]);distance=f(.8);animation=79;}
 if((flags&3)===3){add(orientation);distance=f(f(runRate*400)/f(1e6));animation=flags&4?86:flags&8?87:4;run=true;}
 else if(flags&1){add(orientation);distance=f(f(walkRate*400)/f(1e6));animation=flags&4?84:flags&8?85:2;}
 else if(flags&2){add(orientation,-1);distance=f(f(walkRate*400)/f(1e6));animation=3;}
 const facing=driveTurnFacing(orientation,flags);if(flags&48)vector=driveTurnFacing(vector,flags);
 const direction=normalize(vector),target=position.map((v,i)=>f(v+f(direction[i]*distance)));
 return{target,facing,animation,run,mode:2};
}
//7fdeb0 direct-line/bisection phase. The complete mode2 owner below
// additionally searches angular brackets if no positive fraction is clear.
export function clipDrivePreview(from,target,clear,options={}){return resourceFlow(clipPreview(from,target,clear,options));}
function* clipPreview(from,target,clear,{onPartial=()=>{}}={}){
 if(yield clear(from,target))return target;
 let fraction=f(.5),step=f(.25),best=null;
 do{const point=from.map((v,i)=>f(v+f(f(target[i]-v)*fraction)));if(yield clear(from,point)){best=point;fraction=f(fraction+step);}else fraction=f(fraction-step);step=f(step*.5);}while(f(.005)<step);
 if(best)onPartial(fraction);return best;
}
//7fdeb0 mode2: if every forward fraction is blocked, bisect the two
// angular brackets up to15 times, then verify the native scaled slide.
// The rendered origin and path speed factor are distinct from canonical state.
export function drivePreviewPath(from,target,clear,options={}){return resourceFlow(previewPath(from,target,clear,options));}
function* previewPath(from,target,clear,{render=from}={}){
 from=from.map(f);target=target.map(f);render=render.map(f);
 let resendFraction;const clipped=yield clipDrivePreview(from,target,clear,{onPartial:value=>{resendFraction=value;}});if(clipped)return{target:clipped,factor:1,...(resendFraction===undefined?{}:{resendFraction})};
 const delta=target.map((v,i)=>f(v-from[i])),direction=normalizeNativeVector(delta),length=f(Math.sqrt(f(f(f(delta[0]*delta[0])+f(delta[1]*delta[1]))+f(delta[2]*delta[2]))));
 let bestA=normalizeNativeVector([-direction[1],direction[0],0]),bestB=normalizeNativeVector(bestA.map(v=>f(-v))),blockedA=direction.slice(),blockedB=direction.slice(),searchA=true,searchB=true,clearA=false,clearB=false;
 const sum=(a,b)=>normalizeNativeVector(a.map((v,i)=>f(v+b[i]))),endpoint=(v,distance)=>render.map((p,i)=>f(p+f(v[i]*distance))),dot=v=>f(f(f(v[1]*direction[1])+f(v[0]*direction[0]))+f(v[2]*direction[2]));
 for(let step=0;step<15&&(searchA||searchB);step++){
  const a=sum(bestA,blockedA),b=sum(bestB,blockedB);
  if(searchA)clearA=Boolean(yield clear(from,endpoint(a,length)));
  if(searchB)clearB=Boolean(yield clear(from,endpoint(b,length)));
  if(searchA){if(clearA)bestA=a;else{searchA=!clearB;blockedA=a;}}
  if(searchB){if(clearB)bestB=b;else{searchB=!clearA;blockedB=b;}}
 }
 const selected=searchA===searchB?(dot(bestA)<=dot(bestB)?bestB:bestA):searchA?bestA:bestB;
 const factor=Math.max(f(.25),dot(selected)),end=endpoint(selected,f(factor*length));
 return (yield clear(from,end))?{target:end,factor}:null;
}
//6f1bc0 subtracts500000-trunc(floatRatio*500000.0) microseconds
// from the current timer. The multiplication here is native double precision.
export function partialDriveSendTimestamp(now,fraction){return now-(500000-Math.trunc(f(fraction)*500000))/1000;}
export const blockedDrivePreviewAnimation=id=>[6,8,17,18,19,20,61,70,71,221,222,250,251,252,253,261].includes(id);
