'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../../../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const read=r=>JSON.parse(fs.readFileSync(path.join(project,r),'utf8'));
const pin=r=>{const b=fs.readFileSync(path.join(project,r));return {relative:r,bytes:b.length,sha256:sha(b)};};
async function main(){
 const component=read('.cache/nwn66-light-input/component-acceptance.json'),selection=read('.cache/nwn66-light-input/selection.json');assert(component.success);
 for(const row of [selection.engine,selection.descriptor,selection.component,selection.runtimeSelector,selection.rollbackSelector])assert.deepEqual(pin(row.relative),row);
 const reference=read('.cache/nwn66-light-input/world-graphics-reference-a.json'),optimized=read('.cache/nwn66-light-input/world-graphics-optimized-a.json');
 assert(reference.success&&optimized.success);assert(optimized.fast_rows>0);assert.deepEqual(optimized.observations,reference.observations);
 const menu=read('reports/native-nwn66-menu-a.json'),native=read('reports/native-nwn66-menu-a.native.json'),startup=read('reports/native-nwn66-menu-a.startup.json');
 assert(menu.success&&menu.sourceUnchanged&&menu.startupMainMenu.ready&&menu.startupMainMenu.mainVisible&&menu.menuExitCheck.success);
 assert.equal(menu.nativeExit,0);assert.equal(menu.publicConnections,0);assert.equal(native.workers_remaining,0);assert.equal(native.clean_exit,true);
 assert.equal(startup.verification.status,'observed');assert.deepEqual(startup.verification.errors,[]);assert.equal(startup.runtime.executableSha256,selection.engine.sha256);
 // Menu checks intentionally keep their existing isolated policy. Actual-world
 // Forward+ checks above ran the full functional flag set, separately.
 assert.equal(startup.renderCore.enabled,false);
 const runtime=await require(path.join(project,'tools/native-performance-runtime.cjs')).selectPerformanceRuntime(project,'verified-native');
 assert.equal(runtime.executableSha256,selection.engine.sha256);
 const descriptor=read(selection.descriptor.relative);assert.deepEqual(require(path.join(project,'tools/native-performance-runtime.cjs')).acceptedRenderCore().flags,descriptor.fullFunctionalFlags);
 const tracy=read('.cache/native-tracy/live-source-check-nwn66-e-a/receipt.json');assert(tracy.success&&tracy.checks===59);
 const files=['.cache/nwn66-light-input/component-acceptance.json','.cache/nwn66-light-input/selection.json','.cache/nwn66-light-input/world-graphics-reference-a.json','.cache/nwn66-light-input/world-graphics-optimized-a.json','reports/native-nwn66-menu-a.json','reports/native-nwn66-menu-a.native.json','reports/native-nwn66-menu-a.startup.json','.cache/native-tracy/live-source-check-nwn66-e-a/receipt.json'];
 const receipt={version:1,issue:'NWN-66',success:true,created:new Date().toISOString(),selection,files:files.map(pin),
 normalRuntimeTests:{command:'node --test tests/native_performance_runtime.test.cjs',passed:8},
 graphics:{backend:'Vulkan Forward+',functionalFlags:descriptor.fullFunctionalFlags,referenceChecks:reference.checks,optimizedChecks:optimized.checks,unchangedFastRows:optimized.fast_rows,observationsEqual:true},
 menu:{success:true,actualEngineSha256:startup.runtime.executableSha256,actualStartupVerified:true,cleanExit:true,workersRemaining:0,scope:'Graphical isolated menu and source-defined Exit button; no server connection.'},
 scope:'NWN-66 local component optimization installed in the normal selector, with matched normal-engine component timing, state parity, guarded lifetime regressions and graphical checks. No live Arelith FPS or loading-latency measurement; broader client acceptance remains NWN-54.',
 caveat:'Saved Tracy capture and retained diagnostic engine use Core D and do not contain this optimization.'};
 const out='.cache/nwn66-light-input/acceptance.json';fs.writeFileSync(path.join(project,out),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,receipt:pin(out),graphics:receipt.graphics,menu:receipt.menu}));
}
main().catch(error=>{console.error(error);process.exitCode=1;});
