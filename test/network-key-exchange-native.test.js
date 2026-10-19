import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {NetworkKeyExchange} from '../src/network_key_exchange.js';
import {NetworkCrypto} from '../electron/network_crypto.mjs';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-key-exchange-observations.json',import.meta.url)));
const bytes=(tag,size=4)=>{const out=Buffer.alloc(size);out.write(tag,0,Math.min(4,size),'ascii');return out;};

test('key-exchange wrappers match original native stage, length, reset, identity and dispatch behavior',async()=>{
 assert.equal(native.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');let count=0;
 for(const row of native.cases){
  const c=row.case;if(!c.statePresent)continue; // Native peer-container lookup is a separate transport owner.
  count++;const calls=[],diagnostics=[],crypto={finish:async()=>{calls.push(['crypto3']);if(c.cryptoResult)throw new Error('Fixture crypto rejection');return{packet3:Uint8Array.from({length:48},(_,i)=>i),serverPublicKey:Uint8Array.from({length:32},(_,i)=>i)};},reset:async()=>{calls.push(['zero',0x10c]);}};
  const exchange=new NetworkKeyExchange(crypto,{onDiagnostic:d=>diagnostics.push(d)});exchange.stage=c.stage;exchange.identity=c.identity;exchange.haveSessionKeys=Boolean(c.haveKeys);
  const input=bytes(c.tag,Math.max(c.size,8));input.writeUInt32LE(c.incomingIdentity,4);
  const result=await exchange.receive(input.subarray(0,c.size));
  if(result.send)calls.push(['send',Buffer.from(result.send).toString('hex')]);if(result.readyForLogin)calls.push(['login']);
  assert.equal(result.accepted,Boolean(row.result),JSON.stringify(c));assert.equal(exchange.stage,row.stage,JSON.stringify(c));assert.equal(exchange.identity,row.identity,JSON.stringify(c));assert.equal(Number(exchange.haveSessionKeys),row.haveKeys,JSON.stringify(c));assert.equal(exchange.connectionError,row.connectionError,JSON.stringify(c));
  assert.deepEqual(calls,row.calls.filter(c=>c[0]!=='rejected'),JSON.stringify(c));
  if(!result.accepted||result.failed)assert.ok(diagnostics.length,JSON.stringify(c));
 }
 assert.equal(count,31);
});

test('server identity mismatch resets the provider and sends native BNK0 before login',async()=>{
 let resets=0;const diagnostics=[],exchange=new NetworkKeyExchange({start:async()=>new Uint8Array(32),finish:async()=>({packet3:new Uint8Array(48),serverPublicKey:new Uint8Array(32).fill(7)}),reset:async()=>{resets++;}},{expectedServerPublicKey:new Uint8Array(32),onDiagnostic:d=>diagnostics.push(d)});
 assert.equal((await exchange.begin()).length,36);const result=await exchange.receive(bytes('BNK2',84));
 assert.equal(Buffer.from(result.send).toString('ascii'),'BNK0');assert.equal(resets,1);assert.equal(exchange.haveSessionKeys,false);assert.equal(exchange.connectionError,0x13);assert.equal(result.failed,true);assert.match(diagnostics[0].reason,/identity mismatch/);
});

test('compiled libhydrogen helper handles rejection, restart and EOF without exposing keys',async()=>{
 const crypto=new NetworkCrypto();try{
  assert.equal((await crypto.start()).length,32);
  await assert.rejects(crypto.finish(new Uint8Array(80)),/authentication failed/);
  await crypto.reset();assert.equal((await crypto.start()).length,32);await crypto.reset();
 }finally{crypto.close();}
 await assert.rejects(crypto.start(),/closed/);
});

test('default diagnostics retain an unsupported packet occurrence without its payload',async()=>{
 const first=runtimeDiagnostics.records.length,exchange=new NetworkKeyExchange({});
 const result=await exchange.receive(Buffer.from('BNZZprivate-payload'));
 assert.equal(result.accepted,false);const records=runtimeDiagnostics.records.slice(first);
 assert.equal(records.length,1);assert.equal(records[0].code,'network.key-exchange-rejected');
 assert.deepEqual(records[0].context,{tag:'BNZZ',stage:0});assert.ok(!JSON.stringify(records).includes('private-payload'));
});

test('public-key ownership survives caller/provider Buffer reuse',async()=>{
 const pin=Buffer.alloc(32,9),publicKey=Buffer.alloc(32,9);
 const exchange=new NetworkKeyExchange({start:async()=>new Uint8Array(32),finish:async()=>({packet3:new Uint8Array(48),serverPublicKey:publicKey})},{expectedServerPublicKey:pin});
 pin.fill(8);await exchange.begin();const result=await exchange.receive(bytes('BNK2',84));
 assert.equal(Buffer.from(result.send.subarray(0,4)).toString('ascii'),'BNK3');
 publicKey.fill(7);assert.deepEqual(exchange.serverPublicKey,new Uint8Array(32).fill(9));
});
