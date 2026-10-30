// Headless numeric/control checkpoint only; no full UI/visual acceptance.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=fileURLToPath(new URL('../',import.meta.url));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(project,file),'utf8'));
const receipts=[];
for(const [run,checks] of [['native-pregame-character-data-v2',802],['native-pregame-character-worker-v2',24],['native-pregame-character-skills-v1',373],['native-pregame-character-spells-v1',296],['native-pregame-character-input-headless-v1',14],['native-pregame-character-chooser-headless-v3',23]]){
 const r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');
 assert.equal(r.success,true);assert.equal(r.checks,checks);assert.deepEqual(r.failures,[]);assert.equal(r.publicConnections,0);assert.equal(r.fullUiParity,false);
 for(const key of ['success','sourceUnchanged','armed','normalHeap'])assert.equal(p[key],true);
 for(const key of ['graphical','exception','engineOrLifetimeError'])assert.equal(p[key],false);
 assert.equal(p.debuggerExit,0);assert.ok(Object.keys(p.sourceSha256).length);
 for(const [file,digest] of Object.entries(p.sourceSha256))assert.equal(sha(await fs.readFile(path.join(project,file))),digest,file+' changed');
 receipts.push({run,checks,graphical:false});
}
const binary='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
const oracle=await read('../backups/animations/native-pregame-character-observations-v1.json');assert.equal(oracle.target,binary);assert.equal(oracle.rows.length,72);
const evidence=await read('../backups/animations/rea-native-pregame-character-v1.json');assert.equal(evidence.subjectSha256,binary);
assert.equal(evidence.setData.normalized_result.artifact.sha256,binary);assert.equal(evidence.setData.normalized_result.coverage.exhausted,true);assert.equal(evidence.setData.normalized_result.coverage.total,49011);assert.equal(evidence.setData.normalized_result.procedure_address,'0x1409bbfc0');
assert.equal(evidence.vtable.normalized_result.complete,true);assert.ok(evidence.vtable.normalized_result.bytes_hex.startsWith('c0bf9b400100000080639b4001000000'));
for(const row of Object.values(evidence.rows))assert.equal(row.subject.digest.sha256,binary);
const xp=await read('../backups/animations/rea-native-pregame-character-xp-v1.json');for(const row of Object.values(xp.rows)){assert.equal(row.subject.digest.sha256,binary);assert.equal(row.authority,'shipped-artifact');assert.ok(row.pseudocode);}
assert.match(xp.rows.rulesCtor.pseudocode,/"EXPTABLE"/);assert.match(xp.rows.rulesCtor.pseudocode,/< 0x29/);
for(const run of ['native-pregame-character-chooser-headless-v1','native-pregame-character-chooser-headless-v2']){const p=await read('reports/'+run+'.debugger.json');assert.equal(p.success,false);assert.equal(p.engineOrLifetimeError,true);assert.equal(p.sourceUnchanged,true);}
const crash=await read('reports/native-lobby-record-feats-v2.debugger.json');assert.equal(crash.exception,true);assert.equal(crash.success,false);
const sources={};
for(const file of ['../scripts/inspect-native-pregame-character.py','../scripts/inspect-native-pregame-skills.py','../backups/animations/native-pregame-character-observations-v1.json','../backups/animations/native-pregame-skill-observations-v1.json','../backups/animations/rea-native-pregame-character-v1.json','../backups/animations/rea-native-pregame-character-xp-v1.json','../backups/animations/rea-native-pregame-skills-v1.json','systems/native_character_preview.gd','systems/native_character_lobby.gd','systems/native_data/pregame_record.gd','tests/native_pregame_record_test.gd','tests/native_lobby_record_stats_test.gd','NATIVE-PREGAME-CHARACTER-NUMBERS.md'])sources[file]=sha(await fs.readFile(path.join(project,file)));
const archive='backups/native-pregame-character-numbers-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(project,archive))),checkpoint.sha256);
for(const row of checkpoint.manifest)assert.equal(sha(await fs.readFile(path.join(project,row.sourceScope==='workspace'?'../'+row.source:row.file))),row.sha256);
const result={success:true,checks:receipts.reduce((sum,r)=>sum+r.checks,0),receipts,sources,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},publicConnections:0,nativePregameCharacterNumbers:true,graphicalValidated:false,freshLocalValidated:false,fullRecordParity:false,fullUiParity:false,fullStabilityParity:false,startupExceptionResolved:false,retainedStartupException:'native-lobby-record-feats-v2',goalComplete:false,remaining:'See NATIVE-PREGAME-CHARACTER-NUMBERS.md and NATIVE-UI-PARITY-GOAL.md.'};assert.equal(result.checks,1532);
await fs.writeFile(path.join(project,'reports/native-pregame-character-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:result.checks,checkpoint:result.checkpoint,graphicalValidated:false,freshLocalValidated:false,goalComplete:false}));
