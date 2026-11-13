// Client-known disclosure runs, not permanent server object identities.
// Canonical retained proxies/server fields remain owned by NetworkWorld.
export class EntityDisclosureLifetimes {
 constructor({maximumSerial=Number.MAX_SAFE_INTEGER}={}){
  if(!Number.isSafeInteger(maximumSerial)||maximumSerial<1)throw new TypeError('Invalid disclosure counter limit');
  this.maximumSerial=maximumSerial;this.serial=0;this.identities=new WeakMap();this.diagnostics={};
 }
 note(code){this.diagnostics[code]=Math.min(65535,(this.diagnostics[code]??0)+1);}
 reset(){this.identities=new WeakMap();this.note('resets');}
 token(object){
  if(!object||typeof object!=='object'){this.note('invalidSource');return null;}
  if(object.replicationRemoved)return null;
  if(this.identities.has(object))return this.identities.get(object);
  if(this.serial>=this.maximumSerial){this.note('exhausted');return null;}
  const token=++this.serial;this.identities.set(object,token);return token;
 }
 transportRow(object,row){return {...row,clientKnownLifetime:this.token(object)};}
 observeAccepted(records,registry){
  // Invoke only after the canonical transaction succeeded. A repeated A alone
  // is not retirement. Every D already makes the canonical proxy unavailable
  // to this read model, irrespective of its original native deletion flag.
  if(!Array.isArray(records)||!registry||typeof registry.get!=='function'){this.note('invalidBoundary');return;}
  for(const record of records){
   if(record?.action!=='delete')continue;
   const object=registry.get(record.id);
   if(object&&typeof object==='object'&&this.identities.delete(object))this.note('retired');
  }
 }
 snapshot(){return {serial:this.serial,maximumSerial:this.maximumSerial,diagnostics:{...this.diagnostics}};}
}
