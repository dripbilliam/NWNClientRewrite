// Derived GPU evidence, without resource payloads or authentication traffic.
import fs from 'node:fs/promises';import assert from 'node:assert/strict';
const root=new URL('../backups/animations/',import.meta.url),load=async name=>JSON.parse(await fs.readFile(new URL(name,root),'utf8'));
const staticRun=await load('creation-performance-light-capacity-v1.json'),moving=await load('creation-performance-light-capacity-v2.json');
const summary=p=>{const times=[...p.completedFrameMs].sort((a,b)=>a-b);return{capacity:p.capacity,moving:p.moving??false,forcedShadowRefresh:p.forcedShadowRefresh??false,frames:times.length,meanMs:times.reduce((a,b)=>a+b)/times.length,p95Ms:times[Math.ceil(times.length*.95)-1],maxMs:times.at(-1),mainDraws:p.main.calls,shadowDraws:p.shadow.drawCalls,reusedLights:p.shadow.reusedLights,redrawnLights:p.shadow.renderedLights};};
for(const run of[staticRun,moving]){
 assert.deepEqual(run.errors,[]);assert.equal(run.changedBytes,0);assert.equal(run.maxByteDelta,0);assert.equal(run.width,3100);assert.equal(run.height,1121);
 for(const phase of run.phases){assert.equal(phase.main.calls,1275);assert.equal(phase.lighting.selection.admitted,42);assert.equal(phase.lighting.shadows.admitted,15);assert.equal(phase.completedFrameMs.length,24);}
}
assert.deepEqual(staticRun.phases.map(p=>p.capacity),[128,64,128,64]);assert.equal(moving.shadowSize,512);assert.equal(moving.movingShadows,true);
for(const p of moving.phases)assert.ok(p.shadowFrames.every(f=>p.forcedShadowRefresh?f.renderedLights===15:f.renderedLights>0&&f.reusedLights>0));
const proof={scope:'Synthetic isolated GPU experiment using production light/shadow adapters and Lambert shaders; no server connection',gpu:moving.gpu,resolution:[3100,1121],staticCapacity:staticRun.phases.map(summary),movingShadows:moving.phases.map(summary),changedPixelBytes:0,productionLightPolicyChanged:false,
 conclusion:'No useful improvement from reducing 128 declared light slots to 64 in this fixture. Existing moving-shadow cache matches full redraw at the same final poses. Retain production admission/reserve policy.',
 limits:'Synthetic low-poly objects and a one-pixel texture; no native/modded area, skinned animation, network latency, or long fullscreen acceptance. gl.finish includes driver/GPU completion. Static v1 uses64px shadow maps; moving v2 uses production512px maps. Pixel comparison covers final matching poses, not every intermediate frame.42*1.5 is63, which rounds up to64, not128; offscreen potential lights or an earlier retained capacity can explain a larger live pool.'};
await fs.writeFile(new URL('creation-performance-light-capacity-proof-v1.json',root),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify(proof));
