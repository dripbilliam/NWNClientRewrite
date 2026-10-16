import {nativeItemTag} from './item_stack_compare.js';

// CExoString::AsTAG14016ac40 and SetTag14045df80. The original sign-extends
// each byte before CRT classification. Its default static C-locale table
// admits ASCII alphanumerics; the owner also admits '_' and keeps at most63
// accepted bytes. Iteration uses the descriptor length, including embedded NUL.
// Runtime changes to the original process CRT locale are not modeled.
export function nativeObjectTag(value){
 if(value===null)return '';
 let result='';
 for(const byte of nativeItemTag(value).bytes){
  if(byte===95||byte>=48&&byte<=57||byte>=65&&byte<=90||byte>=97&&byte<=122){
   result+=String.fromCharCode(byte);if(result.length===63)break;
  }
 }
 return result;
}
