import fs from 'node:fs/promises';import path from 'node:path';import os from 'node:os';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
const hash=b=>createHash('sha256').update(b).digest('hex');
export async function validateVaultHandoffFixture(f){
 const root=path.resolve(f.root),temp=path.resolve(os.tmpdir());
 assert.equal(path.dirname(root),temp);assert.match(path.basename(root),/^nwn-godot-vault-handoff-[A-Za-z0-9]+$/);assert.equal(f.vault,path.join(root,'vault'));assert.equal(f.reference,'native_hand');assert.ok([2,17].includes(f.source));assert.equal(f.servers.length,2);
 for(const [i,s]of f.servers.entries()){
  const label=i?'B':'A';assert.equal(s.label,label);assert.equal(s.profile,path.join(root,label));assert.equal(s.port,i?5122:5121);assert.equal(s.module,'GodotHand'+label+'1');assert.equal(await fs.realpath(path.join(s.profile,'servervault')),await fs.realpath(f.vault));
  assert.equal(hash(await fs.readFile(path.join(s.profile,'modules',s.module+'.mod'))),s.sha256);
 }
 return f;
}
export async function createVaultHandoffFixture(base,{source=17}={}){
 assert.ok([2,17].includes(source));
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-godot-vault-handoff-')),vault=path.join(root,'vault');await fs.mkdir(vault);
 const servers=[];
 for(const s of base.servers){
  assert.ok(['A','B'].includes(s.label));const profile=path.join(root,s.label),bytes=await fs.readFile(path.join(s.profile,'modules',s.module+'.mod'));assert.equal(hash(bytes),s.sha256);
  await fs.mkdir(path.join(profile,'modules'),{recursive:true});await fs.mkdir(path.join(profile,'nwm'));
  await fs.writeFile(path.join(profile,'modules',s.module+'.mod'),bytes,{flag:'wx'});await fs.writeFile(path.join(profile,'nwm',s.module+'.nwm'),bytes,{flag:'wx'});
  await fs.symlink(vault,path.join(profile,'servervault'),'junction');
  await fs.writeFile(path.join(profile,'settings.tml'),'[server.identity]\nname = "Owned Native Vault Handoff"\npublic = false\n[server.net]\naccept-relayed-connections = false\n[server.login.player-dm]\nenabled = false\n',{flag:'wx'});
  servers.push({...s,profile});
 }
 return validateVaultHandoffFixture({version:1,root,vault,reference:'native_hand',source,servers,scope:'External authored profiles and shared external server vault; two owned loopback servers only'});
}
export async function seedVaultHandoffFixture(f,{identity,install}){
 await validateVaultHandoffFixture(f);assert.equal((await fs.readdir(f.vault)).length,0,'Test vault is not empty');
 const {openServerResourceContext}=await import('../../electron/server_resource_context.mjs');const {loadCreationRules,initialCreationDraft,recommendCreation,creationErrors,createCharacterBic}=await import('../../src/character_creation.js');
 const resolver=await openServerResourceContext({install}),rules=await loadCreationRules(resolver),draft=initialCreationDraft(rules);
 Object.assign(draft,{classId:10,raceId:6,gender:0,packageId:Number(rules.classes.orderedRows[10].Package),firstName:'Native',lastName:'Vault Handoff'});await recommendCreation(draft,rules);assert.deepEqual(creationErrors(draft,rules),[]);
 const bytes=await createCharacterBic(draft,rules);let folder=f.vault;
 if(f.source===17){const account=identity.publicKey.toLowerCase();if(!/^[a-z0-9]{8}$/.test(account))throw Error('Test account identity is unavailable');folder=path.join(f.vault,account);await fs.mkdir(folder);}
 await fs.writeFile(path.join(folder,f.reference+'.bic'),bytes,{flag:'wx'});
 const result={reference:f.reference,source:f.source,bytes:bytes.length,sha256:hash(bytes),name:'Native Vault Handoff',generatedByReplacement:true,sharedVault:true};bytes.fill(0);return result;
}
export async function verifyVaultHandoffSeed(f,seed,{identity}){
 await validateVaultHandoffFixture(f);assert.equal(seed.reference,f.reference);assert.equal(seed.source,f.source);assert.equal(seed.generatedByReplacement,true);assert.equal(seed.sharedVault,true);assert.match(seed.sha256,/^[a-f0-9]{64}$/);assert.ok(seed.bytes>1000);
 const account=f.source===17?identity.publicKey.toLowerCase():null;if(account&&!/^[a-z0-9]{8}$/.test(account))throw Error('Test account identity is unavailable');
 const folder=account?path.join(f.vault,account):f.vault,bytes=await fs.readFile(path.join(folder,f.reference+'.bic'));assert.equal(bytes.length,seed.bytes);assert.equal(hash(bytes),seed.sha256);bytes.fill(0);return seed;
}
