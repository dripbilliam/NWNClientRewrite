// Scoped native-preview evidence; never accepts complete record/UI parity.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=fileURLToPath(new URL('../',import.meta.url));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(project,file),'utf8'));
async function pinned(proof){assert.ok(Object.keys(proof.sourceSha256).length);for(const [file,digest] of Object.entries(proof.sourceSha256))assert.equal(sha(await fs.readFile(path.join(project,file))),digest,file+' changed');}
const receipts=[];
for(const [suffix,checks,graphical] of [['worker-v3',24,false],['frame-v3',15,true],['chooser-v2',25,true],['pages-v1',32,true],['phase-v1',22,true]]){
 const run='native-character-preview-'+suffix,r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');
 assert.equal(r.success,true);assert.equal(r.checks,checks);assert.deepEqual(r.failures,[]);assert.equal(r.publicConnections,0);
 for(const key of ['success','sourceUnchanged','armed','normalHeap'])assert.equal(p[key],true);
 assert.equal(p.graphical,graphical);assert.equal(p.exception,false);assert.equal(p.engineOrLifetimeError,false);assert.equal(p.debuggerExit,0);await pinned(p);
 if(graphical){assert.equal(r.window.focused,false);assert.equal(r.window.unfocusable,true);assert.equal(r.window.mouse_mode,0);assert.notEqual(r.window.screen,r.window.primary);}
 receipts.push({run,checks});
}
for(const suffix of ['startup-v1','local-v2']){
 const run='native-character-preview-'+suffix,r=await read('reports/'+run+'.json'),n=await read('reports/'+run+'.native.json');
 for(const key of ['success','sourceUnchanged','debuggerArmed','protocolOnly'])assert.equal(r[key],true);
 assert.equal(r.nativeExit,0);assert.equal(r.nativeException,false);assert.equal(r.publicConnections,0);assert.equal(r.forcedNativeStop,undefined);await pinned(r);
 assert.equal(n.startup_window.non_activating,true);assert.notEqual(n.startup_window.screen,n.startup_window.primary);assert.equal(n.pregame_cleanup.closed,true);assert.equal(n.pregame_cleanup.workers_running,0);
 assert.equal(r.characterPreviewStorage.closed,true);assert.equal(r.characterPreviewStorage.files,0);assert.equal(r.characterPreviewCleanupFailed,undefined);
 if(suffix.startsWith('startup')){
  assert.equal(n.network_connections,0);assert.equal(r.characterPreviewStorage.written,0);assert.equal(n.pregame_entry.success,true);assert.equal(n.pregame_entry.art_ready_required,true);assert.equal(Object.keys(n.pregame_entry.checks).length,12);assert.ok(Object.values(n.pregame_entry.checks).every(Boolean));assert.equal(n.final_window.focused,false);receipts.push({run,checks:12});
 }else{
  assert.equal(r.endpoint,'127.0.0.1:5125');assert.equal(r.nativeAdmission.success,true);assert.equal(Object.keys(r.nativeAdmission.checks).length,7);assert.ok(Object.values(r.nativeAdmission.checks).every(Boolean));
  assert.equal(r.lobbyPages.success,true);assert.equal(r.lobbyPages.checks.length,18);assert.ok(r.lobbyPages.checks.every(row=>row.passed));assert.equal(r.lobbyParticipant.closed,true);assert.deepEqual(r.lobbyPageAuthoritative,{success:true,observerSubmitted:false,observerWorldObjects:0});
  assert.equal(r.actions.checks.length,170);assert.ok(r.actions.checks.every(row=>row.passed));assert.deepEqual(r.actions.failures,[]);assert.equal(r.native.workersRemaining,0);
  const proof=r.characterPreviewProof;assert.equal(proof.success,true);assert.equal(proof.native_only,true);assert.equal(proof.title_matches,true);for(const key of ['sha256','abilities','classes','skill_count','feat_count','spell_count'])assert.deepEqual(proof[key],r.characterPreviewExpected[key]);
  assert.equal(n.character_preview.closed,true);assert.equal(n.character_preview.worker_running,false);assert.equal(n.character_preview.decoded,1);assert.equal(n.character_preview.failed,0);assert.equal(n.character_preview.derived_combat_ready,false);assert.equal(r.characterPreviewStorage.written,1);assert.equal(r.characterPreviewStorage.removed,1);receipts.push({run,checks:195});
 }
 await assert.rejects(fs.access(path.join(project,'../runtime-logs/native-character-previews',run)),{code:'ENOENT'});
}
const tap=await fs.readFile(path.join(project,'reports/native-character-preview-service-v2.tap'),'utf8');assert.match(tap,/# tests 55\r?\n/);assert.match(tap,/# pass 55\r?\n/);assert.match(tap,/# fail 0\r?\n/);receipts.push({run:'native-character-preview-service-v2',checks:55});
const inputs=['tools/native-lobby.test.mjs','tools/native-portal-lobby.test.mjs','tools/native-lobby-pages.test.mjs','../test/network-server-vault.test.js','../test/server-discovery.test.js','../test/native-private-participant-key.test.cjs','tools/native-character-preview-store.test.mjs','../test/network-character-preview-native.test.mjs'];
const serviceSources={};for(const file of inputs)serviceSources[file]=sha(await fs.readFile(path.join(project,file)));
const service=spawnSync(process.execPath,['--test',...inputs.map(file=>path.join(project,file))],{cwd:path.resolve(project,'..'),encoding:'utf8',windowsHide:true});assert.equal(service.status,0,service.stdout+service.stderr);assert.match(service.stdout,/# tests 55\r?\n/);assert.match(service.stdout,/# pass 55\r?\n/);assert.match(service.stdout,/# fail 0\r?\n/);for(const [file,digest] of Object.entries(serviceSources))assert.equal(sha(await fs.readFile(path.join(project,file))),digest);
const failed=await read('reports/native-character-preview-local-v1.json');assert.equal(failed.success,false);assert.equal(failed.actions.success,true);assert.equal(failed.failure,'Native engine or lifetime errors');
const archive='backups/native-character-preview-v2.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(project,archive))),checkpoint.sha256);for(const row of checkpoint.manifest)assert.equal(sha(await fs.readFile(path.join(project,row.sourceScope==='workspace'?'../'+row.source:row.file))),row.sha256);
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),receipts,serviceSources,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},publicConnections:0,nativePreviewProjection:true,derivedCombatParity:false,fullRecordPages:false,fullUiParity:false,goalComplete:false,retainedFailure:'native-character-preview-local-v1',remaining:'See NATIVE-CHARACTER-PREVIEW.md and NATIVE-UI-PARITY-GOAL.md.'};assert.equal(result.checks,380);
await fs.writeFile(path.join(project,'reports/native-character-preview-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
