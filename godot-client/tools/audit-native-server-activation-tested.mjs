// Verify scoped graphical/local evidence; this does not accept full UI parity.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=fileURLToPath(new URL('../',import.meta.url));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(project,file),'utf8'));
async function pinned(proof){
 for(const [file,digest] of Object.entries(proof.sourceSha256))
  assert.equal(sha(await fs.readFile(path.join(project,file))),digest,file+' changed');
}
const receipts=[];
for(const [run,checks] of [
 ['native-server-activation-graphical-v1',24],
 ['native-server-activation-keys-graphical-v2',15],
 ['native-server-activation-details-graphical-v1',31],
 ['native-server-activation-entry-graphical-v1',35],
 ['native-server-activation-pages-graphical-v1',32]
]){
 const r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');
 assert.equal(r.success,true);assert.equal(r.checks,checks);assert.deepEqual(r.failures,[]);
 assert.equal(r.publicConnections,0);
 for(const key of ['success','sourceUnchanged','armed','normalHeap','graphical'])assert.equal(p[key],true);
 for(const key of ['exception','engineOrLifetimeError'])assert.equal(p[key],false);
 assert.equal(p.debuggerExit,0);await pinned(p);
 if(r.window){assert.equal(r.window.focused,false);assert.equal(r.window.unfocusable,true);assert.equal(r.window.mouse_mode,0);assert.notEqual(r.window.screen,r.window.primary);}
 receipts.push({run,checks,graphical:true});
}
for(const run of ['native-server-activation-startup-v1','native-server-activation-local-v1']){
 const r=await read('reports/'+run+'.json'),n=await read('reports/'+run+'.native.json');
 for(const key of ['success','sourceUnchanged','debuggerArmed','protocolOnly'])assert.equal(r[key],true);
 assert.equal(r.nativeExit,0);assert.equal(r.nativeException,false);assert.equal(r.publicConnections,0);
 assert.equal(r.forcedNativeStop,undefined);assert.equal(r.renderingPrepared,false);await pinned(r);
 assert.equal(n.pregame_cleanup.closed,true);assert.equal(n.pregame_cleanup.workers_running,0);
 if(run.includes('startup')){
  assert.equal(n.network_connections,0);assert.equal(n.pregame_entry.success,true);
  assert.equal(n.pregame_entry.art_ready_required,true);assert.equal(Object.keys(n.pregame_entry.checks).length,12);
  assert.ok(Object.values(n.pregame_entry.checks).every(Boolean));
  assert.equal(n.final_window.focused,false);assert.equal(n.final_window.unfocusable,true);
  assert.equal(n.final_window.mouse_mode,0);assert.notEqual(n.final_window.screen,n.final_window.primary);
  receipts.push({run,checks:12});
 }else{
  assert.equal(r.endpoint,'127.0.0.1:5125');assert.equal(r.nativeAdmission.success,true);
  assert.equal(Object.keys(r.nativeAdmission.checks).length,7);assert.ok(Object.values(r.nativeAdmission.checks).every(Boolean));
  assert.equal(r.actions.checks.length,170);assert.ok(r.actions.checks.every(row=>row.passed));
  assert.deepEqual(r.actions.failures,[]);assert.equal(r.native.workersRemaining,0);
  receipts.push({run,checks:177});
 }
}
const tap=await fs.readFile(path.join(project,'reports/native-server-activation-service-graphical-v1.tap'),'utf8');
assert.match(tap,/# tests 59\r?\n/);assert.match(tap,/# pass 59\r?\n/);assert.match(tap,/# fail 0\r?\n/);
receipts.push({run:'native-server-activation-service-graphical-v1',checks:59});
const archive='backups/native-server-activation-tested-v1.zip',checkpoint=await read(archive+'.verified.json');
assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(project,archive))),checkpoint.sha256);
for(const row of checkpoint.manifest)assert.equal(sha(await fs.readFile(path.join(project,row.sourceScope==='workspace'?'../'+row.source:row.file))),row.sha256);
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),receipts,
 checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},
 publicConnections:0,graphicalChecksPassed:true,localServerChecksPassed:true,
 fullUiParity:false,fullServerBrowserParity:false,goalComplete:false,
 remaining:'See NATIVE-SERVER-ACTIVATION.md and the full UI goal. Original role/scale/audio/status and broader menu migration remain open.'};
await fs.writeFile(path.join(project,'reports/native-server-activation-tested-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,checks:result.checks,checkpoint:result.checkpoint,goalComplete:false}));
