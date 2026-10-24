import * as THREE from 'three';
import {multiplyParticleQuaternion,rotateParticleVector} from './particle_math.js';
import {restartVisualCurveSync,sampleVisualCurveSync} from './visual_curve.js';
const f=Math.fround,rad=f(.017453292);

// YawPitchRoll22f6d0: native yaw +Z, pitch +X, roll +Y, in degrees.
export function nativeVisualQuaternion([yaw,pitch,roll]){
 let q=[1,0,0,0];
 for(const[angle,axis]of [[yaw,3],[pitch,1],[roll,2]])if(angle!==0){
  const a=f(f(f(angle)*rad)*.5),r=[f(Math.cos(a)),0,0,0];r[axis]=f(Math.sin(a));q=multiplyParticleQuaternion(q,r);
 }
 return q;
}
export function adjustedVisualPose(position,quaternion,{rotation,translation,scale},baseScale=1){
 const offset=rotateParticleVector(quaternion,translation),delta=nativeVisualQuaternion(rotation);
 return{position:position.map((v,i)=>f(f(v)+offset[i])),quaternion:rotation.every(v=>v===0)?[...quaternion]:multiplyParticleQuaternion(quaternion,delta),scale:f(f(scale)*f(baseScale))};
}

export function identityVisualTransform(){
 const bytes=new Uint8Array(640),v=new DataView(bytes.buffer);
 for(const channel of [0,1,2,9]){v.setFloat32(channel*64+4,1,true);v.setFloat32(channel*64+8,1,true);}
 return bytes;
}
export function networkVisualTransformBytes(leaf,p){
 if(!leaf||leaf.identity)return identityVisualTransform();
 if(!Array.isArray(leaf.channels)||leaf.channels.length!==10)throw Error('Native visual transform channels are unavailable');
 const bytes=new Uint8Array(640),v=new DataView(bytes.buffer);
 for(const[c,index]of leaf.channels.map((value,index)=>[value,index])){
  const base=index*64;
  for(const[offset,value]of [[0,c.type??0],[12,c.duration??0],[24,c.field18??0],[28,c.field1c??0]])v.setInt32(base+offset,value,true);
  for(const[offset,value]of [[4,c.value],[8,c.target??c.value],[16,c.parameter??0],[20,c.progress??0]]){
   if(!Number.isFinite(value))throw Error('Native visual transform contains a non-finite channel');v.setFloat32(base+offset,value,true);
  }
  //973450 constructs/refreshed the temporary curve, then972c70 copies it
  //and refreshes again. Gob095890 does the final model-owned copy/refresh.
  const curve=bytes.subarray(base,base+64);restartVisualCurveSync(curve,p);restartVisualCurveSync(curve,p);
 }
 return bytes;
}

// CNWCAnimBase+a8 ->968190: scopes target model Gobs, with root0 and
// model lookup BYTE255 potentially aliasing. Reset removed scopes AFTER the
// assignments, preserving that alias/reset behavior from the original.
export function assignModelVisualTransforms(input,previous,{root,lookup,assign}){
 const entries=new Map(input?.legacy?[[0,input.legacy]]:(input?.entries??[]).map(e=>[e.key|0,e.value]));
 assign(root,entries.get(0)??{identity:true});const current=[0];
 for(const[key,value]of [...entries].sort((a,b)=>a[0]-b[0]))if(key!==0&&key<256){const model=lookup(key&255);if(model){assign(model,value);current.push(key);}}
 for(const key of previous)if(!current.includes(key)){const model=lookup(key&255);if(model)assign(model,{identity:true});}
 return current;
}

// Rendering-only model state. Canonical object positions, collision and IDs
// are untouched. Each model instance owns its curve clocks and reset history.
export class ModelVisualTransforms{
 constructor({root,lookup,providers}){Object.assign(this,{root,lookup,providers});this.scopes=[];this.units=new Set();this.input=null;this.assigned=false;}
 unit(group,animators=[]){
  const unit={group,bytes:identityVisualTransform(),curves:[],scale:1};unit.curves=Array.from({length:10},(_,i)=>unit.bytes.subarray(i*64,i*64+64));this.units.add(unit);
  unit.owner=this;
  for(const animator of animators)if(animator){const play=animator.play,provider=animator.nativeVisualSpeedProvider;
   animator.nativeVisualSpeedProvider=()=>sampleVisualCurveSync(unit.curves[9],unit.owner.providers);
   animator.play=function(...args){const result=play.apply(this,args);if(result){this.nativeVisualSpeed=this.nativeVisualSpeedProvider();if(this.nativeVisualSpeed<0&&this.clip){this.time=this.clip.length;this.apply?.(this.clip,this.time);}}return result;};
   (unit.animators??=[]).push({animator,play,provider});
  }
  return unit;
 }
 sync(input){
  if(this.assigned&&input===this.input)return;this.input=input;this.assigned=true;
  this.scopes=assignModelVisualTransforms(input,this.scopes,{root:this.root,lookup:this.lookup,assign:(unit,leaf)=>{
   const bytes=networkVisualTransformBytes(leaf,this.providers);unit.bytes.set(bytes);
   for(const curve of unit.curves)restartVisualCurveSync(curve,this.providers);
  }});this.update();
 }
 update(){for(const unit of this.units){
  const sample=i=>sampleVisualCurveSync(unit.curves[i],this.providers),z=sample(8),y=sample(7),x=sample(6),rz=sample(5),ry=sample(4),rx=sample(3),scale=sample(0),q=nativeVisualQuaternion([rx,ry,rz]);
  unit.group.position.set(x,z,-y);unit.group.quaternion.set(q[1],q[3],-q[2],q[0]);unit.group.scale.setScalar(scale);unit.scale=scale;
 }}
 dispose(){for(const unit of this.units)for(const{animator,play,provider}of unit.animators??[]){animator.play=play;if(provider)animator.nativeVisualSpeedProvider=provider;else delete animator.nativeVisualSpeedProvider;delete animator.nativeVisualSpeed;}this.units.clear();}
}
