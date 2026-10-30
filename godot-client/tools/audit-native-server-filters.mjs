// Scoped original filter migration; full browser/UI acceptance remains false.
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
const oracleBytes=await fs.readFile(path.join(workspace,'backups/animations/native-server-filter-observations-v1.json')),oracle=JSON.parse(oracleBytes);
assert.equal(oracle.rows.length,4480);assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(sha(await fs.readFile(path.join(workspace,'scripts/inspect-native-server-filters.py'))),oracle.harnessSha256);
assert.equal(sha(await fs.readFile(path.resolve(workspace,'../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe'))),oracle.binarySha256);
const service=spawnSync(process.execPath,['--test','tools/server-browser.test.mjs'],{cwd:home,encoding:'utf8'});assert.equal(service.status,0,service.stdout+service.stderr);assert.match(service.stdout,/# tests 43\r?\n/);assert.match(service.stdout,/# pass 43\r?\n/);assert.match(service.stdout,/# fail 0\r?\n/);
await fs.writeFile(path.join(home,'reports/native-server-filter-service-audit-v1.tap'),service.stdout,{flag:'wx'});receipts.push({run:'native-server-filter-service-audit-v1',checks:43,originalInstructionRows:4480});
for(const [run,count] of [['native-server-filter-input-v4',23],['native-server-filter-browser-regression-v2',22],['native-server-filter-entry-regression-v1',35],['native-server-browser-source-v2',5]]){
 const r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');assert.equal(r.success,true);assert.equal(r.checks,count);assert.deepEqual(r.failures,[]);
 for(const key of ['success','armed','sourceUnchanged','normalHeap'])assert.equal(p[key],true);for(const key of ['exception','engineOrLifetimeError'])assert.equal(p[key],false);assert.equal(p.debuggerExit,0);assert.equal(p.publicConnections,0);await pinned(p);
 if(run.includes('input')||run.includes('entry')){assert.equal(p.graphical,true);assert.equal(r.window.focused,false);assert.equal(r.window.unfocusable,true);assert.equal(r.window.mouse_mode,0);assert.notEqual(r.window.screen,r.window.primary);assert.equal(r.fullUiParity,false);}
 if(run.includes('source')){assert.equal(Object.keys(r.layouts.serverlist_page1.controls).length,28);for(const tag of ['ctl_serverlist','modulenamelist','playerlist','levellist','pvplist','synclist'])assert.ok(r.layouts.serverlist_page1.controls[tag]);assert.equal(Object.keys(r.layouts.serverlist_filt.controls).length,10);}
 receipts.push({run,checks:count});
}
for(const run of ['native-server-filter-startup-v2','native-server-filter-local-v1']){
 const r=await read('reports/'+run+'.json'),native=await read('reports/'+run+'.native.json');
 for(const key of ['success','sourceUnchanged','debuggerArmed'])assert.equal(r[key],true);assert.equal(r.nativeExit,0);assert.equal(r.nativeException,false);assert.equal(r.publicConnections,0);assert.equal(r.protocolOnly,true);assert.equal(r.renderingPrepared,false);assert.equal(r.forcedNativeStop,undefined);await pinned(r);assert.equal(native.pregame_cleanup.closed,true);assert.equal(native.pregame_cleanup.workers_running,0);
 if(run.includes('startup')){
  assert.equal(native.network_connections,0);assert.equal(native.pregame_entry.success,true);assert.equal(native.pregame_entry.art_ready_required,true);assert.equal(native.pregame_entry.headless_routes_only,false);assert.equal(Object.keys(native.pregame_entry.checks).length,12);assert.ok(Object.values(native.pregame_entry.checks).every(v=>v===true));
  assert.equal(native.offline_prework.ready,true);assert.equal(native.offline_prework.state.worker_failed,false);assert.equal(native.offline_ui_preload.ready,true);assert.equal(native.offline_ui_preload.state.cancelled,true);assert.ok(native.menu_check_stages.find(row=>row.stage==='ui_cancel_finished').elapsed_ms<20000);
  assert.equal(native.final_window.focused,false);assert.equal(native.final_window.unfocusable,true);assert.equal(native.final_window.mouse_mode,0);assert.notEqual(native.final_window.screen,native.final_window.primary);receipts.push({run,checks:12});
 }else{assert.equal(r.endpoint,'127.0.0.1:5125');assert.equal(r.nativeAdmission.success,true);assert.equal(Object.keys(r.nativeAdmission.checks).length,7);assert.ok(Object.values(r.nativeAdmission.checks).every(v=>v===true));assert.equal(r.actions.checks.length,170);assert.ok(r.actions.checks.every(row=>row.passed));assert.deepEqual(r.actions.failures,[]);assert.equal(r.native.workersRemaining,0);receipts.push({run,checks:177});}
}
const archive='backups/native-server-filters-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(home,archive))),checkpoint.sha256);
for(const row of checkpoint.manifest){const file=row.sourceScope==='workspace'?path.join(workspace,row.source):path.join(home,row.file);assert.equal(sha(await fs.readFile(file)),row.sha256,row.file??row.source);}
assert.ok(checkpoint.manifest.some(row=>row.source==='scripts/inspect-native-server-filters.py'));
const acceptance={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),originalInstructionRows:4480,oracleSha256:sha(oracleBytes),goalComplete:false,fullUiParity:false,fullServerBrowserParity:false,fullMigrationAccepted:false,publicConnections:0,receipts,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},remaining:'Main list pages remain generic. Original browser list/scroll/sort/details/password/connection/selection, input limits/gestures, all role/scale/audio/backdrop/original-client comparisons and the complete UI ledger remain unfinished.'};
await fs.writeFile(path.join(home,'reports/native-server-filter-acceptance-v1.json'),JSON.stringify(acceptance,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(acceptance));
