import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {serverObjectIdForClient,readClientObjectId,readSafeProjectileHeader,localSafeProjectileFields,decodeLocalSafeProjectile} from '../src/client_projectile_message.js';
import {ModuleSession} from '../src/module_session.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-projectile-message-observations.json',import.meta.url)));

test('projectile typed-field projection matches original sender for spell/override/weapon layouts and selected client build',()=>{
 for(const row of native.rows.filter(r=>r.case.mode==='send')){
  const c=row.case,appearance=row.fields.find(r=>r.type==='byte').value,data={sourceId:99,targetId:100,from:[1.25,-2,3.5],to:[4,5,6],duration:250,appearance,flags:c.flags,baseItem:49,result:3,deflection:5};
  assert.deepEqual(localSafeProjectileFields(data),row.fields,JSON.stringify(c));
  assert.equal(appearance,c.appearance>7&&!c.build?0:c.appearance);assert.deepEqual(row.calls[0],c.appearance>7?['build',8193,36,4]:['create',41,0xffffffff,1]);
  assert.equal(row.result,c.payload?c.send>>>0:0);assert.equal(row.calls.some(r=>r[0]==='send'),Boolean(c.payload));
 }
});

test('projectile header matches original read order, external IDs, appearance branches and all three overflow exits',()=>{
 for(const row of native.rows.filter(r=>r.case.mode==='header')){
  const c=row.case,calls=[],bytes=new Uint8Array(8),view=new DataView(bytes.buffer);view.setUint32(0,c.source,true);view.setUint32(4,c.target,true);const state={bytes,cursor:0,available:8};let guard=0,fi=0,di=0,bi=0;
  const values=[c.appearance,...(c.appearance===6?[]:c.appearance===7?[5]:[5,49,3])];
  const result=readSafeProjectileHeader({overflow:()=>{calls.push(['overflow']);return++guard===c.fail?1:0;},objectId:()=>readClientObjectId(state),
   float:(scale,bits)=>{calls.push(['float',scale,bits]);return[1.25,-2,3.5,4,5,6][fi++];},dword:bits=>{calls.push(['dword',bits]);return di++===0?250:c.flags;},byte:(bits,align)=>{calls.push(['byte',bits,align]);return values[bi++];}});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));const expected=row.header?{...row.header,from:row.header.from_}:null;if(expected)delete expected.from_;
  assert.deepEqual(result,expected,JSON.stringify(c));assert.equal(state.cursor,row.readCursor,JSON.stringify(c));
 }
});

test('original object-ID writer/reader preserve external classification, invalid ID, short-read advance and DWORD wrap',()=>{
 for(const row of native.rows.filter(r=>r.case.mode==='encode'))assert.equal(serverObjectIdForClient(row.case.source),row.encoded,JSON.stringify(row.case));
 for(const row of native.rows.filter(r=>r.case.mode==='objectRead')){
  const bytes=new Uint8Array(16),view=new DataView(bytes.buffer);[0x80000063,0x80000064,0x12345678,0x87654321].forEach((v,i)=>view.setUint32(i*4,v,true));const state={bytes,cursor:row.case.cursor,available:row.case.available};
  assert.equal(readClientObjectId(state),row.result,JSON.stringify(row.case));assert.equal(state.cursor,row.readCursor,JSON.stringify(row.case));
 }
 assert.equal(native.rows.length,774);assert.throws(()=>readClientObjectId({bytes:new Uint8Array(),cursor:0,available:4}),/backing bytes/);
});

test('local native projectile decoding keeps client and authoritative IDs separate and diagnoses malformed fields',()=>{
 const s=new ModuleSession(null),source=s.register('creature','source',{}),target=s.register('creature','target',{}),cursor=s.registry.nextObjectId[0],data={sourceId:source.id,targetId:target.id,from:[1,2,3],to:[4,5,6],duration:250,appearance:6,flags:37,baseItem:255,result:0,deflection:0};
 const decoded=decodeLocalSafeProjectile(data);assert.equal(decoded.sourceId,serverObjectIdForClient(source.id));assert.equal(decoded.targetId,serverObjectIdForClient(target.id));assert.equal(decoded.spellId,37);assert.equal(decoded.path,null);assert.equal(decoded.baseItem,255);assert.equal(decoded.result,0);
 assert.equal(s.registry.get(source.id),source);assert.equal(s.registry.get(target.id),target);assert.equal(s.registry.nextObjectId[0],cursor);
 assert.throws(()=>decodeLocalSafeProjectile({...data,flags:undefined}),/spell flags/);assert.throws(()=>decodeLocalSafeProjectile({...data,from:[1,2]}),/from point/);assert.throws(()=>decodeLocalSafeProjectile({...data,sourceId:-1}),/object ID/);
});
