import {normalizeNativeVector} from './native_vector.js';
const f=Math.fround;

// Vector::Magnitude1402303d0..40c; f32 XYZ multiply/add then sqrtf.
// Unordered/nonpositive squared length returns fresh +0.
export function scriptVectorMagnitude(vector){
 if(!Array.isArray(vector)||vector.length!==3||!vector.every(v=>typeof v==='number'))throw new Error('Native script magnitude input is unavailable');
 const[x,y,z]=vector.map(f),squared=f(f(f(x*x)+f(y*y))+f(z*z));
 return squared>0?f(Math.sqrt(squared)):0;
}

// ExecuteCommandVectorNormalize14054ab60..14054ac2e. Exactly zero input
// returns a fresh +0 vector; nonzero underflow reaches the lower's +X default.
export function scriptNormalizeVector(vector){
 if(!Array.isArray(vector)||vector.length!==3||!vector.every(Number.isFinite))throw new Error('Native script normalization input is unavailable');
 const [x,y,z]=vector.map(f);if(x===0&&y===0&&z===0)return[0,0,0];
 return normalizeNativeVector([x,y,z]);
}

// Complete PrintString1403147c0's successful typed-pop body. The common
// native logger is a lower boundary; it receives a fixed format and a C string.
// Only raw prefix1 selects PRINTSTRING. Active nwscript exposes one argument;
// the native wrapper's private optional second argument is retained here.
export function scriptPrintString(text,prefix=0,write){
 if(typeof text!=='string'||typeof write!=='function')throw new Error('Native script logging input/provider is unavailable');
 const value=text.split('\0')[0],tagged=(prefix|0)===1,format=tagged?'PRINTSTRING: %s\n':'%s\n';
 write(format.replace('%s',()=>value),{flags:[1,2],function:'ExecuteCommandPrintString',file:'game\\sharedcore\\nwvmcmdshared.cpp',line:tagged?150:154,format,text:value});
}
