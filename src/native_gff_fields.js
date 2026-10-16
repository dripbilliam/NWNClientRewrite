import {getGffFieldTypes} from './gff.js';
import {encodeGffText,decodeGffText} from './gff_text.js';
// CExoString explicit-length assignment14003d8c0 still clears a string whose
// first byte is NUL. Embedded NUL after a nonzero first byte retains its length.
export const nativeAssignedString=value=>value.startsWith('\0')?'':value;
// GetFieldByLabel14019fcc0 copies the query through strncpy(...,16),
// then compares four DWORDs with the serialized16-byte label. Native code
// contains longer literals (e.g. AnimationReplaceList) than a GFF label.
export function nativeGffLabel(name){const bytes=encodeGffText(name),nul=bytes.indexOf(0);return decodeGffText(bytes.subarray(0,Math.min(16,nul<0?bytes.length:nul)));}

// Typed field admission used by CResGFF readers. Parsed GFF has already
// checked payload bounds; runtime/synthetic records must not guess its widths.
// Supported original readers: DWORD1510, INT1770, FLOAT1650, string1130,
// struct04e0 and list02c0 (all addresses relative to1401a0000).
export function readNativeGff(data,name,type,fallback){
 name=nativeGffLabel(name);
 if(!data||!Object.hasOwn(data,name))return{status:0,value:fallback};
 const types=getGffFieldTypes(data);if(!types)throw new Error(`Native GFF type metadata for ${name} is unavailable`);
 if(types[name]!==type)return{status:0,value:fallback};
 const value=data[name];
 return{status:1,value:type===4?value>>>0:type===5?value|0:type===8?Math.fround(value):type===10?nativeAssignedString(value):value};
}
