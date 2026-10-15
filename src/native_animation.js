import {nativeAnimationNames,nativeAnimationRows,nativeAnimationContexts} from './native_animation_names.js';
import {scriptStringCase} from './script_string.js';

const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native client animation ${name} is unavailable`);return value|0;};
const resref=value=>{
  const text=String(value??'').split('\0')[0];
  if([...text].some(c=>c.charCodeAt(0)>127))throw new Error('Native animation override byte encoding is unsupported');
  return text.slice(0,16);
};

// CNWSObject::LoadAnimationOverrides1404969c0,34-byte records. Keep physical
// duplicate order and16-byte resrefs. The caller owns native object storage.
export function importedAnimationOverrides(root){
  const list=root?.AnimationReplace?.AnimationReplaceList??[];
  if(!Array.isArray(list))throw new Error('Native animation override list is unavailable');
  return list.map(r=>({old:resref(r.OldAnimation),replacement:resref(r.NewAnimation)}));
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
