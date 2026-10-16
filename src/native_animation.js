import {nativeAnimationNames,nativeAnimationRows,nativeAnimationContexts} from './native_animation_names.js';
import {scriptStringCase} from './script_string.js';
import {getGffFieldTypes} from './gff.js';
import {readNativeGff,nativeGffLabel} from './native_gff_fields.js';
import {objectTemplateResRef} from './create_object.js';
import {decodeGffText} from './gff_text.js';

const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native client animation ${name} is unavailable`);return value|0;};
const resref=value=>objectTemplateResRef(String(value??''));

// CNWSObject::LoadAnimationOverrides1404969c0,34-byte records. Keep physical
// duplicate order and16-byte resrefs. The caller owns native object storage.
export function importedAnimationOverrides(root){
  if(getGffFieldTypes(root)){
    const section=readNativeGff(root,'AnimationReplace',14,null);if(section.status===0)return[];
    const result=readNativeGff(section.value,'AnimationReplaceList',15,null);if(result.status===0)return[];
    if(!Array.isArray(result.value))throw new Error('Native animation override list is unavailable');
    return result.value.map(row=>({old:resref(readNativeGff(row,'OldAnimation',11,'').value),replacement:resref(readNativeGff(row,'NewAnimation',11,'').value)}));
  }
  // Compatibility for semantic in-memory fixtures. Parsed resources always
  // use typed admission and the original16-byte query-label behavior above.
  const section=root?.AnimationReplace,list=section?.[nativeGffLabel('AnimationReplaceList')]??section?.AnimationReplaceList??[];
  if(!Array.isArray(list))throw new Error('Native animation override list is unavailable');
  return list.map(r=>({old:resref(r.OldAnimation),replacement:resref(r.NewAnimation)}));
}

// Once the actual data owner has accepted a replacement list, its retained
// pool is authoritative across missing-root reloads and explicit empty clears.
// Legacy imported actors keep the parsed-root bridge until that first load.
export function objectAnimationOverrides(object){
 if(object.nativeAnimationOverridesLoaded!==1)return importedAnimationOverrides(object.creatureData??object.authored);
 const pool=object.nativeVisualPools?.[0x2d8];if(!Array.isArray(pool?.records))throw new Error('Native object animation replacement pool is unavailable');
 return pool.records.map(bytes=>{
  if(!(bytes instanceof Uint8Array)||bytes.byteLength!==34)throw new Error('Native object animation replacement record is unavailable');
  return{old:decodeGffText(bytes.subarray(0,17)).split('\0')[0],replacement:decodeGffText(bytes.subarray(17,34)).split('\0')[0]};
 });
}

// Animation-base virtual+58,140961540. Context byte names are retained until
// their separate initialization owners establish their semantic values.
// Native unknown WORD IDs fall back to the body-specific pause; empty names
// inside the switch remain empty. They must not become invented idle clips.
export function nativeAnimationName(id,context,overrides=[]){
  id=integer(id,'ID')&65535;
  const body=(integer(context?.fieldDE,'context BYTEde')&255)===1?1:0;
  const style=integer(context?.fieldDD,'context BYTEdd')&255,side=integer(context?.fieldE0,'context BYTEe0')&255;
  const key=`${body}:${style}:${side}`,row=nativeAnimationContexts[key];
  if(row===undefined)throw new Error(`Native animation context ${key} has not been mapped`);
  if(integer(context.fieldEC??0,'movement override')!==0||integer(context.fieldE8??0,'special walk')!==0)
    throw new Error('Native special-walk/movement animation override is not connected');
  let name=id>425?body?'pause1':'cpause1':nativeAnimationNames[nativeAnimationRows[row][id]];
  // Native override140964530 uses first case-insensitive match, then copies
  // the replacement without recursively applying another override.
  if(!Array.isArray(overrides))throw new Error('Native animation override pool is unavailable');
  for(const record of overrides)if(scriptStringCase(resref(record.old))===scriptStringCase(name)){
    name=resref(record.replacement);break;
  }
  return scriptStringCase(name);
}
