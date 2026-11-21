// Scoped native chooser page receipts. Never accepts full UI/chooser parity.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=fileURLToPath(new URL('../',import.meta.url)),workspace=path.resolve(project,'..');
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(project,file),'utf8'));
async function pinned(proof){for(const [file,digest] of Object.entries(proof.sourceSha256))assert.equal(sha(await fs.readFile(path.join(project,file))),digest,file+' changed');}
const run='native-lobby-pages-input-graphical-v3',r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');
assert.equal(r.success,true);assert.equal(r.checks,32);assert.deepEqual(r.failures,[]);assert.equal(r.publicConnections,0);
for(const key of ['success','sourceUnchanged','armed','normalHeap','graphical'])assert.equal(p[key],true);
for(const key of ['exception','engineOrLifetimeError'])assert.equal(p[key],false);
assert.equal(p.debuggerExit,0);await pinned(p);
assert.equal(r.window.focused,false);assert.equal(r.window.unfocusable,true);assert.equal(r.window.mouse_mode,0);assert.notEqual(r.window.screen,r.window.primary);
const receipts=[{run,checks:32}];
for(const name of ['native-lobby-pages-startup-v3','native-lobby-pages-local-v2']){
 const report=await read('reports/'+name+'.json'),native=await read('reports/'+name+'.native.json');
 for(const key of ['success','sourceUnchanged','debuggerArmed','protocolOnly'])assert.equal(report[key],true);
 assert.equal(report.nativeExit,0);assert.equal(report.nativeException,false);assert.equal(report.publicConnections,0);assert.equal(report.forcedNativeStop,undefined);await pinned(report);
 assert.equal(native.pregame_cleanup.closed,true);assert.equal(native.pregame_cleanup.workers_running,0);
 if(name.includes('startup')){
  assert.equal(native.network_connections,0);assert.equal(native.pregame_entry.success,true);assert.equal(native.pregame_entry.art_ready_required,true);
  assert.equal(Object.keys(native.pregame_entry.checks).length,12);assert.ok(Object.values(native.pregame_entry.checks).every(Boolean));assert.equal(native.final_window.focused,false);assert.notEqual(native.final_window.screen,native.final_window.primary);receipts.push({run:name,checks:12});
 }else{
  assert.equal(report.endpoint,'127.0.0.1:5125');assert.equal(report.nativeAdmission.success,true);assert.equal(Object.keys(report.nativeAdmission.checks).length,7);assert.ok(Object.values(report.nativeAdmission.checks).every(Boolean));
  assert.equal(report.actions.checks.length,170);assert.ok(report.actions.checks.every(row=>row.passed));assert.deepEqual(report.actions.failures,[]);assert.equal(report.native.workersRemaining,0);receipts.push({run:name,checks:177});
 }
}
const inputs=['tools/native-lobby.test.mjs','tools/native-portal-lobby.test.mjs','tools/native-lobby-pages.test.mjs','../test/network-server-vault.test.js','../test/server-discovery.test.js'];
const sources={};for(const file of [...inputs,'tools/native-lobby.mjs','../electron/network_game_session.mjs','../electron/server_browser.mjs','../src/network_character_selection.js','../src/network_game_messages.js','../src/server_discovery.js'])sources[file]=sha(await fs.readFile(path.join(project,file)));
const service=spawnSync(process.execPath,['--test',...inputs.map(file=>path.join(project,file))],{cwd:workspace,encoding:'utf8',windowsHide:true});
assert.equal(service.status,0,service.stdout+service.stderr);assert.match(service.stdout,/# tests 44\r?\n/);assert.match(service.stdout,/# pass 44\r?\n/);assert.match(service.stdout,/# fail 0\r?\n/);
for(const [file,digest] of Object.entries(sources))assert.equal(sha(await fs.readFile(path.join(project,file))),digest);
receipts.push({run:'native-lobby-pages-service-audit-v1',checks:44});
const bytes=await fs.readFile(path.join(workspace,'backups/animations/rea-native-lobby-pages-v1.json')),evidence=JSON.parse(bytes);
assert.equal(evidence.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
for(const key of ['lobby-player-row-ctor','character-select-server-details','lobby-dialog-font-initialization','0x1404df850','0x14045c5e0','0x14045c7d0'])assert.ok(evidence.rows[key].normalized_result.pseudocode);
const archive='backups/native-lobby-pages-v1.zip',checkpoint=await read(archive+'.verified.json');
assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(project,archive))),checkpoint.sha256);
for(const row of checkpoint.manifest)assert.equal(sha(await fs.readFile(path.join(project,row.sourceScope==='workspace'?'../'+row.source:row.file))),row.sha256);
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),receipts,sources,evidenceSha256:sha(bytes),checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},publicConnections:0,fullUiParity:false,fullCharacterChooserParity:false,liveTwoParticipantRosterAccepted:false,goalComplete:false,remaining:'See NATIVE-LOBBY-PAGES.md. Fresh two-participant live roster and original-client role/state/large-font/scale/audio comparison remain open; embedded record/local editing/keyboard and whole UI still incomplete.'};
await fs.writeFile(path.join(project,'reports/native-lobby-pages-service-audit-v1.tap'),service.stdout,{flag:'wx'});
await fs.writeFile(path.join(project,'reports/native-lobby-pages-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,checks:result.checks,checkpoint:result.checkpoint,goalComplete:false}));
