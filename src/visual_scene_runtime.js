import {intEntry} from './combat_stats.js';
import {nativeFloatEntry} from './movement_rate.js';
import {nativeStringEntry} from './spell_metadata.js';
import {loadVisualEffectAsync} from './visual_loader.js';
import {loadVisualProgram,clearVisualProgram,updateVisualProgram} from './visual_program.js';
import {startType4Visual,attachType4Visual,stopType4Visual} from './visual_type4.js';
import {VisualPhaseRuntime,createVisualPhaseState} from './visual_phase_runtime.js';
import {visualLocalPoseServices} from './visual_scene_pose.js';
import {setModelLightPriority} from './model_light.js';

function unparent(model){
 const root=model.root,position=root.getWorldPosition(root.position.clone()),quaternion=root.getWorldQuaternion(root.quaternion.clone()),scale=root.getWorldScale(root.scale.clone());
 root.removeFromParent();root.position.copy(position);root.quaternion.copy(quaternion);root.scale.copy(scale);root.updateWorldMatrix(true,true);
}

// Platform adapter around shared native owners. Asset reads are prefetched as
// data only; each actual LoadProgram still creates/stores a fresh model at its
// native phase boundary. Canonical records and game-object IDs are never edited.
export async function createVisualSceneRuntime({actor,record,tables,objects,renderFor,player,loadAsset,createModel,destroyModel,releaseAsset,shadowing,report,sceneRoot,settings=()=>({quality64:1,violence40:2})}){
 const state=createVisualPhaseState(),owned=new Set(),assets=new Map(),pending=new Map(),reported=new Set(),contexts=new WeakMap();let runtime=null,closed=false,elapsedMs=0,previousMs=0;
 const data={objectId:actor.id,visualId:record.visualId},failure=(code,message,extra={})=>{const key=`${code}:${JSON.stringify(extra)}`;if(!reported.has(key)){reported.add(key);report(code,message,{...data,...extra});}};
 const transform=record.transform;
 if(!transform||transform.scale!==1||![...transform.translate,...transform.rotate].every(v=>v===0))throw new Error('Native visual transform-controller presentation is not implemented');
 if(record.bodyPart!==0)throw new Error('Native non-default looping visual body-part delivery is not implemented');
 if(actor.objectType!==5)throw new Error('Native non-creature visual model-prefix views are not connected');
 const getAsset=name=>{
  name=String(name).toLowerCase();
  if(!pending.has(name))pending.set(name,(async()=>{try{const asset=await loadAsset(name);assets.set(name,asset);return asset;}catch(error){failure('visual.model-load-failed',error.message,{model:name,stack:error.stack});return null;}})());
  return pending.get(name);
 };
 const instantiate=(name,alias)=>{
  const asset=assets.get(String(name).toLowerCase());if(!asset)return null;
  const model=createModel(asset,String(name),alias);owned.add(model);return model;
 };
 const destroy=model=>{if(!owned.has(model))return;owned.delete(model);poses.forgetAttachment(model);destroyModel(model);};
 const view=object=>{
  const scene=renderFor(object.id);if(!scene)return null;
  return{scene,actor:object,get position38(){const p=object.position;return[p[0],-p[2],p[1]].map(Math.fround);}};
 };
 const context=object=>{
  if(object?.objectType!==5)return null;
  if(!contexts.has(object))contexts.set(object,{id:object.id,context30:{}});return contexts.get(object);
 };
 const poses=visualLocalPoseServices({sceneRoot}),current=e=>{const phase=e.programPhaseFa&255;return phase>=1&&phase<=3?e.programsD0[phase-1]&65535:65535;};
 const type=id=>intEntry(tables.programs,id&65535,'Type').value&255;
 const unsupported=(operation,id)=>failure(`visual.program-${operation}-unimplemented`,`Native procedural visual ${operation} is not implemented`,{programId:id&65535,type:type(id)});
 const p={...poses,
  clientObject:id=>objects.get(id),renderObject:view,modelHandle:(v,...args)=>poses.modelHandle(v.scene,...args),
  gameObjectRegistry:()=>objects,gameObject:(registry,id)=>({success:!!registry.get(id),value:registry.get(id)}),
  prefixViewA0:v=>{if(v.actor.objectType===5)return null;throw new Error('Native visual placeable-prefix view is unavailable');},
  prefixView28:v=>{if(v.actor.objectType===5)return null;throw new Error('Native visual door-prefix view is unavailable');},
  view58:v=>context(v.actor),view1406ac1a0:()=>context(player()),
  creatureView58:v=>v.actor.objectType===5?{appearanceCc:(v.actor.creatureData??v.actor.authored).Appearance_Type}:null,
  appearanceInt:(id,column)=>intEntry(tables.appearance,id,column),
  settings:()=>{failure('visual.client-settings-unimplemented','Native visual client settings are not connected; explicit local quality/violence profile is used',settings());return settings();},
  visualInt:(id,column)=>intEntry(tables.visuals,id,column),visualFloat:(id,column)=>nativeFloatEntry(tables.visuals,id,column),visualString:(id,column)=>nativeStringEntry(tables.visuals,id,column),
  programInt:(id,column)=>intEntry(tables.programs,id,column),programFloat:(id,column)=>nativeFloatEntry(tables.programs,id,column),programString:(id,column)=>nativeStringEntry(tables.programs,id,column),programType:(_e,id)=>type(id),
  findNode:(model,name)=>{if(String(name).toLowerCase()==='root')return model.root.children.find(v=>v.userData.mdlNode)??null;let found=null;model.root.traverse(v=>{if(!found&&v.userData.mdlNode?.toLowerCase()===String(name).toLowerCase()&&v.userData.mdlModel===model.root.userData.mdlRoot)found=v;});return found;},
  loadModel:instantiate,
  warning:(line,message)=>failure('visual.native-model-warning',message,{line}),
  modelSetting1a0:(model,priority)=>{setModelLightPriority(model.root,priority);failure('light.priority-selection-unimplemented','Native light priority is retained; renderer-wide light selection is not implemented',{priority});},
  copyControllers:(e,value)=>{e.controllers128=structuredClone(value);},consumeControllers:()=>{},destroyControllers:()=>{},
  setParent:(model,parent,...args)=>{if(!parent){poses.forgetAttachment(model);unparent(model);return null;}if(sceneRoot)failure('visual.attachment-lifetime-unimplemented','Native attachment event propagation, handle invalidation and behavior lifetime are not implemented');return poses.setParent(model,parent,...args);},
  setScene:(model,scene)=>{if(scene!==0)throw new Error('Native visual scene rebinding is unavailable');unparent(model);if(model.model.nodes.some(node=>node.type==='emitter'))failure('visual.detached-particles-unverified','Detached emitter scene/lifetime handling has not been verified',{model:model.resourceName});},
  destroyModel:destroy,detachProcedural:(...args)=>p.setParent(...args),unsceneProcedural:(...args)=>p.setScene(...args),destroyProcedural:destroy,
  playAnimation:(model,name,speed,flags,time)=>{
   if(!model.model.animations.some(clip=>clip.name===String(name).toLowerCase()))return 0;
   return model.animator.playNative(name,{speed,flags,time})?1:0;
  },animationInfo:(model,name)=>({length:model.model.animations.find(clip=>clip.name===name)?.length??0}),
  programAttach14096bbb0:e=>attachType4Visual(e,p),
  shadowing:(model,enabled)=>shadowing(model,enabled),
  controlledClient:()=>({videoF8:{gui248:{}}}),registerGuiD8:()=>failure('visual.gui-attachment-unimplemented','Native selected-view visual GUI attachment is not implemented'),
  refreshContext1407e9bc0:()=>failure('visual.context-renderer-unimplemented','Native dynamic-projection/shadow context refresh is not implemented'),
  clearProgram:e=>clearVisualProgram(e,p),loadProgram:(e,id)=>loadVisualProgram(e,id,p),
  startProgram:(e,id)=>{if(!e.updateProgramD8)return;if(type(id)===4)startType4Visual(e,id,p);else if(type(id)>=1&&type(id)<=13)unsupported('start',id);},
  stopProgram:(e,id)=>{if(!e.updateProgramD8)return;if(type(id)===4)stopType4Visual(e,id,p);else if(type(id)>=1&&type(id)<=13)unsupported('stop',id);},
  updateProgram:(e,id,delta)=>updateVisualProgram(e,id,delta,p),currentProgram:current,
  update140971e10:()=>failure('visual.program-update-unimplemented','Native Type5 visual update is not implemented'),update1409720e0:()=>failure('visual.program-update-unimplemented','Native Type6 visual update is not implemented'),
  detach:e=>runtime.detachModels(),
  applyModelState:(_e,_render,model)=>{model.root.userData.visualControllers128=structuredClone(state.controllers128);failure('visual.material-state-unimplemented','Native resource/material visual metadata application is incomplete');},
  positionalSound:(name,position,gain,kind)=>{if(name)failure('visual.positional-audio-unimplemented','Native visual positional sound output is not implemented',{sound:name,position,gain,kind});},
  createSound:resRef=>({resRef,settings:{},playing:false,destroyed:false}),soundSetting:(sound,key,value)=>{sound.settings[key]=value;},
  playSound:sound=>{sound.playing=true;if(sound.resRef)failure('visual.duration-audio-unimplemented','Native duration sound output is not implemented',{sound:sound.resRef});},
  stopSound:sound=>{sound.playing=false;},destroySound:sound=>{sound.destroyed=true;},updateSound:(sound,position)=>{sound.position=position;},
  shakeOnce:(_client,delay)=>failure('visual.camera-shake-unimplemented','Native visual camera shake is not implemented',{delay}),shakeLoop:(_client,delay,duration)=>failure('visual.camera-shake-unimplemented','Native visual camera shake is not implemented',{delay,duration})
 };
 for(const address of['14096ba80','14096b630','140969ef0','14096aff0','1409689f0'])p[`programAttach${address}`]=()=>unsupported('attach',current(state));
 p.renderSetting158=()=>unsupported('attach',current(state));
 const dispose=()=>{
  if(closed)return;closed=true;
  try{runtime?.dispose();}finally{for(const model of [...owned])destroy(model);for(const asset of assets.values())releaseAsset(asset);assets.clear();}
 };
 try{
  const delivery=record.delivery??{instant:0,sourcePart:0,targetPart:0,point:[0,0,0]};
  const loaded=await loadVisualEffectAsync(state,{visual:record.visualId,target:actor.id,source:record.sourceId,...delivery,controllers:transform},{...p,loadModel:async(name,alias)=>{await getAsset(name);return instantiate(name,alias);}});
  if(!loaded)throw new Error('Native visual target is unavailable');
  // Browser I/O cannot run synchronously inside a phase transition. Prefetch
  // data without creating models or changing native phase/list state.
  for(const id of new Set(state.programsD0)){
   const kind=type(id),column=kind===4?'param7':kind===7?'param1':kind===12?'param2':null;
   if(column)await getAsset(nativeStringEntry(tables.programs,id,column).value);
  }
  runtime=new VisualPhaseRuntime(state,p);
  const snapshot=()=>{
   const models=[...state.models88,state.proceduralB8].filter(Boolean),lights=[];
   for(const model of models)model.root.traverse(light=>{if(light.isLight)lights.push({name:light.name,ambient:Number(light.userData.mdlLight?.ambientonly)>0,color:light.color.toArray(),intensity:light.intensity,radius:light.userData.mdlLight?.radius??0,shadow:light.castShadow,priority:light.userData.mdlLightPriority90??null,properties:light.userData.mdlLight});});
   const active=state.proceduralB8??models[0];return{phase:state.programPhaseFa,closed:state.closedEc,finished:state.finishedF4,remaining:state.programRemainingCc,time:active?.animator.time??0,playing:active?.animator.playing??false,nativePose:Boolean(active?.animator.nativePose),position:active?.root.position.toArray()??[0,0,0],lights,models:models.map(model=>model.resourceName)};
  };
  return{nativeState:state,get program(){const id=current(state);return{id,type:type(id),model:state.proceduralB8?.resourceName,animation:state.proceduralB8?.animator.clip?.name};},
   attach:()=>{runtime.attach();failure('visual.owner-suppression-unimplemented','Native visual owner suppression is not connected; local unsuppressed profile is used');failure('visual.clock-scene-order-unverified','Native phase owners use renderer-derived milliseconds; outer client clock/frame ordering and scene gates remain unverified');},
   attachModels:()=>runtime.attachModels(),detachModels:()=>runtime.detachModels(),restart:()=>runtime.restart(),stopForSelection:value=>runtime.stopForSelection(value),stop:value=>runtime.stop(value),
   update:delta=>{poses.updateAttachments();for(const model of owned)model.animator.update(delta);elapsedMs+=delta*1000;const now=Math.trunc(elapsedMs);runtime.updateMilliseconds((now-previousMs)>>>0);previousMs=now;},
   isRetired:()=>runtime.isRetired(),snapshot,dispose};
 }catch(error){dispose();throw error;}
}
