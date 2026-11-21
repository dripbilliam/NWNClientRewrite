import {createAreaVisualState,loadAreaVisualEffect} from '../../src/area_visual_effect.js';
import {intEntry} from '../../src/combat_stats.js';import {nativeFloatEntry} from '../../src/movement_rate.js';import {nativeStringEntry} from '../../src/spell_metadata.js';import {networkVisualIdentity} from '../../src/network_visual_presentation.js';
// Area packet4/2 is a CNWCVisualEffect/type11, not an object looping effect.
export async function prepareAreaVisualDefinition({message,table,resource,current=()=>true}){
 if(!networkVisualIdentity(message.visualTransform))throw Error('Native area visual transform-controller map remains unsupported');
 const state=createAreaVisualState({day:0,time:0}),resources={},warnings=[];
 const query={integer:{},float:{},string:{}};
 const get=(kind,fn)=>(id,key)=>{const result=fn(table,id,key);query[kind][key]=result;return result;};
 const p={quality:()=>1,int:get('integer',intEntry),float:get('float',nativeFloatEntry),string:get('string',nativeStringEntry),
  loadModel:async(e,name,part,flags)=>{if(part!==255||flags!==8)throw Error('Unexpected area model loader flags');const key=String(name).toLowerCase();const result=await resource(key);if(!current()||!result)return 0;resources[key]=result;e.model={id:1,resource:key};return 1;},
  animationMode:()=>warnings.push({code:'visual.area-orientation-mode-pending'}),defaultAnimation:()=>warnings.push({code:'visual.area-default-animation-pending'}),shake:()=>warnings.push({code:'visual.area-camera-shake-pending'})};
 const loaded=await loadAreaVisualEffect(state,message.visualId,p);
 if(!current())return null;
 if(!loaded)throw Error('Native area model resource is unavailable');
 for(const column of ['SoundImpact','SoundDuration','SoundCessation'])query.string[column]=nativeStringEntry(table,message.visualId,column);
 state.instant190=1;state.destroy194=1;state.position=message.position.map(Math.fround);
 return{version:1,kind:'area-visual-definition',state,resources,warnings,query,scope:'Original type11 area model selection; native animation/AI owner. Special orientation, shake, audio and exact scene scheduling remain pending.'};
}
