// Scoped receipt audit; full UI/browser acceptance deliberately remains false.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=fileURLToPath(new URL('../',import.meta.url)),workspace=path.resolve(project,'..');
const hash=data=>createHash('sha256').update(data).digest('hex');
const read=async name=>JSON.parse(await fs.readFile(path.join(project,name),'utf8'));
async function pinned(receipt){for(const [file,digest] of Object.entries(receipt.sourceSha256)){assert.equal(hash(await fs.readFile(path.join(project,file))),digest,file+' changed');}}
const receipts=[];
for(const [run,checks] of [['native-server-details-input-v2',28],['native-server-details-pages-v1',32]]){
 const r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');assert.equal(r.success,true);assert.equal(r.checks,checks);assert.deepEqual(r.failures,[]);
 for(const key of ['success','sourceUnchanged','armed','normalHeap','graphical'])assert.equal(p[key],true);for(const key of ['exception','engineOrLifetimeError'])assert.equal(p[key],false);assert.equal(p.debuggerExit,0);await pinned(p);
 assert.equal(r.window.focused,false);assert.equal(r.window.unfocusable,true);assert.equal(r.window.mouse_mode,0);assert.notEqual(r.window.screen,r.window.primary);receipts.push({run,checks});
}
for(const run of ['native-server-details-startup-v1','native-server-details-local-v1']){
 const r=await read('reports/'+run+'.json'),n=await read('reports/'+run+'.native.json');for(const key of ['success','sourceUnchanged','debuggerArmed','protocolOnly'])assert.equal(r[key],true);assert.equal(r.nativeExit,0);assert.equal(r.nativeException,false);assert.equal(r.publicConnections,0);assert.equal(r.forcedNativeStop,undefined);assert.equal(r.renderingPrepared,false);await pinned(r);
 for(const file of ['../src/server_discovery.js','../src/gff_text.js','../electron/server_browser.mjs','tools/server-browser-service.mjs','tools/server-browser-store.mjs','tools/local-protocol.cjs','systems/native_server_details.gd','systems/native_server_password.gd'])assert.ok(r.sourceSha256[file]);
 assert.equal(n.pregame_cleanup.closed,true);assert.equal(n.pregame_cleanup.workers_running,0);
 if(run.includes('startup')){assert.equal(n.network_connections,0);assert.equal(n.pregame_entry.success,true);assert.equal(n.pregame_entry.art_ready_required,true);assert.ok(Object.values(n.pregame_entry.checks).every(Boolean));assert.equal(Object.keys(n.pregame_entry.checks).length,12);assert.equal(n.final_window.focused,false);assert.notEqual(n.final_window.screen,n.final_window.primary);receipts.push({run,checks:12});}
 else{assert.equal(r.endpoint,'127.0.0.1:5125');assert.equal(r.nativeAdmission.success,true);assert.equal(Object.keys(r.nativeAdmission.checks).length,7);assert.ok(Object.values(r.nativeAdmission.checks).every(Boolean));assert.equal(r.actions.checks.length,170);assert.ok(r.actions.checks.every(row=>row.passed));assert.deepEqual(r.actions.failures,[]);assert.equal(r.native.workersRemaining,0);receipts.push({run,checks:177});}
}
const tap=await fs.readFile(path.join(project,'reports/native-server-details-service-v3.tap'),'utf8');assert.match(tap,/# tests 56\r?\n/);assert.match(tap,/# pass 56\r?\n/);assert.match(tap,/# fail 0\r?\n/);receipts.push({run:'native-server-details-service-v3',checks:56});
const wire=await read('reports/native-server-details-local-wire-v1.json');assert.equal(wire.parsed.type,'details');assert.equal(wire.queried.extendedReceived,true);assert.equal(wire.queried.host,'127.0.0.1');assert.equal(wire.queried.port,5125);assert.equal(wire.parsed.serverVersion,'8193');
const archive='backups/native-server-details-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(hash(await fs.readFile(path.join(project,archive))),checkpoint.sha256);for(const row of checkpoint.manifest){assert.equal(hash(await fs.readFile(row.sourceScope==='workspace'?path.join(workspace,row.source):path.join(project,row.file))),row.sha256);}
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),receipts,publicConnections:0,fullUiParity:false,fullServerBrowserParity:false,fullDetailsParity:false,goalComplete:false,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},remaining:'See NATIVE-SERVER-DETAILS.md and entire UI parity ledger; no full-goal acceptance implied.'};
await fs.writeFile(path.join(project,'reports/native-server-details-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
