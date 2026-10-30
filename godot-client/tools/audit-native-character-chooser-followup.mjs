// Scoped original cursor/title follow-up; graphical/local acceptance is open.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=fileURLToPath(new URL('../',import.meta.url));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(project,file),'utf8'));
const receipts=[];
for(const [kind,checks] of [['key-policy',386],['keyboard',19],['preview',13],['chooser',23],['stats',25],['phase',20],['numbers',802],['details',225],['worker',24],['skills',373],['spells',296]]){
 const run='native-character-chooser-followup-'+kind+'-v1',r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');
 assert.equal(r.success,true);assert.equal(r.checks,checks);assert.deepEqual(r.failures,[]);assert.equal(r.publicConnections,0);assert.equal(r.fullUiParity,false);
 for(const key of ['success','sourceUnchanged','armed','normalHeap'])assert.equal(p[key],true);
 for(const key of ['graphical','exception','engineOrLifetimeError'])assert.equal(p[key],false);
 assert.equal(p.debuggerExit,0);assert.ok(Object.keys(p.sourceSha256).length);
 for(const [file,digest] of Object.entries(p.sourceSha256))assert.equal(sha(await fs.readFile(path.join(project,file))),digest,file+' changed');
 receipts.push({run,checks,graphical:false});
}
const binary='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
const oracle=await read('../backups/animations/native-character-chooser-key-observations-v1.json');assert.equal(oracle.target,binary);assert.equal(oracle.rows.length,192);assert.ok(oracle.rows.some(r=>r.calls.some(c=>c[0]==='scroll')));
const evidence=await read('../backups/animations/rea-native-character-chooser-keys-title-v1.json');assert.equal(evidence.binarySha256,binary);for(const row of Object.values(evidence.rows)){assert.equal(row.subject.digest.sha256,binary);assert.equal(row.authority,'shipped-artifact');assert.ok(row.pseudocode);}
assert.equal(evidence.rows.keyHandler.procedure.address,'0x140710a90');assert.match(evidence.rows.title.pseudocode,/0xf182/);assert.match(evidence.rows.title.pseudocode,/%s, %s/);
const pending=await read('../backups/animations/rea-native-character-chooser-first-selection-v1.json');assert.equal(pending.subject.digest.sha256,binary);assert.equal(pending.authority,'shipped-artifact');assert.match(pending.pseudocode,/SelectTab/);assert.match(pending.pseudocode,/0x1c78/);
const failedRun='native-character-chooser-followup-pages-v1',failed=await read('reports/'+failedRun+'.json'),failedProof=await read('reports/'+failedRun+'.debugger.json');assert.equal(failed.success,false);assert.equal(failed.checks,28);assert.deepEqual(failed.failures,['Original Player List scrollbar artwork prepares before input','Original Player List scrollbar advances one44-pixel received row']);assert.equal(failedProof.sourceUnchanged,true);assert.equal(failedProof.graphical,false);assert.equal(failedProof.exception,false);assert.equal(failedProof.engineOrLifetimeError,false);
for(const [file,digest] of Object.entries(failedProof.sourceSha256))assert.equal(sha(await fs.readFile(path.join(project,file))),digest,file+' changed');
const crash=await read('reports/native-lobby-record-feats-v2.debugger.json');assert.equal(crash.exception,true);assert.equal(crash.success,false);
const sources={};
for(const file of ['../scripts/inspect-native-character-chooser-keys.py','../backups/animations/native-character-chooser-key-observations-v1.json','../backups/animations/rea-native-character-chooser-keys-title-v1.json','../backups/animations/rea-native-character-chooser-first-selection-v1.json','systems/native_data/character_lobby_keys.gd','systems/native_character_lobby.gd','systems/lobby_record_probe.gd','native_session_world.gd','tests/native_character_lobby_keys_test.gd','tests/native_character_lobby_keyboard_frame_test.gd','tests/native_character_preview_frame_test.gd','NATIVE-CHARACTER-CHOOSER-KEYS.md'])sources[file]=sha(await fs.readFile(path.join(project,file)));
const archive='backups/native-character-chooser-keys-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(project,archive))),checkpoint.sha256);
for(const row of checkpoint.manifest)assert.equal(sha(await fs.readFile(path.join(project,row.sourceScope==='workspace'?'../'+row.source:row.file))),row.sha256);
const result={success:true,checks:receipts.reduce((sum,r)=>sum+r.checks,0),receipts,sources,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},publicConnections:0,nativeChooserCursorKeys:true,nativeRecordTitle:true,graphicalValidated:false,freshLocalValidated:false,fullCharacterLobbyParity:false,fullUiParity:false,fullStabilityParity:false,startupExceptionResolved:false,retainedStartupException:'native-lobby-record-feats-v2',retainedUnacceptedRegression:failedRun,automaticFirstSelectionImplemented:false,goalComplete:false,remaining:'See NATIVE-CHARACTER-CHOOSER-KEYS.md and NATIVE-UI-PARITY-GOAL.md.'};assert.equal(result.checks,2206);
await fs.writeFile(path.join(project,'reports/native-character-chooser-followup-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:result.checks,checkpoint:result.checkpoint,retainedUnacceptedRegression:failedRun,graphicalValidated:false,freshLocalValidated:false,goalComplete:false}));
