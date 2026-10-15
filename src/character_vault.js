import { parseCharacter } from './character.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';

export function describeCharacter(bytes,name,source='Imported') {
  const root=parseCharacter(bytes),local=s=>typeof s==='string'?s:s?.entries?.[0]?.text??'';
  return {bytes,name,source,displayName:[local(root.FirstName),local(root.LastName)].filter(Boolean).join(' ')||name,
    raceId:root.Race,gender:root.Gender,portrait:root.Portrait,classes:root.ClassList.map(c=>({id:c.Class,level:c.ClassLevel})),level:root.ClassList.reduce((n,c)=>n+c.ClassLevel,0)};
}

export class CharacterVault {
  constructor(){this.entries=new Map();this.database=null;}
  async open(){
    if(!this.database)this.database=await new Promise((resolve,reject)=>{
      const request=indexedDB.open('nwn-local-character-vault',1);
      request.onupgradeneeded=()=>request.result.createObjectStore('characters',{keyPath:'id'});
      request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error);
    });
    const saved=await new Promise((resolve,reject)=>{const request=this.database.transaction('characters').objectStore('characters').getAll();request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error);});
    for(const entry of saved)try{this.entries.set(entry.id,{...describeCharacter(entry.bytes,entry.name,'Local vault'),id:entry.id});}catch(error){runtimeDiagnostics.error(error,'character.vault-record-failed',{name:entry.name,id:entry.id});}
  }
  async add(bytes,name,{persist=false,source='Imported'}={}){
    const entry=describeCharacter(bytes,name,source),input=bytes instanceof ArrayBuffer?bytes:new Uint8Array(bytes.buffer,bytes.byteOffset,bytes.byteLength);
    const digest=await crypto.subtle.digest('SHA-256',input),id=[...new Uint8Array(digest)].map(n=>n.toString(16).padStart(2,'0')).join('');
    entry.id=id;
    if(persist){
      if(!this.database)await this.open();
      await new Promise((resolve,reject)=>{const tx=this.database.transaction('characters','readwrite');tx.objectStore('characters').put({id,name,bytes:input});tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error??new Error('Local character save was aborted'));});
    }
    this.entries.set(id,entry);return entry;
  }
}
