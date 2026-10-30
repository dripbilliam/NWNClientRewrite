const {test}=require('node:test');
const assert=require('node:assert/strict');
const {Readable}=require('node:stream');
const {savePrivateLogin}=require('./private-login.cjs');
test('private pipe saves only a validated key and clears its transient request',async()=>{
 const key=Array(7).fill('AAAAA').join('-');let request;
 const matches=await savePrivateLogin(Readable.from([Buffer.from(JSON.stringify({cdKey:key}))]),{update:async value=>{assert.equal(value.cdKey,key);request=value;}});
 assert.equal(request.cdKey,'');
 assert.equal(matches(key),true);assert.equal(matches('OTHER'),false);assert.equal(matches(undefined),false);
});
test('malformed, oversized or failed private input produces no secret-bearing errors',async()=>{
 for(const data of ['SECRET','{"cdKey":"SECRET"}',JSON.stringify({cdKey:Array(7).fill('AAAAA').join('-'),extra:true}),'SECRET'.repeat(3000)]){
  let calls=0;await assert.rejects(savePrivateLogin(Readable.from([data]),{update:async()=>calls++}),/Could not save the private login key \((read|decode|validate)\)/);assert.equal(calls,0);
 }
 await assert.rejects(savePrivateLogin(Readable.from([JSON.stringify({cdKey:Array(7).fill('AAAAA').join('-')})]),{update:async()=>{throw Error('SECRET');}}),{message:'Could not save the private login key (store)'});
});
