import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';
import {NetworkCharacterVault} from '../electron/network_character_vault.mjs';
import {writeGff,gffRecord,gffField} from '../src/gff_writer.js';
const bic=hp=>writeGff('BIC ',gffRecord({FirstName:gffField(12,{strRef:0xffffffff,entries:[{language:0,gender:0,text:'Export / .. Hero'}]}),HitPoints:gffField(3,hp),EffectList:gffField(15,[gffRecord({Type:gffField(3,40)})])}));
async function cleanup(dir){const resolved=await fs.realpath(dir),parent=await fs.realpath(os.tmpdir());assert.equal(path.dirname(resolved),parent);assert.ok(path.basename(resolved).startsWith('nwn-character-vault-'));await fs.rm(resolved,{recursive:true,force:true});}
test('durable vault retains byte-exact active-effect BICs, stable selection lineage and older immutable exports',async()=>{
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-character-vault-')),v=new NetworkCharacterVault(dir);try{
  const data=bic(45),a=await v.save({data});assert.deepEqual(data,bic(45));assert.ok(!a.name.includes('Saved character'));assert.deepEqual(await new NetworkCharacterVault(dir).read(a.id),data);
  const next=await v.save({data:bic(42)},{id:a.id});assert.equal(next.id,a.id);assert.notEqual(next.sha256,a.sha256);assert.equal((await v.list()).length,1);assert.deepEqual(await v.read(a.id),bic(42));assert.deepEqual(new Uint8Array(await fs.readFile(path.join(dir,'blobs',a.sha256+'.bic'))),data);await assert.rejects(v.read('../escape'),/Invalid/);await assert.rejects(v.save({data:Uint8Array.of(1,2)}));assert.deepEqual(await v.read(a.id),bic(42));
 }finally{await cleanup(dir);}
});
test('entry commit failure preserves the previous export and corrupt saved blobs fail integrity checks',async()=>{
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-character-vault-failure-')),v=new NetworkCharacterVault(dir),rename=fs.rename;try{
  const a=await v.save({data:bic(45)});fs.rename=async(from,to)=>{if(to.includes(path.sep+'entries'+path.sep))throw Error('simulated entry commit failure');return rename(from,to);};await assert.rejects(v.save({data:bic(44)},{id:a.id}),/commit failure/);fs.rename=rename;assert.deepEqual(await v.read(a.id),bic(45));
  await fs.writeFile(path.join(dir,'blobs',a.sha256+'.bic'),new Uint8Array(a.bytes));await assert.rejects(v.read(a.id),/integrity/);await assert.rejects(v.save({data:bic(45)},{id:a.id}),/integrity/);
 }finally{fs.rename=rename;await cleanup(dir);}
});
