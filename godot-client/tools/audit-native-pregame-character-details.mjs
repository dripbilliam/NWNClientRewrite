// Scoped pregame detail data/input checkpoint; complete UI remains unaccepted.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=fileURLToPath(new URL('../',import.meta.url));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(project,file),'utf8'));
const receipts=[];
for(const [run,checks] of [['native-pregame-character-details-data-v4',225],['native-pregame-character-details-input-headless-v3',25],['native-pregame-character-details-numbers-v1',802],['native-pregame-character-details-worker-v1',24],['native-pregame-character-details-skills-v1',373],['native-pregame-character-details-spells-v1',296],['native-pregame-character-details-chooser-headless-v1',23]]){
 const r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');
 assert.equal(r.success,true);assert.equal(r.checks,checks);assert.deepEqual(r.failures,[]);assert.equal(r.publicConnections,0);assert.equal(r.fullUiParity,false);
 for(const key of ['success','sourceUnchanged','armed','normalHeap'])assert.equal(p[key],true);
 for(const key of ['graphical','exception','engineOrLifetimeError'])assert.equal(p[key],false);
 assert.equal(p.debuggerExit,0);assert.ok(Object.keys(p.sourceSha256).length);
 for(const [file,digest] of Object.entries(p.sourceSha256))assert.equal(sha(await fs.readFile(path.join(project,file))),digest,file+' changed');
 receipts.push({run,checks,graphical:false});
}
const binary='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
const oracle=await read('../backups/animations/native-pregame-character-detail-observations-v2.json');assert.equal(oracle.target,binary);assert.equal(oracle.rows.length,72);
const titles=new Set(oracle.rows.flatMap(r=>r.captured.filter(s=>s.includes('Label66198:')).map(s=>s.slice(s.lastIndexOf('Label105')))));assert.equal(titles.size,9);assert.ok(oracle.rows.some(r=>r.source.stats.classes.some(c=>c.id===250)));
const original=await read('../backups/animations/rea-native-pregame-character-details-v1.json');assert.equal(original.binarySha256,binary);for(const row of Object.values(original.rows)){assert.equal(row.subject.digest.sha256,binary);assert.equal(row.authority,'shipped-artifact');assert.ok(row.pseudocode);}
assert.equal(original.setDataProcedure.normalized_result.item.address,'0x1409bbfc0');assert.equal(original.setDataProcedure.normalized_result.item.body.total_bytes,11103);
const controls=await read('../backups/animations/rea-native-pregame-character-detail-controls-v1.json');assert.equal(controls.binarySha256,binary);for(const row of Object.values(controls.rows)){assert.equal(row.subject.digest.sha256,binary);assert.equal(row.authority,'shipped-artifact');assert.ok(row.pseudocode);}
const height=await read('../backups/animations/rea-native-character-detail-row-height-v1.json');assert.equal(height.rowAdd.subject.digest.sha256,binary);assert.match(height.rowAdd.pseudocode,/this \+ 0x430/);
for(const run of ['native-pregame-character-details-data-v1','native-pregame-character-details-data-v2']){const r=await read('reports/'+run+'.json');assert.equal(r.success,false);assert.equal(r.failures.length,11);assert.ok(r.failures.every(s=>s.startsWith('Exact original row enumeration')));}
const crash=await read('reports/native-lobby-record-feats-v2.debugger.json');assert.equal(crash.exception,true);assert.equal(crash.success,false);
const sources={};
for(const file of ['../scripts/inspect-native-pregame-character-details.py','../backups/animations/native-pregame-character-detail-observations-v2.json','../backups/animations/native-pregame-character-detail-observations-v1.json','../backups/animations/inspect-native-pregame-character-details-fixture-v1.py','../backups/animations/rea-native-pregame-character-details-v1.json','../backups/animations/rea-native-pregame-character-detail-controls-v1.json','../backups/animations/rea-native-character-detail-row-height-v1.json','../backups/animations/rea-native-character-frame-research-v1.json','../backups/animations/rea-native-pregame-skills-v1.json','systems/native_character_lobby.gd','systems/native_data/character_lobby_layout.gd','systems/native_data/pregame_record.gd','systems/native_data/pregame_record_details.gd','tests/native_pregame_record_details_test.gd','tests/native_lobby_record_stats_test.gd','NATIVE-PREGAME-CHARACTER-DETAILS.md'])sources[file]=sha(await fs.readFile(path.join(project,file)));
const archive='backups/native-pregame-character-details-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(project,archive))),checkpoint.sha256);
for(const row of checkpoint.manifest)assert.equal(sha(await fs.readFile(path.join(project,row.sourceScope==='workspace'?'../'+row.source:row.file))),row.sha256);
const result={success:true,checks:receipts.reduce((sum,r)=>sum+r.checks,0),receipts,sources,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},publicConnections:0,nativePregameCharacterDetails:true,graphicalValidated:false,freshLocalValidated:false,fullRecordParity:false,fullUiParity:false,fullStabilityParity:false,startupExceptionResolved:false,retainedStartupException:'native-lobby-record-feats-v2',goalComplete:false,remaining:'See NATIVE-PREGAME-CHARACTER-DETAILS.md and NATIVE-UI-PARITY-GOAL.md.'};assert.equal(result.checks,1768);
await fs.writeFile(path.join(project,'reports/native-pregame-character-details-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:result.checks,checkpoint:result.checkpoint,graphicalValidated:false,freshLocalValidated:false,goalComplete:false}));
