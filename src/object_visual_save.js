import {gffField as f,gffRecord as record} from './gff_writer.js';
import {decodeGffText} from './gff_text.js';
import {nativeGffLabel} from './native_gff_fields.js';
import {objectTemplateResRef} from './create_object.js';
import {canCarryUUID} from './object_uuid.js';
import {zeroVisualTransforms} from './object_visual_transform.js';
import {visualCurveProgress} from './visual_curve.js';
export {visualCurveProgress} from './visual_curve.js';

const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native visual save ${n} is unavailable`);return v|0;};
const view=(bytes,length)=>{if(!(bytes instanceof Uint8Array)||bytes.length!==length)throw new Error('Native visual save record storage is unavailable');return new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);};
const fixed=(bytes,offset,length)=>{const chars=bytes.subarray(offset,offset+length),end=chars.indexOf(0);return decodeGffText(chars.subarray(0,end<0?chars.length:end));};
const put=(root,name,type,value)=>{root.fields[nativeGffLabel(name)]=f(type,value);};
const pool=(o,offset)=>{const values=o.nativeVisualPools?.[offset]?.records;if(!Array.isArray(values))throw new Error('Native visual save pool is unavailable');return values;};

// Complete LerpFloat::WriteGFF1402ea250..2ea35a. Endpoint fields are written
// BEFORE Progress, but repeat counters/duration/flags are read AFTER it.
export async function saveVisualCurve(bytes,root,name,p){
 const v=view(bytes,64),node=record({},0);put(root,name,14,node);
 put(node,'TimerType',5,v.getInt32(0,true));put(node,'ValueTo',8,v.getFloat32(4,true));put(node,'LerpType',5,v.getInt32(12,true));
 if(v.getInt32(12,true)!==0){
  put(node,'ValueFrom',8,v.getFloat32(8,true));put(node,'LerpProgress',8,await visualCurveProgress(bytes,p));
  put(node,'LerpDuration',8,v.getFloat32(16,true));put(node,'BehaviorFlags',5,v.getInt32(24,true));put(node,'RepeatsRemaining',5,v.getInt32(28,true));
 }
 return root;
}
// Complete CNWSObject::SaveVisualTransform14049a780..49a9b4. The verified
// shared zero-map predicate checks defined cells, ignoring clock caches/keys.
export async function saveObjectVisualTransforms(o,root,p){
 const map=o.nativeVisualTransforms2b0;if(map===null)return root;
 if(!(map instanceof Map))throw new Error('Native visual save transform map is unavailable');if(zeroVisualTransforms(map))return root;
 const entries=[];put(root,'VisTransformList',15,entries);
 for(const [scope,bytes]of [...map].sort((a,b)=>a[0]-b[0])){
  view(bytes,640);const node=record({},6);entries.push(node);put(node,'Scope',5,integer(scope,'transform scope'));
  for(const [name,index]of [['AnimationSpeed',9],['ScaleX',0],['ScaleY',1],['ScaleZ',2],['RotateX',3],['RotateY',4],['RotateZ',5],['TranslateX',6],['TranslateY',7],['TranslateZ',8]])await saveVisualCurve(bytes.subarray(index*64,index*64+64),node,name,p);
 }
 return root;
}

// CNWSObject SaveMaterialOverrides140499f20..49a227. The native cap is1024;
// unknown INT types still emit Type/Material/Param but no numeric payload.
export function saveMaterialOverrides(o,root){
 const source=pool(o,0x2b8);if(source.length===0)return root;
 const material=record({},7),entries=[];put(root,'Material',14,material);put(material,'ShaderParams',15,entries);
 for(let i=0;i<Math.min(1024,source.length);i++){
  const bytes=source[i],v=view(bytes,108),type=v.getInt32(0,true),node=record({},0);entries.push(node);put(node,'Type',0,type&255);
  if(type===1)put(node,'Int',5,v.getInt32(88,true));else if(type===2)for(let n=0;n<4;n++)put(node,`Float${n+1}`,8,v.getFloat32(92+n*4,true));
  put(node,'Material',10,fixed(bytes,4,17));put(node,'Param',10,fixed(bytes,21,65));
 }
 return root;
}
// Complete texture49a640..49a76e / animation499c10..499d3e owners.
export function saveVisualReplacements(o,root,kind){
 const spec={texture:[0x2c8,'TextureReplace',9,'TextureReplaceList','OldTexture','NewTexture'],animation:[0x2d8,'AnimationReplace',11,'AnimationReplaceList','OldAnimation','NewAnimation']}[kind];
 if(!spec)throw new Error('Native visual save replacement kind is unavailable');
 const [offset,name,type,label,oldName,newName]=spec,source=pool(o,offset);if(source.length===0)return root;
 const node=record({},type),entries=[];put(root,name,14,node);put(node,label,15,entries);
 for(const bytes of source){view(bytes,34);entries.push(record({[oldName]:f(11,objectTemplateResRef(fixed(bytes,0,17))),[newName]:f(11,objectTemplateResRef(fixed(bytes,17,17)))},0));}
 return root;
}
// SaveMiscVisuals14049a230..49a34a always emits the struct, including defaults.
export function saveMiscVisuals(o,root){
 const fields=o.nativeMiscVisualFields;if(!fields)throw new Error('Native visual save misc storage is unavailable');
 const node=record({},8);put(root,'MiscVisuals',14,node);
 for(const [name,offset,type]of [['MouseCursor',0x260,5],['HiliteColorR',0x254,8],['HiliteColorG',0x258,8],['HiliteColorB',0x25c,8],['VisibleDistance',0x268,8],['UiDiscoverMask',0x26c,5],['TextBubbleType',0x270,5],['TextBubbleText',0x278,10]]){
  const value=fields[offset];if(type===10){if(typeof value!=='string')throw new Error('Native visual save bubble string is unavailable');put(node,name,type,value);}
  else if(type===8){if(typeof value!=='number')throw new Error('Native visual save FLOAT is unavailable');put(node,name,type,Math.fround(value));}
  else put(node,name,type,integer(value,name));
 }
 return root;
}
// CNWSUUID::SaveToGff140505c70..505cbc: member eligibility uses parent BYTE;
// the stored string length, not its first NUL, controls field inclusion.
export function saveObjectUUID(o,root){
 if(canCarryUUID(integer(o.objectType,'object type')&255)===0)return root;
 const value=o.nativeUUID?.value;if(typeof value!=='string')throw new Error('Native UUID save string is unavailable');
 if(value.length!==0)put(root,'UUID',10,value);return root;
}
