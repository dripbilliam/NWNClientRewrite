// Local layout convenience, separate from campaign saves. Payloads use native
// QBList fields; canonical runtime IDs are reconstructed on each import.
export class QuickbarLayouts {
  async open(){return this.db??=await new Promise((resolve,reject)=>{const r=indexedDB.open('nwn-quickbar-layouts',1);r.onupgradeneeded=()=>r.result.createObjectStore('characters');r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});}
  async get(key){const db=await this.open();return new Promise((resolve,reject)=>{const r=db.transaction('characters').objectStore('characters').get(key);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});}
  async put(key,list){const db=await this.open();return new Promise((resolve,reject)=>{const tx=db.transaction('characters','readwrite');tx.objectStore('characters').put(list,key);tx.oncomplete=resolve;tx.onerror=tx.onabort=()=>reject(tx.error);});}
}
