'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../../../../..'),base=path.join(project,'.cache/native-render-gap/original/compiler/pgo');
const read=f=>JSON.parse(fs.readFileSync(f,'utf8').replace(/^\ufeff/,'')),hash=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
const semanticFile=path.join(base,'semantic-generation-a/root-training-run.json'),heavyFile=path.join(base,'heavy-training-a.json');
const semantic=read(semanticFile),heavy=read(heavyFile),generation=read(path.join(base,'notrace-dv-a/build-a/generation-receipt.json'));
assert(semantic.success&&semantic.observationsIdentical&&semantic.checks===4274&&semantic.rows===10);
const result=read(heavy.evidence[0].file);assert(result.success&&result.trainingOnly===true&&result.performanceAccepted===false&&result.processes.every(p=>p.exit===0));
assert.equal(hash(result.moduleProof.engine),generation.generation.sha256);
for(const run of [semantic,heavy]){assert(run.cleanExit&&run.exitCode===0);assert.equal(run.generatedExeSha256,generation.generation.sha256);for(const pin of run.evidence)assert.equal(hash(pin.file),pin.sha256);}
const manifest={version:1,success:true,serialized:true,generatedExeSha256:generation.generation.sha256,sealedUtc:new Date().toISOString(),runs:[{...semantic,evidence:[{file:semanticFile,sha256:hash(semanticFile)},...semantic.evidence]},{...heavy,evidence:[{file:heavyFile,sha256:hash(heavyFile)},...heavy.evidence]}],profiles:generation.generatedObjects.map(row=>({file:row.expectedProfile,bytes:fs.statSync(row.expectedProfile).size,sha256:hash(row.expectedProfile)})),scope:'Root reviewed two nonoverlapping natural-exit runs:4274 public semantic/bit checks with48representative values across34distinct Variant types plus Object/Callable paths, followed by genuine heavy-scene movement and60squiet. Instrumentation timings are excluded from FPS evidence. Profiles remain at fixed adjacent locations.'};
const out=path.join(base,'notrace-dv-a/training-a.json');fs.writeFileSync(out,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file:out,sha256:hash(out),profiles:manifest.profiles}));
