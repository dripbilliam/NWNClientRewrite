// Scoped evidence verification; does not certify the full UI or live Delete IPC.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import proof from './native-character-preview-proof.cjs';
const home=fileURLToPath(new URL('../',import.meta.url));
const hash=b=>createHash('sha256').update(b).digest('hex'), evidence=[];
async function read(file){const b=await fs.readFile(path.join(home,file));evidence.push({file,sha256:hash(b)});return JSON.parse(b);}
async function sources(entries){for(const[file,digest]of Object.entries(entries))assert.equal(hash(await fs.readFile(path.join(home,file))),digest,file+' changed since test');}
let nativeChecks=0;
for(const[name,count]of [['native-delete-final-input-v1',95],['native-delete-current-picker-v1',41],['native-delete-current-cache-v1',22],['native-delete-current-metadata-v1',61]]){
 const r=await read('reports/'+name+'.json'),d=await read('reports/'+name+'.debugger.json');
 assert.equal(r.success,true);assert.deepEqual(r.failures,[]);assert.equal(r.checks,count);assert.equal(r.publicConnections,0);
 for(const k of ['success','sourceUnchanged','armed'])assert.equal(d[k],true,k);
 for(const k of ['exception','engineOrLifetimeError'])assert.equal(d[k],false,k);
 assert.equal(d.debuggerExit,0);await sources(d.sourceSha256);nativeChecks+=count;
}
const run='native-delete-local-current-v1',r=await read('reports/'+run+'.json'),n=await read('reports/'+run+'.native.json');
for(const k of ['success','sourceUnchanged','debuggerArmed'])assert.equal(r[k],true,k);
assert.equal(r.nativeException,false);assert.equal(r.nativeExit,0);assert.equal(r.publicConnections,0);assert.equal(r.endpoint,'127.0.0.1:5125');await sources(r.sourceSha256);
assert.equal(r.nativeAdmission.success,true);assert.equal(Object.keys(r.nativeAdmission.checks).length,7);assert.ok(Object.values(r.nativeAdmission.checks).every(v=>v===true));nativeChecks+=7;
for(const[section,count]of [[r.lobbyPages,18],[r.characterPreviewProof.record_input,12],[r.actions,170]]){assert.equal(section.success,true);assert.equal(section.checks.length,count);assert.ok(section.checks.every(c=>c.passed===true));nativeChecks+=count;}
assert.equal(r.characterPreviewProof.key,'local:nwn_local_ui.bic');assert.equal(r.characterPreviewProof.success,true);
assert.equal(proof.previewProofMatches(r.characterPreviewProof,r.characterPreviewProof,r.characterPreviewExpected),true);
assert.equal(r.characterPreviewStorage.closed,true);assert.equal(r.characterPreviewStorage.files,0);assert.equal(r.lobbyParticipant.closed,true);
assert.equal(n.success,true);assert.equal(n.workers_remaining,0);assert.equal(n.protocol_finish_ack,true);
for(const k of ['native_only','ready','closed'])assert.equal(n.local_character_catalog[k],true);
assert.equal(n.local_character_catalog.worker_running,false);assert.equal(n.lobby_preferences.show_pregenerated,false);
const original=await read('../backups/animations/native-character-delete-results-v1.json');assert.equal(original.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(original.cases.length,55);
for(const file of ['rea-native-character-delete-confirmation-v1.json','rea-native-confirmation-label-v1.json','rea-native-modal-escape-dispatch-v1.json'])await read('../backups/animations/'+file);
const picture='reports/native-delete-final-input-v1.confirmation.png',png=await fs.readFile(path.join(home,picture));assert.equal(png.subarray(1,4).toString(),'PNG');evidence.push({file:picture,sha256:hash(png),visualReview:'Bounded original question and OK/Cancel controls reviewed; no full original-client pixel parity claim.'});
const unit=execFileSync(process.execPath,['--test','--test-reporter=tap',path.join(home,'tools/native-lobby.test.mjs')],{encoding:'utf8',windowsHide:true,maxBuffer:1024*1024});assert.match(unit,/# tests 25\r?\n/);assert.match(unit,/# fail 0\r?\n/);
for(const file of ['tools/native-lobby.test.mjs','tools/native-lobby.mjs'])evidence.push({file,sha256:hash(await fs.readFile(path.join(home,file)))});
const archive='backups/native-local-character-deletion-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(hash(await fs.readFile(path.join(home,archive))),checkpoint.sha256);
for(const entry of checkpoint.manifest){const file=entry.sourceScope==='workspace'?path.join(home,'..',entry.source):path.join(home,entry.file);assert.equal(hash(await fs.readFile(file)),entry.sha256,entry.file+' changed since checkpoint');}
const result={success:true,goalComplete:false,fullUiParity:false,fullLiveDeleteIpcAccepted:false,customizeImplemented:false,nativeChecks,lobbyUnitChecks:25,publicGameplayConnections:0,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},evidence,limits:'Native dialog/file mutation and raw refresh service tested separately; original-server regression covers admission and authoritative actions. Full live Delete IPC, DM management, Customize, prompt sound, remaining modal keys and complete UI acceptance remain open.'};
await fs.writeFile(path.join(home,'reports/native-character-delete-audit-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({...result,evidence:undefined}));
