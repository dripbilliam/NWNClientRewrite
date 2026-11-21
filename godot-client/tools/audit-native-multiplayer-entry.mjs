// Scoped original Multiplayer navigation. Entire-UI acceptance remains false.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url)),workspace=path.resolve(home,'..');
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(home,file),'utf8'));
async function pinned(proof){assert.ok(Object.keys(proof.sourceSha256).length>100);for(const [file,digest] of Object.entries(proof.sourceSha256))assert.equal(sha(await fs.readFile(path.join(home,file))),digest,file+' changed');}
const receipts=[];
const service=spawnSync(process.execPath,['--test','tools/server-browser.test.mjs'],{cwd:home,encoding:'utf8'});
assert.equal(service.status,0,service.stdout+service.stderr);assert.match(service.stdout,/# tests 37\r?\n/);assert.match(service.stdout,/# pass 37\r?\n/);assert.match(service.stdout,/# fail 0\r?\n/);
await fs.writeFile(path.join(home,'reports/native-multiplayer-entry-service-audit-v1.tap'),service.stdout,{flag:'wx'});receipts.push({run:'native-multiplayer-entry-service-audit-v1',checks:37});
const result=await read('reports/native-multiplayer-entry-v3.json'),proof=await read('reports/native-multiplayer-entry-v3.debugger.json');
assert.equal(result.success,true);assert.equal(result.checks,35);assert.deepEqual(result.failures,[]);assert.equal(result.fullUiParity,false);assert.equal(result.fullMultiplayerMenuParity,false);assert.deepEqual(result.unportedActions,['New/Load hosting','LAN discovery']);
for(const key of ['success','armed','sourceUnchanged','normalHeap','graphical'])assert.equal(proof[key],true);for(const key of ['exception','engineOrLifetimeError'])assert.equal(proof[key],false);assert.equal(proof.debuggerExit,0);assert.equal(proof.publicConnections,0);await pinned(proof);
for(const key of ['focused'])assert.equal(result.window[key],false);assert.equal(result.window.unfocusable,true);assert.equal(result.window.mouse_mode,0);assert.notEqual(result.window.screen,result.window.primary);receipts.push({run:'native-multiplayer-entry-v3',checks:35});
for(const run of ['native-multiplayer-entry-startup-v3','native-multiplayer-entry-local-v3']){
 const r=await read('reports/'+run+'.json'),native=await read('reports/'+run+'.native.json');
 for(const key of ['success','sourceUnchanged','debuggerArmed'])assert.equal(r[key],true);assert.equal(r.nativeExit,0);assert.equal(r.nativeException,false);assert.equal(r.publicConnections,0);assert.equal(r.protocolOnly,true);assert.equal(r.renderingPrepared,false);assert.equal(r.forcedNativeStop,undefined);await pinned(r);
 assert.equal(native.pregame_cleanup.closed,true);assert.equal(native.pregame_cleanup.workers_running,0);
 if(run.includes('startup')){
  assert.equal(native.network_connections,0);assert.equal(native.pregame_entry.success,true);assert.equal(native.pregame_entry.art_ready_required,true);assert.equal(native.pregame_entry.headless_routes_only,false);assert.equal(Object.keys(native.pregame_entry.checks).length,10);assert.ok(Object.values(native.pregame_entry.checks).every(v=>v===true));
  assert.equal(native.offline_prework.ready,true);assert.equal(native.offline_prework.state.worker_failed,false);assert.equal(native.offline_ui_preload.ready,true);assert.equal(native.offline_ui_preload.state.cancelled,true);
  assert.equal(native.final_window.focused,false);assert.equal(native.final_window.unfocusable,true);assert.equal(native.final_window.mouse_mode,0);assert.notEqual(native.final_window.screen,native.final_window.primary);
  const finished=native.menu_check_stages.find(row=>row.stage==='ui_cancel_finished');assert.ok(finished&&finished.elapsed_ms<20000);receipts.push({run,checks:10});
 }else{
  assert.equal(r.endpoint,'127.0.0.1:5125');assert.equal(r.nativeAdmission.success,true);assert.equal(Object.keys(r.nativeAdmission.checks).length,7);assert.ok(Object.values(r.nativeAdmission.checks).every(v=>v===true));assert.equal(r.actions.checks.length,170);assert.ok(r.actions.checks.every(row=>row.passed));assert.deepEqual(r.actions.failures,[]);assert.equal(r.native.workersRemaining,0);receipts.push({run,checks:177});
 }
}
const archive='backups/native-multiplayer-entry-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(home,archive))),checkpoint.sha256);
for(const row of checkpoint.manifest){const file=row.sourceScope==='workspace'?path.join(workspace,row.source):path.join(home,row.file);assert.equal(sha(await fs.readFile(file)),row.sha256,row.file??row.source);}
const acceptance={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),goalComplete:false,fullUiParity:false,fullMultiplayerMenuParity:false,fullMigrationAccepted:false,publicConnections:0,receipts,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},remaining:'Hosting/LAN are unported. Original browser pages/filters/details, CD-key/password/connection/selection dialogs, role/scale/backdrop/audio/original-client comparisons and the rest of the full UI ledger remain unfinished.'};
await fs.writeFile(path.join(home,'reports/native-multiplayer-entry-acceptance-v1.json'),JSON.stringify(acceptance,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(acceptance));
