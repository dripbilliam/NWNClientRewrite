import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {ServerEndpointPolicy} from '../tools/server-endpoint.mjs';
const host=fs.readFileSync(new URL('../tools/native-session-host.cjs',import.meta.url),'utf8'),first="const cacheDirectory=path.join(userDirectory,'replacement-client/server-content'),policy=new ServerEndpointPolicy(",start=host.indexOf(first),end=host.indexOf(' const vault=new NetworkCharacterVault(',start);
if(start<0||end<start||host.indexOf(first,start+1)>=0)throw Error('Exact Host policy construction boundary changed');
const fragment=host.slice(start,end),construct=new Function('ServerEndpointPolicy','path','userDirectory','scriptFloatingCheck','levelSourceCheck','actionCheck','creationDirectory','localPort','menuCheck','process',fragment+'\nreturn policy;');
const policy=(script=false,level=false)=>construct(ServerEndpointPolicy,path,'AUTHORED_OWNED_PROFILE',script,level,false,null,script||level?5129:5121,false,{argv:[]});
test('actual Host construction+narrowing admits only explicit localhost5129 for ScriptFloating',t=>{
 const value=policy(true);assert.deepEqual(value.require({host:'127.0.0.1',port:5129}),{host:'127.0.0.1',port:5129});assert.equal(value.allowed.size,1);assert.equal(value.allowAny,false);assert.equal(value.internet,false);
 for(const endpoint of [{host:'127.0.0.1',port:5121},{host:'127.0.0.1',port:5127},{host:'203.0.113.10',port:5129},{host:'example.test',port:5129}]){assert.equal(value.permits(endpoint),false);assert.throws(()=>value.require(endpoint),/No connection was sent/);}
 t.diagnostic(JSON.stringify({hostSha256:crypto.createHash('sha256').update(host).digest('hex'),fragmentSha256:crypto.createHash('sha256').update(fragment).digest('hex'),scope:'Bounded actual current Host endpoint-policy construction/narrowing with real ServerEndpointPolicy. No server, engine, key, socket or Host startup.'}));
});
test('default and existing level-source launches retain their original policy contracts',()=>{
 assert.equal(policy().permits({host:'127.0.0.1',port:5121}),true);assert.equal(policy().permits({host:'127.0.0.1',port:5129}),false);assert.equal(policy(false,true).permits({host:'127.0.0.1',port:5121}),true);assert.equal(policy(false,true).permits({host:'127.0.0.1',port:5129}),true);assert.equal(policy().permits({host:'203.0.113.10',port:5121}),false);
});
test('actual opt-in Host guard refuses public or combined check flags before policy/session creation',()=>{
 const begin=host.indexOf("const scriptFloatingCheck=process.argv.includes('--script-floating-check')"),finish=host.indexOf('if(levelSourceCheck&&',begin);if(begin<0||finish<begin)throw Error('Exact isolated Host admission guard changed');
 const guard=new Function('process','arg','headless','engineRuntime',host.slice(begin,finish));const arg=name=>['script-floating-directory','private-login-pipe'].includes(name)?'AUTHORED_NON_SECRET_FIXTURE':undefined;
 assert.doesNotThrow(()=>guard({argv:['--script-floating-check']},arg,true,'editor'));
 for(const other of ['--public-servers','--level-source-check','--action-check','--creation-check','--local-check','--menu-check','--record-loading','--native-profile'])assert.throws(()=>guard({argv:['--script-floating-check',other]},arg,true,'editor'),/exclusive/);
 assert.throws(()=>guard({argv:['--script-floating-check']},arg,false,'editor'),/exclusive/);assert.throws(()=>guard({argv:['--script-floating-check']},arg,true,'release'),/exclusive/);
});
