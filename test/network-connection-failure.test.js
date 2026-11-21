import test from 'node:test';import assert from 'node:assert/strict';
import {networkConnectionFailure,networkConnectionFailureText} from '../src/network_connection_failure.js';
import {NetworkPeer} from '../electron/network_peer.mjs';
test('connection diagnostics project known stages/codes without error messages, causes or credentials',()=>{
 const error=Object.assign(Error('private-test-key-and-password'),{code:'EACCES',cause:{cdKey:'private-test-key-and-password'}});
 const value=networkConnectionFailure(error,'bind-socket');assert.deepEqual(value,{stage:'bind-socket',name:'Error',code:'EACCES',reason:'connection-failed'});
 assert(!JSON.stringify(value).includes('private-test'));assert.match(networkConnectionFailureText(value),/bind-socket: EACCES/);
 assert.equal(networkConnectionFailure({message:'private-test',name:'private-test',code:'private-test'},'private-test').stage,'session-connect');
 assert.equal(networkConnectionFailure({message:'private-test',name:'private-test',code:'private-test'},'session-connect').code,null);
 assert.equal(networkConnectionFailure(Error('Concurrent native crypto operations are unavailable'),'platform-identity').reason,'crypto-concurrent');
});
test('invalid options retain the failure stage and close without starting a socket',async()=>{
 const peer=new NetworkPeer({crypto:{close(){}},onDiagnostic(){}});
 await assert.rejects(peer.connect({}, {host:'localhost',port:5121.5,metadata:{}}),/Invalid native network/);
 assert.equal(peer.connectionFailure.stage,'validate-options');assert.equal(peer.closed,true);assert.equal(peer.socket,undefined);
});
test('an identity helper failure retains its safe cause and original connection behavior',async()=>{
 const diagnostics=[],peer=new NetworkPeer({crypto:{applicationId:async()=>{throw Object.assign(Error('secret-marker'),{code:'EIO'});},close(){}},onDiagnostic:v=>diagnostics.push(v)});
 await assert.rejects(peer.connect({}, {host:'127.0.0.1',metadata:{}}),error=>error.message==='Native network connection failed'&&error.cause?.code==='EIO');
 assert.equal(peer.connectionFailure.stage,'application-identity');assert.equal(peer.connectionFailure.code,'EIO');assert.equal(peer.closed,true);assert(!JSON.stringify(diagnostics).includes('secret-marker'));
 assert.equal(diagnostics.filter(v=>v.code==='network.connect-failed').length,1);
});
