// Scoped catalog/preparation cancellation. No entire-UI/FPS acceptance.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url)),workspace=path.resolve(home,'..');
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(home,file),'utf8'));
async function pinned(proof){assert.ok(Object.keys(proof.sourceSha256).length>100);for(const [file,digest] of Object.entries(proof.sourceSha256))assert.equal(sha(await fs.readFile(path.join(home,file))),digest,file+' changed');}
const receipts=[];
for(const [run,count] of [['native-catalog-cancel-v2',13],['native-ui-cancel-preload-cold-v2',24],['native-ui-cancel-preload-warm-v1',21]]){
 const result=await read('reports/'+run+'.json'),proof=await read('reports/'+run+'.debugger.json');assert.equal(result.success,true);assert.equal(result.checks,count);assert.deepEqual(result.failures,[]);
 for(const key of ['success','armed','sourceUnchanged','normalHeap'])assert.equal(proof[key],true);for(const key of ['exception','engineOrLifetimeError'])assert.equal(proof[key],false);assert.equal(proof.debuggerExit,0);assert.equal(proof.publicConnections,0);await pinned(proof);receipts.push({run,checks:count});
}
const cold=await read('reports/native-ui-cancel-preload-cold-v2.json'),warm=await read('reports/native-ui-cancel-preload-warm-v1.json');assert.equal(cold.preload.gui_documents,104);assert.ok(cold.preload.rendered>0);assert.ok(cold.preload.saved>0);assert.equal(warm.preload.rendered,0);assert.ok(warm.preload.reused>0);assert.equal(cold.all_models,false);assert.equal(warm.all_models,false);
const observations={};
for(const run of ['native-ui-cancel-startup-v1','native-ui-cancel-local-v1']){
 const r=await read('reports/'+run+'.json'),native=await read('reports/'+run+'.native.json');
 for(const key of ['success','sourceUnchanged','debuggerArmed'])assert.equal(r[key],true);assert.equal(r.nativeExit,0);assert.equal(r.nativeException,false);assert.equal(r.publicConnections,0);assert.equal(r.protocolOnly,true);assert.equal(r.renderingPrepared,false);assert.equal(r.forcedNativeStop,undefined);await pinned(r);assert.equal(native.pregame_cleanup.closed,true);assert.equal(native.pregame_cleanup.workers_running,0);
 if(run.includes('startup')){
  assert.equal(native.network_connections,0);assert.equal(native.pregame_entry.success,true);assert.equal(native.pregame_entry.art_ready_required,true);assert.equal(native.pregame_entry.headless_routes_only,false);assert.equal(Object.keys(native.pregame_entry.checks).length,7);assert.ok(Object.values(native.pregame_entry.checks).every(v=>v===true));assert.equal(native.offline_prework.ready,true);assert.equal(native.offline_prework.state.worker_failed,false);assert.equal(native.offline_ui_preload.ready,true);assert.equal(native.offline_ui_preload.state.cancelled,true);
  assert.equal(native.final_window.focused,false);assert.equal(native.final_window.unfocusable,true);assert.equal(native.final_window.mouse_mode,0);assert.notEqual(native.final_window.screen,native.final_window.primary);
  const stages=native.menu_check_stages;for(const name of ['entry_begin','entry_ready','model_cancel_requested','model_cancel_finished','ui_cancel_requested','ui_cancel_finished'])assert.ok(stages.some(row=>row.stage===name));
  const at=name=>stages.find(row=>row.stage===name).elapsed_ms;assert.ok(at('ui_cancel_finished')<20000);observations.traceMs=at('ui_cancel_finished');observations.modelCancelMs=at('model_cancel_finished')-at('model_cancel_requested');observations.uiCancelMs=at('ui_cancel_finished')-at('ui_cancel_requested');observations.catalog=native.pregame_entry.state.catalog;receipts.push({run,checks:9});
 }else{assert.equal(r.endpoint,'127.0.0.1:5125');assert.equal(r.nativeAdmission.success,true);assert.equal(Object.keys(r.nativeAdmission.checks).length,7);assert.ok(Object.values(r.nativeAdmission.checks).every(v=>v===true));assert.equal(r.actions.checks.length,170);assert.ok(r.actions.checks.every(row=>row.passed));assert.deepEqual(r.actions.failures,[]);assert.equal(r.native.workersRemaining,0);receipts.push({run,checks:177});}
}
const archive='backups/native-ui-cancellation-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(home,archive))),checkpoint.sha256);for(const row of checkpoint.manifest){const file=row.sourceScope==='workspace'?path.join(workspace,row.source):path.join(home,row.file);assert.equal(sha(await fs.readFile(file)),row.sha256);}
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),goalComplete:false,fullUiParity:false,fullMigrationAccepted:false,originalBinaryRenderingParity:false,generalLoadingPerformanceAccepted:false,userContentStartupCancelCheckAccepted:true,allMenuPixelsPrepared:false,publicConnections:0,existingWatchdogMs:20000,observations,receipts,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},remaining:'Original multiplayer entry tier and server-browser pages, role/scale/original-client comparisons and the entire UI ledger remain incomplete. Source cancellation waits for the current indivisible read/parse/helper step; no universal latency bound is claimed. Selected-model cold/reuse checks are not a completed all-menu bake or a general FPS/loading benchmark.'};
await fs.writeFile(path.join(home,'reports/native-ui-cancellation-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:result.checks,traceMs:observations.traceMs,watchdogMs:20000,goalComplete:false,checkpoint:result.checkpoint}));
