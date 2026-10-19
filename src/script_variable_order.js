import {nativeItemTag} from './item_stack_compare.js';

const rotate=(v,n)=>(v<<n|v>>>(32-n))>>>0;
// Original byte hash14016ca80..16cd24 (seed0), used by CExoString::GetHash
// 14016b780. The latter XORs the empty-string hash after hashing stored bytes.
export function nativeVariableByteHash(bytes){
 if(!(bytes instanceof Uint8Array))throw new Error('Native variable hash bytes are unavailable');
 const p1=0x9e3779b1,p2=0x85ebca77,p3=0xc2b2ae3d,p4=0x27d4eb2f,p5=0x165667b1,v=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
 const round=(a,b)=>Math.imul(rotate((a+Math.imul(b,p2))>>>0,13),p1)>>>0;let at=0,hash;
 if(bytes.length>=16){let a=(p1+p2)>>>0,b=p2,c=0,d=(-p1)>>>0;do{a=round(a,v.getUint32(at,true));b=round(b,v.getUint32(at+4,true));c=round(c,v.getUint32(at+8,true));d=round(d,v.getUint32(at+12,true));at+=16;}while(at<=bytes.length-16);hash=(rotate(a,1)+rotate(b,7)+rotate(c,12)+rotate(d,18))>>>0;}
 else hash=p5;
 hash=(hash+bytes.length)>>>0;
 while(at<=bytes.length-4){hash=Math.imul(rotate((hash+Math.imul(v.getUint32(at,true),p3))>>>0,17),p4)>>>0;at+=4;}
 while(at<bytes.length){hash=Math.imul(rotate((hash+Math.imul(bytes[at++],p5))>>>0,11),p1)>>>0;}
 hash=Math.imul(hash^(hash>>>15),p2)>>>0;hash=Math.imul(hash^(hash>>>13),p3)>>>0;return(hash^(hash>>>16))>>>0;
}
const emptyHash=nativeVariableByteHash(new Uint8Array());
export const nativeVariableNameHash=name=>(nativeVariableByteHash(Uint8Array.from(nativeItemTag(name).bytes))^emptyHash)>>>0;

// Native hash _Insert14048b0d0 and ctor48b760: eight buckets, load1, grow8x
// below512 buckets then2x. Nodes form contiguous bucket groups in list order.
// This owns order only; ScriptVariableTable retains the actual typed records.
export class NativeVariableOrder{
 constructor(){this.bucketCount=8;this.names=[];this.hashes=new Map();}
 hash(name){return this.hashes.get(name)??nativeVariableNameHash(name);}
 bucket(name){return this.hash(name)&(this.bucketCount-1);}
 find(name){
  const bytes=nativeItemTag(name).bytes,bucket=this.bucket(name);
  for(const key of this.names){
   if(this.bucket(key)!==bucket)continue;const other=nativeItemTag(key).bytes;if(other.length!==bytes.length)continue;
   let i=0;while(i<bytes.length&&bytes[i]!==0&&bytes[i]===other[i])i++;
   if(i===bytes.length||bytes[i]===0&&other[i]===0)return key;
  }
  return undefined;
 }
 place(name){
  const old=this.names.indexOf(name);if(old>=0)this.names.splice(old,1);
  const bucket=this.bucket(name),first=this.names.findIndex(key=>this.bucket(key)===bucket);
  if(first<0)this.names.push(name);else this.names.splice(first,0,name);
 }
 insert(name){
  const existing=this.find(name);if(existing!==undefined)return existing;
  this.hashes.set(name,this.hash(name));
  this.place(name);
  if(this.names.length>this.bucketCount){const old=[...this.names];this.bucketCount*=this.bucketCount<512?8:2;this.names=[];for(const key of old)this.place(key);}
  return name;
 }
 remove(name){const key=this.find(name);if(key===undefined)return;this.names.splice(this.names.indexOf(key),1);this.hashes.delete(key);}
}
