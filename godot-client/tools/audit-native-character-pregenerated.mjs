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
for(const [run,checks] of [['native-pregen-preferences-graphical-v2',26],['native-pregen-chooser-graphical-v2',31],['native-pregen-edit-graphical-v1',94]]){
 const r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');
 assert.equal(r.success,true);assert.equal(r.checks,checks);assert.deepEqual(r.failures,[]);assert.equal(r.publicConnections,0);assert.equal(r.fullUiParity,false);
 for(const field of ['success','sourceUnchanged','armed','normalHeap','graphical'])assert.equal(p[field],true);
 for(const field of ['exception','engineOrLifetimeError'])assert.equal(p[field],false);
 assert.equal(p.debuggerExit,0);await pins(p.sourceSha256);
 assert.equal(r.window.focused,false);assert.equal(r.window.unfocusable,true);assert.notEqual(r.window.screen,r.window.primary);assert.equal(r.window.mouse_mode,0);
 if(checks===26){const cfg=await fs.readFile(r.preferencePath,'utf8');assert.match(cfg,/\[game\.character-generation\]/);assert.match(cfg,/show-pregenerated=false/);assert.match(cfg,/keep="received after opening"/);assert.equal((await fs.readFile(path.join(project,'reports/'+run+'.restored.png'))).subarray(0,8).toString('hex'),'89504e470d0a1a0a');}
 receipts.push({run,checks,graphical:true});
}
const run='native-pregen-local-v1',r=await read('reports/'+run+'.json'),n=await read('reports/'+run+'.native.json');
for(const field of ['success','sourceUnchanged','debuggerArmed'])assert.equal(r[field],true);assert.equal(r.nativeException,false);assert.equal(r.nativeExit,0);assert.equal(r.publicConnections,0);assert.equal(r.endpoint,'127.0.0.1:5125');await pins(r.sourceSha256);
assert.equal(r.nativeAdmission.success,true);assert.equal(Object.keys(r.nativeAdmission.checks).length,7);assert.ok(Object.values(r.nativeAdmission.checks).every(v=>v===true));
for(const [field,count] of [['lobbyPages',18],['actions',170]]){assert.equal(r[field].success,true);assert.equal(r[field].checks.length,count);assert.ok(r[field].checks.every(row=>row.passed===true));}
const {previewProofMatches}=await import('./native-character-preview-proof.cjs');assert.equal(r.characterPreviewProof.success,true);assert.equal(previewProofMatches(r.characterPreviewProof,r.characterPreviewProof,r.characterPreviewExpected),true);
assert.equal(r.characterPreviewStorage.closed,true);assert.equal(r.characterPreviewStorage.files,0);assert.equal(r.characterPreviewStorage.written,2);assert.equal(r.characterPreviewStorage.removed,2);assert.equal(r.lobbyParticipant.closed,true);assert.equal(n.success,true);assert.equal(n.workers_remaining,0);assert.equal(n.protocol_finish_ack,true);
assert.equal(n.lobby_preferences.path,path.join(project,'reports',run+'.lobby.cfg'));assert.equal(n.lobby_preferences.failure,'');assert.equal(n.lobby_preferences.writes,1);assert.equal(n.lobby_preferences.native_only,true);assert.equal(n.lobby_preferences.persistent,true);assert.equal(n.lobby_preferences.show_pregenerated,false);assert.match(await fs.readFile(n.lobby_preferences.path,'utf8'),/show-pregenerated=false/);receipts.push({run,checks:207,ownedLocal:true});
const binary='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
const evidence=await read('../backups/animations/rea-native-character-pregen-persistence-v1.json');assert.equal(evidence.binarySha256,binary);
for(const row of [evidence.ctor,evidence.destructor,...evidence.toggle]){assert.equal(row.subject.digest.sha256,binary);assert.equal(row.authority,'shipped-artifact');}
assert.equal(evidence.ctor.procedure.address,'0x140708660');assert.equal(evidence.destructor.procedure.address,'0x14070a6b0');assert.match(evidence.ctor.pseudocode,/show-pregenerated/);assert.match(evidence.ctor.pseudocode,/Get<bool>/);assert.match(evidence.destructor.pseudocode,/Set<bool>/);assert.match(evidence.toggle[0].normalized_result.raw_disassembly,/0x1c80/);assert.equal(evidence.toggle[1].normalized_result.raw_disassembly,'JMP 0x140714a70');
const crash=await read('reports/native-lobby-record-feats-v2.debugger.json');assert.equal(crash.exception,true);assert.equal(crash.success,false);
const archive='backups/native-character-pregenerated-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(project,archive))),checkpoint.sha256);for(const row of checkpoint.manifest)assert.equal(sha(await fs.readFile(path.join(project,row.sourceScope==='workspace'?'../'+row.source:row.file))),row.sha256);
const sources={};for(const file of ['systems/native_data/character_lobby_preferences.gd','systems/character_lobby.gd','systems/native_character_lobby.gd','native_session_world.gd','tools/native-session-host.cjs','tests/native_character_lobby_preferences_test.gd','../backups/animations/rea-native-character-pregen-persistence-v1.json','NATIVE-CHARACTER-PREGENERATED.md'])sources[file]=sha(await fs.readFile(path.join(project,file)));
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),receipts,sources,checkpoint:{file:archive,files:checkpoint.files,sha256:checkpoint.sha256},pregeneratedPersistenceImplemented:true,nativeLocalMetadataComplete:false,normalLocalFilteringFullyAvailable:false,freshLocalValidated:true,graphicalInputValidated:true,exactOriginalAppearanceAccepted:false,publicConnections:0,fullCharacterLobbyParity:false,fullUiParity:false,fullStabilityParity:false,startupExceptionResolved:false,headlessPlayerArtworkIssueResolved:false,goalComplete:false,remaining:'See NATIVE-CHARACTER-PREGENERATED.md and NATIVE-UI-PARITY-GOAL.md.'};assert.equal(result.checks,358);
await fs.writeFile(path.join(project,'reports/native-character-pregenerated-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:result.checks,checkpoint:result.checkpoint,fullUiParity:false,goalComplete:false}));
