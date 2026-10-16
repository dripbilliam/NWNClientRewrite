import {encodeGffText} from './gff_text.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native effect identity ${n} is unavailable`);return v|0;};
const f=Math.fround,packed=e=>(integer(e.subtype,'subtype')|integer(e.durationType,'duration'))&65535;
const uint64=(value,name)=>{if(typeof value!=='string'||!/^[0-9a-f]{1,16}$/i.test(value))throw new Error(`Native effect identity ${name} is unavailable`);return BigInt('0x'+value);};
function textEqual(a,b){
 if(typeof a!=='string'||typeof b!=='string')throw new Error('Native effect identity string is unavailable');
 return encodeGffText(a).length===encodeGffText(b).length&&a.split('\0')[0]===b.split('\0')[0];
}
// Complete CGameEffect::operator==140423ac0. Duration/expiry/exposure/icon and
// link pointers are deliberately not compared. Representation covers valid
// decoded CExoString values, not corrupt pointer/length combinations.
export function equalEffectValues(a,b){
 if(uint64(a.id,'ID')!==uint64(b.id,'ID')||(integer(a.type,'type')&65535)!==(integer(b.type,'type')&65535)||packed(a)!==packed(b))return false;
 for(const key of ['creatorId','spellId','casterLevel','bypassImmunity'])if(integer(a[key],key)!==integer(b[key],key))return false;
 if(uint64(a.propertyId,'property ID')!==uint64(b.propertyId,'property ID')||!textEqual(a.customTag,b.customTag))return false;
 if(a.integers.length!==b.integers.length||a.integers.some((v,i)=>integer(v,'integer')!==integer(b.integers[i],'integer')))return false;
 if(a.floats.length!==4||b.floats.length!==4||a.floats.some((v,i)=>f(v)!==f(b.floats[i])))return false;
 if(a.objectIds.length!==4||b.objectIds.length!==4||a.objectIds.some((v,i)=>integer(v,'object ID')!==integer(b.objectIds[i],'object ID')))return false;
 const strings=e=>e.strings??Array(6).fill('');if(strings(a).length!==6||strings(b).length!==6||strings(a).some((v,i)=>!textEqual(v,strings(b)[i])))return false;
 return a.vectors.length===2&&b.vectors.length===2&&a.vectors.every((v,i)=>v.length===3&&b.vectors[i].length===3&&v.every((x,j)=>f(x)===f(b.vectors[i][j])));
}
