import {encodeGffText} from './gff_text.js';
import {readNativeGff} from './native_gff_fields.js';
import {objectTemplateResRef} from './create_object.js';

// Base CNWSObject ctor14048b933..956/14048bc4d..cbe. These fields are
// separate from effect visuals and do not allocate canonical game objects.
export function initializeObjectVisualData(object){
 object.nativeVisualTransforms2b0??=null;
 const pools=object.nativeVisualPools??={};for(const offset of[0x2b8,0x2c8,0x2d8])pools[offset]??={records:[],capacity:0};
 const fields=object.nativeMiscVisualFields??={};
 for(const[offset,value]of[[0x254,-1],[0x258,-1],[0x25c,-1],[0x260,-1],[0x268,object.nativeProjectileRange268??45],[0x26c,15],[0x270,0],[0x278,'']])fields[offset]??=value;
 // This existing bridge name refers to the same native FLOAT268 cell read
 // by projectile code; importing VisibleDistance must update that cell too.
 Object.defineProperty(object,'nativeProjectileRange268',{enumerable:true,configurable:true,get(){return this.nativeMiscVisualFields[0x268];},set(value){this.nativeMiscVisualFields[0x268]=Math.fround(value);}});
}
// Base dtor14048c212..251: map deletion precedes UUID destruction. Pool
// releases2d8/2c8/2b8 and bubble string278 follow UUID, in objectTail.
export function releaseObjectVisualTransforms(object){object.nativeVisualTransforms2b0?.clear();object.nativeVisualTransforms2b0=null;}
export function releaseObjectVisualPools(object){
 for(const offset of[0x2d8,0x2c8,0x2b8]){const pool=object.nativeVisualPools?.[offset];if(pool){pool.records=[];pool.capacity=0;}}
 if(object.nativeMiscVisualFields)object.nativeMiscVisualFields[0x278]='';
}
// Creature ctor14037a49f..4cb constructs both maps; dtor14037b83c..892
// releases left/ac0 before right/ab0. They are owned copies, not item IDs.
export function initializeCreatureVisualData(object){const maps=object.nativeHandVisualMaps??={};for(const offset of[0xab0,0xac0])maps[offset]??=new Map();}
export function releaseCreatureVisualData(object){for(const offset of[0xac0,0xab0])object.nativeHandVisualMaps?.[offset]?.clear();}

// strncpy-style fixed byte fields. The zero-filled record also owns the
// separate terminator byte after each native16/64-byte character array.
const fixed=(record,offset,length,value)=>{
 const bytes=encodeGffText(value),nul=bytes.indexOf(0),end=Math.min(length,nul<0?bytes.length:nul);
 record.set(bytes.subarray(0,end),offset);
};
async function append(object,offset,record,p){
 const pool=object.nativeVisualPools[offset];
 if(pool.records.length===pool.capacity){
  const capacity=pool.capacity===0?16:pool.capacity*2;
  await p.reserve(object,offset,capacity);pool.capacity=capacity;
 }
 pool.records.push(record);
}
async function clear(object,offset,p){
 await p.clear(object,offset);(object.nativeVisualPools??={})[offset]={records:[],capacity:0};
}

// LoadMaterial140496ea0..1404972a9. Absent/wrong-type structures or lists
// retain the old pool. A successfully read empty list clears it. At most1024
// physical rows are visited; unknown Type bytes and failed rows are skipped.
export async function loadObjectShaderParams(object,data,p){
 const root=await p.struct(data,'Material');if((root.status|0)===0)return;
 const list=await p.list(root.value,'ShaderParams');if((list.status|0)===0)return;
 await clear(object,0x2b8,p);
 const count=Math.min(1024,(await p.count(list.value))|0);
 for(let i=0;i<count;i++){
  const row=await p.element(list.value,i);if((row.status|0)===0)continue;
  const type=(await p.read(row.value,'byte','Type',0)).value&255;
  if(type!==1&&type!==2)continue;
  const record=new Uint8Array(108),view=new DataView(record.buffer);view.setInt32(0,type,true);
  if(type===1)view.setInt32(88,(await p.read(row.value,'int','Int',0)).value,true);
  else for(let n=0;n<4;n++)view.setFloat32(92+n*4,(await p.read(row.value,'float',`Float${n+1}`,0)).value,true);
  fixed(record,4,16,(await p.read(row.value,'string','Material','')).value);
  fixed(record,21,64,(await p.read(row.value,'string','Param','')).value);
  await append(object,0x2b8,record,p);
 }
}

const replacements={
 texture:{root:'TextureReplace',list:'TextureReplaceList',old:'OldTexture',replacement:'NewTexture',offset:0x2c8},
 animation:{root:'AnimationReplace',list:'AnimationReplaceList',old:'OldAnimation',replacement:'NewAnimation',offset:0x2d8},
};
// Complete LoadTextureReplace140497990..140497b9f and
// LoadAnimationOverrides1404969c0..140496bcf. Physical duplicate order and
// case are retained; each record consists of two17-byte terminated fields.
export async function loadObjectReplacements(kind,object,data,p){
 const spec=replacements[kind];if(!spec)throw new Error(`Native ${kind} replacement data loader is unavailable`);
 const root=await p.struct(data,spec.root);if((root.status|0)===0)return;
 const list=await p.list(root.value,spec.list);if((list.status|0)===0)return;
 await clear(object,spec.offset,p);
 for(let i=0,count=(await p.count(list.value))|0;i<count;i++){
  const row=await p.element(list.value,i);if((row.status|0)===0)continue;
  const record=new Uint8Array(34);
  fixed(record,0,16,(await p.read(row.value,'resref',spec.old,'')).value);
  fixed(record,17,16,(await p.read(row.value,'resref',spec.replacement,'')).value);
  await append(object,spec.offset,record,p);
 }
}

// Complete LoadMiscVisuals1404972b0..1404974ac. Root failure retains all
// existing values. Within a valid struct even absent fields use these defaults.
export async function loadObjectMiscVisuals(object,data,p){
 const root=await p.struct(data,'MiscVisuals');if((root.status|0)===0)return;
 const fields=object.nativeMiscVisualFields??={};
 for(const[kind,name,offset,fallback]of[
  ['int','MouseCursor',0x260,-1],['float','HiliteColorR',0x254,-1],['float','HiliteColorG',0x258,-1],['float','HiliteColorB',0x25c,-1],
  ['float','VisibleDistance',0x268,45],['int','UiDiscoverMask',0x26c,15],['int','TextBubbleType',0x270,0],['string','TextBubbleText',0x278,''],
 ]){const value=(await p.read(root.value,kind,name,fallback)).value;fields[offset]=kind==='float'?Math.fround(value):kind==='int'?value|0:value;}
}

// Concrete parsed-GFF boundaries for the owners above. JS owns storage/free;
// native logical count/capacity and record widths are maintained by the owners.
// Does not model native heap addresses, OOM, or add renderer/transport behavior.
export function objectVisualDataGffProviders(){return{
 struct:(data,name)=>readNativeGff(data,name,14,null),
 list:(data,name)=>readNativeGff(data,name,15,null),
 count:list=>{if(!Array.isArray(list))throw new Error('Native visual GFF list is unavailable');return list.length;},
 element:(list,index)=>{if(!Array.isArray(list)||!list[index]||typeof list[index]!=='object')throw new Error('Native visual GFF list element is unavailable');return{status:1,value:list[index]};},
 read:(data,kind,name,fallback)=>{
  const type={byte:0,int:5,float:8,string:10,resref:11}[kind];if(type===undefined)throw new Error(`Native visual GFF ${kind} reader is unavailable`);
  const result=readNativeGff(data,name,type,fallback);if(kind==='resref')result.value=objectTemplateResRef(result.value);return result;
 },
 clear:()=>{},reserve:()=>{},
};}
