import {getGffFieldTypes} from './gff.js';
import {readNativeGff} from './native_gff_fields.js';
const integer=value=>{if(!Number.isInteger(value))throw new Error('Native creature immortality INT8b8 is unavailable');return value|0;};

// Constructor14037b226, getter140525f40 and setter140541fa0 share ONE INT.
// Script writes retain raw INTs; different native consumers test ==1 or !=0.
export function initializeCreatureImmortality(actor){
 const values=[actor.nativeFlag8b8,actor.immortal].filter(v=>v!==undefined).map(integer);
 if(values.some(v=>v!==values[0]))throw new Error('Conflicting native creature immortality values');
 actor.nativeFlag8b8=values[0]??0;
 Object.defineProperty(actor,'immortal',{enumerable:true,configurable:true,get(){return this.nativeFlag8b8;},set(v){this.nativeFlag8b8=integer(v);}});
}
// Both ReadStatsFromGff paths14040ff21..47 /1404100da..100 call the
// Boolean BYTE reader1401a0f60, default0. Authored data is an import snapshot.
export function importCreatureImmortality(actor,data){
 const value=getGffFieldTypes(data)?readNativeGff(data,'IsImmortal',0,0).value:integer(data?.IsImmortal??0);
 actor.nativeFlag8b8=Number((value&255)!==0);
}
export function getCreatureImmortal(actor){return actor?.objectType===5?integer(actor.nativeFlag8b8):0;}
export function setCreatureImmortal(actor,value){if(actor?.objectType===5)actor.nativeFlag8b8=integer(value);}
