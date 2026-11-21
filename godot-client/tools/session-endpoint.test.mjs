import test from 'node:test';import assert from 'node:assert/strict';
import {sessionEndpointOptions} from './session-endpoint.mjs';
test('default stays local and public startup requires explicit endpoint',()=>{
 const {policy,startup}=sessionEndpointOptions([]);assert.equal(startup,null);assert.equal(policy.localOnly,true);
 assert.throws(()=>sessionEndpointOptions(['--join-server=145.239.204.29:5124']));
});
test('explicit public browser allows user chosen endpoints and discovery while preserving validation',()=>{
 const {policy,startup}=sessionEndpointOptions(['--public-servers']);assert.equal(startup,null);assert.equal(policy.localOnly,false);assert.equal(policy.internet,true);
 assert.equal(policy.permits({host:'chosen.arelith.com',port:5125}),true);assert.throws(()=>policy.require({host:'https://invalid',port:5125}));
 assert.throws(()=>sessionEndpointOptions(['--public-servers','--auto-play']));
});
test('authorized startup admits only exact endpoint and never autoplays a fixture',()=>{
 const args=['--allow-server=145.239.204.29:5124','--join-server=145.239.204.29:5124','--player-name=ReplacementTest'];
 const {policy,startup,name}=sessionEndpointOptions(args);assert.deepEqual(startup,{host:'145.239.204.29',port:5124});assert.equal(name,'ReplacementTest');
 assert.equal(policy.internet,false);assert.equal(policy.permits({host:startup.host,port:5123}),false);
 for(const flag of ['--auto-play','--smoke','--nwsync-smoke'])assert.throws(()=>sessionEndpointOptions([...args,flag]));
 assert.throws(()=>sessionEndpointOptions(['--player-name=\n']));
});
