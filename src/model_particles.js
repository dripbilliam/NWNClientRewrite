import * as THREE from 'three';
import {EMITTER_FLAGS} from './mdl_emitter.js';
import {NativeRandom} from './native_random.js';
import {particleQuaternionBasis} from './particle_math.js';
import {animateEmitterParticles} from './particle_frame.js';
import {updateFountainEmitter} from './fountain_emitter.js';
import {updateExplosionEmitter,updateSingleEmitter} from './burst_single_emitter.js';
import {updateLightningEmitter} from './lightning_emitter.js';
import {initializeLightningEmitter,setEmitterTarget} from './emitter_target.js';
import {modelReferenceSceneForRoot} from './model_reference_scene.js';
import {cameraSceneQuery} from './camera_scene_query.js';
import {fountainParticleProviders} from './fountain_particle_providers.js';
import {buildParticleVertices} from './particle_vertices.js';
import {createPointWindList,addPointWind,advancePointWinds} from './point_wind.js';
const f=Math.fround,BASIS=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2),INVERSE=BASIS.clone().invert();
const renderModes={Normal:0,Billboard_to_Local_Z:1,Billboard_to_World_Z:2,Linked:3,Aligned_to_World_Z:4,Aligned_to_Particle_Dir:5,Motion_Blur:6};
const updates={Fountain:updateFountainEmitter,Explosion:updateExplosionEmitter,Single:updateSingleEmitter,Lightning:updateLightningEmitter};
const fields={birthrate:'birthRate',lifeexp:'lifeExp',particlerot:'particleRot',blurlength:'blurLength',velocity:'velocity',randvel:'randomVelocity',framestart:'frameStart',frameend:'frameEnd',xsize:'xSize',ysize:'ySize',spread:'spread',mass:'mass',bounce_co:'bounceCoefficient',sizestart:'sizeStart',sizeend:'sizeEnd',sizestart_y:'sizeStartY',sizeend_y:'sizeEndY',alphastart:'alphaStart',alphaend:'alphaEnd',fps:'fps',deadspace:'deadspace',blastradius:'blastRadius',blastlength:'blastLength',lightningdelay:'lightningDelay',lightningradius:'lightningRadius',lightningscale:'lightningScale'};
const flag=value=>value===true||value==='true'||Number(value)!==0&&Number.isFinite(Number(value));
function properties(e,p){
  for(const [name,key]of Object.entries(fields))e[key]=f(p[name]??(name==='blurlength'?1:0));
  e.colorStart=(p.colorstart??[0,0,0]).map(f);e.colorEnd=(p.colorend??[0,0,0]).map(f);
}
function pose(object){
  object.updateWorldMatrix(true,false);
  const position=object.getWorldPosition(new THREE.Vector3()),rotation=INVERSE.clone().multiply(object.getWorldQuaternion(new THREE.Quaternion())).multiply(BASIS);
  return{position:[position.x,-position.z,position.y].map(f),quaternion:[rotation.w,rotation.x,rotation.y,rotation.z].map(f)};
}
// Camera local axes already mean right/up/back, unlike the converted MDL
// node axes. Convert its world basis on the left only; conjugating would turn
// the camera-facing particle normal into the camera's up vector.
function cameraPose(camera){
  const result=pose(camera),rotation=INVERSE.clone().multiply(camera.getWorldQuaternion(new THREE.Quaternion()));
  result.quaternion=[rotation.w,rotation.x,rotation.y,rotation.z].map(f);return result;
}
// Only serializable metadata lives in userData so ordinary model clones get
// independent runtime state. Templates contain no particles, RNG or game IDs.
export function createModelEmitter(node,textures,modelName){
  const p=node.properties??{},texture=textures.get(String(p.texture??'').toLowerCase())??null;
  const mesh=new THREE.Mesh(new THREE.BufferGeometry(),new THREE.ShaderMaterial({uniforms:{particleMap:{value:texture}},vertexShader:`
    attribute vec4 particleColor;
    varying vec4 particleTint;
    varying vec2 particleUv;
    void main(){particleTint=particleColor;particleUv=uv;gl_Position=projectionMatrix*viewMatrix*vec4(position,1.0);}
  `,fragmentShader:`
    uniform sampler2D particleMap;
    varying vec4 particleTint;
    varying vec2 particleUv;
    void main(){gl_FragColor=particleTint*texture2D(particleMap,particleUv);
      #include <colorspace_fragment>
    }
  `,transparent:true,depthWrite:false,toneMapped:false}));
  mesh.name=`${node.name} particles`;mesh.frustumCulled=false;mesh.visible=false;mesh.raycast=()=>{};
  mesh.userData.mdlEmitter={model:modelName,node:node.name,properties:structuredClone(p)};
  return mesh;
}

// Scene adapter around the independently checked native CPU owners. Three's
// world matrices, shader color pipeline and missing higher-quality particle
// depth/fog passes are deliberately reported as remaining parity work.
export class ModelParticlePresentation{
  constructor({camera,report,seed=1}){this.camera=camera;this.report=report;this.random=new NativeRandom(seed);this.entries=new Map();this.reported=new Set();this.pointWinds=createPointWindList();this.sceneRoot=null;}
  once(code,message,data={}){const key=`${code}:${JSON.stringify(data)}`;if(!this.reported.has(key)){this.reported.add(key);this.report(code,message,data);}}
  create(mesh){
    mesh.raycast=()=>{};
    const metadata=mesh.userData.mdlEmitter,p=metadata.properties;
    let root=mesh.parent;while(root&&!root.userData.mdlRoot)root=root.parent;
    if(!root)throw new Error('Emitter source model root is unavailable');
    // NULL-textured simulation helpers can have zero lifetime and never draw.
    // Still diagnose a named bitmap that actually failed to load.
    if(!mesh.material.uniforms?.particleMap?.value&&p.texture&&String(p.texture).toLowerCase()!=='null')throw new Error(`Emitter bitmap ${p.texture} is unavailable`);
    if(!updates[p.update])throw new Error(`Emitter update ${p.update??''} is not implemented`);
    if(renderModes[p.render]===undefined)throw new Error(`Emitter render mode ${p.render??''} is unavailable`);
    let flags=p.flags|0;for(const [name,bit]of Object.entries(EMITTER_FLAGS))if(Object.hasOwn(p,name)){if(flag(p[name]))flags|=bit;else flags&=~bit;}
    // Lightning never calls the base movement pointer; its own fixed chain
    // owner uses the reference target regardless of the base P2P flag.
    if(flags&1&&p.update!=='Lightning')throw new Error('Emitter point-to-point movement and target events are not implemented');
    if(p.chunkname)throw new Error('Chunk particle model ownership is not implemented');
    if(p.blend==='Punch-Through')throw new Error('Native particle punch-through alpha threshold is not implemented');
    const initial=pose(mesh.parent),e={...initial,position1e0:initial.position,quaternion1d0:initial.quaternion,previous19c:initial.position.slice(),previousQuaternion178:initial.quaternion.slice(),reference10c:[0,0,0],referenceQuaternion118:[1,0,0,0],basis140:particleQuaternionBasis(initial.quaternion),active188:{records:[],capacity:0},free130:{records:[],capacity:0},initialized208:0,source50:{...pose(root),adjustedScale:1,opacity108:1},instance100:null,flags,chunkName:p.chunkname??'',renderMode1a8:renderModes[p.render],blendMode68:p.blend==='Normal'?0:2,spawnType:Number(p.spawntype??0)|0,loop:Number(p.loop??0)|0,xGrid:Number(p.xgrid??0)|0,yGrid:Number(p.ygrid??0)|0,ageMode1cc:1,accumulator198:0,remaining164:[0,0,0],detonate108:0,blastLatch1c8:0,elevationThreshold:5,hit1f0:{normal:[0,0,0]},twoSided:flag(p.twosidedtex)};
    properties(e,p);
    const services={random:()=>this.random.next(),cameraPosition:()=>pose(this.camera).position,globalTransform:()=>pose(mesh.parent),targetPosition:model=>pose(model.root).position,updateEmitter:(emitter,delta)=>updates[p.update](emitter,delta,providers),clearHit:()=>{},destroyParticle:()=>{}};
    services.collide=(from,to,out,hit)=>{
      if(!this.collisionQuery)throw new Error('Particle static-scene collision query is unavailable');
      const result=this.collisionQuery.nearestHit(from,to);if(!result)return 0;
      out.splice(0,3,...result.position);hit.normal=result.normal;return 1;
    };
    if(flags&16)this.once('particle.scene-collision-partial','Bouncing particles use native polygon crossing against static tile faces/walkmesh; native scene BSP scheduling, dynamic-object hits and CHitInfo ownership remain incomplete');
    if(p.update==='Lightning'){
      Object.assign(e,{target1c0:null,lightningElapsed:0,lightningPreviousDirection:[0,0,0],lightningPreviousPosition:[0,0,0],partScale:f(mesh.parent.scale.x)});
      const referenceOwner=modelReferenceSceneForRoot(root),part=referenceOwner?.partForGroup(mesh.parent);
      if(!part&&mesh.parent.children.some(o=>o.userData.nativeModelPart?.type==='reference'))throw new Error('Lightning physical reference owner is unavailable');
      initializeLightningEmitter(e,{baseInitialize:()=>{},listen:()=>({active:true})});
      setEmitterTarget(e,{children:()=>part?.children38??[],referenceView:part=>part.node.type==='reference'?part:null,globalPosition:()=>pose(mesh.parent).position,targetPosition:services.targetPosition,lightningView:()=>e,removeListener:(_source,listener)=>{listener.active=false;}});
      this.once('particle.reference-target-scheduling-unverified','Native first-direct-reference endpoint binding is connected; full Gob construction, notification and cache scheduling remain unverified',{model:metadata.model,node:metadata.node});
    }
    services.addPointSourceWind=(position,radius,duration,strength)=>{
      addPointWind(this.pointWinds,position,radius,duration,strength);
      this.once('particle.wind-scene-unimplemented','Point wind bursts retain native records and lifetimes; ambient/noise sampling, scene wind-manager registration and native frame scheduling remain unimplemented');
    };
    const providers=fountainParticleProviders(e,services);
    // Clones initially share the template's empty buffers/material. A live
    // instance owns its GPU resources from this point onward.
    const texture=mesh.material.uniforms.particleMap.value;
    mesh.geometry=new THREE.BufferGeometry();mesh.material=mesh.material.clone();mesh.material.uniforms.particleMap.value=texture;mesh.material.depthWrite=e.blendMode68===1;mesh.material.side=e.twoSided?THREE.DoubleSide:THREE.FrontSide;
    mesh.material.blending=THREE.CustomBlending;mesh.material.blendSrc=THREE.SrcAlphaFactor;mesh.material.blendDst=e.blendMode68===0?THREE.OneMinusSrcAlphaFactor:THREE.OneFactor;mesh.material.blendEquation=THREE.AddEquation;
    const entry={mesh,root,e,providers,failed:false,capacity:0,frames:0,drawCount:0};this.entries.set(mesh,entry);
    this.once('particle.presentation-approximate','Particles use verified native CPU physics and vertex generation; Three world transforms, shader gamma, native soft-depth/fog, scene wind/collision/tint, model events and client RNG startup remain incomplete');
    return entry;
  }
  upload(entry,out){
    const {mesh}=entry;if(!out){mesh.visible=false;entry.drawCount=0;return;}
    if(!mesh.material.uniforms?.particleMap?.value)throw new Error(`Emitter bitmap ${mesh.userData.mdlEmitter.properties.texture??''} is unavailable for drawing`);
    if(out.count>entry.capacity){
      entry.capacity=Math.max(96,entry.capacity*2,out.count);
      mesh.geometry.setAttribute('position',new THREE.BufferAttribute(new Float32Array(entry.capacity*3),3).setUsage(THREE.DynamicDrawUsage));
      mesh.geometry.setAttribute('uv',new THREE.BufferAttribute(new Float32Array(entry.capacity*2),2).setUsage(THREE.DynamicDrawUsage));
      mesh.geometry.setAttribute('particleColor',new THREE.BufferAttribute(new Uint8Array(entry.capacity*4),4,true).setUsage(THREE.DynamicDrawUsage));
    }
    const view=new DataView(out.buffer),position=mesh.geometry.getAttribute('position'),uv=mesh.geometry.getAttribute('uv'),color=mesh.geometry.getAttribute('particleColor');
    for(let i=0;i<out.count;i++){
      const off=i*24;position.setXYZ(i,view.getFloat32(off+4,true),view.getFloat32(off+12,true),-view.getFloat32(off+8,true));uv.setXY(i,view.getFloat32(off+16,true),view.getFloat32(off+20,true));color.array.set(new Uint8Array(out.buffer,off,4),i*4);
    }
    for(const attribute of [position,uv,color])attribute.needsUpdate=true;
    mesh.geometry.setDrawRange(0,out.count);mesh.visible=true;entry.drawCount=out.count;
  }
  update(root,delta){
    if(root!==this.sceneRoot){this.sceneRoot=root;this.pointWinds=createPointWindList();this.collisionQuery=root?cameraSceneQuery(root,root.userData.particleCollisionTriangles??[]):null;}
    this.collisionQuery?.update();
    advancePointWinds(this.pointWinds,delta);
    const retained=new Set();
    root?.traverse(mesh=>{
      if(!mesh.userData.mdlEmitter)return;retained.add(mesh);
      let entry=this.entries.get(mesh);if(entry?.failed)return;
      try{
        const created=!entry;entry??=this.create(mesh);const {e,providers}=entry,p=mesh.parent.userData.mdlEmitterProperties??mesh.userData.mdlEmitter.properties;properties(e,p);if(created&&mesh.userData.mdlEmitter.properties.update==='Lightning')e.lifeExp=1;e.partScale=f(mesh.parent.scale.x);
        Object.assign(e.source50,pose(entry.root));e.source50.adjustedScale=f(entry.root.getWorldScale(new THREE.Vector3()).x);
        // The BYTE command is consumed by Explosion; numeric/event detonate
        // channels are not treated as a permanently asserted birth property.
        if(p.detonate)throw new Error('Emitter detonate controller delivery is not implemented');
        if(mesh.userData.mdlPendingDetonate){e.detonate108=1;delete mesh.userData.mdlPendingDetonate;}
        animateEmitterParticles(e,delta,providers);
        const out=buildParticleVertices(e,{...providers,cameraQuaternion:()=>cameraPose(this.camera).quaternion});
        this.upload(entry,out);entry.frames++;
      }catch(error){
        mesh.visible=false;if(entry)entry.failed=true;else{entry={mesh,failed:true};this.entries.set(mesh,entry);}
        this.once('particle.runtime-unavailable',error.message,{...mesh.userData.mdlEmitter,properties:undefined});
      }
    });
    for(const [mesh,entry]of this.entries)if(!retained.has(mesh)){if(entry.e){mesh.geometry.dispose();mesh.material.dispose();}this.entries.delete(mesh);}
  }
  snapshot(){return[...this.entries.values()].map(entry=>({model:entry.mesh.userData.mdlEmitter.model,node:entry.mesh.userData.mdlEmitter.node,failed:entry.failed,active:entry.e?.active188.records.length??0,free:entry.e?.free130.records.length??0,frames:entry.frames??0,vertices:entry.drawCount??0}));}
  dispose(){for(const [mesh,entry]of this.entries)if(entry.e){mesh.visible=false;mesh.geometry.dispose();mesh.material.dispose();}this.entries.clear();this.pointWinds=createPointWindList();this.sceneRoot=null;}
}
