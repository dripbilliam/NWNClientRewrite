// Scoped original page migration. This cannot accept the full browser/UI goal.
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
const receipts=[],oracles=[];
const binary=sha(await fs.readFile(path.resolve(workspace,'../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe')));
assert.equal(binary,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
for(const [name,script,count] of [['native-server-filter-observations-v1.json','inspect-native-server-filters.py',4480],['native-browser-sort-observations-v1.json','inspect-native-browser-sort.py',4608]]){
 const bytes=await fs.readFile(path.join(workspace,'backups/animations',name)),oracle=JSON.parse(bytes);assert.equal(oracle.binarySha256,binary);assert.equal(oracle.rows.length,count);assert.equal(sha(await fs.readFile(path.join(workspace,'scripts',script))),oracle.harnessSha256);oracles.push({file:name,rows:count,sha256:sha(bytes)});
}
const service=spawnSync(process.execPath,['--test','tools/server-browser.test.mjs'],{cwd:home,encoding:'utf8',windowsHide:true});assert.equal(service.status,0,service.stdout+service.stderr);assert.match(service.stdout,/# tests 46\r?\n/);assert.match(service.stdout,/# pass 46\r?\n/);assert.match(service.stdout,/# fail 0\r?\n/);
await fs.writeFile(path.join(home,'reports/native-server-pages-service-audit-v1.tap'),service.stdout,{flag:'wx'});receipts.push({run:'native-server-pages-service-audit-v1',checks:46});
for(const [run,count] of [['native-server-pages-input-v4',32],['native-server-pages-entry-v3',35],['native-server-pages-filter-v1',23],['native-server-pages-generic-v1',22],['native-server-pages-catalog-v2',5]]){
 const r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');assert.equal(r.success,true);assert.equal(r.checks,count);assert.deepEqual(r.failures,[]);
 for(const key of ['success','armed','sourceUnchanged','normalHeap'])assert.equal(p[key],true);for(const key of ['exception','engineOrLifetimeError'])assert.equal(p[key],false);assert.equal(p.debuggerExit,0);assert.equal(p.publicConnections,0);await pinned(p);
 if(r.window){assert.equal(p.graphical,true);assert.equal(r.window.focused,false);assert.equal(r.window.unfocusable,true);assert.equal(r.window.mouse_mode,0);assert.notEqual(r.window.screen,r.window.primary);assert.equal(r.fullUiParity,false);}
 if(run.includes('input'))assert.equal(r.fullServerBrowserParity,false);
 if(run.includes('catalog')){assert.equal(r.gameTypesError,'');assert.equal(r.gameTypes.orderedRows.length,13);assert.equal(Object.keys(r.layouts.serverlist_page1.controls).length,28);for(const tag of ['ctl_serverlist','modulenamelist','playerlist','levellist','pvplist','synclist'])assert.ok(r.layouts.serverlist_page1.controls[tag]);}
 receipts.push({run,checks:count});
}
const browserSources=['tools/server-browser-service.mjs','tools/server-browser-store.mjs','tools/server-browser-filters.mjs','tools/server-browser-sort.mjs','tools/server-endpoint.mjs','tools/local-protocol.cjs','systems/native_server_browser.gd','systems/native_data/server_browser_layout.gd'];
for(const run of ['native-server-pages-startup-v2','native-server-pages-local-v2']){
 const r=await read('reports/'+run+'.json'),native=await read('reports/'+run+'.native.json');
 for(const key of ['success','sourceUnchanged','debuggerArmed'])assert.equal(r[key],true);assert.equal(r.nativeExit,0);assert.equal(r.nativeException,false);assert.equal(r.publicConnections,0);assert.equal(r.protocolOnly,true);assert.equal(r.renderingPrepared,false);assert.equal(r.forcedNativeStop,undefined);await pinned(r);for(const file of browserSources)assert.ok(r.sourceSha256[file],file+' omitted from runtime receipt');
 assert.equal(native.pregame_cleanup.closed,true);assert.equal(native.pregame_cleanup.workers_running,0);
 if(run.includes('startup')){
  assert.equal(native.network_connections,0);assert.equal(native.pregame_entry.success,true);assert.equal(native.pregame_entry.art_ready_required,true);assert.equal(native.pregame_entry.headless_routes_only,false);assert.equal(Object.keys(native.pregame_entry.checks).length,12);assert.ok(Object.values(native.pregame_entry.checks).every(v=>v===true));assert.equal(native.pregame_entry.browser.ready,true);assert.equal(native.pregame_entry.browser.native_only,true);assert.equal(native.pregame_entry.browser.full_browser_parity,false);assert.deepEqual(native.pregame_entry.browser.source_pages,['Internet','History','Favorites']);
  assert.equal(native.offline_prework.ready,true);assert.equal(native.offline_prework.state.worker_failed,false);assert.equal(native.offline_ui_preload.ready,true);assert.equal(native.offline_ui_preload.state.cancelled,true);assert.ok(native.menu_check_stages.find(row=>row.stage==='ui_cancel_finished').elapsed_ms<20000);
  assert.equal(native.final_window.focused,false);assert.equal(native.final_window.unfocusable,true);assert.equal(native.final_window.mouse_mode,0);assert.notEqual(native.final_window.screen,native.final_window.primary);receipts.push({run,checks:12});
 }else{assert.equal(r.endpoint,'127.0.0.1:5125');assert.equal(r.nativeAdmission.success,true);assert.equal(Object.keys(r.nativeAdmission.checks).length,7);assert.ok(Object.values(r.nativeAdmission.checks).every(v=>v===true));assert.equal(r.actions.checks.length,170);assert.ok(r.actions.checks.every(row=>row.passed));assert.deepEqual(r.actions.failures,[]);assert.equal(r.native.workersRemaining,0);receipts.push({run,checks:177});}
}
const archive='backups/native-server-pages-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(home,archive))),checkpoint.sha256);
for(const row of checkpoint.manifest){const file=row.sourceScope==='workspace'?path.join(workspace,row.source):path.join(home,row.file);assert.equal(sha(await fs.readFile(file)),row.sha256,row.file??row.source);}assert.ok(checkpoint.manifest.some(row=>row.source==='scripts/inspect-native-browser-sort.py'));
const acceptance={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),originalInstructionRows:oracles.reduce((sum,row)=>sum+row.rows,0),oracles,goalComplete:false,fullUiParity:false,fullServerBrowserParity:false,fullMigrationAccepted:false,publicConnections:0,receipts,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},remaining:'Game-type filtering remains readonly; full original Details/password/connection owners, double-click/keyboard, PvP/NWSync status text, complete comparator, bounded labels, all role/scale/audio/backdrop/original-client comparisons and the entire UI ledger remain unfinished.'};
await fs.writeFile(path.join(home,'reports/native-server-pages-acceptance-v1.json'),JSON.stringify(acceptance,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(acceptance));
