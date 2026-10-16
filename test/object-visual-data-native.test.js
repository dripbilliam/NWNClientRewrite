import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {loadObjectShaderParams,loadObjectReplacements,loadObjectMiscVisuals,objectVisualDataGffProviders} from '../src/object_visual_data.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffRecord as R,gffField as F} from '../src/gff_writer.js';
import {decodeGffText} from '../src/gff_text.js';
import {importedAnimationOverrides,nativeAnimationName} from '../src/native_animation.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-object-visual-data-observations.json',import.meta.url)));
const sizes={0x2b8:108,0x2c8:34,0x2d8:34};
const canonical=value=>JSON.parse(JSON.stringify(value));
test('four complete visual-data loaders match original retention, reset, fixed buffers, row cap, duplicate order and capacity growth',async()=>{
 for(const row of native.rows){
  const c=row.case,calls=[],o={nativeVisualPools:Object.fromEntries(Object.entries(sizes).map(([offset,size])=>[offset,{capacity:2,records:[Uint8Array.from({length:size},(_,i)=>(i+Number(offset))&255)]}])),nativeMiscVisualFields:{}};
  for(const offset of [0x260,0x254,0x258,0x25c,0x268,0x26c,0x270])o.nativeMiscVisualFields[offset]=[0x254,0x258,0x25c,0x268].includes(offset)?offset/8:offset;
  o.nativeMiscVisualFields[0x278]='old bubble';
  const p={
   struct:(_data,name)=>{calls.push(['struct',name]);return{status:c.structStatus??1,value:'root'};},
   list:(record,name)=>{calls.push(['list',record,name]);return{status:c.listStatus??1,value:'list'};},
   count:()=>{calls.push(['count']);return c.count??c.rows?.length??0;},
   element:(_list,index)=>{calls.push(['element',index]);return{status:c.rows[index].status??1,value:index};},
   read:(record,kind,name,fallback)=>{calls.push(['read',record,kind,name,fallback]);const entry=(record==='root'?c.fields:c.rows[record].fields)?.[name]??{status:0,value:fallback};return{...entry,value:kind==='string'&&entry.value.startsWith('\0')?'':entry.value};},
   clear:(_o,offset)=>calls.push(['clear',offset]),reserve:(_o,offset,capacity)=>calls.push(['reserve',offset,capacity]),
  };
  if(c.mode==='material')await loadObjectShaderParams(o,'data',p);
  else if(c.mode==='misc')await loadObjectMiscVisuals(o,'data',p);
  else await loadObjectReplacements(c.mode,o,'data',p);
  const label=JSON.stringify(c),pools=Object.fromEntries(Object.entries(o.nativeVisualPools).map(([key,pool])=>[key,{capacity:pool.capacity,records:pool.records.map(bytes=>Buffer.from(bytes).toString('hex'))}]));
  // Material's two alignment bytes86..87 are not initialized by the native
  // owner. They are unspecified stack padding, not serialized shader fields.
  const mask=pools=>Object.fromEntries(Object.entries(pools).map(([key,pool])=>[key,{...pool,records:pool.records.map(hex=>{const bytes=Buffer.from(hex,'hex');if(Number(key)===0x2b8){bytes[86]=0;bytes[87]=0;}return bytes.toString('hex');})}]));
  assert.deepEqual(canonical(calls),row.calls,label);assert.deepEqual(mask(pools),mask(row.pools),label);assert.deepEqual(o.nativeMiscVisualFields,row.fields,label);
  if(c.stackSeed)assert.equal(Buffer.from(row.pools[0x2b8].records[0],'hex')[86],c.stackSeed);
 }
 assert.equal(native.rows.length,167);
});

test('parsed GFF bridge preserves typed admission, missing-list retention and explicit empty-list clearing',async()=>{
 const data=fields=>parseGff(writeGff('UTP ',R(fields))).root,p=objectVisualDataGffProviders(),o={};
 const animationData=data({AnimationReplace:F(14,R({AnimationReplace:F(15,[
  R({OldAnimation:F(11,'Pause1'),NewAnimation:F(11,'replacement')}),
  R({OldAnimation:F(10,'wrongtype'),NewAnimation:F(11,'second')}),
  R({OldAnimation:F(11,'Pause1'),NewAnimation:F(11,'last')}),
 ])}))});
 await loadObjectReplacements('animation',o,animationData,p);
 const pool=o.nativeVisualPools[0x2d8];assert.equal(pool.capacity,16);assert.equal(pool.records.length,3);
 const names=pool.records.map(bytes=>[decodeGffText(bytes.subarray(0,17)).split('\0')[0],decodeGffText(bytes.subarray(17)).split('\0')[0]]);
 assert.deepEqual(names,[['Pause1','replacement'],['','second'],['Pause1','last']]);
 const overrides=importedAnimationOverrides(animationData);assert.deepEqual(overrides,names.map(([old,replacement])=>({old,replacement})));
 assert.equal(nativeAnimationName(0,{fieldDE:1,fieldDD:3,fieldE0:0},overrides),'replacement');
 await loadObjectReplacements('animation',o,data({AnimationReplace:F(10,'wrongtype')}),p);assert.equal(o.nativeVisualPools[0x2d8],pool);
 await loadObjectReplacements('animation',o,data({AnimationReplace:F(14,R({AnimationReplace:F(14,R({}))}))}),p);assert.equal(o.nativeVisualPools[0x2d8],pool);
 await loadObjectReplacements('animation',o,data({AnimationReplace:F(14,R({}))}),p);assert.equal(o.nativeVisualPools[0x2d8],pool);
 await loadObjectReplacements('animation',o,data({AnimationReplace:F(14,R({AnimationReplace:F(15,[])}))}),p);
 assert.deepEqual(o.nativeVisualPools[0x2d8],{capacity:0,records:[]});
 await loadObjectShaderParams(o,data({Material:F(14,R({ShaderParams:F(15,[
  R({Type:F(5,1),Int:F(5,42)}),R({Type:F(0,1),Int:F(4,42)}),R({Type:F(0,2),Float1:F(8,.1),Float2:F(5,99),Material:F(10,'mat\0tail'),Param:F(10,'p'.repeat(80))}),
 ])}))}),p);
 const records=o.nativeVisualPools[0x2b8].records;assert.equal(records.length,2);assert.equal(new DataView(records[0].buffer).getInt32(88,true),0);
 const float=new DataView(records[1].buffer);assert.equal(float.getFloat32(92,true),Math.fround(.1));assert.equal(float.getFloat32(96,true),0);
 assert.equal(decodeGffText(records[1].subarray(4,21)).split('\0')[0],'mat');assert.equal(decodeGffText(records[1].subarray(21,85)),'p'.repeat(64));assert.equal(records[1][85],0);
 await loadObjectMiscVisuals(o,data({MiscVisuals:F(14,R({MouseCursor:F(4,999),VisibleDistance:F(5,999),TextBubbleText:F(10,'bubble\0tail')}))}),p);
 assert.equal(o.nativeMiscVisualFields[0x260],-1);assert.equal(o.nativeMiscVisualFields[0x268],45);assert.equal(o.nativeMiscVisualFields[0x278],'bubble\0tail');
 const misc=o.nativeMiscVisualFields;await loadObjectMiscVisuals(o,data({MiscVisuals:F(10,'wrongtype')}),p);assert.equal(o.nativeMiscVisualFields,misc);
 await loadObjectMiscVisuals(o,data({MiscVisuals:F(14,R({}))}),p);assert.equal(o.nativeMiscVisualFields[0x278],'');
});
