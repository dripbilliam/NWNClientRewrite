import {normalizeTileVector} from './tile_surface_mesh.js';
const f=Math.fround,add=(a,b)=>f(a+b),sub=(a,b)=>f(a-b),mul=(a,b)=>f(a*b),epsilon=f(.0001);
const plus=(a,b)=>a.map((n,i)=>add(n,b[i])),minus=(a,b)=>a.map((n,i)=>sub(n,b[i])),scale=(a,k)=>a.map(n=>mul(n,k));
const magnitude=a=>f(Math.sqrt(add(add(mul(a[0],a[0]),mul(a[1],a[1])),mul(a[2],a[2]))));
export const cameraCollisionState=()=>({primary:{distance:0,focus:[0,0,0]},stiff:{distance:0,focus:[0,0,0]}});
// Original dispatcher7d07d0 and primary7d2940/stiff7d3840. A query returns
// the native closest hit point or null; prediction is an explicit dependency
// so this module never needs a renderer or canonical game-object mutation.
export function stepCameraCollision(s,caches,{position,cameraPosition,enabled=true,eligible=true,clampsEnabled=true,flags=0},seconds,inputSpeed,query,predict){
 const speed=f(inputSpeed),dt=f(seconds);
 if(s.findClearView||(flags&2)||!enabled||!eligible)return speed;
 const focus=plus(position,s.offset),delta=minus(focus,cameraPosition);if(!(magnitude(delta)>0))return speed;
 const direction=normalizeTileVector(delta),nudge=scale(direction,f(.001)),cache=s.mode===2?caches.stiff:caches.primary;
 if(cache.focus.every(n=>n===0))cache.focus=[...position];
 const prediction=predict(cache.focus,speed);cache.focus=prediction.focus;const view=prediction.position;
 let zoom=speed,distance=0,clamp=true,recovering=false;
 const clippedDistance=point=>magnitude(minus(point,focus));
 const recover=()=>{
  if(!(cache.distance>0))return;
  const wanted=minus(focus,scale(direction,cache.distance)),hit=cache.distance<=s.distance?query(wanted,view):query(view,wanted);
  distance=add(s.distance,mul(mul(sub(cache.distance,s.distance),3.5),dt));
  if(hit){const limit=clippedDistance(plus(hit,nudge));if(limit<=distance)distance=limit;}
  else{
   recovering=true;
   if(s.mode===2?cache.distance<=distance:sub(distance,cache.distance)>=f(-.0001)){distance=cache.distance;cache.distance=0;}
  }
 };
 let negativeOnly=false;
 if(s.mode===2){
  const hit=query(focus,view);
  if(hit){distance=clippedDistance(plus(hit,nudge));if(cache.distance===0)cache.distance=s.distance;}
  else recover();
 }else{
  let retry=false;
  if(speed<0){
   const far=minus(focus,scale(direction,s.effectiveLimits.maxDist)),first=query(view,far),second=first?query(plus(first,nudge),view):query(far,view);
   if(second){distance=clippedDistance(minus(second,nudge));cache.distance=0;negativeOnly=true;}
   else retry=true;
  }
  if(!negativeOnly){
   const first=query(view,focus),second=first?query(minus(first,nudge),view):query(focus,view);
   if(second){if(cache.distance===0)cache.distance=s.distance;if(retry)zoom=0;distance=clippedDistance(plus(second,nudge));}
   else recover();
  }
 }
 if(!negativeOnly){
  if(speed>0)cache.distance=0;
  if(distance===0&&s.distance<s.effectiveLimits.minDist||distance>0&&sub(s.effectiveLimits.minDist,distance)>=epsilon){clamp=false;if(cache.distance<s.effectiveLimits.minDist)cache.distance=s.effectiveLimits.minDist;zoom=0;}
 }
 if(clampsEnabled){
  s.clampDist=Number(clamp);
  if(distance>0){s.distance=distance;if(!recovering)zoom=0;s.manual=1;}
  if(s.distance<=s.effectiveLimits.minDist)zoom=Math.min(zoom,0);
  if(s.distance>=s.effectiveLimits.maxDist)zoom=Math.max(zoom,0);
 }
 return zoom;
}
