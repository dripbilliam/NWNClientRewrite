const test=require('node:test'),assert=require('node:assert/strict');
const {creationSocketTrace}=require('../tools/native-creation-socket-trace.cjs');
test('private endpoint matcher includes exact network-order port and both loopback socket forms',()=>{
 const value=creationSocketTrace(49153),text=value.commands.join('\n');
 assert.equal(value.port,49153);assert.equal(value.cap,32);assert(text.includes('wo(@rdx+2)==0x1c0'));
 assert(text.includes('wo(@rdx)==2'));assert(text.includes('wo(@rdx)==0x17'));assert(text.includes('dwo(@rdx+4)==0x0100007f'));assert(text.includes('dwo(@rdx+20)==0x0100007f'));
 assert(text.includes('@rcx==@$t1'));assert(text.includes('r @$t2=0'));assert(text.includes('bd6 7 8 9'));assert(text.includes('.time; k0n12;'));assert(text.includes('@$t0>=0n32'));
 assert(!/select|ioctlsocket|recv|\bdb\b|\bdd\b/.test(text));
 for(const port of [0,80,65536,1.5,'5129',null])assert.throws(()=>creationSocketTrace(port));
});
