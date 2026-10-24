import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {saveObjectVisualTransforms,saveMaterialOverrides,saveVisualReplacements,saveMiscVisuals,saveObjectUUID,saveVisualCurve,visualCurveProgress} from '../src/object_visual_save.js';
import {gffRecord,writeGff} from '../src/gff_writer.js';
import {parseGff,getGffStructType} from '../src/gff.js';
import {encodeGffText} from '../src/gff_text.js';
import {visualCurveProgressSync} from '../src/visual_curve.js';
const observations=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-object-visual-save-observations.json',import.meta.url)));
const bits=n=>{const v=new DataView(new ArrayBuffer(4));v.setFloat32(0,n,true);return v.getUint32(0,true);};
function curve(v){
 const b=new Uint8Array(64),d=new DataView(b.buffer);
 for(const [offset,key]of [[0,'timer'],[12,'lerp'],[24,'flags'],[28,'repeats']])d.setInt32(offset,v[key],true);
 for(const [offset,key]of [[4,'to'],[8,'from'],[16,'duration'],[20,'progress']])d.setFloat32(offset,v[key],true);
 for(const [offset,key]of [[32,'start'],[48,'end']])d.setBigUint64(offset,BigInt(v[key]),true);
 for(const [offset,key]of [[40,'worldStart'],[56,'worldEnd']]){d.setUint32(offset,v[key].day,true);d.setUint32(offset+4,v[key].time,true);}
 return b;
}
function fixture(c){
 const calls=[];let tick=0,sub=0;const p={clock:()=>{calls.push(['clock']);return BigInt(c.ticks[Math.min(tick++,c.ticks.length-1)]);},worldTimer:()=>{calls.push(['worldTimer']);return c.world?{}:null;},worldTime:()=>{calls.push(['worldTime']);return c.now;},
  subtractWorld:(_world,a,b)=>{calls.push(['subtract',a.day,a.time,b.day,b.time]);const result=c.subtracts[Math.min(sub++,c.subtracts.length-1)];return result.status===0?result:{status:result.status};},
  worldSeconds:(_world,seconds)=>{calls.push(['worldSeconds',seconds]);return c.worldDelta;},addWorld:(_world,a,b)=>{calls.push(['add',a.day,a.time,b.day,b.time]);return c.added;},
 };
 const fixed=(bytes,offset,len,text)=>bytes.set(encodeGffText(text).subarray(0,len),offset);
 const material=c.materials.map(r=>{const b=new Uint8Array(108),v=new DataView(b.buffer);v.setInt32(0,r.type,true);fixed(b,4,16,r.material);fixed(b,21,64,r.param);v.setInt32(88,r.int,true);r.floats.forEach((x,i)=>v.setFloat32(92+i*4,x,true));return b;});
 const replacement=source=>source.map(([a,b])=>{const bytes=new Uint8Array(34);fixed(bytes,0,16,a);fixed(bytes,17,16,b);return bytes;});
 const map=c.transforms===null?null:new Map(c.transforms.map(t=>{const bytes=new Uint8Array(640);t.curves.forEach((v,i)=>bytes.set(curve(v),i*64));return[t.scope,bytes];}));
 const object={objectType:c.objectType,nativeUUID:{value:c.uuid},nativeVisualTransforms2b0:map,nativeVisualPools:{0x2b8:{records:material},0x2c8:{records:replacement(c.textures)},0x2d8:{records:replacement(c.animations)}},nativeMiscVisualFields:Object.fromEntries([[0x254,'r'],[0x258,'g'],[0x25c,'b'],[0x268,'distance'],[0x260,'cursor'],[0x26c,'mask'],[0x270,'bubble'],[0x278,'text']].map(([key,name])=>[key,c.misc[name]]))};
 return{p,calls,object,bytes:curve(c.curve)};
}
async function all(o,root,p){await saveObjectVisualTransforms(o,root,p);saveMaterialOverrides(o,root);saveVisualReplacements(o,root,'texture');saveVisualReplacements(o,root,'animation');saveMiscVisuals(o,root);saveObjectUUID(o,root);return root;}
test('visual/UUID save and curve owners match original typed output, call order and mutable clock/repeat state',async()=>{
 assert.equal(observations.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const {case:c,output,calls:expected,curve:expectedCurve,transformCurves,progressBits}of observations.cases){
  const {p,calls,object,bytes}=fixture(c),root=gffRecord({});
  if(c.mode==='all')await all(object,root,p);else if(c.mode==='curve')await saveVisualCurve(bytes,root,'Curve',p);else assert.equal(bits(await visualCurveProgress(bytes,p)),progressBits,c.name);
  assert.deepEqual(root,output,c.name);assert.deepEqual(calls,expected,c.name);assert.deepEqual([...bytes],expectedCurve,c.name);
  if(c.mode==='progress'){const sync=fixture(c);assert.equal(bits(visualCurveProgressSync(sync.bytes,sync.p)),progressBits,c.name+' synchronous');assert.deepEqual(sync.calls,expected,c.name+' synchronous call order');assert.deepEqual([...sync.bytes],expectedCurve,c.name+' synchronous mutation');}
  const actualCurves=[...(object.nativeVisualTransforms2b0??new Map())].sort((a,b)=>a[0]-b[0]).flatMap(([_scope,b])=>Array.from({length:10},(_,i)=>[...b.subarray(i*64,i*64+64)]));assert.deepEqual(actualCurves,transformCurves,c.name);
 }
});
test('zero transforms are omitted and extended native replacement labels round-trip',async()=>{
 for(const name of ['transform-empty','transform-zero']){const c=observations.cases.find(x=>x.case.name===name).case,{object,p}=fixture(c);assert.ok(!('VisTransformList'in(await all(object,gffRecord({}),p)).fields));}
 const c=observations.cases.find(x=>x.case.name==='replacement-case').case,{object,p}=fixture(c),root=parseGff(writeGff('UTI ',await all(object,gffRecord({}),p)),'UTI ').root;
 assert.equal(root.TextureReplace.TextureReplaceLi[0].OldTexture,'UpperCaseOld');assert.equal(getGffStructType(root.AnimationReplace),11);assert.equal(root.AnimationReplace.AnimationReplace[0].NewAnimation,'Replace');
});
