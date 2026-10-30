// Source/pixel/worker/local evidence for GUI model sampling only.
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
for(const [run,checks,graphical] of [['native-gui-sampler-pixels-v3',126,true],['native-gui-sampler-prework-v4',34,false],['native-gui-sampler-chooser-v2',25,true],['native-gui-sampler-pages-v1',32,true],['native-gui-sampler-phase-v1',22,true]]){
 const r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');
 assert.equal(r.success,true);assert.equal(r.checks,checks);assert.deepEqual(r.failures,[]);assert.equal(r.publicConnections,0);
 for(const key of ['success','sourceUnchanged','armed','normalHeap'])assert.equal(p[key],true);
 assert.equal(p.graphical,graphical);assert.equal(p.exception,false);assert.equal(p.engineOrLifetimeError,false);assert.equal(p.debuggerExit,0);await pinned(p);
 if(graphical){assert.equal(r.window.focused,false);assert.equal(r.window.unfocusable,true);assert.equal(r.window.mouse_mode,0);assert.notEqual(r.window.screen,r.window.primary);}
 receipts.push({run,checks});
}
for(const run of ['native-gui-sampler-startup-v1','native-gui-sampler-local-v1']){
 const r=await read('reports/'+run+'.json'),n=await read('reports/'+run+'.native.json');
 for(const key of ['success','sourceUnchanged','debuggerArmed','protocolOnly'])assert.equal(r[key],true);
 assert.equal(r.nativeExit,0);assert.equal(r.nativeException,false);assert.equal(r.publicConnections,0);assert.equal(r.forcedNativeStop,undefined);await pinned(r);
 assert.equal(n.startup_window.non_activating,true);assert.notEqual(n.startup_window.screen,n.startup_window.primary);assert.equal(n.pregame_cleanup.closed,true);assert.equal(n.pregame_cleanup.workers_running,0);
 if(run.includes('startup')){
  assert.equal(n.network_connections,0);assert.equal(n.pregame_entry.success,true);assert.equal(n.pregame_entry.art_ready_required,true);assert.equal(Object.keys(n.pregame_entry.checks).length,12);assert.ok(Object.values(n.pregame_entry.checks).every(Boolean));assert.equal(n.final_window.focused,false);receipts.push({run,checks:12});
 }else{
  assert.equal(r.endpoint,'127.0.0.1:5125');assert.equal(r.nativeAdmission.success,true);assert.equal(Object.keys(r.nativeAdmission.checks).length,7);assert.ok(Object.values(r.nativeAdmission.checks).every(Boolean));
  assert.equal(r.lobbyPages.success,true);assert.equal(r.lobbyPages.checks.length,18);assert.ok(r.lobbyPages.checks.every(row=>row.passed));assert.equal(n.lobby_pages.success,true);assert.equal(r.lobbyParticipant.closed,true);
  assert.deepEqual(r.lobbyPageAuthoritative,{success:true,observerSubmitted:false,observerWorldObjects:0});assert.deepEqual(r.lobbyPageWire.sent,[[112,49,1],[112,49,2],[112,49,1],[112,49,2]]);assert.ok(r.lobbyPageWire.received.some(row=>row.present&&row.id===r.lobbyPages.rosterId));assert.ok(r.lobbyPageWire.received.some(row=>!row.present&&row.id===r.lobbyPages.rosterId));
  assert.equal(r.actions.checks.length,170);assert.ok(r.actions.checks.every(row=>row.passed));assert.deepEqual(r.actions.failures,[]);assert.equal(r.native.workersRemaining,0);for(const key of ['gameplay_visible','gameplay_canvas_visible','chat_visible_in_tree'])assert.equal(r.native.gameplayUi.startup[key],true);receipts.push({run,checks:195});
 }
}
const oracle=await read('../backups/animations/native-gui-sampler-observations-v1.json'),binary=await read('../backups/animations/rea-native-gui-sampler-v1.json');
assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(binary.binarySha256,oracle.binarySha256);assert.equal(oracle.samplers.length,64);assert.equal(oracle.fields.length,41);
for(const evidence of Object.values(binary.rows)){assert.ok(evidence);assert.equal(evidence.subject.digest.sha256,oracle.binarySha256);assert.equal(evidence.authority,'shipped-artifact');}
const original=await read('reports/native-lobby-art-source-v2.json');assert.equal(original.success,true);assert.match(original.rasters.gui_boxes_ingame.txi.text,/filter 0/);assert.match(original.rasters.gui_pre_playtabs.txi.text,/clamp 3/);
const rejected=await read('reports/native-gui-sampler-reuse-v5.json'),rejectedProof=await read('reports/native-gui-sampler-reuse-v5.debugger.json');assert.equal(rejected.success,false);assert.ok(rejected.failures.some(label=>label.includes('Unrecorded native resource: pnl_party_bar:2022')));assert.equal(rejectedProof.sourceUnchanged,true);assert.equal(rejectedProof.engineOrLifetimeError,false);assert.equal(rejectedProof.exception,false);assert.equal(rejectedProof.debuggerExit,1);await pinned(rejectedProof);
const policyFailure=await read('reports/native-gui-sampler-pixels-v1.json');assert.equal(policyFailure.success,false);assert.equal(policyFailure.failures.length,16);assert.ok(policyFailure.failures.every(label=>label.startsWith('GUI sampler policy matches captured original GL')));
const priorBlood=await read('reports/native-lobby-live-local-v2.json');assert.equal(priorBlood.success,false);assert.ok(priorBlood.actions.failures.includes('Actual original blood models change the native viewport after the real server hit'));
const inputs=['tools/native-lobby.test.mjs','tools/native-portal-lobby.test.mjs','tools/native-lobby-pages.test.mjs','../test/network-server-vault.test.js','../test/server-discovery.test.js','../test/native-private-participant-key.test.cjs'];
const sources={};for(const file of [...inputs,'../scripts/inspect-native-gui-sampler.py','../backups/animations/native-gui-sampler-observations-v1.json','../backups/animations/rea-native-gui-sampler-v1.json','reports/native-lobby-art-source-v2.json','reports/native-gui-sampler-tabs-animation-v1.json'])sources[file]=sha(await fs.readFile(path.join(project,file)));
const service=spawnSync(process.execPath,['--test',...inputs.map(file=>path.join(project,file))],{cwd:workspace,encoding:'utf8',windowsHide:true});assert.equal(service.status,0,service.stdout+service.stderr);assert.match(service.stdout,/# tests 46\r?\n/);assert.match(service.stdout,/# pass 46\r?\n/);assert.match(service.stdout,/# fail 0\r?\n/);for(const [file,digest] of Object.entries(sources))assert.equal(sha(await fs.readFile(path.join(project,file))),digest);receipts.push({run:'native-gui-sampler-service-v1',checks:46});
const archive='backups/native-gui-sampler-v2.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(project,archive))),checkpoint.sha256);for(const row of checkpoint.manifest)assert.equal(sha(await fs.readFile(path.join(project,row.sourceScope==='workspace'?'../'+row.source:row.file))),row.sha256);
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),receipts,sources,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},publicConnections:0,fullGuiSamplerParity:false,fullUiParity:false,oldSealedCorpusRegressionAccepted:false,fullBloodRenderingParity:false,goalComplete:false,retainedFailures:{samplerPolicy:'native-gui-sampler-pixels-v1',oldSealedCorpus:'native-gui-sampler-reuse-v5',priorBlood:'native-lobby-live-local-v2'},remaining:'See NATIVE-GUI-SAMPLER.md and NATIVE-UI-PARITY-GOAL.md. Old capture TXI closure, original GPU/state/scale comparison, anisotropy/other TXI and direct canvas sampling, record/local BIC/editing/keyboard and every other open UI surface remain unfinished.'};assert.equal(result.checks,492);
await fs.writeFile(path.join(project,'reports/native-gui-sampler-service-v1.tap'),service.stdout,{flag:'wx'});await fs.writeFile(path.join(project,'reports/native-gui-sampler-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:result.checks,checkpoint:result.checkpoint,oldSealedCorpusRegressionAccepted:false,goalComplete:false}));
