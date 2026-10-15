import {scriptCos,scriptSin} from './script_scalar.js';
import {normalizeOrientation} from './combat_lifecycle.js';
// ExecuteCommandLocation1405354a0. Keep copied native XYZ, canonical area
// ID and normalized native facing vector; the degree scalar is compatibility
// metadata for existing local consumers, not the original structure storage.
export function scriptLocation(areaId,position,facing){
  if(!Number.isInteger(areaId)||!Array.isArray(position)||position.length!==3||!position.every(Number.isFinite))throw new Error('Native script location arguments are unavailable');
  const f=Math.fround,orientation=normalizeOrientation([scriptCos(facing),0,f(-scriptSin(facing))]);
  return{areaId:areaId>>>0,position:position.map(f),orientation:f(facing),nativeOrientation:[orientation[0],f(-orientation[2]),orientation[1]]};
}
