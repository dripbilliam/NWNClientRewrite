import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {connectRequest,validationResponse,readConnectResponse,readValidationResponse} from '../src/network_login_packets.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-login-packets-observations.json',import.meta.url)));

test('login codecs match actual original BNCS/BNCR/BNVS/BNVR writer outputs',()=>{
 assert.equal(native.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const row of native.cases){
  const c=row.case,wire=Buffer.from(row.calls.find(c=>c[0]==='send')[1],'hex');assert.equal(row.result,7);
  if(c.tag==='BNCS')assert.deepEqual(Buffer.from(connectRequest({...c,platformId:2})),wire,JSON.stringify(c));
  else if(c.tag==='BNVS')assert.deepEqual(Buffer.from(validationResponse(c)),wire,JSON.stringify(c));
  else if(c.tag==='BNCR'){
   const parsed=readConnectResponse(wire);
   if(c.reason){assert.equal(parsed.kind,'rejected');assert.equal(parsed.reason,c.reason);assert.equal(parsed.connectionError,c.reason===7||c.reason===255?1:c.reason);}
   else assert.deepEqual(parsed,{kind:'challenge',port:c.port,passwordRequired:Boolean(c.passwordRequired),passwordChallenge:c.passwordRequired?c.challenges[0]:'',keyChallenge:c.challenges[c.passwordRequired?1:0],communityChallenge:c.challenges[c.passwordRequired?2:1],trailingBytes:0});
  }else{
   const parsed=readValidationResponse(wire);
   assert.deepEqual(parsed,c.reason?{kind:'rejected',connectionError:c.reason}:{kind:'accepted',applicationId:c.applicationId,build:{number:c.build.number,revision:c.build.revision,postfix:c.build.postfix}});
  }
 }
 assert.equal(native.cases.length,32);
});

test('challenge truncations cannot read uninitialized bytes; native trailing bytes remain visible',()=>{
 const row=native.cases.find(r=>r.case.tag==='BNCR'&&r.case.passwordRequired),wire=Buffer.from(row.calls[0][1],'hex');
 for(let size=0;size<wire.length;size++)assert.throws(()=>readConnectResponse(wire.subarray(0,size)),/Truncated/);
 assert.equal(readConnectResponse(Buffer.concat([wire,Buffer.from([9])])).trailingBytes,1);
 const bad=Buffer.from(wire);bad[6]=88;assert.throws(()=>readConnectResponse(bad),/Unsupported/);
});

test('validation accepts legacy build omissions while retaining unsigned application identity',()=>{
 const row=native.cases.find(r=>r.case.tag==='BNVR'&&r.case.reason===0),wire=Buffer.from(row.calls[0][1],'hex');
 for(let size=0;size<9;size++)assert.throws(()=>readValidationResponse(wire.subarray(0,size)),/Truncated/);
 assert.deepEqual(readValidationResponse(wire.subarray(0,9)),{kind:'accepted',applicationId:0x89abcdef,build:{number:0,revision:0,postfix:0}});
 assert.equal(readValidationResponse(wire.subarray(0,17)).build.postfix,0);
 const bad=Buffer.from(wire);bad[4]=88;assert.throws(()=>readValidationResponse(bad),/Unsupported/);
});

test('missing identity inputs and unsafe length overflows fail explicitly',()=>{
 const c=native.cases.find(r=>r.case.tag==='BNCS').case;
 assert.throws(()=>connectRequest({...c,platformId:2,platformIdentifier:undefined}),/unavailable/);
 assert.throws(()=>connectRequest({...c,platformId:2,name:'x'.repeat(256)}),/wire length/);
 assert.throws(()=>connectRequest({...c,platformId:undefined}),/unavailable/);
 assert.throws(()=>validationResponse({keyResponse:'',communityResponse:'',passwordResponse:0}),/unavailable/);
});
