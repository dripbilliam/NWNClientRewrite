import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {NativeCharacterPreviewStore} from './native-character-preview-store.mjs';
const fixture=async()=>{const parent=await fs.mkdtemp(path.join(os.tmpdir(),'native-character-preview-test-'));const store=await new NativeCharacterPreviewStore(path.join(parent,'owned')).open();return{parent,store,close:async()=>{await store.close();await fs.rmdir(parent);}};};
test('native preview transport retains exact large BIC bytes without JSON UI projection',async()=>{
 const f=await fixture(),bytes=new Uint8Array(2*1024*1024).fill(7);bytes.set(Buffer.from('BIC V3.2'));
 try{const packet=await f.store.encode(bytes);assert.equal(packet.format,'native-bic-file-v1');assert.equal(packet.bytes,bytes.length);assert.equal(packet.sha256,createHash('sha256').update(bytes).digest('hex'));assert.deepEqual(new Uint8Array(await fs.readFile(packet.path)),bytes);assert.ok(JSON.stringify(packet).length<1024);assert.equal(packet.abilities,undefined);assert.equal(packet.classes,undefined);assert.ok(bytes.every((v,i)=>v===(i<8?Buffer.from('BIC V3.2')[i]:7)));}finally{await f.close();}
 assert.equal(f.store.snapshot().files,0);assert.equal(f.store.snapshot().closed,true);
});
test('identical preview sources reuse the owned file and reject external byte changes',async()=>{
 const f=await fixture(),bytes=new Uint8Array(64).fill(3);
 try{const first=await f.store.encode(bytes),second=await f.store.encode(bytes);assert.deepEqual(first,second);assert.equal(f.store.snapshot().written,1);assert.equal(f.store.snapshot().reused,1);await fs.writeFile(first.path,new Uint8Array(64).fill(4));await assert.rejects(f.store.encode(bytes),/changed/);}finally{await f.close();}
});
test('preview storage bounds retained sources and drains pending writes on close',async()=>{
 const f=await fixture();
 try{for(let i=0;i<12;i++)await f.store.encode(new Uint8Array(64).fill(i));assert.equal(f.store.snapshot().files,8);assert.equal((await fs.readdir(f.store.directory)).length,8);assert.equal(f.store.snapshot().removed,4);await f.store.encode(new Uint8Array(64).fill(20));}finally{await f.close();}
 assert.throws(()=>f.store.encode(new Uint8Array(64)),/unavailable/);
});
test('preview encoder rejects invalid inputs and never overwrites an unowned file',async()=>{
 const f=await fixture();
 try{assert.throws(()=>f.store.encode('BIC'),/unavailable/);assert.throws(()=>f.store.encode(new Uint8Array(55)),/unavailable/);const bytes=new Uint8Array(64).fill(9),digest=createHash('sha256').update(bytes).digest('hex'),file=path.join(f.store.directory,digest+'.bic');await fs.writeFile(file,'preserved');await assert.rejects(f.store.encode(bytes));assert.equal(await fs.readFile(file,'utf8'),'preserved');await fs.unlink(file);}finally{await f.close();}
});
