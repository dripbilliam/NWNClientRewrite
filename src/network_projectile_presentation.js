import * as THREE from 'three';
import {ClientProjectilePresentation} from './client_projectile_presentation.js';
import {clientProjectileModelQuaternion} from './client_projectile_orientation.js';
import {nativeCosf,nativeSinf} from './native_math.js';
import {randomSceneModelPart} from './model_random_part.js';

export function networkProjectilePose(object){
 const state=object.replicated??{},fixed=object.staticState??object.lightState,position=state.position??fixed?.position,orientation=state.orientation??fixed?.orientation,vector=Array.isArray(orientation)?orientation:orientation?.vector;
 if(!Array.isArray(position))throw new Error('Native network projectile object position is unavailable');
 if(vector)return{position,orientation:vector};const yaw=(orientation?.yaw??0)*Math.PI/180;return{position,orientation:[nativeCosf(yaw),nativeSinf(yaw),0]};
}

// Server IDs and native poses pass through unchanged. Internal projectile and
// dummy IDs belong to ClientObjectArray, never NetworkWorld.registry.
export function networkProjectilePresentation(scene){
 const {world,root,poses,tables,combat}=scene,basis=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2),inverse=basis.clone().invert();
 const objects=()=>[...world.registry.objects.values()].filter(o=>o.areaId===world.areaId&&!o.replicationRemoved&&Array.isArray(o.replicated?.position??o.staticState?.position??o.lightState?.position));
 const loadModel=async name=>{const model=await scene.model(name);scene.animators=scene.animators.filter(a=>a!==model.animator);model.model??=model.animator?.model;model.resourceName=name;return model;};
 const prepareModel=async name=>{
  if(!scene.visuals)throw new Error('Native procedural projectile asset owner is unavailable');
  const asset=await scene.visuals.asset(name),owned=new Set();let released=false;
  const destroy=model=>{if(!owned.delete(model))return;poses.forgetAttachment(model);scene.visuals.destroyModel(model);};
  return{create:alias=>{if(released||scene.closed)throw new Error('Prepared projectile scene is closed');const model=scene.visuals.createModel(asset,name);model.alias=alias;owned.add(model);return model;},destroy,release:()=>{if(released)return;released=true;for(const model of [...owned])destroy(model);}};
 };
 return new ClientProjectilePresentation({objects,renderFor:id=>scene.objects.get(id)?.wrapper,playerId:()=>world.localObjectId,rules:()=>tables,
  nativePose:networkProjectilePose,
  now:()=>combat.timer.time(),dayLength:()=>combat.timer.dayLength,random:combat.random,
  loadModel,prepareProjectileModel:prepareModel,prepareAuxiliaryModel:prepareModel,destroyModel:model=>{poses.forgetAttachment(model);scene.destroyModels([model]);},
  modelFor:render=>{for(const binding of scene.objects.values())if(binding.wrapper===render)return binding.models[0];return poses.modelHandle(render);},
  nodePose:(model,name,position,quaternion)=>poses.nodePoseInto(model,name,position,quaternion),
  orient:(model,vector)=>{const q=clientProjectileModelQuaternion(vector);if(q)model.root.quaternion.copy(basis).multiply(new THREE.Quaternion(q[1],q[2],q[3],q[0])).multiply(inverse);},
  castAttachment:{attach:(...args)=>poses.setParent(...args),forget:m=>poses.forgetAttachment(m),updateAttachments:()=>poses.updateAttachments()},
  impactAttachment:{attach:(...args)=>poses.setParent(...args),setNodePose:(...args)=>poses.setNodePose(...args),forget:m=>poses.forgetAttachment(m),updateAttachments:()=>poses.updateAttachments()},
  // game.gore registration6b995d..6b99be defaults to1 and callback6bce30
  // writes client byte40. The replacement currently uses that native default.
  hitPartsEnabled:()=>1,
  randomImpactPart:model=>randomSceneModelPart(model,combat.random),
  castAnimation:o=>scene.objects.get(o.id)?.combat?.visual??o.replicated?.animation??0,
  castFields:o=>{const cast=o.replicated?.cast;if(!cast)throw new Error('Replicated cast fields are unavailable');return[{type:'dword',value:cast.spell},{type:'object',value:cast.casterTarget},{type:'bool',value:cast.silent}];},
  voiceFields:o=>({race:o.replicated?.stats?.racialType??o.replicated?.stats?.fieldD20??-1,gender:o.appearance?.gender??255}),
  soundFactory:scene.soundFactory?options=>scene.soundFactory(options):null,
  nativeAudio:Boolean(scene.oneShot),oneShot:event=>{if(scene.oneShot)scene.oneShot(event);else scene.report('network.scene-projectile-audio-unhandled','Native projectile audio output is not connected',{resource:event.resRef,channel:event.channel});},
  scene:root,report:scene.report});
}
