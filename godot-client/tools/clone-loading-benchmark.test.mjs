import test from 'node:test';import assert from 'node:assert/strict';
import fs from 'node:fs/promises';import path from 'node:path';import os from 'node:os';import {createHash} from 'node:crypto';
import {cloneRecording} from './clone-loading-benchmark.mjs';
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
export async function makeFixture(root){
 const source=path.join(root,'source'),catalog=path.join(source,'catalog-1');await fs.mkdir(path.join(catalog,'objects'),{recursive:true});
 const bytes=Buffer.from('2DA V2.0\n\n Label\n0 exact\n'),digest=sha(bytes),zero=sha(Buffer.alloc(0));
 await fs.writeFile(path.join(catalog,'objects',digest),bytes);await fs.writeFile(path.join(catalog,'objects',zero),Buffer.alloc(0));
 const manifest={version:2,complete:true,availability:{'table:2017':3,'alias:2017':1,'unused:2002':5,'failed:3':2,'zero:4':3,'long_reference_12345678901234567:2022':3,'žtest:2047':3},resources:{'table:2017':{sha256:digest,bytes:bytes.length},'alias:2017':{sha256:digest,bytes:bytes.length},'failed:3':{error:'original read error'},'zero:4':{sha256:zero,bytes:0},'long_reference_12345678901234567:2022':{sha256:digest,bytes:bytes.length},'žtest:2047':{sha256:digest,bytes:bytes.length}},talk:{base:{sha256:digest,bytes:bytes.length}}};
 const catalogBytes=Buffer.from(JSON.stringify(manifest));await fs.writeFile(path.join(catalog,'manifest.json'),catalogBytes);
 const timeline=Buffer.from(JSON.stringify({sequence:1,kind:'frame',at:0,value:{kind:'setup',resourceSources:{recordedCatalog:'catalog-1'}}})+'\n');await fs.writeFile(path.join(source,'timeline.jsonl'),timeline);
 const recording=Buffer.from(JSON.stringify({version:1,complete:true,events:1,timelineSha256:sha(timeline),catalogs:[{directory:'catalog-1',sha256:sha(catalogBytes)}]}));await fs.writeFile(path.join(source,'recording.json'),recording);
 return{source,catalog,bytes,manifest,recording,timeline,catalogBytes};
}
test('clone preserves sealed data and full namespace, deduplicates exact payloads and retains explicit gaps',async()=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-archive-clone-test-'));try{
  const f=await makeFixture(root),destination=path.join(root,'clone'),proof=await cloneRecording(f.source,destination);
  assert.equal(proof.originalUnchanged,true);assert.equal(proof.catalogs[0].uniquePayloads,2);assert.equal(proof.catalogs[0].gaps,2);
  assert.deepEqual(await fs.readFile(path.join(f.source,'recording.json')),f.recording);assert.deepEqual(await fs.readFile(path.join(f.source,'catalog-1','manifest.json')),f.catalogBytes);assert.deepEqual(await fs.readFile(path.join(destination,'timeline.jsonl')),f.timeline);
  const bytes=await fs.readFile(path.join(destination,'catalog-1','resources.erf'));assert.equal(bytes.subarray(0,8).toString(),'ERF V1.1');assert.equal(bytes.readUInt32LE(16),7);assert.equal(bytes.length,160+7*48+f.bytes.length);
  const catalog=JSON.parse(await fs.readFile(path.join(destination,'catalog-1','manifest.json')));assert.deepEqual(catalog.availability,f.manifest.availability);assert.deepEqual(catalog.resources,f.manifest.resources);assert.equal(catalog.packedSource.sha256,sha(bytes));
  assert.deepEqual(await fs.readFile(path.join(destination,'catalog-1','objects',f.manifest.talk.base.sha256)),f.bytes);
  await assert.rejects(cloneRecording(f.source,destination));await assert.rejects(cloneRecording(f.source,path.join(f.source,'nested')));
 }finally{await fs.rm(root,{recursive:true});}
});
test('corrupt originals cannot become successfully sealed clones',async()=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-archive-clone-test-'));try{const f=await makeFixture(root);await fs.writeFile(path.join(f.catalog,'objects',f.manifest.resources['table:2017'].sha256),'changed');await assert.rejects(cloneRecording(f.source,path.join(root,'clone')),/checksum\/length/);await assert.rejects(fs.access(path.join(root,'clone','recording.json')));}finally{await fs.rm(root,{recursive:true});}
});
