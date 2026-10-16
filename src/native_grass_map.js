const hash=key=>{
 let h=0xcbf29ce484222325n;key>>>=0;
 for(let i=0;i<4;i++)h=BigInt.asUintN(64,(h^BigInt(key>>>(i*8)&255))*0x100000001b3n);
 return h;
};

// MSVC native grass unordered map:14035ac00/140369990/1403596b0.
// New bucket groups append; new keys in an existing bucket prepend its group.
// A rehash reinserts the prior list order with those same rules. Duplicate
// updates preserve their node identity/position. Bucket growth starts at8.
export class NativeGrassMap{
 constructor(){this.entries=[];this.bucketCount=8;}
 get size(){return this.entries.length;}
 bucket(key){return Number(hash(key)&BigInt(this.bucketCount-1));}
 place(entry){
  const bucket=this.bucket(entry.nativeMessageFields[0x10]),i=this.entries.findIndex(e=>this.bucket(e.nativeMessageFields[0x10])===bucket);
  if(i<0)this.entries.push(entry);else this.entries.splice(i,0,entry);
 }
 set(key,value){
  key>>>=0;value.nativeMessageFields[0x10]=key;const old=this.entries.find(e=>e.nativeMessageFields[0x10]===key);
  if(old){old.nativeName18=value.nativeName18;old.nativeMessageFields=value.nativeMessageFields;return old;}
  value.nativeMessageFields[0x10]=key;this.place(value);
  if(this.size>this.bucketCount){
   const entries=this.entries;this.entries=[];this.bucketCount*=this.bucketCount<512?8:2;
   for(const entry of entries)this.place(entry);
  }
  return value;
 }
}
