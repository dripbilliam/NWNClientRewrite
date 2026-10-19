import {Quaternion,Vector3} from 'three';
import {nativeLogfBranches} from './native_log.js';
import {cameraCollisionState,stepCameraCollision} from './camera_collision.js';
import {addCameraRate} from './camera_rate_input.js';
const f=Math.fround,rad=f(.017453292),deg=f(57.295776);
// Finite CRT trigonometry is a presentation boundary in the native oracle.
// Round at its float return; do not constrain a continuously orbiting camera
// to the smaller angle domain used by deterministic gameplay math.
const nativeSinf=v=>f(Math.sin(f(v))),nativeCosf=v=>f(Math.cos(f(v)));
const add=(a,b)=>f(a+b),mul=(a,b)=>f(a*b),clamp=(v,lo,hi)=>Math.max(lo,Math.min(hi,v));
const walking=new Set([2,3,4,78,79,84,85,86,87]);
export function cameraAngle(value){while(value< -180)value=add(value,360);while(value>180)value=add(value,-360);return value;}
// Original quaternion layout is w,x,y,z, and its world is Z-up.
function product(a,b){const [w,x,y,z]=a,[v,i,j,k]=b;return[f(mul(w,v)-mul(x,i)-mul(y,j)-mul(z,k)),f(mul(w,i)+mul(x,v)+mul(y,k)-mul(z,j)),f(mul(w,j)-mul(x,k)+mul(y,v)+mul(z,i)),f(mul(w,k)+mul(x,j)-mul(y,i)+mul(z,v))];}
export function cameraQuaternion(yaw,pitch){
 const a=mul(mul(yaw,rad),.5),b=mul(mul(pitch,rad),.5);
 return product([nativeCosf(a),0,0,nativeSinf(a)],[nativeCosf(b),nativeSinf(b),0,0]);
}
function slerp(a,b,t){
 let dot=add(add(add(mul(a[0],b[0]),mul(a[1],b[1])),mul(a[2],b[2])),mul(a[3],b[3]));
 if(dot<0){a=a.map(v=>-v);dot=-dot;}
 let q;if(Math.abs(dot)>=1)q=[...a];else{const angle=f(Math.acos(dot));if(angle===0)q=[...a];else{const sin=nativeSinf(angle),bt=f(nativeSinf(mul(angle,t))/sin),at=f(nativeSinf(f(angle-mul(angle,t)))/sin);q=a.map((v,i)=>add(mul(v,at),mul(b[i],bt)));}}
 const square=add(add(add(mul(q[1],q[1]),mul(q[0],q[0])),mul(q[2],q[2])),mul(q[3],q[3]));if(square===1)return q;if(!(square>0))return[1,0,0,0];const scale=f(Math.sqrt(f(1/square)));return q.map(v=>mul(v,scale));
}
export function cameraQuaternionYaw(q){const [w,x,y,z]=q,a=mul(2,f(mul(x,y)-mul(w,z))),b=f(1-mul(2,add(mul(z,z),mul(x,x))));return a===0&&b===0?0:mul(f(Math.atan2(-a,b)),deg);}
// CAurBehaviorCameraFollow::Control55100: rates/deltas are consumed once;
// exponential distance change and quaternion/focus spring use elapsed seconds.
export function stepCameraFollow(s,seconds,target){
 const dt=f(seconds);s.yaw=add(add(mul(dt,s.turn??0),s.yaw),s.turnDelta??0);s.turn=0;s.turnDelta=0;
 if(s.clampYaw)s.yaw=clamp(s.yaw,s.minYaw,s.maxYaw);
 s.pitch=add(add(mul(dt,s.tilt??0),s.pitch),s.tiltDelta??0);s.tilt=0;s.tiltDelta=0;
 if(s.clampPitch)s.pitch=clamp(s.pitch,s.minPitch,s.maxPitch);
 s.distance=mul(f(Math.pow(2,mul(mul(dt,s.speed??0),-.5))),s.distance);s.speed=0;
 if(s.clampDist)s.distance=clamp(s.distance,s.minDist,s.maxDist);
 const alpha=f(1-f(Math.pow(.5,mul(dt,s.spring)))),old=f(1-alpha),offset=s.offset??[0,0,s.height??1];
 s.focus=s.focus.map((v,i)=>add(mul(add(target[i],offset[i]),alpha),mul(old,v)));
 s.quaternion=slerp(s.quaternion,cameraQuaternion(s.yaw,s.pitch),alpha);
 const [w,x,y,z]=s.quaternion;
 const axis=[mul(2,add(mul(w,y),mul(x,z))),mul(2,f(mul(y,z)-mul(w,x))),f(1-mul(2,add(mul(y,y),mul(x,x))))];
 s.position=s.focus.map((v,i)=>add(mul(axis[i],s.distance),v));return s;
}
// Native7cc070: one-shot entry/attachment search. Prediction7cc730 has its
// own module focus and global pitch/distance limits; it does not consume the
// actual Follow inputs or replace its displayed quaternion. A scene query is
// an explicit boundary: true means the segment hit geometry.
export function findCameraClearView(s,{position,facing,focus=s.focus},seconds,blocked){
 s.yaw=f(facing);s.manualLatch=1;s.turning=0;
 const limits=s.effectiveLimits,predicted={...s,...s.predictionInputs,focus:[...focus],quaternion:[...s.quaternion],spring:750,clampYaw:0,clampPitch:1,minPitch:limits.minPitch,maxPitch:limits.maxPitch,clampDist:1,minDist:limits.minDist,maxDist:limits.maxDist};
 stepCameraFollow(predicted,seconds,position);
 const end=position.map((v,i)=>add(v,s.offset[i])),start=predicted.position,delta=start.map((v,i)=>f(v-end[i])),z=add(delta[2],end[2]);
 let queries=0;
 const hit=p=>{queries++;return blocked(p,end);};
 let selected=false;
 if(hit(start)){
  if(!hit([add(-delta[0],end[0]),add(-delta[1],end[1]),z])){s.yaw=add(s.yaw,180);selected=true;}
  else if(!hit([add(end[0],-delta[1]),f(end[1]- -delta[0]),z])){s.yaw=add(s.yaw,-90);selected=true;}
  // The native fourth segment repeats the first endpoint, yet selects +90.
  // Preserve the executed behavior rather than inventing a corrected endpoint.
  else if(!hit(start)){s.yaw=add(s.yaw,90);selected=true;}
 }
 return{selected,queries,focus:predicted.focus};
}
// Gameplay mode owners7d0d00/7d0ab0/7d1c90. A manual camera gesture latches
// chase steering off until movement starts again; top-down never auto-turns.
export function stepCameraSteering(s,{facing,animation,strafe=0,strafing=0},seconds){
 if(s.mode===1)return s;
 if(walking.has(animation)){if(s.wasIdle){s.manualLatch=0;s.wasIdle=0;}}else s.wasIdle=1;
 if(s.manual){s.manualLatch=1;s.turning=0;return s;}
 if(s.manualLatch)return s;
 const yaw=s.mode===0?cameraQuaternionYaw(s.quaternion):s.yaw;
 let difference=cameraAngle(f(facing-yaw));
 if(!strafing){if(difference>90&&strafe===2)difference=-90;else if(difference< -90&&strafe===1)difference=90;}
 if(Math.abs(difference)<=1){s.turning=0;return s;}
 if(s.mode===0){if(Math.abs(difference)>30||s.turning){addCameraRate(s,'yaw',clamp(difference,-90,90));s.turning=1;}}
 else{
  let rate=clamp(mul(difference,5),-180,180),remaining=cameraAngle(f(facing-add(mul(rate,f(seconds)),yaw)));
  if(rate>.0001&&remaining<.0001||rate<.0001&&remaining>.0001)rate=f(f(facing-yaw)/f(seconds));
  addCameraRate(s,'yaw',rate);s.turning=1;
 }
 return s;
}
// Native7d11f0 synchronizes yaw/pitch and exponential distance rates using the
// slowest axis. The transition integer is a rate, not a tween duration.
export function stepCameraLocation(s,seconds,paused=false){
 const t=s.scriptLocation,epsilon=f(.0001),dt=f(seconds),div=(a,b)=>f(a/b),abs=Math.abs;
 if(!t||t.rate<epsilon)return true;if(paused)return false;
 // Preserve CRT IEEE results for a zero/infinite ratio; the shared gameplay
 // log provider deliberately throws for exceptional inputs outside its scope.
 const delta=cameraAngle(f(t.yaw-s.yaw)),pitchDelta=f(t.pitch-s.pitch),log=x=>x===Infinity?Infinity:Number.isNaN(x)||x<0?NaN:nativeLogfBranches(f(x))[0],ratio=log(div(t.distance,s.distance));
 let yawRate=t.rate,pitchRate,zoomRate=div(t.rate,abs(div(90,log(4))));
 const yawMetric=abs(div(delta,t.rate)),zoomMetric=abs(mul(div(-2,zoomRate),ratio)),pitchMetric=abs(div(pitchDelta,div(t.rate,f(3.6734693))));
 if(!(yawMetric>epsilon||zoomMetric>epsilon||pitchMetric>epsilon))return true;
 if(yawMetric<zoomMetric||yawMetric<pitchMetric){
  if(zoomMetric<yawMetric||zoomMetric<pitchMetric){yawRate=abs(div(delta,pitchMetric));pitchRate=div(t.rate,f(3.6734693));zoomRate=abs(div(add(ratio,ratio),pitchMetric));}
  else{yawRate=abs(div(delta,zoomMetric));pitchRate=abs(div(pitchDelta,zoomMetric));}
 }else{zoomRate=abs(div(add(ratio,ratio),yawMetric));pitchRate=abs(div(pitchDelta,yawMetric));}
 const current=cameraAngle(s.yaw),target=cameraAngle(t.yaw),difference=cameraAngle(f(target-current)),turn=difference<0?-yawRate:difference>0?yawRate:0,next=add(mul(turn,dt),current);
 let yawDone=true,zoomDone=true,pitchDone=true;
 if(target<current&&next<target||current<target&&target<next)s.yaw=target;
 else if(current!==target){addCameraRate(s,'yaw',turn);yawDone=false;}
 if(s.mode!==2){
  const speed=t.distance<s.distance?zoomRate:t.distance>s.distance?-zoomRate:0,predicted=mul(s.distance,f(Math.pow(2,mul(mul(speed,dt),-.5))));
  if(s.distance>t.distance&&predicted<t.distance||s.distance<t.distance&&predicted>t.distance)s.distance=t.distance;
  else if(s.distance!==t.distance){addCameraRate(s,'zoom',speed);zoomDone=false;}
  const tilt=s.pitch>t.pitch?-pitchRate:s.pitch<t.pitch?pitchRate:0,predictedPitch=add(mul(tilt,dt),s.pitch);
  if(t.pitch<s.pitch&&predictedPitch<t.pitch||s.pitch<t.pitch&&t.pitch<predictedPitch)s.pitch=t.pitch;
  else if(s.pitch!==t.pitch){addCameraRate(s,'pitch',tilt);pitchDone=false;}
 }
 return yawDone&&zoomDone&&pitchDone;
}
const conversion=new Quaternion().setFromAxisAngle(new Vector3(1,0,0),-Math.PI/2);
const defaultLimits=Object.freeze({minPitch:1,maxPitch:89,minDist:1,maxDist:25});
export class GameCamera{
 constructor(){this.reset();}
 reset({mode=this.mode??1,yaw=0,position=null,height=1}={}){
  this.appearanceHeight=height;height=Math.max(1,f(height-(mode===1?.5:0)));
  Object.assign(this,{mode,yaw:f(yaw),pitch:50,distance:20,height,offset:[0,0,height],spring:750,clampPitch:1,minPitch:1,maxPitch:89,clampDist:1,minDist:1,maxDist:25,clampYaw:0,minYaw:0,maxYaw:360,turn:0,tilt:0,speed:0,turnDelta:0,tiltDelta:0,zoomImpulse:0,manual:0,manualLatch:0,turning:0,wasIdle:1});
  this.quaternion=cameraQuaternion(this.yaw,this.pitch);this.focus=position?position.map((v,i)=>f(v+this.offset[i])):null;this.position=null;
  this.defaultHeight=height;this.heightOverride=null;this.modeAppearanceHeight=null;this.rawLimits={minPitch:-1,maxPitch:-1,minDist:-1,maxDist:-1};this.effectiveLimits={...defaultLimits};this.locks={pitch:false,distance:false,yaw:false};this.savedCamera=null;this.scriptLocation=null;this.rememberedPose=null;this.findClearView=false;this.clearViewResult=null;this.clearViewFocus=null;this.flags=0;this.collisionState=cameraCollisionState();this.predictionInputs=null;this.yawEvent=0;this.zoomEvent=0;
 }
 // Native7cf6f0 -> Camera::SetFollow5b4c0 creates a fresh Follow behavior.
 // Global script locks remain set, but locked bounds retain ctor defaults.
 attach({position,height=1,creature=true,findClearView=false,clampsEnabled=true}){
  const pose=this.rememberedPose;this.setHeight(creature?height:1);if(!creature){this.defaultHeight=1;this.height=1;this.offset=[0,0,1];}
  Object.assign(this,{focus:position.map(f),distance:8,yaw:0,pitch:this.effectiveLimits.maxPitch,spring:750,turn:0,tilt:0,speed:0,turnDelta:0,tiltDelta:0,zoomImpulse:0,clampYaw:0,minYaw:0,maxYaw:360,clampPitch:Number(clampsEnabled),minPitch:this.locks.pitch?0:this.effectiveLimits.minPitch,maxPitch:this.locks.pitch?360:this.effectiveLimits.maxPitch,clampDist:Number(clampsEnabled),minDist:this.locks.distance?0:this.effectiveLimits.minDist,maxDist:this.locks.distance?10:this.effectiveLimits.maxDist,findClearView});
  if(pose&&pose.distance!==0)Object.assign(this,pose);this.clearViewFocus=[...this.focus];this.clearViewResult=null;
 }
 setHeight(height,{preserveOverride=false}={}){this.appearanceHeight=height;this.defaultHeight=Math.max(1,f(height-(this.mode===1?.5:0)));if(!preserveOverride)this.heightOverride=null;this.height=this.heightOverride??this.defaultHeight;this.offset=[0,0,this.height];}
 bound(key){return this.rawLimits[key]>=0?this.rawLimits[key]:defaultLimits[key];}
 setMode(mode,height=this.modeAppearanceHeight??this.appearanceHeight){if(![0,1,2].includes(mode))return false;if(this.mode!==mode){this.mode=mode;this.pitch=50;this.distance=20;this.setHeight(height);this.manualLatch=0;this.turning=0;for(const key of Object.keys(defaultLimits))this.effectiveLimits[key]=this.bound(key);for(const [axis,lo,hi]of [['pitch','minPitch','maxPitch'],['distance','minDist','maxDist']])if(!this.locks[axis]){this[lo]=this.bound(lo);this[hi]=this.bound(hi);}}return true;}
 // Receiver77a7f0 and Store7cfd30/Restore7cf350. Limits9 are stored until
 // mode initialization or unlocking, rather than silently clamping at receipt.
 applyCommand(command){
  if(command.kind==='camera-flags'){if(!Number.isInteger(command.flags)||command.flags< -2147483648||command.flags>2147483647)return false;this.flags=command.flags|0;return true;}
  if(command.kind==='camera-location'){
   const fields=['yawRadians','distance','pitch','transition'];if(!Number.isInteger(command.mask)||command.mask<0||command.mask>255||fields.some((key,i)=>((command.mask&(1<<i))||Object.hasOwn(command,key))&&!Number.isFinite(command[key])))return false;
   const mask=command.mask,limits=this.effectiveLimits,distance=clamp(mask&2?f(command.distance):this.distance,limits.minDist,limits.maxDist),pitch=clamp(mask&4?f(command.pitch):this.pitch,limits.minPitch,limits.maxPitch);
   const yaw=mul(f(f(mask&1?command.yawRadians:this.yaw)-f(1.5707964)),deg),rate=mask&8?command.transition|0:0;
   this.scriptLocation={distance,yaw,pitch,rate:rate>=0&&rate<=180?rate:0};
   if(this.scriptLocation.rate===0){if(mask&1)this.yaw=f(Number(yaw.toFixed(6)));if(mask&2)this.distance=f(Number(distance.toFixed(6)));if(mask&4)this.pitch=f(Number(pitch.toFixed(6)));}return true;
  }
  if(command.kind==='camera-mode')return this.setMode(command.mode);
  if(command.kind==='camera-store'){this.savedCamera={mode:this.mode,distance:this.distance,yaw:this.yaw,pitch:this.pitch};return true;}
  if(command.kind==='camera-restore'){
   if(this.scriptLocation)this.scriptLocation.rate=0;
   const saved=this.savedCamera;this.savedCamera=null;if(!saved)return true;
   this.setMode(saved.mode);this.yaw=f(Number(saved.yaw.toFixed(6)));this.distance=f(Number((saved.distance===0?20:saved.distance).toFixed(6)));this.pitch=f(Number((saved.pitch===0?50:saved.pitch).toFixed(6)));return true;
  }
  if(command.kind==='camera-height'){if(!Number.isFinite(command.height))return false;this.heightOverride=command.height===0?null:f(command.height);this.height=this.heightOverride??this.defaultHeight;this.offset=[0,0,this.height];return true;}
  if(command.kind==='camera-limits'){if(!Object.keys(defaultLimits).every(key=>Number.isFinite(command.limits?.[key])))return false;this.rawLimits=Object.fromEntries(Object.keys(defaultLimits).map(key=>[key,f(command.limits[key])]));return true;}
  if(command.kind==='camera-lock'){
   const {axis}=command;if(!Object.hasOwn(this.locks,axis)||typeof command.locked!=='boolean')return false;const locked=command.locked;this.locks[axis]=locked;
   if(axis==='yaw'){this.minYaw=locked?this.yaw:0;this.maxYaw=locked?this.yaw:360;this.clampYaw=Number(locked);}
   else{const [lo,hi]=axis==='pitch'?['minPitch','maxPitch']:['minDist','maxDist'];this[lo]=locked?this[axis]:this.bound(lo);this[hi]=locked?this[axis]:this.bound(hi);if(!locked){this.effectiveLimits[lo]=this[lo];this.effectiveLimits[hi]=this[hi];}}
   return true;
  }
  return false;
 }
 input(values){if(Object.hasOwn(values,'yaw'))addCameraRate(this,'yaw',values.yaw,true);if(Object.hasOwn(values,'pitch'))addCameraRate(this,'pitch',values.pitch,true);if(Object.hasOwn(values,'zoom'))this.zoomImpulse=add(this.zoomImpulse??0,values.zoom);}
 update({position,facing=0,animation=0,paused=false,clearViewFacing=facing,clearViewQuery=null,collision=null},seconds,camera,controls){
  if(!position)return false;if(!this.focus)this.focus=position.map((v,i)=>f(v+this.offset[i]));
  //6e6220 invokes both angular rate setters each frame, including zero input.
  addCameraRate(this,'yaw',0);addCameraRate(this,'pitch',0);
  if(!this.findClearView){stepCameraSteering(this,{facing,animation},seconds);if(stepCameraLocation(this,seconds,paused)&&this.scriptLocation)this.scriptLocation.rate=0;this.rememberedPose={distance:this.distance,yaw:this.yaw,pitch:this.pitch};}
  //6edcfa accumulates wheel events at7.5 times the configured multiplier;
  //6e6220 passes that rate to Follow for this frame, then clears it.
  let zoom=this.zoomImpulse??0;this.zoomImpulse=0;
  if(collision?.query&&(!collision.keyholeActive||collision.disableWithKeyhole===false||(this.flags&1))){
   zoom=stepCameraCollision(this,this.collisionState,{...collision,flags:this.flags},seconds,zoom,collision.query,(focus,speed)=>stepCameraFollow({...this,...this.predictionInputs,focus:[...focus],quaternion:[...this.quaternion],offset:[0,0,1],speed,spring:750,clampYaw:0,clampPitch:1,minPitch:this.effectiveLimits.minPitch,maxPitch:this.effectiveLimits.maxPitch,clampDist:1,minDist:this.effectiveLimits.minDist,maxDist:this.effectiveLimits.maxDist},seconds,collision.position));
  }
  //7d4340 adds a nontrivial external wheel/key rate to the existing Follow
  // speed (which can already contain a script rate). Camera flag64 blocks it.
  if(Math.abs(zoom)>f(.0001))addCameraRate(this,'zoom',zoom);
  if(this.findClearView){
   //7cffc0 clears the one-shot flag even when the search fails. Leaving it set
   // permanently suppresses ordinary mode steering and scripted locations.
   this.clearViewResult=clearViewQuery?findCameraClearView(this,{position,facing:clearViewFacing,focus:this.clearViewFocus??this.focus},seconds,clearViewQuery):{selected:false,queries:0,unavailable:true};
   this.clearViewFocus=this.clearViewResult.focus??this.clearViewFocus;this.findClearView=false;
  }
  stepCameraFollow(this,seconds,position);this.manual=0;
  camera.position.set(this.position[0],this.position[2],-this.position[1]);
  camera.quaternion.copy(conversion).multiply(new Quaternion(this.quaternion[1],this.quaternion[2],this.quaternion[3],this.quaternion[0]));
  if(controls)controls.target.set(this.focus[0],this.focus[2],-this.focus[1]);camera.updateMatrixWorld?.();return true;
 }
 snapshot(){return{mode:this.mode,yaw:this.yaw,pitch:this.pitch,distance:this.distance,height:this.height,focus:this.focus,position:this.position,quaternion:this.quaternion,locks:{...this.locks},limits:{...this.rawLimits},savedCamera:this.savedCamera?{...this.savedCamera}:null,scriptLocation:this.scriptLocation?{...this.scriptLocation}:null,findClearView:this.findClearView,clearView:this.clearViewResult,flags:this.flags,collision:structuredClone(this.collisionState)};}
}
