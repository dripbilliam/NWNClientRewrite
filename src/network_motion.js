import {stepClientFacing} from './network_facing.js';
const f=Math.fround;
const length=v=>f(Math.sqrt(f(f(f(v[0]*v[0])+f(v[1]*v[1]))+f((v[2]??0)*(v[2]??0)))));
const sub=(a,b)=>a.map((v,i)=>f(v-b[i]));
const normalize=v=>{const n=length(v);return n>0?v.map(x=>f(x/n)):[0,0,0];};
export const clientPathAnimation=id=>[2,3,4,78,79,84,85,86,87].includes(id&65535);

// Client8114d0: transmitted rates are millimetres/second, world delta is ms.
// Ordinary paths accelerate/decelerate; script paths use the transmitted factor.
export function clientMotionDistance(s,dt){
 dt=dt>>>0;const animation=s.animation&65535;
 const rate=animation===78||animation===79?f(1600.0001220703125):f([2,3,84,85].includes(animation)?s.walkRate:s.runRate);
 if(!Number.isFinite(rate)||rate<0)throw new Error('Native client movement rate is unavailable');
 let acceleration=1,distance;
 if(s.script){distance=f(f(f(dt)*f(rate*f(s.factor)))/f(1e6));}
 else{
  let remaining=0,last=s.position;
  for(const point of s.path.slice(s.cursor)){remaining=f(remaining+length([f(point[0]-last[0]),f(point[1]-last[1]),0]));last=point;}
  const halfSecond=f(f(rate*f(1000))/f(2e6));let limit=1;
  if(!(halfSecond<remaining)){const ratio=f(remaining/halfSecond);limit=f((ratio<f(.01)?f(.1):f(Math.sqrt(ratio)))-f(f(dt)/f(1000)));}
  const old=f(s.acceleration),ramp=s.newPath?f(500):f(1000);let next=limit;
  if(old<=1){next=f(f(f(dt)/ramp)+old);if(limit<=next)next=limit;}
  acceleration=next<f(.1)?f(.1):next;
  distance=f(f(f(f(f(dt)*rate)*f(old+acceleration))*f(.5))/f(1e6));s.acceleration=acceleration;
 }
 return{distance,acceleration,rate};
}

// Original811fc0/804bf0 consume server waypoints, never compute a new route.
export function stepClientPath(s,distance,height=p=>p[2]){
 let position=[...s.position],direction=[...(s.orientation??[1,0,0])],done=false;
 while(s.cursor<s.path.length){
  const point=s.path[s.cursor],delta=[f(point[0]-position[0]),f(point[1]-position[1]),0],n=length(delta);
  if(distance<=n){
   if(n<=f(.01))position=[...point];else{direction=normalize(delta);position=position.map((v,i)=>f(f(distance*direction[i])+v));}
   if(s.cursor===s.path.length-1)done=length(sub(position,point))<=f(.01);
   break;
  }
  distance=f(distance-n);position=[...point];direction=n<=f(.01)?[...(s.orientation??[1,0,0])]:normalize(delta);
  if(s.cursor===s.path.length-1){done=true;break;}s.cursor++;
 }
 if(s.cursor===s.path.length-1&&!s.script){const end=s.path.at(-1),remaining=length([f(end[0]-s.position[0]),f(end[1]-s.position[1]),0]);if(remaining<=1&&f(f(direction[0]*(s.orientation?.[0]??1))+f(direction[1]*(s.orientation?.[1]??0)))<f(-.707)){direction=[f(-direction[0]),f(-direction[1]),0];s.animation=3;}}
 const z=height(position,s.position[2]);if(Number.isFinite(z))position[2]=f(z);
 return{position,direction,done};
}

// Original804840 corrects the displayed position over512ms; large corrections
// snap at four horizontal metres. Canonical server positions are never changed.
export function correctClientMotion(s,position,dt){
 s.correctionCue=null;const timer=s.correction>>>0;if(dt>=timer){s.correction=0;return[...position];}
 s.correction=timer-dt;const d=sub(s.position,s.render),xy=f(f(d[0]*d[0])+f(d[1]*d[1])),square=f(xy+f(d[2]*d[2]));
 if(square<f(1e-5)||xy>=16){s.correction=0;return[...position];}
 if([0,1].includes(s.visualAnimation??s.animation)&&square>=f(.04)){
  const direction=normalize(d),facing=normalize(s.orientation),dot=f(f(f(direction[1]*facing[1])+f(direction[0]*facing[0]))+f(direction[2]*facing[2]));
  const cross=f(f(direction[0]*facing[1])-f(direction[1]*facing[0]));
  s.correctionCue={animation:dot>=f(.707)?24:dot<=f(-.707)?25:cross<=0?27:26,type:6,duration:s.correction&65535};
 }
 const ratio=f(f(s.correction)/f(dt+s.correction));return s.render.map((v,i)=>f(f(f(v-position[i])*ratio)+position[i]));
}

// Presentation state belongs to the scene, separately from NetworkWorld proxies.
export class NetworkMotion{
 constructor({height=(_p,z)=>z,report=()=>{}}={}){this.height=height;this.report=report;this.objects=new Map();this.remainderMs=0;}
 ensure(object){
  let s=this.objects.get(object.id);if(s)return s;const r=object.replicated;if(!r?.position)return null;
  s={position:r.position.map(f),render:r.position.map(f),orientation:[1,0,0],animation:r.animation??0,restingBase:r.animation===1?1:0,walkRate:r.walkRate,runRate:r.runRate,path:[],cursor:0,acceleration:0,correction:0,script:0,factor:1,newPath:1,active:false};this.objects.set(object.id,s);this.orientation(s,r.orientation,true);s.targetOrientation??=[...s.orientation];return s;
 }
 orientation(s,value,immediate=false){let direction;if(Array.isArray(value))direction=value.map(f);else if(value?.vector)direction=value.vector.map(f);else if(value?.yaw!==undefined){const angle=value.yaw*Math.PI/180;direction=[f(-Math.sin(angle)),f(Math.cos(angle)),0];}if(direction){s.targetOrientation=direction;if(immediate)s.orientation=[...direction];}}
 observe(object,changes,created=false){
  const s=this.ensure(object);if(!s)return;
  if(created){s.position=object.replicated.position.map(f);s.render=[...s.position];s.path=[];s.active=false;s.acceleration=0;s.correction=0;}
  this.orientation(s,changes.orientation,created);for(const key of ['walkRate','runRate','animation'])if(changes[key]!==undefined)s[key]=changes[key];
  if(changes.animation===0||changes.animation===1)s.restingBase=changes.animation;
  if(changes.path!==undefined){
   s.script=changes.path.length?Number(Boolean(changes.field8F4||s.script)):s.script;
   if(changes.path.length)s.factor=f(changes.field8EC??1);
   if(changes.path.length&&clientPathAnimation(s.animation)){
    const end=changes.path.at(-1),prior=s.path.at(-1);
    if(!prior||Math.hypot(prior[0]-end[0],prior[1]-end[1])>.001||!s.active){s.path=changes.path.map(p=>[f(p[0]),f(p[1]),0]);s.cursor=0;s.newPath=1;s.active=true;}
   }else{s.path=[];s.cursor=0;s.active=false;}
  }
  if(changes.position){
   const next=changes.position.map(f);
   if(!s.active||!clientPathAnimation(s.animation)){
    if(length(sub(next,s.position))>f(.0001)){s.position=next;s.correction=512;}
   }
  }
 }
 update(seconds){
  if(!Number.isFinite(seconds)||seconds<0)return;const elapsed=seconds*1000+this.remainderMs,dt=Math.trunc(elapsed);this.remainderMs=elapsed-dt;
  for(const [id,s]of this.objects){
   s.correctionCue=null;
   if(s.active&&s.path.length&&clientPathAnimation(s.animation)){
    try{const {distance,acceleration,rate}=clientMotionDistance(s,dt),step=stepClientPath(s,distance,this.height);s.position=step.position;s.render=correctClientMotion(s,step.position,dt);s.movementDirection=step.direction;s.gait={animation:s.animation,rate,script:s.script,factor:s.factor,acceleration};
     if(step.done){s.active=false;s.acceleration=0;s.script=0;s.finished=true;}
    }catch(error){s.active=false;this.report('network.scene-movement-unavailable',error.message,{objectId:id});}
   }else if(s.correction)s.render=correctClientMotion(s,s.position,dt);
   // Reader781e80 stores desired facing separately at2b4. Client8114d0
   // selects the path direction while moving, then calls807690 each frame.
   const target=clientPathAnimation(s.animation)?s.movementDirection??s.orientation:s.targetOrientation;
   const facing=stepClientFacing(s.orientation,target,s.visualAnimation??s.animation,dt,{modelType:s.modelType??1,restored:s.restingBase});s.orientation=facing.orientation;s.facingTurn=facing.requests[0]??null;
  }
 }
 pose(id){const s=this.objects.get(id);return s?{position:[s.render[0],s.render[2],-s.render[1]],rotation:-Math.atan2(s.orientation[0],s.orientation[1])}:null;}
}
