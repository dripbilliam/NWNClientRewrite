// Written during the actual-tests hold. No execution or native-oracle
// acceptance is claimed. Stub power boundaries check data flow only.
import test from 'node:test';
import assert from 'node:assert/strict';
import {nativeColorSpaceFromSrgb,nativeLightAdjustedColor,nativeLightAdjustedRange,nativePointLightUpload,nativeLightFalloffUniforms} from '../src/native_light_upload.js';

test('native color conversion bypasses nonpositive, NaN and exactly-one channels',()=>{
 const power=()=>assert.fail('bypass channel reached native math boundary');
 assert.deepEqual(nativeColorSpaceFromSrgb([-1,0,1],{gammaCorrection:true,power}),[-1,0,1]);
 assert.ok(Number.isNaN(nativeColorSpaceFromSrgb([NaN,0,1],{gammaCorrection:true,power})[0]));
 assert.deepEqual(nativeColorSpaceFromSrgb([.5,2,.25],{gammaCorrection:false,power}),[.5,2,.25]);
});

test('native color conversion uses the float32 2.2 power boundary rather than silently choosing sRGB',()=>{
 const calls=[],power=(value,exponent)=>{calls.push([value,exponent]);return value*value;};
 assert.deepEqual(nativeColorSpaceFromSrgb([.5,.25,.125],{gammaCorrection:true,power}),[.25,.0625,.015625]);
 assert.deepEqual(calls,[[.5,Math.fround(2.2)],[.25,Math.fround(2.2)],[.125,Math.fround(2.2)]]);
 assert.throws(()=>nativeColorSpaceFromSrgb([.5,0,1],{gammaCorrection:true}),/power boundary/);
 assert.deepEqual(nativeColorSpaceFromSrgb([.5,0,1,.25],{gammaCorrection:true,power}),[.25,0,1,.25]);
});

test('native enhanced color/range move overbright energy into range, with the 1000-radius bypass',()=>{
 const light={color:[4,2,1],radius:1,multiplier:2},policy={gammaCorrection:true,cutoffRangeMultiplier:2};
 assert.deepEqual(nativeLightAdjustedColor(light,policy),[1,.5,.25]);
 assert.equal(nativeLightAdjustedRange(light,policy),16);
 for(const radius of [1000,1001]){
  const longRange={...light,radius};
  assert.deepEqual(nativeLightAdjustedColor(longRange,policy),[4,2,1]);
  assert.equal(nativeLightAdjustedRange(longRange,policy),radius);
 }
 assert.deepEqual(nativeLightAdjustedColor(light,{gammaCorrection:false}),[4,2,1]);
 assert.equal(nativeLightAdjustedRange(light,{gammaCorrection:false}),2);
});

test('native unordered comparison branches are not replaced by Math.max or a blanket clamp',()=>{
 const policy={gammaCorrection:true,cutoffRangeMultiplier:2};
 const adjusted=nativeLightAdjustedColor({color:[4,NaN,1],radius:NaN},policy);
 assert.equal(adjusted[0],1);assert.ok(Number.isNaN(adjusted[1]));assert.equal(adjusted[2],.25);
 assert.ok(Number.isNaN(nativeLightAdjustedRange({color:[4,2,1],radius:NaN,multiplier:2},policy)));
});

test('point-light property preparation fades before conversion, encodes ambient-only range and keeps caller inputs',()=>{
 const light={color:[4,2,1],radius:1,multiplier:2,fade:.5,ambientOnly:0,position:[10,20,30]},original=structuredClone(light);
 const policy={gammaCorrection:true,cutoffRangeMultiplier:2,power:value=>value*value};
 const diffuse=nativePointLightUpload(light,policy);
 assert.deepEqual(diffuse.ambient,[0,0,0,1]);assert.deepEqual(diffuse.diffuse,[2,1,.5,1]);
 assert.deepEqual(diffuse.position,[10,20,30,1]);assert.equal(diffuse.quadraticAttenuation,4.5);
 assert.deepEqual(diffuse.enhancedColor,[.25,.0625,.015625,256]);
 const ambient=nativePointLightUpload({...light,ambientOnly:1},policy);
 assert.deepEqual(ambient.ambient,[2,1,.5,1]);assert.deepEqual(ambient.diffuse,[0,0,0,1]);
 assert.equal(ambient.enhancedColor[3],-256);assert.deepEqual(light,original);
});

test('legacy preparation does not invoke enhanced power conversion or impose an authored-radius cutoff',()=>{
 const light={color:[.5,.25,.125],radius:1,multiplier:3,fade:.5,ambientOnly:0,position:[0,0,0]};
 const result=nativePointLightUpload(light,{gammaCorrection:false,power:()=>assert.fail('legacy power call')});
 assert.deepEqual(result.diffuse,[.25,.125,.0625,1]);assert.equal(result.enhancedColor,null);assert.equal(result.quadraticAttenuation,4.5);
});

test('falloff uniform preparation preserves native parameter roles across the explicit math boundary',()=>{
 const options={cutoffRangeMultiplier:2,intensityAtRange:.25,maxIntensity:2};
 assert.deepEqual(nativeLightFalloffUniforms({...options,gammaCorrection:false}),{lightFalloffFactor:14,lightMaxIntensityInv:.5});
 const calls=[],power=(value,exponent)=>{calls.push([value,exponent]);return 1/(value*value);};
 assert.deepEqual(nativeLightFalloffUniforms({...options,gammaCorrection:true,power}),{lightFalloffFactor:63,lightMaxIntensityInv:.25});
 assert.deepEqual(calls,[[.25,Math.fround(-2.2)],[2,Math.fround(-2.2)]]);
});
