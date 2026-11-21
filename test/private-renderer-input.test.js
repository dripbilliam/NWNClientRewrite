import test from 'node:test';
import assert from 'node:assert/strict';
import net from 'node:net';
import crypto from 'node:crypto';
import {prepareRendererInput} from '../scripts/private-renderer-input.mjs';

async function readInput(input,token=input.token){
 const pair=crypto.generateKeyPairSync('x25519'),stream=net.connect({host:'127.0.0.1',port:input.port});
 stream.setTimeout(3000,()=>stream.destroy(new Error('Test input timed out')));
 stream.write(JSON.stringify({token,publicKey:pair.publicKey.export({format:'der',type:'spki'}).toString('base64')})+'\n');
 const chunks=[];for await(const b of stream)chunks.push(b);return{pair,bytes:Buffer.concat(chunks)};
}
test('private renderer input encrypts a one-use request and erases caller credential fields',async()=>{
 const original={credentials:{cdKey:'test-only-placeholder',password:'fake'},options:{hidden:true}},input=await prepareRendererInput(original);
 assert.deepEqual(original.credentials,{cdKey:'',password:''});const {pair,bytes}=await readInput(input);
 assert.equal(bytes.includes(Buffer.from('test-only-placeholder')),false);
 const envelope=JSON.parse(bytes),publicKey=crypto.createPublicKey({key:Buffer.from(envelope.publicKey,'base64'),format:'der',type:'spki'}),shared=crypto.diffieHellman({privateKey:pair.privateKey,publicKey}),key=Buffer.from(crypto.hkdfSync('sha256',shared,Buffer.from(input.token),'nwn-renderer-probe-input',32)),d=crypto.createDecipheriv('aes-256-gcm',key,Buffer.from(envelope.iv,'base64'));
 d.setAuthTag(Buffer.from(envelope.tag,'base64'));const payload=Buffer.concat([d.update(Buffer.from(envelope.ciphertext,'base64')),d.final()]);assert.deepEqual(JSON.parse(payload),{credentials:{cdKey:'test-only-placeholder',password:'fake'},options:{hidden:true}});payload.fill(0);key.fill(0);shared.fill(0);
 await assert.rejects(readInput(input),/ECONNREFUSED/);
});
test('private renderer input sends nothing for a wrong token',async()=>{
 const input=await prepareRendererInput({options:{hidden:true}}),{bytes}=await readInput(input,'0'.repeat(64));assert.equal(bytes.length,0);
});
