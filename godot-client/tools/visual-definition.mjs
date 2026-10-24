import {loadVisualEffectAsync} from '../../src/visual_loader.js';
import {createVisualPhaseState} from '../../src/visual_phase_runtime.js';
import {intEntry} from '../../src/combat_stats.js';
import {nativeFloatEntry} from '../../src/movement_rate.js';
import {nativeStringEntry} from '../../src/spell_metadata.js';
import {clientProjectileTargetPrefix} from '../../src/client_projectile_target.js';
import {networkVisualIdentity} from '../../src/network_visual_presentation.js';

// Original loader decisions, active table outputs and external-resource inputs
// for a native phase owner. No phase clock, scene/model animation or skinning
// runs here. Host model descriptors are physical binding metadata, not actors.
export async function prepareVisualDefinition({actorId,record,objects,modelFor,tables,resource,current=()=>true,settings={quality64:1,violence40:2}}){
 const transform=record.transform;
 if(!transform||transform.scale!==1||![...transform.translate,...transform.rotate].every(value=>value===0))throw Error('Native visual transform-controller presentation is not implemented');
 if(record.bodyPart!==0)throw Error('Native non-default looping visual body-part delivery is not implemented');
 if(!networkVisualIdentity(record.networkTransform))throw Error('Native network visual controller-map presentation is not connected');
 const actor=objects.get(actorId);if(!actor||![5,9,10].includes(actor.objectType))throw Error('Native visual target type is unavailable');
 const state=createVisualPhaseState(),resources={},warnings=[],pending=new Map();let serial=0;
 const live=()=>current()&&objects.get(actorId)===actor;
 const warning=(code,reason,extra={})=>{if(live())warnings.push({code,reason,...extra});};
 async function asset(name){
  name=String(name).toLowerCase();if(!live())return null;
  if(!pending.has(name))pending.set(name,(async()=>{
   try{const value=await resource(name);if(!live())return null;if(!value){warning('visual.resource-unavailable','Visual model resource is unavailable',{model:name});return null;}resources[name]=value;return name;}
   catch(error){warning('visual.resource-unavailable',error.message,{model:name});return null;}
  })());
  return pending.get(name);
 }
 const view=object=>{const model=modelFor(object.id);return model?{actor:object,model}:null;};
 const prefix=(render,type,key)=>render.actor.objectType===type?{[key]:clientProjectileTargetPrefix(type,render.model.loadedName)}:null;
 const p={
  clientObject:id=>objects.get(id),renderObject:view,modelHandle:render=>render.model,
  prefixViewA0:render=>prefix(render,9,'prefix1e0'),prefixView28:render=>prefix(render,10,'prefix1c8'),
  creatureView58:render=>render.actor.objectType===5?{appearanceCc:render.actor.appearance?.appearance??render.actor.creatureData?.Appearance_Type??0}:null,
  appearanceInt:(id,column)=>intEntry(tables.appearance,id,column),settings:()=>settings,
  visualInt:(id,column)=>intEntry(tables.visuals,id,column),visualString:(id,column)=>nativeStringEntry(tables.visuals,id,column),
  findNode:(model,name)=>String(name).toLowerCase()==='root'?model.parts.length>0:model.parts.some(part=>part.toLowerCase()===String(name).toLowerCase()),
  loadModel:async(name,alias)=>{const key=await asset(name);return key===null?null:{id:++serial,resource:key,alias};},
  modelSetting1a0:(model,priority)=>model.priority=priority,
  warning:(line,reason)=>warning('visual.native-model-warning',reason,{line}),
  copyControllers:(effect,value)=>effect.controllers128=structuredClone(value),consumeControllers:()=>{},
 };
 const loaded=await loadVisualEffectAsync(state,{visual:record.visualId,target:actorId,source:record.sourceId??0x7f000000,...(record.delivery??{instant:0,sourcePart:0,targetPart:0,point:[0,0,0]}),controllers:transform},p);
 if(!live())return null;if(!loaded)throw Error('Native visual target model is unavailable');
 const programs={};
 for(const id of new Set(state.programsD0)){
  if(id===65535)continue;if(!live())return null;
  const type=intEntry(tables.programs,id,'Type'),row={id,type,integer:{},float:{},string:{}};
  for(let index=1;index<=7;index++){const column='param'+index;row.integer[column]=intEntry(tables.programs,id,column);row.float[column]=nativeFloatEntry(tables.programs,id,column);row.string[column]=nativeStringEntry(tables.programs,id,column);}
  const kind=type.value&255,column=kind===4?'param7':kind===7?'param1':kind===12?'param2':null;
  if(column)row.resource=await asset(row.string[column].value);
  programs[id]=row;
 }
 if(!live())return null;
 const visual={integer:{},float:{},string:{}};
 visual.integer.ShakeType=intEntry(tables.visuals,state.visualF8,'ShakeType');
 for(const column of ['ShakeDuration','ShakeDelay'])visual.float[column]=nativeFloatEntry(tables.visuals,state.visualF8,column);
 for(const column of ['SoundImpact','SoundDuration','SoundCessation','Type_FD'])visual.string[column]=nativeStringEntry(tables.visuals,state.visualF8,column);
 const hosts={};for(const id of new Set([actorId,record.sourceId])){const object=objects.get(id),model=object&&modelFor(id);if(object&&model)hosts[id]={id,type:object.objectType,privateToken:object.privateToken??0,prefix:[9,10].includes(object.objectType)?clientProjectileTargetPrefix(object.objectType,model.loadedName):''};}
 return{version:1,kind:'visual-definition',state,programs,visual,hosts,resources,warnings,settings:{...settings},scope:'Original loader/resource decisions for native phase integration; not full program/controller/projectile acceptance'};
}
