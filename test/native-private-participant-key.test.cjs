const test=require('node:test'),assert=require('node:assert/strict'),{Readable}=require('node:stream');
const {readPrivateKey,connectPrivatePipe}=require('../godot-client/tools/private-login.cjs');
// Synthetic format-only input, never used for a login or a real credential.
const synthetic=Array(7).fill('ABCDE').join('-');
test('participant pipe reads bounded chunked credentials without a settings writer',async()=>{
 const text=JSON.stringify({cdKey:synthetic});
 assert.equal(await readPrivateKey(Readable.from([Buffer.from(text.slice(0,11)),Buffer.from(text.slice(11))])),synthetic);
});
test('participant parser rejects malformed, extra-field and oversized input without reflecting it',async()=>{
 for(const text of ['not-json',JSON.stringify({cdKey:'private-invalid-marker'}),JSON.stringify({cdKey:synthetic,save:true}),'x'.repeat(16385)]){
  await assert.rejects(readPrivateKey(Readable.from([text])),error=>error.message==='Could not read private participant credentials');
 }
 assert.throws(()=>connectPrivatePipe('untrusted-pipe'),{message:'Invalid private login pipe'});
});
