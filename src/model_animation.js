import * as THREE from 'three';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import { applyModelLightChannel, updateModelLight } from './model_light.js';
import {animateModelEvents,ModelEventDispatcher} from './model_events.js';
import {playModelAnimation} from './model_playback.js';
import {advanceModelRuns} from './model_run_clock.js';
import {ModelNativePose} from './model_native_pose.js';

const BASIS = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1, 0, 0), -Math.PI / 2);
const INVERSE_BASIS = BASIS.clone().invert();

export function sampleTrack(track, time) {
  const frames = track.frames;
  if (!frames.length) return null;
  if (time <= frames[0].time) return [...frames[0].value];
  if (time >= frames.at(-1).time) return [...frames.at(-1).value];
  let index = 1;
  while (frames[index].time < time) index += 1;
  const from = frames[index - 1], to = frames[index];
  const t = (time - from.time) / (to.time - from.time);
  if (track.interpolation === 'slerp') {
    return new THREE.Quaternion(...from.value).slerp(new THREE.Quaternion(...to.value), t).normalize().toArray();
  }
  return from.value.map((value, component) => {
    if (track.interpolation !== 'bezier') return value + (to.value[component] - value) * t;
    const a = value + from.out[component], b = to.value[component] + to.in[component];
    return (1 - t) ** 3 * value + 3 * (1 - t) ** 2 * t * a + 3 * (1 - t) * t * t * b + t ** 3 * to.value[component];
  });
}

export class ModelAnimator {
  constructor(model, root, updateSkin = null) {
    this.model = model;
    this.root = root;
    this.eventDispatcher=new ModelEventDispatcher(root);
    // MdlNodeEmitter::InternalCreateInstance1400621f0 registers this handler
    // on its source model only for Explosion emitters, before initialization.
    root.traverse(mesh=>{const emitter=mesh.userData.mdlEmitter;if(emitter?.model.toLowerCase()===model.modelName.toLowerCase()&&emitter.properties.update==='Explosion')this.eventDispatcher.add('Detonate',(_owner,_name,target)=>{target.userData.mdlPendingDetonate=1;},mesh);});
    this.updateSkin = updateSkin;
    this.bindings = new Map();
    const nodeNameCounts=new Map();for(const node of model.nodes)nodeNameCounts.set(node.name,(nodeNameCounts.get(node.name)??0)+1);
    const ambiguous=new Set((model.animations??[]).flatMap(clip=>clip.tracks??[]).filter(track=>(nodeNameCounts.get(track.node)??0)>1).map(track=>track.node));
    if(ambiguous.size)runtimeDiagnostics.record('animation.duplicate-node-binding-unimplemented','Native animation track resolution for duplicate node names is not implemented; the physical model hierarchy is preserved',{model:model.modelName,nodes:[...ambiguous]});
    this.clip = null;
    this.time = 0;
    this.playing = false;
    this.loop = true;
    this.onComplete = null;
    const names = new Set(model.nodes.map(node => node.name.toLowerCase()));
    root.traverse(object => {
      const name = object.userData.mdlNode?.toLowerCase();
      if (!name || object.userData.mdlModel?.toLowerCase() !== model.modelName.toLowerCase() || !names.has(name) || this.bindings.has(name)) return;
      const materials = object.children.filter(child => child.isMesh).flatMap(mesh => {
        // Opacity tracks must not modify another instance's shared materials.
        const hasAlpha = model.animations.some(animation => animation.tracks.some(track => track.node.toLowerCase() === name && track.property === 'alpha'));
        if (hasAlpha) mesh.material = Array.isArray(mesh.material) ? mesh.material.map(material => material.clone()) : mesh.material.clone();
        return (Array.isArray(mesh.material) ? mesh.material : [mesh.material]).map(material => ({ material, opacity: material.opacity, visible:material.visible, transparent: material.transparent, depthWrite: material.depthWrite }));
      });
      const lights = object.children.filter(child => child.isLight && child.userData.mdlLight).map(light => ({ light, properties: structuredClone(light.userData.mdlLight) }));
      const source=model.nodes[object.userData.mdlNodeIndex]??model.nodes.find(node=>node.name.toLowerCase()===name);
      const emitterDefaults=source?.type==='emitter'?structuredClone(source.properties??{}):null;
      if(emitterDefaults)object.userData.mdlEmitterProperties=structuredClone(emitterDefaults);
      this.bindings.set(name, { object, position: object.position.clone(), quaternion: object.quaternion.clone(), scale: object.scale.clone(), materials, lights, emitterDefaults });
    });
    this.missingNodes = [];
    this.reportedMissing = new Set();
  }

  reset() {
    for (const binding of this.bindings.values()) {
      binding.object.position.copy(binding.position);
      binding.object.quaternion.copy(binding.quaternion);
      binding.object.scale.copy(binding.scale);
      if(binding.emitterDefaults)binding.object.userData.mdlEmitterProperties=structuredClone(binding.emitterDefaults);
      for (const saved of binding.lights) { saved.light.userData.mdlLight = structuredClone(saved.properties); updateModelLight(saved.light); }
      for (const saved of binding.materials) {
        saved.material.opacity = saved.opacity;
        saved.material.visible = saved.visible;
        saved.material.transparent = saved.transparent;
        saved.material.depthWrite = saved.depthWrite;
      }
    }
  }

  apply(clip, time) {
    this.reset();
    const missing = new Set();
    for (const track of clip?.tracks ?? []) {
      const binding = this.bindings.get(track.node.toLowerCase());
      if (!binding) { missing.add(track.node); continue; }
      const value = sampleTrack(track, time);
      if (!value) continue;
      if (track.property === 'position') binding.object.position.set(value[0], value[2], -value[1]);
      else if (track.property === 'orientation') binding.object.quaternion.copy(BASIS).multiply(new THREE.Quaternion(...value)).multiply(INVERSE_BASIS);
      else if (track.property === 'scale') binding.object.scale.setScalar(value[0]);
      else if(track.property.startsWith('emitter.')) {
        if(binding.emitterDefaults)binding.object.userData.mdlEmitterProperties[track.property.slice(8)]=value.length===1?value[0]:[...value];
        else {
          const key=`${clip.name}:${track.node}:${track.property}`;
          if(!this.reportedMissing.has(key)){this.reportedMissing.add(key);runtimeDiagnostics.record('animation.controller-binding-unavailable','Emitter animation has no matching emitter node',{model:this.model.modelName,clip:clip.name,node:track.node,property:track.property});}
        }
      }
      else if (track.property.startsWith('light')) for (const { light } of binding.lights) applyModelLightChannel(light, track.property, value);
      else if (track.property === 'alpha') for (const { material, transparent, depthWrite } of binding.materials) {
        material.opacity = Math.max(0, Math.min(1, value[0]));
        if (material.userData.mdlOpacityDriven) material.visible = material.opacity > 0;
        const authoredHint = material.userData.mdlTransparencyHint;
        material.transparent = (authoredHint ?? transparent) || material.opacity < 1;
        material.depthWrite = (authoredHint === undefined ? depthWrite : !authoredHint) && material.opacity >= 1;
        if (material.userData.animationTransparent !== material.transparent) {
          material.needsUpdate = true;
          material.userData.animationTransparent = material.transparent;
        }
      }
    }
    this.missingNodes = [...missing];
    for (const binding of this.bindings.values()) for (const { light } of binding.lights) updateModelLight(light);
    for (const node of missing) {
      const key = `${clip.name}:${node}`;
      if (!this.reportedMissing.has(key)) { this.reportedMissing.add(key); runtimeDiagnostics.record('animation.node-unavailable', `Animation ${clip.name} has no binding for ${node}`, { model: this.model.modelName, instance: this.root.name, clip: clip.name, node }); }
    }
    // Refresh blend programs when switching back to a clip without alpha tracks.
    for (const binding of this.bindings.values()) for (const { material } of binding.materials) {
      if (material.userData.animationTransparent !== undefined && material.userData.animationTransparent !== material.transparent) {
        material.needsUpdate = true;
        material.userData.animationTransparent = material.transparent;
      }
    }
    this.root.updateWorldMatrix(true, true);
    this.updateSkin?.();
    this.root.userData.animationClip = clip?.name ?? '';
    this.root.userData.animationTime = time;
  }

  play(name, { loop = true, onComplete = null } = {}) {
    this.nativePlayback=null;this.nativePose=null;
    const clip = this.model.animations.find(animation => animation.name === String(name).toLowerCase());
    if (!clip) { runtimeDiagnostics.record('animation.clip-unavailable', `Animation ${name} is unavailable`, { model: this.model.modelName, instance: this.root.name, clip: name }); return false; }
    const missingEvents=clip.events?.filter(event=>!this.eventDispatcher.accepts(event.name))??[];
    if(missingEvents.length){const key=`events:${clip.name}`;if(!this.reportedMissing.has(key)){this.reportedMissing.add(key);runtimeDiagnostics.record('animation.event-handler-unavailable','Authored model events have no implemented engine handler',{model:this.model.modelName,instance:this.root.name,clip:clip.name,events:missingEvents});}}
    this.clip = clip;
    this.time = 0;
    this.loop = loop;
    this.onComplete = onComplete;
    this.playing = clip.length > 0;
    this.apply(clip, 0);
    return true;
  }

  // Binary own clips use the checked runtime hierarchy/controller field views.
  // Legacy decoded-only models still admit only the prior unblended profile.
  playNative(name,{speed=1,flags=3,time=0,onComplete=null}={}){
    if(!Number.isFinite(speed)||!Number.isFinite(time))throw new Error('Native model playback parameters are unavailable');
    const clip=this.model.animations.find(animation=>animation.name===String(name).toLowerCase());
    const value=String(name).split('\0')[0].toLowerCase(),clearing=name===null||name===undefined||value===''||value==='null';
    const nativePose=Boolean(this.model.nativeRoot&&(!clip||clip.nativeRoot));
    if(flags!==3&&!nativePose&&!clearing)throw new Error('Native stacked/blended model pose presentation is unavailable');
    if(!clearing&&(flags&256))throw new Error('Native model motion-controller delivery is unavailable');
    if(clip?.inheritedFrom)throw new Error('Native inherited-animation scale presentation is unavailable');
    if(clip?.nativeRoot&&nativePose)this.nativePose??=new ModelNativePose(this.model,this.root,(...args)=>runtimeDiagnostics.record(...args));
    else if(clip){this.nativePose=null;if(!this.nativeStorageLimitationsReported){this.nativeStorageLimitationsReported=true;runtimeDiagnostics.record('animation.native-node-storage-unimplemented','Decoded-only model pose presentation lacks native node/controller storage',{model:this.model.modelName,instance:this.root.name});}}
    if(!this.nativeLimitationsReported){this.nativeLimitationsReported=true;runtimeDiagnostics.record('animation.native-scene-adapter-incomplete','Native run/controller owners are active; outer scene/visibility/attachment gates, periodic scene work and specialized renderer services remain incomplete',{model:this.model.modelName,instance:this.root.name});}
    this.nativeClips??=new Map();
    const descriptor=animation=>{
      if(!animation)return null;
      if(!this.nativeClips.has(animation))this.nativeClips.set(animation,{name:animation.name,length90:animation.length,transition94:animation.transition??0,events:animation.events??[],source:animation});
      return this.nativeClips.get(animation);
    };
    const gob=this.nativePlayback??={model68:this.model,model80:null,runsE0:[],root90:this.root,period188:0};
    const p={findAnimation:(_model,value)=>descriptor(this.model.animations.find(animation=>animation.name===value.toLowerCase())),createRun:()=>({}),destroyRun:()=>{},animationScale:()=>1,playbackScale:()=>1,event:(event,data)=>this.eventDispatcher.dispatch(event,data)};
    const result=playModelAnimation(gob,name,speed,flags,time,p);
    if(!result){runtimeDiagnostics.record('animation.clip-unavailable',`Animation ${name} is unavailable`,{model:this.model.modelName,instance:this.root.name,clip:name});return false;}
    const missingEvents=clip?.events?.filter(event=>!this.eventDispatcher.accepts(event.name))??[];
    if(missingEvents.length){const key=`events:${clip.name}`;if(!this.reportedMissing.has(key)){this.reportedMissing.add(key);runtimeDiagnostics.record('animation.event-handler-unavailable','Authored model events have no implemented engine handler',{model:this.model.modelName,instance:this.root.name,clip:clip.name,events:missingEvents});}}
    this.clip=gob.runsE0[0]?.clip0.source??null;this.time=gob.runsE0[0]?.time14??this.time;this.loop=false;this.onComplete=onComplete;this.playing=gob.runsE0.length>0;return true;
  }

  pose(name) {
    if (!this.play(name, { loop: false })) return false;
    this.time = this.clip.length;
    this.apply(this.clip, this.time);
    this.playing = false;
    return true;
  }

  update(delta) {
    if (!this.playing || !this.clip || !Number.isFinite(delta) || delta < 0) return;
    if(this.nativePlayback){
      const gob=this.nativePlayback;
      advanceModelRuns(gob,delta,{
        event:(name,data)=>this.eventDispatcher.dispatch(name,data),destroyRun:()=>{},
        applyClip:(descriptor,previous,time,weight,scale,motionRun)=>{
          if(this.nativePose){this.clip=descriptor.source;this.time=time;this.nativePose.apply(descriptor.source.nativeRoot,previous,time,weight,scale,motionRun);this.root.userData.animationClip=this.clip.name;this.root.userData.animationTime=time;return;}
          if(weight!==1||gob.runsE0.length!==1)throw new Error('Native stacked/blended model pose presentation is unavailable');
          this.clip=descriptor.source;this.time=time;this.apply(this.clip,time);
        },
        animateEvents:(descriptor,previous,time,flags)=>animateModelEvents(descriptor,previous,time,flags,(name,data)=>this.eventDispatcher.dispatch(name,data)),
        updateRoot:()=>{this.root.updateWorldMatrix(true,true);if(this.nativePose)this.updateSkin?.();},periodicUpdate:()=>{}
      });
      this.playing=gob.runsE0.length>0;
      if(!this.playing){const callback=this.onComplete;this.onComplete=null;callback?.();}return;
    }
    const previous=this.time;
    this.time += delta;
    if (this.loop) this.time %= this.clip.length;
    else this.time = Math.min(this.time, this.clip.length);
    this.apply(this.clip, this.time);
    animateModelEvents(this.clip,previous,this.time,0,(name,data)=>this.eventDispatcher.dispatch(name,data));
    if (!this.loop && this.time >= this.clip.length) {
      this.playing = false;
      const callback = this.onComplete;
      this.onComplete = null;
      callback?.();
    }
  }
}
