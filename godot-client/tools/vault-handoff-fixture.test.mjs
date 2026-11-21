import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import {createHash} from 'node:crypto';import {createVaultHandoffFixture,validateVaultHandoffFixture,verifyVaultHandoffSeed} from './vault-handoff-fixture.mjs';
test('external profile validation rejects unrelated roots before filesystem work',async()=>{
 const malformed=[{}, {root:path.resolve('.'),vault:path.resolve('vault'),source:17,reference:'native_hand',servers:[]}];
 for(const f of malformed)await assert.rejects(validateVaultHandoffFixture(f));
});
test('owned fixtures share only their explicit external test vault and pin authored module bytes',async()=>{
 const source=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-authored-vault-source-')),bytes=Buffer.from('Authored fixture placeholder, not native code or original art'),sha256=createHash('sha256').update(bytes).digest('hex');await fs.mkdir(path.join(source,'modules'));
 const servers=[];for(const [i,label]of ['A','B'].entries()){const module='GodotHand'+label+'1';await fs.writeFile(path.join(source,'modules',module+'.mod'),bytes,{flag:'wx'});servers.push({label,module,profile:source,port:i?5122:5121,sha256});}
 const f=await createVaultHandoffFixture({servers});assert.equal(await validateVaultHandoffFixture(f),f);assert.equal(await fs.realpath(path.join(f.servers[0].profile,'servervault')),await fs.realpath(path.join(f.servers[1].profile,'servervault')));
 for(const change of [v=>v.source=14,v=>v.reference='../other',v=>v.servers[0].profile=source,v=>v.servers[1].port=5123,v=>v.servers[0].module='../arbitrary',v=>v.vault=source]){const altered=structuredClone(f);change(altered);await assert.rejects(validateVaultHandoffFixture(altered));}
 const identity={publicKey:'AUTH1234'},content=Buffer.alloc(2000,65),folder=path.join(f.vault,'auth1234');await fs.mkdir(folder);const seed={reference:'native_hand',source:17,generatedByReplacement:true,sharedVault:true,bytes:content.length,sha256:createHash('sha256').update(content).digest('hex')};await fs.writeFile(path.join(folder,'native_hand.bic'),content,{flag:'wx'});
 assert.equal(await verifyVaultHandoffSeed(f,seed,{identity}),seed);await assert.rejects(verifyVaultHandoffSeed(f,{...seed,source:2},{identity}));await assert.rejects(verifyVaultHandoffSeed(f,{...seed,sha256:'0'.repeat(64)},{identity}));await fs.writeFile(path.join(folder,'native_hand.bic'),Buffer.from('tampered'));await assert.rejects(verifyVaultHandoffSeed(f,seed,{identity}));
 await fs.writeFile(path.join(f.servers[1].profile,'modules',f.servers[1].module+'.mod'),Buffer.from('Changed authored bytes'));await assert.rejects(validateVaultHandoffFixture(f));
 // Keep these tiny authored fixtures in Temp; no recursive traversal of their
 // junctions or unrelated profile cleanup is needed for this test.
});
