// Scoped chooser milestone; never treats narrow UI evidence as full parity.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
const project=fileURLToPath(new URL('../',import.meta.url));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(project,file),'utf8'));
const current=async pins=>{assert.ok(Object.keys(pins).length);for(const [file,digest] of Object.entries(pins))assert.equal(sha(await fs.readFile(path.join(project,file))),digest,file+' changed');};
const receipts=[];
for(const [run,checks,graphical] of [
 ['native-auto-selection-chooser-graphical-v3',31,true],
 ['native-auto-selection-keyboard-graphical-v2',19,true],
 ['native-auto-selection-pages-graphical-v3',32,true],
 ['native-auto-selection-lifecycle-v2',17,false],
 ['native-auto-selection-probe-scope-v2',8,false]
]){
 const r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');
 assert.equal(r.success,true);assert.equal(r.checks,checks);assert.deepEqual(r.failures,[]);assert.equal(r.publicConnections,0);assert.equal(r.fullUiParity,false);
 for(const field of ['success','sourceUnchanged','armed','normalHeap'])assert.equal(p[field],true);
 for(const field of ['exception','engineOrLifetimeError'])assert.equal(p[field],false);
 assert.equal(p.graphical,graphical);assert.equal(p.debuggerExit,0);await current(p.sourceSha256);
 if(graphical){assert.equal(r.window.focused,false);assert.equal(r.window.unfocusable,true);assert.notEqual(r.window.screen,r.window.primary);assert.equal(r.window.mouse_mode,0);}
 receipts.push({run,checks,graphical});
}
for(const [run,checks] of [['native-auto-selection-local-v2',207],['native-auto-selection-menu-v1',12]]){
 const r=await read('reports/'+run+'.json');
 for(const field of ['success','sourceUnchanged','debuggerArmed'])assert.equal(r[field],true);
 assert.equal(r.nativeException,false);assert.equal(r.publicConnections,0);assert.equal(r.nativeExit,0);await current(r.sourceSha256);
 assert.equal(r.characterPreviewStorage.closed,true);assert.equal(r.characterPreviewStorage.files,0);
 const n=await read('reports/'+run+'.native.json');assert.equal(n.success,true);
 if(checks===207){
  assert.equal(r.endpoint,'127.0.0.1:5125');
  assert.equal(r.nativeChooserReady.success,true);assert.equal(r.nativeChooserReady.unadmitted,true);
  assert.equal(r.nativeChooserReady.key,r.nativeChooserReady.firstKey);
  assert.equal(r.nativeAdmission.success,true);assert.equal(Object.keys(r.nativeAdmission.checks).length,7);assert.ok(Object.values(r.nativeAdmission.checks).every(v=>v===true));
  for(const [field,count] of [['actions',170],['lobbyPages',18]]){assert.equal(r[field].success,true);assert.equal(r[field].checks.length,count);assert.ok(r[field].checks.every(row=>row.passed===true));}
  const {previewProofMatches}=await import('./native-character-preview-proof.cjs');const proof=r.characterPreviewProof;
  assert.equal(proof.success,true);assert.equal(proof.key,'installed:wizard.bic');assert.equal(previewProofMatches(proof,proof,r.characterPreviewExpected),true);
  assert.equal(r.characterPreviewStorage.written,2);assert.equal(r.characterPreviewStorage.removed,2);assert.equal(r.lobbyParticipant.closed,true);
  assert.ok(r.authoritativeDistance>0.2&&r.authoritativeDistance<2);assert.equal(n.workers_remaining,0);assert.equal(n.protocol_finish_ack,true);
 }else{
  assert.equal(n.pregame_entry.success,true);assert.equal(n.pregame_entry.connected,false);assert.equal(Object.keys(n.pregame_entry.checks).length,12);assert.ok(Object.values(n.pregame_entry.checks).every(v=>v===true));
  assert.equal(n.pregame_cleanup.closed,true);assert.equal(n.pregame_cleanup.workers_running,0);
  assert.equal(n.final_window.focused,false);assert.equal(n.final_window.unfocusable,true);assert.notEqual(n.final_window.screen,n.final_window.primary);assert.equal(n.final_window.mouse_mode,0);
 }
 receipts.push({run,checks,graphical:true,ownedLocal:checks===207});
}
const node=await promisify(execFile)(process.execPath,['--test',path.join(project,'tools/native-character-preview-proof.test.cjs')],{cwd:project});
assert.match(node.stdout,/# tests 17\b/);assert.match(node.stdout,/# pass 17\b/);assert.match(node.stdout,/# fail 0\b/);
receipts.push({run:'native-character-preview-proof.test.cjs',checks:17,stdoutSha256:sha(node.stdout)});
const evidence=await read('../backups/animations/rea-native-character-chooser-first-selection-v1.json');
assert.equal(evidence.subject.digest.sha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(evidence.authority,'shipped-artifact');assert.match(evidence.pseudocode,/SelectTab/);assert.match(evidence.pseudocode,/0x1c78/);assert.match(evidence.pseudocode,/FUN_?140712440/);
const crash=await read('reports/native-lobby-record-feats-v2.debugger.json');assert.equal(crash.exception,true);assert.equal(crash.success,false);
const historical=await read('reports/native-character-chooser-followup-pages-v1.json');assert.equal(historical.success,false);assert.equal(historical.failures.length,2);
for(const run of ['native-auto-selection-chooser-v1','native-auto-selection-pages-graphical-v1','native-auto-selection-local-v1','native-auto-selection-lifecycle-v1'])assert.equal((await read('reports/'+run+'.json')).success,false);
const archive='backups/native-character-auto-selection-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(project,archive))),checkpoint.sha256);
for(const row of checkpoint.manifest)assert.equal(sha(await fs.readFile(path.join(project,row.sourceScope==='workspace'?'../'+row.source:row.file))),row.sha256);
const sources={};for(const file of ['native_session_world.gd','systems/native_character_lobby.gd','systems/lobby_pages_probe.gd','systems/lobby_record_probe.gd','tools/native-session-host.cjs','tools/native-character-preview-proof.cjs','tools/native-character-preview-proof.test.cjs','tests/native_character_lobby_automatic_test.gd','NATIVE-CHARACTER-AUTO-SELECTION.md','../backups/animations/rea-native-character-chooser-first-selection-v1.json'])sources[file]=sha(await fs.readFile(path.join(project,file)));
const result={success:true,checks:receipts.reduce((sum,r)=>sum+r.checks,0),receipts,sources,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},automaticFirstSelectionImplemented:true,graphicalInputValidated:true,freshLocalValidated:true,exactOriginalAppearanceAccepted:false,publicConnections:0,headlessPlayerArtworkIssueResolved:false,startupExceptionResolved:false,fullStabilityParity:false,fullCharacterLobbyParity:false,fullUiParity:false,goalComplete:false,remaining:'See NATIVE-CHARACTER-AUTO-SELECTION.md and NATIVE-UI-PARITY-GOAL.md.'};assert.equal(result.checks,343);
await fs.writeFile(path.join(project,'reports/native-character-auto-selection-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:result.checks,checkpoint:result.checkpoint,freshLocalValidated:true,fullUiParity:false,goalComplete:false}));
