// Scoped chooser evidence only: full UI/chooser parity remains incomplete.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=fileURLToPath(new URL('../',import.meta.url)),workspace=path.resolve(project,'..');
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(project,file),'utf8'));
async function pinned(p){for(const [file,digest] of Object.entries(p.sourceSha256))assert.equal(hash(await fs.readFile(path.join(project,file))),digest,file+' changed');}
const run='native-character-chooser-graphical-v3',r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');
assert.equal(r.success,true);assert.equal(r.checks,25);assert.deepEqual(r.failures,[]);assert.equal(r.publicConnections,0);
for(const key of ['success','sourceUnchanged','armed','normalHeap','graphical'])assert.equal(p[key],true);
for(const key of ['exception','engineOrLifetimeError'])assert.equal(p[key],false);
assert.equal(p.debuggerExit,0);await pinned(p);
assert.equal(r.window.focused,false);assert.equal(r.window.unfocusable,true);assert.equal(r.window.mouse_mode,0);assert.notEqual(r.window.screen,r.window.primary);
const receipts=[{run,checks:25}];
for(const name of ['native-character-chooser-startup-v1','native-character-chooser-local-v1']){
 const report=await read('reports/'+name+'.json'),native=await read('reports/'+name+'.native.json');
 for(const key of ['success','sourceUnchanged','debuggerArmed','protocolOnly'])assert.equal(report[key],true);
 assert.equal(report.nativeExit,0);assert.equal(report.nativeException,false);assert.equal(report.publicConnections,0);assert.equal(report.forcedNativeStop,undefined);await pinned(report);
 assert.equal(native.pregame_cleanup.closed,true);assert.equal(native.pregame_cleanup.workers_running,0);
 if(name.includes('startup')){
  assert.equal(native.network_connections,0);assert.equal(native.pregame_entry.success,true);assert.equal(native.pregame_entry.art_ready_required,true);
  assert.equal(Object.keys(native.pregame_entry.checks).length,12);assert.ok(Object.values(native.pregame_entry.checks).every(Boolean));
  assert.equal(native.final_window.focused,false);assert.notEqual(native.final_window.screen,native.final_window.primary);receipts.push({run:name,checks:12});
 }else{
  assert.equal(report.endpoint,'127.0.0.1:5125');assert.equal(report.nativeAdmission.success,true);assert.equal(Object.keys(report.nativeAdmission.checks).length,7);assert.ok(Object.values(report.nativeAdmission.checks).every(Boolean));
  assert.equal(report.actions.checks.length,170);assert.ok(report.actions.checks.every(row=>row.passed));assert.deepEqual(report.actions.failures,[]);assert.equal(report.native.workersRemaining,0);receipts.push({run:name,checks:177});
 }
}
const serviceInputs=['tools/native-lobby.mjs','tools/native-lobby.test.mjs','tools/native-portal-lobby.test.mjs'];const services={};
for(const file of serviceInputs)services[file]=hash(await fs.readFile(path.join(project,file)));
const service=spawnSync(process.execPath,['--test',...serviceInputs.slice(1).map(file=>'godot-client/'+file)],{cwd:workspace,encoding:'utf8',windowsHide:true});
assert.equal(service.status,0,service.stdout+service.stderr);assert.match(service.stdout,/# tests 23\r?\n/);assert.match(service.stdout,/# pass 23\r?\n/);assert.match(service.stdout,/# fail 0\r?\n/);
for(const [file,digest] of Object.entries(services))assert.equal(hash(await fs.readFile(path.join(project,file))),digest);
receipts.push({run:'native-character-chooser-service-audit-v1',checks:23});
const evidence={};
for(const file of ['rea-native-character-chooser-v1.json','rea-native-character-record-owner-v1.json','rea-native-character-lobby-pages-v1.json']){
 const bytes=await fs.readFile(path.join(workspace,'backups/animations',file));assert.equal(JSON.parse(bytes).binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');evidence[file]=hash(bytes);
}
const archive='backups/native-character-chooser-v1.zip',checkpoint=await read(archive+'.verified.json');
assert.equal(checkpoint.verified,true);assert.equal(hash(await fs.readFile(path.join(project,archive))),checkpoint.sha256);
for(const row of checkpoint.manifest)assert.equal(hash(await fs.readFile(path.join(project,row.sourceScope==='workspace'?'../'+row.source:row.file))),row.sha256);
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),receipts,services,evidence,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},publicConnections:0,fullUiParity:false,fullCharacterChooserParity:false,goalComplete:false,remaining:'NATIVE-CHARACTER-LOBBY.md lists disabled pages, local mutation/metadata, automatic/keyboard selection, complete record and original visual/state/role/scale comparison still required.'};
await fs.writeFile(path.join(project,'reports/native-character-chooser-service-audit-v1.tap'),service.stdout,{flag:'wx'});
await fs.writeFile(path.join(project,'reports/native-character-chooser-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,checks:result.checks,checkpoint:result.checkpoint,goalComplete:false}));
