// Derived local QA evidence only. No installed resources or packet payloads.
import fs from 'node:fs/promises';import assert from 'node:assert/strict';
const root=new URL('../backups/animations/',import.meta.url),read=async name=>JSON.parse(await fs.readFile(new URL(name,root),'utf8'));
const runs=[];
for(const version of [3,5]){
 const report=await read(`creation-performance-graphics-local-v${version}.json`);
 assert.equal(report.success,true);assert.equal(report.failure,undefined);assert.deepEqual(report.rendererErrors,[]);
 assert.equal(report.areaReadyEvents.length,2);assert.equal(report.trainerSeen,true);assert.ok(report.transitionRequestedAt);
 const last=report.samples.at(-1),start=report.states.filter(s=>s.phase==='area-loading').at(-1).at;
 const settled=report.samples.find(s=>s.scene?.tiles===100&&s.scene.objects===92&&s.scene.attached&&!s.scene.graphicsPending&&s.scene.controlled.rendered&&!s.performance.preparing&&!s.performance.pendingAssets&&!s.performance.pendingShaders);
 assert.ok(settled);assert.deepEqual(last.scene.failed,[]);assert.equal(last.scene.objects,92);
 runs.push({version,areaAcknowledgedMs:report.areaReadyEvents.at(-1).at-start,all92PreparedMs:settled.at-start,finalFps:last.performance.fps});
}
const report=await read('creation-performance-graphics-local-v5.json'),samples=report.largeViewport.filter(s=>s.frame?.viewport.bufferWidth===3100&&s.frame.viewport.bufferHeight===1121);
assert.ok(samples.length>=30);assert.equal(new Set(samples.map(s=>s.performance.programs)).size,1);
for(const s of samples){assert.equal(s.performance.preparing,false);assert.equal(s.performance.pendingAssets,0);assert.equal(s.performance.pendingShaders,0);assert.equal(s.models.failed,0);}
const rotating=samples.filter(s=>s.rotating);assert.ok(rotating.length>=8);assert.ok(rotating.at(-1).camera.yaw-rotating[0].camera.yaw>300);
const range=values=>({min:Math.min(...values),max:Math.max(...values)}),fps=list=>range(list.map(s=>s.performance.fps));
const gpu=await read('renderer-model-preparation-gpu-v4.json');assert.deepEqual(gpu.errors,[]);assert.equal(gpu.areaPixelsUnchanged,true);assert.equal(gpu.staticFadeNoNewPrograms,true);
const proof={scope:'Unmodified owned vanilla Prelude server, installed wizard, ordinary dialogue/tutorial skip and door transition',endpoint:'127.0.0.1:5121',runs,
 resolution:{width:3100,height:1121,samples:samples.length,fps:fps(samples),rotationSamples:rotating.length,rotationFps:fps(rotating),sampledP95FrameMs:range(samples.map(s=>s.performance.p95FrameMs)),programs:samples[0].performance.programs,newProgramsDuringResizeAndOrbit:0},
 gpuFixture:{areaPixelsUnchanged:true,staticFadeNoNewPrograms:true,errors:0},
 limits:'Two separate current-build runs, not a controlled cold-driver before/after experiment. High-resolution samples cover one academy view and camera orbit, not the earlier dense modded-server scene or prolonged fullscreen behavior. Queued import/acknowledgement and supersession ordering are additionally covered by production frontend lifecycle tests.'};
await fs.writeFile(new URL('creation-performance-graphics-proof-v1.json',root),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify(proof));
