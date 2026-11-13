import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeMessageReader,NativeMessageWriter} from '../src/native_message.js';
import {readGameEnvelope} from '../src/network_game_messages.js';
import {readNetworkClientPause} from '../src/network_client_pause.js';
import {OBJECT_INVALID,EXTERNAL_OBJECT} from '../src/game_object_array.js';

// Actual scalar/stream writers, in original4dd0c0 order. No transport/network
// action: the envelope is authored and these are not captured server packets.
function packet(mask,value,ids=[],{declared=ids.length,clientIds=false,extraBits=0,extraBytes=[]}={}){
 const w=new NativeMessageWriter(1);w.create(2+ids.length*4+extraBytes.length,0xffffffff,1);
 w.writeByte(mask,2,1);w.writeBool(value);w.writeWord(declared,16);
 for(const id of ids)w[clientIds?'writeObjectIdClient':'writeObjectIdServer'](id);
 if(extraBits)w.writeUnsigned(0n,extraBits);
 if(extraBytes.length)w.rawBytes(Uint8Array.from(extraBytes));
 w.setPrefix(Uint8Array.of(80,3,9));return Uint8Array.from(w.getWriteMessage().data);
}
function decode(bytes,{formatMode=1}={}){
 const {major,minor,body}=readGameEnvelope(bytes);
 if(major!==3||minor!==9)throw Error('Not a module3/9 fixture');
 const errors=[],r=new NativeMessageReader(formatMode,{diagnose:error=>errors.push(error)});
 if(!r.setReadMessage(body,body.length,0xffffffff,1))throw Error('Invalid pause streams');
 const result=readNetworkClientPause(r);
 if(errors.length||r.messageReadOverflow()||r.messageReadUnderflow())throw Error('Invalid pause diagnostics');
 return{...result,major,minor};
}
const external=id=>id===OBJECT_INVALID?id:(id|EXTERNAL_OBJECT)>>>0;

test('all two-bit masks and wire values round-trip actual native scalar/OBJECTID writers',()=>{
 const ids=[0,42,0x80000042,OBJECT_INVALID,0xffffffff,42];
 for(let mask=0;mask<4;mask++)for(const value of [0,1]){
  const bytes=packet(mask,value,ids),before=Uint8Array.from(bytes),result=decode(bytes);
  assert.deepEqual(result,{kind:'module-pause-state',major:3,minor:9,mask,value,exclusionIds:ids.map(external)});
  assert.deepEqual(bytes,before,'Reading never mutates packet storage');
 }
});

test('sender BYTE/BOOL narrow independently, including noncanonical BOOL integers',()=>{
 for(const mask of [-1,0,1,2,3,4,255,256])for(const value of [-2147483648,-3,-2,-1,0,1,2,3,127,128,255,256,2147483647]){
  const result=decode(packet(mask,value));
  assert.equal(result.mask,mask&3);assert.equal(result.value,value&1);
  assert.deepEqual(result.exclusionIds,[]);
 }
 assert.equal(decode(packet(2,2)).value,0,'Native BOOL does not coerce every nonzero sender integer to true');
});

test('client receiver preserves duplicate/order/sentinel and every raw DWORD namespace bit',()=>{
 const ids=[0x80000042,0x80000042,0xffffffff,OBJECT_INVALID,0,0x7fffffff,0x80000000,0x80000042];
 const result=decode(packet(3,1,ids,{clientIds:true}));
 assert.deepEqual(result.exclusionIds,ids);
 assert.equal(result.exclusionIds.length,8,'No deduplication belongs in the protocol reader');
 const first=decode(packet(1,1,ids,{clientIds:true})),second=decode(packet(1,1,ids,{clientIds:true}));
 first.exclusionIds[0]=1;assert.equal(second.exclusionIds[0],0x80000042,'Returned arrays are independently owned');
});

test('every physical truncation rejects before a detached DTO can be published',()=>{
 for(let mask=0;mask<4;mask++)for(const value of [0,1])for(const ids of [[],[7],[7,7,OBJECT_INVALID,0xffffffff]]){
  const bytes=packet(mask,value,ids);
  for(let length=0;length<bytes.length;length++)assert.throws(()=>decode(bytes.subarray(0,length)),undefined,'mask'+mask+'/value'+value+'/length'+length);
 }
});

test('declared count cannot exceed available IDs; exact decoder rejects undeclared trailing data',()=>{
 for(const [declared,ids]of [[1,[]],[2,[5]],[65535,[]]])assert.throws(()=>decode(packet(1,1,ids,{declared})),/exclusion count/);
 // The native receiver7a5680 only checks overflow. These underflow rejections
 // are explicitly the strict remote admission rule, not original trailing-byte
 // behavior or evidence that the native receiver itself rejects these packets.
 for(const [declared,ids]of [[0,[5]],[1,[5,6]]])assert.throws(()=>decode(packet(2,0,ids,{declared})),/module-pause fields/);
 assert.throws(()=>decode(packet(1,1,[],{extraBytes:[0]})),/module-pause fields/);
 assert.throws(()=>decode(packet(1,1,[],{extraBits:1})),/module-pause fields/);
 // WORD wraps but the sender writes every entry. Represent the complete
 // original sender edge instead of silently discarding entries to match count.
 const wrapped=Array(65536).fill(7);
 assert.throws(()=>decode(packet(1,1,wrapped)),/module-pause fields/);
});

test('complete WORD count is admitted without an invented smaller list limit',()=>{
 const ids=Array.from({length:65535},(_,i)=>(0x80000000+i)>>>0);
 const result=decode(packet(2,1,ids));
 assert.equal(result.exclusionIds.length,65535);assert.equal(result.exclusionIds[0],0x80000000);assert.equal(result.exclusionIds.at(-1),0x8000fffe);
 assert.deepEqual(result.exclusionIds,ids);
});

test('bad envelope/boundaries reject; no mask/flag/list state is changed by an invalid decode',()=>{
 const good=packet(2,1,[4,4]),original=Uint8Array.from(good);
 for(const envelope of [[112,3,9],[80,3,8],[80,4,9]]){
  const bytes=Uint8Array.from(good);bytes.set(envelope);assert.throws(()=>decode(bytes));
 }
 for(const boundary of [0,3,4,0xffffffff]){
  const bytes=Uint8Array.from(good);new DataView(bytes.buffer).setUint32(3,boundary,true);assert.throws(()=>decode(bytes));
 }
 let stored={mask:0,value:0,exclusionIds:[0x80000001]};
 const initial=structuredClone(stored),publish=bytes=>{const next=decode(bytes);stored=next;};
 for(let length=0;length<good.length;length++){
  assert.throws(()=>publish(good.subarray(0,length)));assert.deepEqual(stored,initial);
 }
 publish(good);assert.deepEqual(stored.exclusionIds,[0x80000004,0x80000004]);assert.deepEqual(good,original);
 // This checks an authored single-commit consumer, not NetworkWorld/Host
 // transaction integration. Those owners remain Root's separate acceptance.
});

test('retained original receiver oracle agrees on scalar order and canonical wire DTOs',()=>{
 const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-pause-observations.json',import.meta.url)));
 assert.equal(capture.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 let compared=0,overflowCases=0,nonWireScalarCases=0;
 for(const row of capture.rows){
  const c=row.case;if(c.mode!=='receive')continue;
  const scalarCalls=row.calls.filter(call=>['byte','bool','word','objectId','overflow'].includes(call[0]));
  assert.deepEqual(scalarCalls,[['byte',2,1],['bool'],['word',16],...c.incoming.map(()=>['objectId']),['overflow']]);
  if(c.overflow){assert.equal(row.result,0);assert.equal(row.calls.some(call=>call[0]==='apply'),false);overflowCases++;continue;}
  // The oracle hooks the BOOL lower and deliberately supplies -1/2 too; those
  // are not possible ReadBOOL outputs from this one-bit packet codec.
  if(![0,1].includes(c.value)){nonWireScalarCases++;continue;}
  const applied=row.calls.find(call=>call[0]==='apply');
  assert.deepEqual(decode(packet(c.mask,c.value,c.incoming,{clientIds:true})),{kind:'module-pause-state',major:3,minor:9,mask:applied[1],value:applied[2],exclusionIds:applied[3]});compared++;
 }
 assert.ok(compared>0&&overflowCases>0&&nonWireScalarCases>0);
 // This is original receiver execution with explicit scalar hooks, not retained
 // native packet bytes, server authority, timer application or GUI evidence.
});
