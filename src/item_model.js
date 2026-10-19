import {intEntry} from './combat_stats.js';
import {nativeStringEntry} from './spell_metadata.js';
import {nativeFloatEntry} from './movement_rate.js';

// CNWBaseItem29dd90/29dc80. MSVC hidden return pointer precedes part BYTE,
// signed model SHORT and optional gender CHAR. Native CResRef stores16 bytes.
export function nativeItemResourceRef({modelType,itemClass,genderSpecific=false},part,number,variant=0,icon=false){
 if(!Number.isInteger(modelType)||typeof itemClass!=='string'||!Number.isInteger(part)||!Number.isInteger(number)||!Number.isInteger(variant))throw new Error('Native item resource fields are unavailable');
 const prefix=(icon?'i':'')+itemClass.split('\0')[0],signed=(number<<16)>>16;
 // Keep the sign before zero padding, matching sprintf %03d.
 const model=signed<0?'-'+String(-signed).padStart(2,'0'):String(signed).padStart(3,'0');
 let suffix='';if(modelType===2){if(part<0||part>2)throw new Error('Native item model part is outside B/M/T');suffix='_'+'BMT'[part];}else if(genderSpecific&&(variant&255)!==0)suffix='_'+String.fromCharCode(variant&255);
 return`${prefix}${suffix}_${model}`.slice(0,16);
}

// CreateItem769130 selects world models separately from its icon builders.
// IDs and model types below are intrinsic native branches, not module rules.
export function groundItemModelPlan(item,{baseitems,parts_chest}){
 if(!item||!Number.isInteger(item.baseItem))throw new Error('Native item appearance is unavailable');
 const modelType=intEntry(baseitems,item.baseItem,'ModelType'),prefix=nativeStringEntry(baseitems,item.baseItem,'ItemClass'),fallback=nativeStringEntry(baseitems,item.baseItem,'DefaultModel');
 if(!modelType.found)throw new Error('Native base-item model rules are unavailable');
 const type=modelType.value&255,parts=item.parts;if(!Array.isArray(parts)||parts.length<(type===3?19:type===2?3:1))throw new Error('Native item model parts are unavailable');
 let palette=null;if(type===1||type===3){if(!Array.isArray(item.colors)||item.colors.length!==6)throw new Error('Native item material colors are unavailable');const c=item.colors;palette=[0,0,c[4],c[5],c[2],c[3],c[0],c[1],0,0];}
 if(type===3){
  const ac=nativeFloatEntry(parts_chest,parts[7],'ACBonus').value,floor=Math.floor(ac),rounded=ac-floor>=.5?Math.ceil(ac):floor;
  const name=!(rounded>=2)?'gi_armor01':!(rounded>=4)?'gi_armor04':!(rounded>=6)?'gi_armor03':'gi_armor02';
  return{modelType:type,palette,defaultAnimation:false,models:[{primary:name,fallback:null,probe:false,selector:255}]};
 }
 if(![0,1,2].includes(type))throw new Error(`Native item model type ${type} is unavailable`);
 const schema={modelType:type,itemClass:prefix.value},models=Array.from({length:type===2?3:1},(_,part)=>({primary:type===1&&item.baseItem===80?'gi_cloak01':nativeItemResourceRef(schema,part,parts[part]),fallback:fallback.value,probe:true,selector:255-part}));
 return{modelType:type,palette,defaultAnimation:true,models};
}

// Exists is distinct from loading: a present, corrupt model must fail its
// load instead of silently replacing the native body failure with a fallback.
export async function selectGroundItemModels(plan,exists){
 const selected=[];for(const model of plan.models){let name=model.primary,fallback=false;if(model.probe&&!await exists(name)){name=model.fallback;fallback=true;if(!name||!await exists(name))throw new Error(`Native item model ${model.primary} and default ${model.fallback} are unavailable`);}selected.push({name,selector:model.selector,fallback});}return selected;
}
