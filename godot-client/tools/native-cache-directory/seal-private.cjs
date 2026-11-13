'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../..'),stage=path.join(project,'.cache/native-tracy/live/manual-cache-a');
const read=f=>JSON.parse(fs.readFileSync(f,'utf8').replace(/^\uFEFF/,'')),sha=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex'),pin=f=>({file:f,sha256:sha(f)});
const configFile=path.join(stage,'config.json'),config=read(configFile);require(path.join(config.source,'verify.cjs')).verify(configFile);
const fixFile=path.join(project,'.cache/native-cache-directory/fix-a/checks-a/acceptance.json'),fix=read(fixFile);
const nativeFile=path.join(stage,'native-checks-a/acceptance.json'),native=read(nativeFile);
const cacheFile=path.join(stage,'cache-check-a/receipt.json'),cache=read(cacheFile);
const parentFile=path.join(project,'.cache/native-tracy/live/manual-source-d/native-acceptance.json'),parent=read(parentFile);
for(const x of [fix,native,cache])assert.equal(x.success,true);
assert.equal(fix.afterSource,config.expectedMainSourceIdentity);assert.equal(native.stageManifestSha256,sha(path.join(stage,'manifest.json')));
assert.equal(native.engineSha256,config.engineSha256);assert.equal(cache.engine,config.engineSha256);
assert.equal(native.particleSha256,config.particleSha256);assert.equal(parent.bridgePassed,true);assert.equal(parent.lifetimePassed,true);
assert.equal(parent.evidence.headlessTrace.sha256,sha(parent.evidence.headlessTrace.file));
const trace=read(parent.evidence.headlessTrace.file);assert.equal(trace.client.sha256,config.engineSha256);
const prior=read(path.join(project,'.cache/native-tracy/live/manual-source-d/config.json'));assert.equal(prior.engineSha256,config.engineSha256);assert.equal(prior.particleSha256,config.particleSha256);
const receipt={version:1,createdUtc:new Date().toISOString(),stageManifestSha256:native.stageManifestSha256,nativeParsed:true,functionalPassed:true,bridgePassed:true,lifetimePassed:true,manuallyReviewed:true,
 performanceAccepted:false,arelithCacheFixTested:false,manualHostSessionTested:false,newFPSRun:false,
 evidence:{normalCacheFix:pin(fixFile),privateNative:pin(nativeFile),privateCache:pin(cacheFile),unchangedBinaryBridgeAndRendering:pin(parentFile)},
 source:config.expectedMainSourceIdentity,privateSource:config.predictedSourceIdentity,engine:config.engineSha256,particle:config.particleSha256,
 inheritedEvidence:'The exact unchanged engine/DLL previously passed connected bridge capture and graphical rendering/lifetime checks. This new script stage passed native parser/owner and real directory/recovery/thread checks with natural exit0. No new graphical/FPS capture was run.',
 scope:'Fresh private launch package carrying only the validated cache-directory script change alongside the existing Tracy engine/DLL and16 flags.'};
const file=path.join(stage,'native-acceptance.json');fs.writeFileSync(file,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,...pin(file),source:receipt.source}));
