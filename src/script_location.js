import {scriptCos,scriptSin} from './script_scalar.js';
import {normalizeOrientation} from './combat_lifecycle.js';
import {scriptObjectFacing} from './script_object_queries.js';
import {OBJECT_INVALID} from './game_object_array.js';
// GetLocation14052b130 / GetScriptLocation140495f30 copies raw vectors and
// area ID; it does not normalize facing, resolve the area, or return null.
export function scriptObjectLocation(actor){
 if(!actor||actor.objectType<=4)return{areaId:OBJECT_INVALID,position:[0,0,0],nativeOrientation:[0,0,0],orientation:0};
 if(!Number.isInteger(actor.areaId)||![actor.position,actor.orientation].every(v=>Array.isArray(v)&&v.length===3&&v.every(Number.isFinite)))throw new Error('Native object script-location storage is unavailable');
 const f=Math.fround,position=[f(actor.position[0]),f(-actor.position[2]),f(actor.position[1])],nativeOrientation=[f(actor.orientation[0]),f(-actor.orientation[2]),f(actor.orientation[1])];
 return{areaId:actor.areaId>>>0,position,nativeOrientation,orientation:scriptObjectFacing(actor)};
}
// ExecuteCommandLocation1405354a0. Keep copied native XYZ, canonical area
// ID and normalized native facing vector; the degree scalar is compatibility
// metadata for existing local consumers, not the original structure storage.
export function scriptLocation(areaId,position,facing){
  if(!Number.isInteger(areaId)||!Array.isArray(position)||position.length!==3||!position.every(Number.isFinite))throw new Error('Native script location arguments are unavailable');
  const f=Math.fround,orientation=normalizeOrientation([scriptCos(facing),0,f(-scriptSin(facing))]);
  return{areaId:areaId>>>0,position:position.map(f),orientation:f(facing),nativeOrientation:[orientation[0],f(-orientation[2]),orientation[1]]};
}
