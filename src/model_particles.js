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
import {observeRendererHierarchy} from './renderer_hierarchy.js';
import {fountainParticleProviders} from './fountain_particle_providers.js';
import {buildParticleVertices,particleDrawCount} from './particle_vertices.js';
import {sampleParticleVertices} from './particle_vertex_batch.js';
import {ParticleVertexPreparation} from './particle_vertex_preparation.js';
import {createPointWindList,addPointWind,advancePointWinds} from './point_wind.js';
import {isCachedRootMatrix} from './cached_root_matrix.js';
import {isObservedRendererCompose} from './renderer_matrix_subtree.js';
const f=Math.fround,BASIS=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2),INVERSE=BASIS.clone().invert();
const renderModes={Normal:0,Billboard_to_Local_Z:1,Billboard_to_World_Z:2,Linked:3,Aligned_to_World_Z:4,Aligned_to_Particle_Dir:5,Motion_Blur:6};
const updates={Fountain:updateFountainEmitter,Explosion:updateExplosionEmitter,Single:updateSingleEmitter,Lightning:updateLightningEmitter};
const fields={birthrate:'birthRate',lifeexp:'lifeExp',particlerot:'particleRot',blurlength:'blurLength',velocity:'velocity',randvel:'randomVelocity',framestart:'frameStart',frameend:'frameEnd',xsize:'xSize',ysize:'ySize',spread:'spread',mass:'mass',bounce_co:'bounceCoefficient',sizestart:'sizeStart',sizeend:'sizeEnd',sizestart_y:'sizeStartY',sizeend_y:'sizeEndY',alphastart:'alphaStart',alphaend:'alphaEnd',fps:'fps',deadspace:'deadspace',blastradius:'blastRadius',blastlength:'blastLength',lightningdelay:'lightningDelay',lightningradius:'lightningRadius',lightningscale:'lightningScale'};
const flag=value=>value===true||value==='true'||Number(value)!==0&&Number.isFinite(Number(value));
const fieldEntries=Object.entries(fields);
function properties(e,p,reuseFrameState=false){
  for(const [name,key]of reuseFrameState?fieldEntries:Object.entries(fields))e[key]=f(p[name]??(name==='blurlength'?1:0));
  e.colorStart=(p.colorstart??[0,0,0]).map(f);e.colorEnd=(p.colorend??[0,0,0]).map(f);
}
const clonePose=sample=>({value:{position:sample.value.position.slice(),quaternion:sample.value.quaternion.slice()},scale:sample.scale,cameraQuaternion:sample.cameraQuaternion.slice()});
function samplePose(object,worldReady=false){
  if(!worldReady)object.updateWorldMatrix(true,false);
  const position=new THREE.Vector3(),worldQuaternion=new THREE.Quaternion(),scale=new THREE.Vector3();object.matrixWorld.decompose(position,worldQuaternion,scale);
  // Camera local axes already mean right/up/back, unlike converted MDL axes:
  // use the left basis conversion for billboards, conjugation for model poses.
  const cameraRotation=INVERSE.clone().multiply(worldQuaternion),rotation=cameraRotation.clone().multiply(BASIS);
  return{value:{position:[position.x,-position.z,position.y].map(f),quaternion:[rotation.w,rotation.x,rotation.y,rotation.z].map(f)},scale:f(scale.x),cameraQuaternion:[cameraRotation.w,cameraRotation.x,cameraRotation.y,cameraRotation.z].map(f)};
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
  `,transparent:true,depthWrite:false,toneMapped:false,side:flag(p.twosidedtex)?THREE.DoubleSide:THREE.FrontSide}));
  mesh.name=`${node.name} particles`;mesh.frustumCulled=false;mesh.visible=false;mesh.raycast=()=>{};
  mesh.userData.mdlEmitter={model:modelName,node:node.name,properties:structuredClone(p)};
  return mesh;
}

// Scene adapter around the independently checked native CPU owners. Three's
// world matrices, shader color pipeline and missing higher-quality particle
// depth/fog passes are deliberately reported as remaining parity work.
export class ModelParticlePresentation{
  constructor({camera,report,seed=1,vertexPool=()=>null,minWorkerParticles=512,reuseFrameState=false,reusePoseSamples=false,reusePoseAncestors=false,referenceScene=modelReferenceSceneForRoot,lightColor=null}){this.lightColor=lightColor;this.referenceScene=referenceScene;this.camera=camera;this.report=report;this.vertexPool=vertexPool;this.minWorkerParticles=minWorkerParticles;this.reuseFrameState=reuseFrameState;this.reusePoseSamples=reusePoseSamples;this.reusePoseAncestors=reusePoseAncestors;this.poseAncestors=new WeakSet();this.poseAncestorStats={updated:0,reused:0,fallback:false};this.poseSamples=new WeakMap();this.poseSampleStats={computed:0,reused:0};this.random=new NativeRandom(seed);this.entries=new Map();this.reported=new Set();this.poseCache=new WeakMap();this.pointWinds=createPointWindList();this.sceneRoot=null;this.hierarchy=null;this.emitterRevision=-1;this.emitters=[];}
  // Particle providers read object poses during this synchronous update; they
  // write particle state, geometry and visibility, not source object transforms.
  // Resolve shared ancestry once in that scope. Unknown matrix/decomposition
  // methods end reuse immediately, retaining their original invocation order.
  preparePoseWorld(object){
   if(!this.reusePoseAncestors)return false;
   const visit=node=>{if(this.poseAncestorStats.fallback){node.updateWorldMatrix(true,false);return;}
    if(this.poseAncestors.has(node)){this.poseAncestorStats.reused++;return;}
    if(node.updateWorldMatrix!==THREE.Object3D.prototype.updateWorldMatrix&&node.updateWorldMatrix!==THREE.Camera.prototype.updateWorldMatrix||node.matrixAutoUpdate&&node.updateMatrix!==THREE.Object3D.prototype.updateMatrix&&!isCachedRootMatrix(node)&&!isObservedRendererCompose(node)){this.poseAncestorStats.fallback=true;node.updateWorldMatrix(true,false);return;}
    if(node.parent)visit(node.parent);node.updateWorldMatrix(false,false);this.poseAncestorStats.updated++;if(!this.poseAncestorStats.fallback)this.poseAncestors.add(node);
   };visit(object);if(object.matrixWorld.decompose!==THREE.Matrix4.prototype.decompose)this.poseAncestorStats.fallback=true;return true;
  }
  worldPose(object){let sample=this.poseCache.get(object);if(!sample){
   const ready=this.preparePoseWorld(object);
   if(!this.reusePoseSamples){sample=samplePose(object,ready);this.poseSampleStats.computed++;}
   else {if(!ready)object.updateWorldMatrix(true,false);const world=object.matrixWorld,previous=this.poseSamples.get(object),known=world.decompose===THREE.Matrix4.prototype.decompose&&world.elements.length===16&&world.elements.every(Number.isFinite);
    if(known&&previous&&previous.matrix.every((v,i)=>Object.is(v,world.elements[i]))){sample=clonePose(previous.sample);this.poseSampleStats.reused++;}
    else {sample=samplePose(object,true);this.poseSampleStats.computed++;if(known)this.poseSamples.set(object,{matrix:world.elements.slice(),sample:clonePose(sample)});else this.poseSamples.delete(object);}
   }this.poseCache.set(object,sample);
  }return sample;}
  poseSnapshot(){return{enabled:this.reusePoseSamples,...this.poseSampleStats,ancestors:{enabled:this.reusePoseAncestors,...this.poseAncestorStats}};}
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
    const initial=this.worldPose(mesh.parent).value,e={...initial,position1e0:initial.position,quaternion1d0:initial.quaternion,previous19c:initial.position.slice(),previousQuaternion178:initial.quaternion.slice(),reference10c:[0,0,0],referenceQuaternion118:[1,0,0,0],basis140:particleQuaternionBasis(initial.quaternion),active188:{records:[],capacity:0},free130:{records:[],capacity:0},initialized208:0,source50:{...this.worldPose(root).value,adjustedScale:1,opacity108:1},instance100:null,flags,chunkName:p.chunkname??'',renderMode1a8:renderModes[p.render],blendMode68:p.blend==='Normal'?0:2,spawnType:Number(p.spawntype??0)|0,loop:Number(p.loop??0)|0,xGrid:Number(p.xgrid??0)|0,yGrid:Number(p.ygrid??0)|0,ageMode1cc:1,accumulator198:0,remaining164:[0,0,0],detonate108:0,blastLatch1c8:0,elevationThreshold:5,hit1f0:{normal:[0,0,0]},twoSided:flag(p.twosidedtex)};
    properties(e,p);
    const services={random:()=>this.random.next(),cameraPosition:()=>this.worldPose(this.camera).value.position,globalTransform:()=>this.worldPose(mesh.parent).value,targetPosition:model=>this.worldPose(model.root).value.position,updateEmitter:(emitter,delta)=>updates[p.update](emitter,delta,providers),clearHit:()=>{},destroyParticle:()=>{}};
    if(typeof this.lightColor==='function')services.lightColor=position=>this.lightColor(mesh,position);
    services.collide=(from,to,out,hit)=>{
      if(!this.collisionQuery)throw new Error('Particle static-scene collision query is unavailable');
      // Only collision consumers need the whole static scene refreshed. Many
      // areas have hundreds of idle emitters but no bouncing particles.
      if(this.collisionQueryDirty){this.collisionQuery.update();this.collisionQueryDirty=false;}
      const result=this.collisionQuery.nearestHit(from,to);if(!result)return 0;
      out.splice(0,3,...result.position);hit.normal=result.normal;return 1;
    };
    if(flags&16)this.once('particle.scene-collision-partial','Bouncing particles use native polygon crossing against static tile faces/walkmesh; native scene BSP scheduling, dynamic-object hits and CHitInfo ownership remain incomplete');
    if(p.update==='Lightning'){
      Object.assign(e,{target1c0:null,lightningElapsed:0,lightningPreviousDirection:[0,0,0],lightningPreviousPosition:[0,0,0],partScale:f(mesh.parent.scale.x)});
      const referenceOwner=this.referenceScene(root),part=referenceOwner?.partForGroup(mesh.parent);
      if(!part&&mesh.parent.children.some(o=>o.userData.nativeModelPart?.type==='reference'))throw new Error('Lightning physical reference owner is unavailable');
      initializeLightningEmitter(e,{baseInitialize:()=>{},listen:()=>({active:true})});
      setEmitterTarget(e,{children:()=>part?.children38??[],referenceView:part=>part.node.type==='reference'?part:null,globalPosition:()=>this.worldPose(mesh.parent).value.position,targetPosition:services.targetPosition,lightningView:()=>e,removeListener:(_source,listener)=>{listener.active=false;}});
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
    const view=new DataView(out.buffer),bytes=new Uint8Array(out.buffer),position=mesh.geometry.getAttribute('position'),uv=mesh.geometry.getAttribute('uv'),color=mesh.geometry.getAttribute('particleColor'),positions=position.array,uvs=uv.array,colors=color.array;
    for(let i=0;i<out.count;i++){
      const off=i*24,p=i*3,u=i*2,c=i*4;positions[p]=view.getFloat32(off+4,true);positions[p+1]=view.getFloat32(off+12,true);positions[p+2]=-view.getFloat32(off+8,true);uvs[u]=view.getFloat32(off+16,true);uvs[u+1]=view.getFloat32(off+20,true);colors[c]=bytes[off];colors[c+1]=bytes[off+1];colors[c+2]=bytes[off+2];colors[c+3]=bytes[off+3];
    }
    for(const attribute of [position,uv,color]){attribute.clearUpdateRanges();attribute.addUpdateRange(0,out.count*attribute.itemSize);attribute.needsUpdate=true;}
    mesh.geometry.setDrawRange(0,out.count);mesh.visible=true;entry.drawCount=out.count;
  }
  update(root,delta){
    this.poseAncestors=new WeakSet();this.poseAncestorStats={updated:0,reused:0,fallback:false};
    this.poseSampleStats={computed:0,reused:0};
    this.poseCache=new WeakMap();
    if(root!==this.sceneRoot){this.vertexPreparation?.close();this.vertexPreparation=null;this.hierarchy?.release();this.hierarchy=root?observeRendererHierarchy(root):null;this.emitterRevision=-1;this.emitters=[];this.sceneRoot=root;this.pointWinds=createPointWindList();this.collisionQuery=root?cameraSceneQuery(root,root.userData.particleCollisionTriangles??[]):null;}
    const membershipChanged=Boolean(this.hierarchy&&this.emitterRevision!==this.hierarchy.revision);
    if(membershipChanged){this.emitters=this.hierarchy.nodes.filter(mesh=>mesh.userData.mdlEmitter);this.emitterRevision=this.hierarchy.revision;}
    this.collisionQueryDirty=true;
    advancePointWinds(this.pointWinds,delta);
    const pool=this.vertexPool();if(this.vertexPreparation&&this.vertexPreparation.pool!==pool){this.vertexPreparation.close();this.vertexPreparation=null;}
    if(pool&&!pool.closed&&!this.vertexPreparation)this.vertexPreparation=new ParticleVertexPreparation({pool,current:()=>this.sceneRoot===root&&this.vertexPool()===pool&&!pool.closed,valid:entry=>this.entries.get(entry.mesh)===entry&&!entry.failed&&Boolean(particleDrawCount(entry.e)),upload:(entry,out)=>this.upload(entry,out),error:(entry,error)=>{entry.failed=true;entry.mesh.visible=false;this.once('particle.runtime-unavailable',error.message,{...entry.mesh.userData.mdlEmitter,properties:undefined});},report:(...args)=>this.report(...args)});
    let activeParticles=0;if(pool&&!pool.closed){if(this.reuseFrameState){for(const entry of this.entries.values())activeParticles+=entry.e?.active188.records.length??0;}else activeParticles=[...this.entries.values()].reduce((n,entry)=>n+(entry.e?.active188.records.length??0),0);}
    const dense=pool&&!pool.closed&&activeParticles>=this.minWorkerParticles,workerFrame=dense?this.vertexPreparation?.frame():null;
    if(!workerFrame?.enabled&&this.vertexPreparation?.pending&&!this.vertexPreparation.invalidated)this.vertexPreparation.invalidate();
    const vertexItems=[];
    // Experimental storage reuse only: simulation, RNG/provider calls and vertex
    // production retain their original order. Membership retirement is needed
    // only when the observed add/remove/reorder revision changes.
    const retained=this.reuseFrameState?(membershipChanged?new Set(this.emitters):null):new Set();
    this.emitters.forEach(mesh=>{
      if(!this.reuseFrameState)retained.add(mesh);
      let entry=this.entries.get(mesh);if(entry?.failed)return;
      try{
        const created=!entry;entry??=this.create(mesh);const {e,providers}=entry,p=mesh.parent.userData.mdlEmitterProperties??mesh.userData.mdlEmitter.properties;properties(e,p,this.reuseFrameState);if(created&&mesh.userData.mdlEmitter.properties.update==='Lightning')e.lifeExp=1;e.partScale=f(mesh.parent.scale.x);
        const sourcePose=this.worldPose(entry.root);Object.assign(e.source50,sourcePose.value);e.source50.adjustedScale=sourcePose.scale;
        // The BYTE command is consumed by Explosion; numeric/event detonate
        // channels are not treated as a permanently asserted birth property.
        if(p.detonate)throw new Error('Emitter detonate controller delivery is not implemented');
        if(mesh.userData.mdlPendingDetonate){e.detonate108=1;delete mesh.userData.mdlPendingDetonate;}
        animateEmitterParticles(e,delta,providers);
        const drawProviders=this.reuseFrameState?(entry.drawProviders??={...providers,cameraQuaternion:()=>this.worldPose(this.camera).cameraQuaternion}):{...providers,cameraQuaternion:()=>this.worldPose(this.camera).cameraQuaternion};
        if(workerFrame?.enabled&&!providers.sineFloat&&!providers.cosineFloat){const input=sampleParticleVertices(e,drawProviders,{capture:workerFrame.collect});if(!input)this.upload(entry,null);else if(workerFrame.collect)vertexItems.push({entry,input});}
        else this.upload(entry,buildParticleVertices(e,drawProviders));entry.frames++;
      }catch(error){
        mesh.visible=false;if(entry)entry.failed=true;else{entry={mesh,failed:true};this.entries.set(mesh,entry);}
        this.once('particle.runtime-unavailable',error.message,{...mesh.userData.mdlEmitter,properties:undefined});
      }
    });
    if(retained)for(const [mesh,entry]of this.entries)if(!retained.has(mesh)){if(entry.e){mesh.geometry.dispose();mesh.material.dispose();}this.entries.delete(mesh);}
    if(workerFrame?.collect)this.vertexPreparation.submit(vertexItems);
  }
  vertexSnapshot(){return this.vertexPreparation?.snapshot()??null;}
  snapshot(){return[...this.entries.values()].map(entry=>({model:entry.mesh.userData.mdlEmitter.model,node:entry.mesh.userData.mdlEmitter.node,failed:entry.failed,active:entry.e?.active188.records.length??0,free:entry.e?.free130.records.length??0,frames:entry.frames??0,vertices:entry.drawCount??0}));}
  dispose(){this.vertexPreparation?.close();this.vertexPreparation=null;for(const [mesh,entry]of this.entries)if(entry.e){mesh.visible=false;mesh.geometry.dispose();mesh.material.dispose();}this.entries.clear();this.poseCache=new WeakMap();this.poseSamples=new WeakMap();this.pointWinds=createPointWindList();this.hierarchy?.release();this.hierarchy=null;this.emitters=[];this.emitterRevision=-1;this.sceneRoot=null;}
}
