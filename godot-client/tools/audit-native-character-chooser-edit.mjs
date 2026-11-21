import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=fileURLToPath(new URL('../',import.meta.url));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(project,file),'utf8'));
const pins=async values=>{assert.ok(Object.keys(values).length);for(const [file,digest] of Object.entries(values))assert.equal(sha(await fs.readFile(path.join(project,file))),digest,file+' changed');};
const receipts=[];
for(const [run,checks] of [['native-chooser-edit-graphical-v1',94],['native-chooser-edit-cursor-graphical-v1',19]]){
 const r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');
 assert.equal(r.success,true);assert.equal(r.checks,checks);assert.deepEqual(r.failures,[]);assert.equal(r.publicConnections,0);assert.equal(r.fullUiParity,false);
 for(const field of ['success','sourceUnchanged','armed','normalHeap','graphical'])assert.equal(p[field],true);
 for(const field of ['exception','engineOrLifetimeError'])assert.equal(p[field],false);
 assert.equal(p.debuggerExit,0);await pins(p.sourceSha256);
 assert.equal(r.window.focused,false);assert.equal(r.window.unfocusable,true);assert.notEqual(r.window.screen,r.window.primary);assert.equal(r.window.mouse_mode,0);
 receipts.push({run,checks,graphical:true});
}
const run='native-chooser-edit-local-v1',r=await read('reports/'+run+'.json'),n=await read('reports/'+run+'.native.json');
for(const field of ['success','sourceUnchanged','debuggerArmed'])assert.equal(r[field],true);assert.equal(r.nativeException,false);assert.equal(r.nativeExit,0);assert.equal(r.publicConnections,0);assert.equal(r.endpoint,'127.0.0.1:5125');await pins(r.sourceSha256);
assert.equal(r.nativeAdmission.success,true);assert.equal(Object.keys(r.nativeAdmission.checks).length,7);assert.ok(Object.values(r.nativeAdmission.checks).every(v=>v===true));
for(const [field,count] of [['lobbyPages',18],['actions',170]]){assert.equal(r[field].success,true);assert.equal(r[field].checks.length,count);assert.ok(r[field].checks.every(row=>row.passed===true));}
assert.equal(r.lobbyPages.checks.filter(row=>row.label==='Original focused pregame edit keys retain chooser focus without opening gameplay/menu/chat or submitting a character'&&row.passed).length,1);
const {previewProofMatches}=await import('./native-character-preview-proof.cjs');assert.equal(r.characterPreviewProof.success,true);assert.equal(previewProofMatches(r.characterPreviewProof,r.characterPreviewProof,r.characterPreviewExpected),true);
assert.equal(r.characterPreviewStorage.closed,true);assert.equal(r.characterPreviewStorage.files,0);assert.equal(r.characterPreviewStorage.written,2);assert.equal(r.characterPreviewStorage.removed,2);assert.equal(r.lobbyParticipant.closed,true);
assert.equal(n.success,true);assert.equal(n.workers_remaining,0);assert.equal(n.protocol_finish_ack,true);assert.ok(r.authoritativeDistance>0.2&&r.authoritativeDistance<2);receipts.push({run,checks:207,ownedLocal:true});
const binary='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
const oracle=await read('../backups/animations/native-character-chooser-edit-observations-v2.json');assert.equal(oracle.target,binary);assert.equal(oracle.rows.length,64);assert.equal(new Set(oracle.rows.map(row=>JSON.stringify(row.case))).size,64);
for(const row of oracle.rows){assert.equal(row.handled,1);assert.deepEqual(row.constructor,{submitCallback:'0x1401e58c0',cancelCallback:'0x1401e58c0',next:0,previous:0});if(row.case.key===9)assert.deepEqual(row.calls,row.case.links?[['focus',true]]:[]);if(row.case.key===27)assert.deepEqual(row.calls,[]);if([10,13].includes(row.case.key))assert.deepEqual(row.calls,[['insert',10]]);}
const evidence=await read('../backups/animations/rea-native-character-chooser-edit-input-v2.json');assert.equal(evidence.binarySha256,binary);for(const row of Object.values(evidence.rows)){assert.equal(row.subject.digest.sha256,binary);assert.equal(row.authority,'shipped-artifact');assert.ok(row.procedure.body.available);assert.ok(row.pseudocode);}
assert.equal(evidence.rows.edit.procedure.address,'0x1401e99b0');assert.equal(evidence.rows.editCtor.procedure.address,'0x1401e7dc0');assert.equal(evidence.rows.emptyCallback.procedure.address,'0x1401e58c0');assert.match(evidence.rows.edit.pseudocode,/return 1/);assert.match(evidence.rows.setup.pseudocode,/SetFocus/);
const before=await read('reports/native-chooser-edit-before-v1.json'),beforeProof=await read('reports/native-chooser-edit-before-v1.debugger.json');assert.equal(before.success,false);assert.equal(before.failures.length,23);assert.equal(beforeProof.sourceUnchanged,true);assert.equal(beforeProof.exception,false);assert.equal(beforeProof.engineOrLifetimeError,false);
const crash=await read('reports/native-lobby-record-feats-v2.debugger.json');assert.equal(crash.exception,true);assert.equal(crash.success,false);
const archive='backups/native-character-chooser-edit-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(project,archive))),checkpoint.sha256);for(const row of checkpoint.manifest)assert.equal(sha(await fs.readFile(path.join(project,row.sourceScope==='workspace'?'../'+row.source:row.file))),row.sha256);
const sources={};for(const file of ['systems/native_character_lobby.gd','systems/lobby_pages_probe.gd','tests/native_character_lobby_edit_test.gd','../scripts/inspect-native-character-chooser-edit.py','../backups/animations/rea-native-character-chooser-edit-input-v2.json','../backups/animations/native-character-chooser-edit-observations-v2.json','../backups/animations/rea-native-character-pregen-persistence-v1.json','NATIVE-CHARACTER-CHOOSER-EDIT.md'])sources[file]=sha(await fs.readFile(path.join(project,file)));
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),receipts,sources,checkpoint:{file:archive,files:checkpoint.files,sha256:checkpoint.sha256},focusedChooserEditInput:true,freshLocalValidated:true,graphicalInputValidated:true,publicConnections:0,exactOriginalAppearanceAccepted:false,pregeneratedPersistenceImplemented:false,fullCharacterLobbyParity:false,fullUiParity:false,fullStabilityParity:false,startupExceptionResolved:false,headlessPlayerArtworkIssueResolved:false,goalComplete:false,remaining:'See NATIVE-CHARACTER-CHOOSER-EDIT.md and NATIVE-UI-PARITY-GOAL.md.'};assert.equal(result.checks,320);
await fs.writeFile(path.join(project,'reports/native-character-chooser-edit-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:result.checks,checkpoint:result.checkpoint,fullUiParity:false,goalComplete:false}));
