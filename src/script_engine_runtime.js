import {saveScriptEngineStructure,loadScriptEngineStructure,createScriptEngineStructure,saveScriptEvent,loadScriptEvent,saveScriptTalent,loadScriptTalent} from './script_engine_structures.js';
import {saveGameEffect,saveLocalLocation} from './object_state_save.js';
import {loadGameEffect} from './game_effect_load.js';
import {loadLocalLocation} from './script_variable_load.js';

export class ScriptEngineRuntime{
 constructor(session){this.session=session;}
 providers(){
  const s=this.session;
  return{saveEffect:saveGameEffect,saveEvent:saveScriptEvent,saveTalent:saveScriptTalent,saveLocation:(v,r)=>{saveLocalLocation(v,r);return 1;},
   createEffect:mode=>{if(mode!==1)throw new Error('Native engine-effect load constructor mode is unavailable');return s.effects.create(0);},
   loadEffect:(effect,data)=>loadGameEffect(effect,data,{setCreator:(e,id)=>s.effects.setCreator(e,id)}),
   create:kind=>{if(kind>=5)throw new Error(`Native opaque engine-structure load constructor ${kind} is unavailable`);return createScriptEngineStructure(kind);},
   loadEvent:loadScriptEvent,loadTalent:loadScriptTalent,loadLocation:(v,r)=>{Object.assign(v,loadLocalLocation(r));return 1;},
   saveOpaque:kind=>{throw new Error(`Native opaque engine-structure save owner ${kind} is unavailable`);},loadOpaque:kind=>{throw new Error(`Native opaque engine-structure load owner ${kind} is unavailable`);}};
 }
 save(kind,value,root){return saveScriptEngineStructure(kind,value,this.providers(),root);}
 load(kind,data,out){return loadScriptEngineStructure(kind,data,this.providers(),out);}
}
