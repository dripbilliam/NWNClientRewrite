'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {project,sha,child,read}=require('./prepare-engine.cjs');
const stage=path.join(project,'.cache/native-tracy/engine-msvc-a'),oldFile=path.join(stage,'build-plan.json'),oldSha='eb8b773b772ecf733c4ceb3d9a3e258e31c96091a63fed1a0222da658ebe5d83';
const plan=read(oldFile,oldSha),fixFile=path.join(project,'.cache/native-tracy/shutdown-order-fix-source-a/manifest.json'),fix=read(fixFile,'dc5620140629245e2c7349f54ef6fa3b8819c5ab1ec3dcfcfde5e5fb58661769');
const reproFile=path.join(project,'.cache/native-tracy/shutdown-order-repro-a/receipt.json'),repro=JSON.parse(fs.readFileSync(reproFile));assert(repro.success);assert.equal(repro.results[0].exit,1);assert.equal(repro.results[1].exit,0);assert.equal(path.resolve(fix.source),path.resolve(plan.source));
const file=path.join(stage,'build-plan-b.json');assert(!fs.existsSync(file),'Keep previous build plan');for(const pin of fix.inputs)assert.equal(sha(pin.file),pin.sha256);
for(const row of fix.outputs){const input=child(fix.output,row.relative),target=child(plan.source,row.relative);assert.equal(sha(input),row.sha256);fs.copyFileSync(input,target);plan.engineTrackedSources.push({relative:row.relative,file:target,sha256:row.sha256,kind:'thread-counter-constant-initialization'});}
plan.parentPlan={file:oldFile,sha256:oldSha};plan.shutdownFix={file:fixFile,sha256:sha(fixFile),reproducer:{file:reproFile,sha256:sha(reproFile)}};plan.output=path.join(stage,'engine-build-b');plan.createdUtc=new Date().toISOString();plan.scope+=' Includes private constant initialization of Thread ID counter, verified by old/fixed early-CRT reproducer; all shutdown assertions retained.';
fs.writeFileSync(file,JSON.stringify(plan,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file,sha256:sha(file),changed:fix.outputs.length,compiled:false}));
