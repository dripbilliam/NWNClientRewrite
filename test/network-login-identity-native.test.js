import fs from 'node:fs';
import {createHash} from 'node:crypto';
import test from 'node:test';
import assert from 'node:assert/strict';
import {publicCdKey,NetworkLoginIdentity} from '../electron/network_login_identity.mjs';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-login-identity-observations.json',import.meta.url)));
const key='ABCDE-FGHIJ-KLMNO-PQRST-UVWXY-ZABCD-EFGHI';
const challenge={kind:'challenge',passwordRequired:false,passwordChallenge:'',keyChallenge:'key-salt',communityChallenge:'community-salt'};

test('Node digest matches original CBWCMD5 rounds across padding and multi-block boundaries',()=>{
 assert.equal(native.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const row of native.md5)assert.equal(createHash('md5').update(Buffer.from(row.input,'hex')).digest('hex'),row.digest);
 assert.equal(native.md5.length,21);
});
test('public extraction matches original CDUtil without exporting private key components',()=>{
 for(const row of native.publicKeys)assert.equal(publicCdKey(row.key),row.public);
 assert.equal(native.publicKeys.length,6);assert.equal(publicCdKey(undefined),'');
});
test('community challenge responses match original coordinator ordering',()=>{
 for(const row of native.community){
  const identity=new NetworkLoginIdentity({cdKey:key,communityPassword:row.password});
  try{assert.equal(identity.respond({...challenge,communityChallenge:row.challenge}).communityResponse,row.response);}finally{identity.dispose();}
 }
 assert.equal(native.community.length,5);
});
test('credentials remain private, missing passwords use native error3, and disposal prevents reuse',()=>{
 const identity=new NetworkLoginIdentity({cdKey:key.toLowerCase(),password:'fixture-password'}),publicId=publicCdKey(key),response=identity.respond({...challenge,passwordRequired:true,passwordChallenge:'pw-salt'});
 assert.equal(identity.publicKey,publicId);assert.equal(response.keyResponse.length,40);assert.equal(response.keyResponse.slice(0,8),publicId);assert.equal(response.passwordResponse.length,32);assert.equal(response.connectionError,0);
 assert.equal(Object.keys(identity).length,0);assert.ok(!JSON.stringify(identity).includes(key));assert.ok(!JSON.stringify(identity).includes('fixture-password'));assert.ok(!JSON.stringify(response).includes(key));
 identity.dispose();assert.throws(()=>identity.publicKey,/disposed/);assert.throws(()=>identity.respond(challenge),/disposed/);
 const empty=new NetworkLoginIdentity({cdKey:key});try{const response=empty.respond({...challenge,passwordRequired:true});assert.equal(response.connectionError,3);assert.equal(response.passwordResponse,'');}finally{empty.dispose();}
 assert.throws(()=>new NetworkLoginIdentity({cdKey:'short'}),/format/);
 assert.throws(()=>new NetworkLoginIdentity({cdKey:key,password:'private-\u{1f512}'}),e=>e.message==='NWN login text encoding is unsupported');
});
