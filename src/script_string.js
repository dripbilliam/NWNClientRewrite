import {encodeGffText} from './gff_text.js';
// CExoString::Right14016bfa0 slices stored bytes, with signed-negative counts
// producing an empty string. NCS/GFF currently use Windows-1252; every decoded
// character is one byte. Reject text outside that codec rather than counting
// UTF-16 code units as native bytes.
// Some Node builds decode the C1 range as Latin-1 despite the 1252 label;
// accept both its one-byte output and the browser's actual 1252 characters.
const extensions=new Set([...'€‚ƒ„…†‡ˆ‰Š‹ŒŽ‘’“”•–—˜™š›œžŸ']);
// CExoString::Left14016bcb0 uses a signed count and clamps it to the
// stored byte length, including embedded NUL bytes in that length.
export function scriptStringLeft(value,count){
  count|=0;if(count<0)return '';
  return [...scriptStringRight(value,0x7fffffff)].slice(0,count).join('');
}
// ExecuteCommandFindSubString1403136a0 ->CExoString::Find14016aea0.
// Bounds use stored length; strstr starts at offset and stops at its next NUL.
// The VM's ordinary empty string has a null CExoString buffer, hence -1.
export function scriptStringBytes(value){return Uint8Array.from(scriptStringRight(value,0x7fffffff),c=>c.codePointAt(0)<=255?c.codePointAt(0):encodeGffText(c)[0]);}
export function scriptFindSubString(value,part,start=0){
 const text=scriptStringBytes(value),needle=scriptStringBytes(part);start|=0;
 if(!text.length||!needle.length||start<0||start>text.length)return -1;
 const end=text.indexOf(0,start),stop=end<0?text.length:end,needleEnd=needle.indexOf(0),size=needleEnd<0?needle.length:needleEnd;
 for(let i=start;i+size<=stop;i++)if(needle.slice(0,size).every((b,j)=>text[i+j]===b))return i;
 return -1;
}
// ExecuteCommandStringConversions140547900 case232 -> CRT atoi140c81d54.
// The C-locale decimal parser saturates at signed32 limits; it does not
// accept a hexadecimal prefix, exponent, non-ASCII space or trailing junk.
export function scriptStringToInt(value){
  const text=scriptStringRight(value,0x7fffffff).split('\0')[0];
  const match=/^[\t\n\v\f\r ]*([+-]?)([0-9]+)/.exec(text);if(!match)return 0;
  const magnitude=BigInt(match[2]),negative=match[1]==='-';
  return negative?Number(- (magnitude>2147483648n?2147483648n:magnitude)):Number(magnitude>2147483647n?2147483647n:magnitude);
}
// ExecuteCommandStringConversions140547981 calls common_atof_l, then
// CVTSD2SS at140547989. Parse the C-locale numeric prefix and round double
// to float, including hexadecimal floats, signed zero and special values.
export function scriptStringToFloat(value){
  const text=scriptStringRight(value,0x7fffffff).split('\0')[0].replace(/^[\t\n\v\f\r ]*/,''),negative=text[0]==='-';
  if(/^[+-]?inf/i.test(text))return negative?-Infinity:Infinity;
  if(/^[+-]?nan/i.test(text))return NaN;
  const hex=/^[+-]?0x((?:[\da-f]+(?:\.[\da-f]*)?|\.[\da-f]+))(?:p([+-]?\d+))?/i.exec(text);
  if(hex){
    const [whole,fraction='']=hex[1].split('.'),digits=(whole+fraction).replace(/^0+/,'');
    if(!digits)return negative?-0:0;
    let mantissa=BigInt(`0x${digits}`),exponent=Number(hex[2]??0)-4*fraction.length;
    const length=mantissa.toString(2).length;
    if(exponent+length>1025)return negative?-Infinity:Infinity;
    if(exponent+length< -1074)return negative?-0:0;
    const shift=Math.max(0,length-53,-exponent-1074);
    if(shift){const n=BigInt(shift),base=mantissa>>n,remainder=mantissa-(base<<n),half=1n<<(n-1n);mantissa=base+BigInt(remainder>half||remainder===half&&(base&1n)!==0n);exponent+=shift;}
    const number=Number(mantissa)*2**exponent;return Math.fround(negative?-number:number);
  }
  const decimal=/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?/i.exec(text);
  return decimal?Math.fround(Number(decimal[0])):0;
}
export function scriptStringRight(value,count){
  count|=0;if(count<0)return '';
  const text=String(value),bytes=[...text];
  if(bytes.some(c=>c.codePointAt(0)>255&&!extensions.has(c)))throw new Error('Native script string byte encoding is unavailable for this text');
  return count>=bytes.length?text:bytes.slice(bytes.length-count).join('');
}
// CExoString::SubString14016c710 treats a negative count as the remainder,
// whereas a negative offset produces an empty result.
export function scriptSubString(value,start,count){
  start|=0;count|=0;if(start<0)return '';
  const text=scriptStringRight(value,0x7fffffff),bytes=[...text];
  if(start>=bytes.length)return '';
  const available=bytes.length-start;
  return bytes.slice(start,start+(count<0||count>available?available:count)).join('');
}
// LowerCase14016bd70 / UpperCase14016c8c0 pass signed bytes to CRT
// tolower140c7fe98 / toupper140c7fec4. The default C-locale branches
// convert only A..Z/a..z. Locale initialization for high bytes is not mapped.
export function scriptStringCase(value,upper=false){
  const text=scriptStringRight(value,0x7fffffff);
  if([...text].some(c=>c.codePointAt(0)>127))throw new Error('Native script string case conversion for locale-specific bytes is unavailable');
  return text.replace(upper?/[a-z]/g:/[A-Z]/g,c=>String.fromCharCode(c.charCodeAt(0)+(upper?-32:32)));
}
