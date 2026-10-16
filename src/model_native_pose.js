import * as THREE from 'three';
import {applyModelControllers} from './model_controller_apply.js';
import {animateModelHierarchy} from './model_animation_hierarchy.js';
import {EMITTER_RUNTIME_FIELDS} from './mdl_emitter.js';
import {updateModelLight} from './model_light.js';
const f=Math.fround,BASIS=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2),INVERSE=BASIS.clone().invert();
const common=new Map([[16,3],[28,4],[44,1]]),lightFields={104:['color',3],116:['radius',1],124:['shadowradius',1],128:['verticaldisplacement',1],168:['multiplier',1]};

// Renderer field views around the checked controller/hierarchy owners. This
// is not a native Part allocator, scene scheduler or culling implementation.
// Buffers retain overlapping BYTE/float writes and per-frame channel state;
// physical IDs and source node identity replace name-only binding.
export class ModelNativePose{
 constructor(model,root,report=()=>{}){
  if(!model.nativeRoot)throw new Error('Native binary model node storage is unavailable');
  this.model=model;this.root=root;this.report=report;this.failures=new Set();this.scale=1;this.motionRun=null;
  const groups=new Map();root.traverse(object=>{
   if(object.userData.mdlModel!==model.modelName||!Number.isInteger(object.userData.mdlNodeIndex))return;
   const index=object.userData.mdlNodeIndex;if(groups.has(index))throw new Error('Native physical Part binding is ambiguous');groups.set(index,object);
  });
  this.byObject=new Map();const byNode=new Map();
  this.parts=model.nodes.map((source,index)=>{
   const object=groups.get(index);if(!source.nativeNode||!object)throw new Error(`Native physical Part ${index} is unavailable`);
   const part={source,object,id30:source.nativeNode.id34,owner50:root,children38:[],childCount40:0,view:new DataView(new ArrayBuffer(0x240)),fields:new Map(common)};
   Object.defineProperty(part,'dirty60',{get:()=>object.userData.mdlControlGate60??0});
   part.view.setFloat32(28,1,true);part.view.setFloat32(44,1,true);
   if(source.type==='light'){
    for(const [offset,[,size]]of Object.entries(lightFields))part.fields.set(Number(offset),size);
    part.view.setFloat32(168,1,true);part.field8c=Number(source.properties.isdynamic)|0;
   }else if(source.type==='trimesh'){part.fields.set(168,1);part.view.setFloat32(168,1,true);}
   else if(source.type==='emitter'){
    for(const [offset,name]of Object.entries(EMITTER_RUNTIME_FIELDS))part.fields.set(Number(offset),name.startsWith('color')?3:1);
    part.view.setFloat32(0xe8,1,true);for(const offset of [0x224,0x225,0x226])part.view.setUint8(offset,255);
   }
   this.byObject.set(object,part);byNode.set(source.nativeNode,part);return part;
  });
  for(const part of this.parts){part.children38=part.source.nativeNode.children68.map(node=>byNode.get(node));part.childCount40=part.children38.length;}
  this.partRoot=byNode.get(model.nativeRoot);if(!this.partRoot)throw new Error('Native physical root Part is unavailable');
  const initialize=part=>{this.control(part.source.nativeNode,part,0,0,1);for(const child of part.children38)initialize(child);};initialize(this.partRoot);
  // Native instance control occurs before client placement. Lazy renderer
  // construction can happen after placement; restore its exact manual fields.
  for(const part of this.parts)if(part.dirty60){const o=part.object,q=INVERSE.clone().multiply(o.quaternion).multiply(BASIS);this.setManualPose(o,[o.position.x,-o.position.z,o.position.y],[q.w,q.x,q.y,q.z]);}
  this.flush();
 }
 diagnostic(code,message,part){const key=code+(part?':'+part.id30:'');if(this.failures.has(key))return;this.failures.add(key);this.report(code,message,{model:this.model.modelName,partId:part?.id30});}
 read(part,offset,count){if(part.fields.get(offset)!==count)throw new Error(`Native ${part.source.type} controller field ${offset}/${count} is unavailable`);return Array.from({length:count},(_,i)=>part.view.getFloat32(offset+i*4,true));}
 write(part,offset,values){if(part.fields.get(offset)!==values.length)throw new Error(`Native ${part.source.type} controller field ${offset}/${values.length} is unavailable`);values.forEach((v,i)=>part.view.setFloat32(offset+i*4,v,true));}
 control(node,part,previous,time,weight){
  const flags=node.flags98;
  if(flags&0x90)throw new Error('Native reference/animated-vertex node control is unavailable');
  const emitter=(flags&5)===5,light=(flags&3)===3,mesh=(flags&33)===33;
  if(emitter&&part.source.type!=='emitter'||!emitter&&light&&part.source.type!=='light'||!emitter&&!light&&mesh&&part.source.type!=='trimesh')throw new Error('Native model node control subtype does not match its physical Part');
  applyModelControllers(node,part,previous,time,weight,{read:(...args)=>this.read(...args),write:(...args)=>this.write(...args),positionScale:()=>this.scale,
   math:{acos:value=>{this.diagnostic('animation.math-library-parity-unverified','Platform quaternion trigonometry matches recorded finite cases; arbitrary native CRT parity remains unverified');return Math.acos(value);},sin:Math.sin},
   activeMotionRun:()=>this.motionRun,motion:()=>{throw new Error('Native model motion-controller delivery is unavailable');}});
  if(emitter)this.diagnostic('animation.emitter-bounds-unimplemented','Native emitter control bounding-radius finalization is not implemented',part);
  if(flags&256)this.diagnostic('animation.dangly-solver-unimplemented','Native dangly mesh simulation is not implemented',part);
 }
 setManualPose(object,position,quaternion){const part=this.byObject.get(object);if(!part)return;this.write(part,16,position.map(f));this.write(part,28,quaternion.map(f));object.userData.mdlControlGate60=1;}
 apply(node,previous,time,weight,scale,motionRun){
  if(!node)throw new Error('Native animation node hierarchy is unavailable');this.scale=f(scale);this.motionRun=motionRun;
  animateModelHierarchy(this.partRoot,node,previous,time,weight,{depth:0},{control:(...args)=>this.control(...args),light:part=>part.source.type==='light'?part:null,
   animateStaticLight:()=>this.diagnostic('animation.static-light-event-unimplemented','Native AnimateStaticLight event and scene invalidation are not implemented')});
  this.flush();
 }
 flush(){
  for(const part of this.parts){
   const object=part.object,position=this.read(part,16,3),[w,x,y,z]=this.read(part,28,4),scale=this.read(part,44,1)[0];
   if(![...position,w,x,y,z,scale].every(Number.isFinite))throw new Error('Native controller produced a non-finite scene pose');
   object.position.set(position[0],position[2],-position[1]);object.quaternion.copy(BASIS).multiply(new THREE.Quaternion(x,y,z,w)).multiply(INVERSE);object.scale.setScalar(scale);
   if(part.source.type==='emitter'){
    const properties=object.userData.mdlEmitterProperties??=structuredClone(part.source.properties??{});
    for(const [offset,name]of Object.entries(EMITTER_RUNTIME_FIELDS)){
     const at=Number(offset);properties[name]=name.startsWith('percent')||name==='detonate'?part.view.getUint8(at):name.startsWith('color')?this.read(part,at,3):this.read(part,at,1)[0];
    }
   }else if(part.source.type==='light')for(const light of object.children.filter(child=>child.isLight&&child.userData.mdlLight)){
    for(const [offset,[name,count]]of Object.entries(lightFields)){const value=this.read(part,Number(offset),count);light.userData.mdlLight[name]=count===1?value[0]:value;}updateModelLight(light);
   }else if(part.source.type==='trimesh'){
    const opacity=Math.max(0,Math.min(1,this.read(part,168,1)[0]));
    for(const mesh of object.children.filter(child=>child.isMesh))for(const material of Array.isArray(mesh.material)?mesh.material:[mesh.material]){
     material.opacity=opacity;if(material.userData.mdlOpacityDriven)material.visible=opacity>0;
     const authored=material.userData.mdlTransparencyHint??Boolean(part.source.transparencyHint);material.transparent=authored||opacity<1;material.depthWrite=!authored&&opacity>=1;
     if(material.userData.animationTransparent!==material.transparent){material.needsUpdate=true;material.userData.animationTransparent=material.transparent;}
    }
   }
  }
  this.root.updateWorldMatrix(true,true);
 }
}
