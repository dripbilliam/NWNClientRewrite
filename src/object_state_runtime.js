import {saveObjectState,saveGameEffect,saveScriptVariables,saveObjectActions,saveObjectTransition,loadObjectTransition} from './object_state_save.js';
import {readItemGffField} from './item_gff_load.js';
import {loadObjectState} from './object_state_load.js';
import {loadGameEffect,savedEffectStorage} from './game_effect_load.js';
import {getGffFieldTypes} from './gff.js';
import {loadObjectActions} from './object_action_load.js';

// Canonical object state only. Opaque VM/solver/JSON data must have its actual
// owner before it can be saved; unsupported live records remain diagnosed.
export class ObjectStateRuntime{
 constructor(session){this.session=session;}
 async load(object,data){
  const s=this.session;
  try{
   if(s.registry.get(object.id)!==object)throw new Error('Native object load requires a canonical registry object');
   await loadObjectState(object,data,{read:(r,n,_t,d)=>readItemGffField(r,'list',n,d),constructEffect:()=>savedEffectStorage(),
    loadEffect:(effect,row)=>loadGameEffect(effect,row,{setCreator:(e,id)=>s.effects.setCreator(e,id)}),releaseEffect:()=>{},
    applyEffect:(o,e,loading,special)=>s.effects.applyNative(e,o.id,undefined,loading,special),
    variables:(o,r)=>getGffFieldTypes(r)?s.loadNativeVariables(o,r):s.loadNativeVariableRows(o,r.VarTable??[]),
    actions:(o,r)=>loadObjectActions(o.objectActionState,r,{read:(data,name,type,fallback)=>readItemGffField(data,({0:'byte',2:'word',4:'dword',5:'int',8:'float',10:'string',14:'struct',15:'list'})[type],name,fallback),scriptSituation:(data,previous)=>s.scriptSituations.load(data,previous)}),
    transition:(o,r)=>this.transitionLoad(o,r),
   });return object;
  }catch(error){s.report(error,{...s.diagnosticContext(object?.id),operation:'native-object-state-load'});throw error;}
 }
 transitionLoad(object,data){
  const current=object.nativeTransition288;if(!current)throw new Error('Native transition constructor state is unavailable');
  return loadObjectTransition(current,data,(record,name,type,fallback)=>readItemGffField(record,type===14?'struct':type===10?'string':'dword',name,fallback));
 }
 async save(object,root){
  const s=this.session;
  try{
   if(s.registry.get(object.id)!==object)throw new Error('Native object save requires a canonical registry object');
   const variableProviders={engineEmpty:(kind,value)=>{if(value===null)return true;throw new Error(`Native local ${kind} emptiness/save owner is unavailable`);},saveEngine:kind=>{throw new Error(`Native local ${kind} save owner is unavailable`);}};
   const actionProviders={actions:o=>o.objectActionState,client:o=>s.combat.broadcastProviders().client(o.id),
    clientFieldD4:()=>s.nativePlayerFieldD4,scriptSituation:(value,root)=>s.scriptSituations.save(value,root)};
   return await saveObjectState(object,{effects:o=>o.effects,effect:saveGameEffect,
    variables:(o,r)=>saveScriptVariables(o.locals.nativeRows(),variableProviders,r),actionsSave:(o,r)=>saveObjectActions(o,actionProviders,r),
    transition:(o,r)=>{if(!o.nativeTransition288)throw new Error('Native transition save storage is unavailable');return saveObjectTransition(o.nativeTransition288,r);},
   },root);
  }catch(error){s.report(error,{...s.diagnosticContext(object?.id),operation:'native-object-state-save'});throw error;}
 }
}
