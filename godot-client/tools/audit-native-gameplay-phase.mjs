// Scoped presentation/input/admission evidence, never a full UI completion audit.
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
const receipts=[];
for(const [run,checks,graphical] of [['native-gameplay-phase-graphical-v2',22,true],['native-gameplay-phase-headless-v4',20,false],['native-gameplay-phase-policy-v1',17,false]]){
 const r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');
 assert.equal(r.success,true);assert.equal(r.checks,checks);assert.deepEqual(r.failures,[]);assert.equal(r.publicConnections,0);assert.equal(r.fullUiParity,false);
 for(const key of ['success','sourceUnchanged','armed','normalHeap'])assert.equal(p[key],true);
 assert.equal(p.graphical,graphical);assert.equal(p.exception,false);assert.equal(p.engineOrLifetimeError,false);assert.equal(p.debuggerExit,0);await pinned(p);
 if(graphical){assert.equal(r.window.focused,false);assert.equal(r.window.unfocusable,true);assert.equal(r.window.mouse_mode,0);assert.notEqual(r.window.screen,r.window.primary);}
 receipts.push({run,checks});
}
for(const run of ['native-gameplay-phase-startup-v2','native-gameplay-phase-local-v2']){
 const r=await read('reports/'+run+'.json'),n=await read('reports/'+run+'.native.json');
 for(const key of ['success','sourceUnchanged','debuggerArmed','protocolOnly'])assert.equal(r[key],true);
 assert.equal(r.nativeExit,0);assert.equal(r.nativeException,false);assert.equal(r.publicConnections,0);assert.equal(r.forcedNativeStop,undefined);await pinned(r);
 assert.equal(n.startup_window.non_activating,true);assert.notEqual(n.startup_window.screen,n.startup_window.primary);
 assert.equal(n.pregame_cleanup.closed,true);assert.equal(n.pregame_cleanup.workers_running,0);
 if(run.includes('startup')){
  assert.equal(n.network_connections,0);assert.equal(n.pregame_entry.success,true);assert.equal(n.pregame_entry.art_ready_required,true);
  assert.equal(Object.keys(n.pregame_entry.checks).length,12);assert.ok(Object.values(n.pregame_entry.checks).every(Boolean));assert.equal(n.final_window.focused,false);assert.notEqual(n.final_window.screen,n.final_window.primary);receipts.push({run,checks:12});
 }else{
  assert.equal(r.endpoint,'127.0.0.1:5125');assert.equal(r.nativeAdmission.success,true);assert.equal(Object.keys(r.nativeAdmission.checks).length,7);assert.ok(Object.values(r.nativeAdmission.checks).every(Boolean));
  assert.equal(r.lobbyPages.success,true);assert.equal(r.lobbyPages.checks.length,18);assert.ok(r.lobbyPages.checks.every(row=>row.passed));assert.equal(n.lobby_pages.success,true);
  for(const label of ['Native chooser stays visible without gameplay chat or stale renderer status','Pregame keys cannot open hidden gameplay menus, focus chat or submit a character'])assert.ok(r.lobbyPages.checks.some(row=>row.label===label&&row.passed));
  assert.deepEqual(r.lobbyPageAuthoritative,{success:true,observerSubmitted:false,observerWorldObjects:0});assert.deepEqual(r.lobbyPageWire.sent,[[112,49,1],[112,49,2],[112,49,1],[112,49,2]]);
  assert.ok(r.lobbyPageWire.received.some(row=>row.present&&row.id===r.lobbyPages.rosterId));assert.ok(r.lobbyPageWire.received.some(row=>!row.present&&row.id===r.lobbyPages.rosterId));assert.equal(r.lobbyParticipant.closed,true);
  assert.equal(r.actions.checks.length,170);assert.ok(r.actions.checks.every(row=>row.passed));assert.deepEqual(r.actions.failures,[]);assert.equal(r.native.workersRemaining,0);
  for(const key of ['gameplay_visible','gameplay_canvas_visible','chat_visible_in_tree'])assert.equal(r.native.gameplayUi.startup[key],true);
  assert.equal(n.loading_screen.active,false);assert.equal(n.loading_screen.error,'');assert.ok(n.loading_screen.completed>=1);receipts.push({run,checks:195});
 }
}
const headlessFailure=await read('reports/native-gameplay-phase-headless-v2.json');
assert.equal(headlessFailure.success,false);assert.deepEqual(headlessFailure.failures,['Borrowed chooser artwork completes without enabling the game canvas']);
const priorBlood=await read('reports/native-lobby-live-local-v2.json');
assert.equal(priorBlood.success,false);assert.deepEqual(priorBlood.actions.failures,['Actual original blood models change the native viewport after the real server hit']);
const inputs=['tools/native-lobby.test.mjs','tools/native-portal-lobby.test.mjs','tools/native-lobby-pages.test.mjs','../test/network-server-vault.test.js','../test/server-discovery.test.js','../test/native-private-participant-key.test.cjs'];
const sources={};for(const file of [...inputs,'tools/native-lobby-participant.mjs','tools/native-lobby.mjs','tools/native-session-host.cjs','tools/native-session-bootstrap.cjs','../electron/network_game_session.mjs','../electron/server_browser.mjs','../src/network_character_selection.js'])sources[file]=sha(await fs.readFile(path.join(project,file)));
const service=spawnSync(process.execPath,['--test',...inputs.map(file=>path.join(project,file))],{cwd:workspace,encoding:'utf8',windowsHide:true});
assert.equal(service.status,0,service.stdout+service.stderr);assert.match(service.stdout,/# tests 46\r?\n/);assert.match(service.stdout,/# pass 46\r?\n/);assert.match(service.stdout,/# fail 0\r?\n/);
for(const [file,digest] of Object.entries(sources))assert.equal(sha(await fs.readFile(path.join(project,file))),digest);receipts.push({run:'native-gameplay-phase-service-v1',checks:46});
const archive='backups/native-gameplay-phase-v1.zip',checkpoint=await read(archive+'.verified.json');
assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(project,archive))),checkpoint.sha256);
for(const row of checkpoint.manifest)assert.equal(sha(await fs.readFile(path.join(project,row.sourceScope==='workspace'?'../'+row.source:row.file))),row.sha256);
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),receipts,sources,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},publicConnections:0,fullUiParity:false,fullOriginalPhaseComparison:false,fullBloodRenderingParity:false,goalComplete:false,retainedFailures:{headlessArtwork:'native-gameplay-phase-headless-v2',restrictedSetup:'native-gameplay-phase-headless-v1',priorBlood:'native-lobby-live-local-v2',bloodRootCauseAccepted:false},remaining:'See NATIVE-GAMEPLAY-PHASE.md and NATIVE-UI-PARITY-GOAL.md. Original visual/role/scale/audio, full transition variants, chooser record/local editing, all other UI inventory gaps and the prior blood-pixel/pending-wind issues remain open.'};
assert.equal(result.checks,312);
await fs.writeFile(path.join(project,'reports/native-gameplay-phase-service-v1.tap'),service.stdout,{flag:'wx'});
await fs.writeFile(path.join(project,'reports/native-gameplay-phase-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,checks:result.checks,checkpoint:result.checkpoint,goalComplete:false}));
