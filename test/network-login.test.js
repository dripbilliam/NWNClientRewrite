import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';
import {NetworkLogin} from '../src/network_login.js';
import {NetworkLoginIdentity} from '../electron/network_login_identity.mjs';
import {NetworkPacketCipher,requiresSessionEncryption} from '../electron/network_packet_cipher.mjs';
import {NetworkCrypto} from '../electron/network_crypto.mjs';
import {installedNetworkBuild} from '../electron/installed_network_build.mjs';
import {isNetworkBytes} from '../src/network_bytes.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-login-packets-observations.json',import.meta.url)));
const nativePolicy=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-encryption-policy-observations.json',import.meta.url)));
const fixture=tag=>Buffer.from(native.cases.find(r=>r.case.tag===tag&&!r.case.reason).calls.find(c=>c[0]==='send')[1],'hex');
const tag=bytes=>Buffer.from(bytes.subarray(0,4)).toString('ascii');
const packet=(type,size=4)=>{const bytes=Buffer.alloc(size);bytes.write(type);return bytes;};
function setup(){
 const diagnostics=[],identity=new NetworkLoginIdentity({cdKey:'ABCDE-FGHIJ-KLMNO-PQRST-UVWXY-ZABCD-EFGHI'});
 const metadata={...native.cases.find(r=>r.case.tag==='BNCS').case,platformId:2};
 const crypto={start:async()=>Buffer.alloc(32),finish:async()=>({packet3:Buffer.alloc(48),serverPublicKey:Buffer.alloc(32)}),reset:async()=>{}};
 return{identity,diagnostics,login:new NetworkLogin(crypto,identity,metadata,{onDiagnostic:d=>diagnostics.push(d)})};
}
async function exchange(login){
 assert.equal(tag((await login.begin()).send),'BNK1');
 assert.equal(tag((await login.receive(packet('BNK2',84))).send),'BNK3');
 const done=packet('BNK4',8);done.writeUInt32LE(0xfeedcafe,4);
 assert.equal(tag((await login.receive(done)).send),'BNCS');assert.equal(login.phase,'connect');
}

test('native login binds key exchange, challenge proof and unsigned remote application identity',async()=>{
 const {login,identity,diagnostics}=setup();try{
  // Actual original packet-writer fixtures, not a second implementation of codecs.
  assert.equal((await login.receive(fixture('BNVR'))).accepted,false);
  await exchange(login);
  const challenge=await login.receive(fixture('BNCR'));assert.equal(tag(challenge.send),'BNVS');assert.equal(login.phase,'validate');
  const accepted=await login.receive(fixture('BNVR'));assert.equal(accepted.admitted,true);assert.equal(login.phase,'admitted');
  assert.equal(accepted.remote.applicationId,0x89abcdef);assert.equal(login.exchange.identity,0xfeedcafe);
  assert.equal((await login.receive(fixture('BNVR'))).accepted,false);
  assert.ok(Object.isFrozen(login.remote.build));assert.equal(diagnostics.length,2);
 }finally{identity.dispose();}
});

test('rejected/malformed login is diagnosed without leaking challenge/credential bytes',async()=>{
 const {login,identity,diagnostics}=setup();try{
  await exchange(login);
  const malformed=Buffer.from('BNCRxxVprivate-unparseable-challenge');
  assert.equal((await login.receive(malformed)).accepted,false);assert.equal(login.phase,'connect');
  const rejected=Buffer.from(native.cases.find(r=>r.case.tag==='BNCR'&&r.case.reason===19).calls.find(c=>c[0]==='send')[1],'hex');
  assert.equal((await login.receive(rejected)).failed,true);assert.equal(login.connectionError,19);assert.equal(login.phase,'rejected');
  const serialized=JSON.stringify({login,diagnostics});assert.ok(!serialized.includes('unparseable'));assert.ok(!serialized.includes('ABCDE'));assert.ok(!serialized.includes('FGHIJ'));
 }finally{identity.dispose();}
});

test('byte validation accepts foreign VM Uint8Arrays and excludes other views',async()=>{
 const foreign=vm.runInNewContext('new Uint8Array([66,78,75,48])');assert.equal(foreign instanceof Uint8Array,false);assert.equal(isNetworkBytes(foreign),true);
 for(const value of [new Int8Array(4),new Uint16Array(4),new DataView(new ArrayBuffer(4)),[],{length:4},null])assert.equal(isNetworkBytes(value),false);
 const {login,identity}=setup();try{await login.begin();assert.equal((await login.receive(foreign)).failed,true);}finally{identity.dispose();}
});

test('native packet family classification and identity envelope preserve unsigned IDs',async()=>{
 assert.equal(nativePolicy.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const row of nativePolicy.cases)assert.equal(requiresSessionEncryption(Buffer.from(row.packet,'hex')),row.requiresEncryption,row.packet);
 for(const type of ['BNK1','BNK3','BNES','BNXI','BNDS','BNDP'])assert.equal(requiresSessionEncryption(packet(type)),false);
 for(const value of [packet('BNCS'),packet('BNVS'),packet('BNCR'),packet('BNVR'),packet('xxxx'),Buffer.alloc(2)])assert.equal(requiresSessionEncryption(value),true);
 const seen=[],crypto={seal:async b=>{seen.push(Buffer.from(b));return Buffer.alloc(b.length+36,7);},open:async b=>Buffer.alloc(b.length-36,8)},cipher=new NetworkPacketCipher(crypto,0xfedcba98);
 const wire=await cipher.encode(packet('BNCS'));assert.equal(wire.length,45);assert.equal(wire[0],73);assert.equal(wire.readUInt32LE(1),0xfedcba98);assert.equal(tag(seen[0]),'BNCS');
 assert.deepEqual(await cipher.decode(wire),Buffer.alloc(4,8));
 const wrong=Buffer.from(wire);wrong[1]^=1;await assert.rejects(cipher.decode(wrong),/identity mismatch/);
 await assert.rejects(cipher.decode(Buffer.alloc(40)),/envelope/);
 assert.deepEqual(await cipher.encode(packet('BNDP')),packet('BNDP'));
});

test('installed native build generates randomized 72-character hex platform identity and disposes',async t=>{
 const install=new URL('../../FullDecomp/NwnRootInstall/',import.meta.url);
 if(!fs.existsSync(new URL('bin/win32/nwmain.exe',install))){t.skip('Pinned local game installation is unavailable');return;}
 const {fileURLToPath}=await import('node:url');
 const build=await installedNetworkBuild(fileURLToPath(install)),crypto=new NetworkCrypto();try{
  assert.deepEqual(build.build,{number:8193,revision:37,postfix:17,commit:'26c6e573'});assert.equal(build.platformId,2);
  const applicationId=await crypto.applicationId();assert.ok(Number.isInteger(applicationId)&&applicationId>=0&&applicationId<=0xffffffff);await crypto.reset();assert.equal(await crypto.applicationId(),applicationId);
  const first=await build.platformIdentifier(crypto),second=await build.platformIdentifier(crypto);assert.match(first,/^[a-f0-9]{72}$/);assert.notEqual(first,second);
  await assert.rejects(crypto.seal(Buffer.alloc(4)),/Invalid native crypto operation/);
  await assert.rejects(crypto.seal(Buffer.alloc(65467)),/length/);await assert.rejects(crypto.open(Buffer.alloc(35)),/length/);
  build.dispose();await assert.rejects(build.platformIdentifier(crypto),/disposed/);
 }finally{crypto.close();build.dispose();}
});
