// Accepts the documented owned Delete paths, not the complete picker or UI.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import proof from './native-character-preview-proof.cjs';
const home=fileURLToPath(new URL('../',import.meta.url)),evidence=[];
const hash=b=>createHash('sha256').update(b).digest('hex');
async function read(file){const b=await fs.readFile(path.join(home,file));evidence.push({file,sha256:hash(b)});return JSON.parse(b);}
async function sources(entries){for(const[file,digest]of Object.entries(entries))assert.equal(hash(await fs.readFile(path.join(home,file))),digest,file+' changed since test');}
let nativeChecks=0;
for(const[name,count]of [['native-delete-ipc-input-final-v1',95],['native-row-signal-retirement-final-v1',18]]){
 const r=await read('reports/'+name+'.json'),d=await read('reports/'+name+'.debugger.json');
 assert.equal(r.success,true);assert.deepEqual(r.failures,[]);assert.equal(r.checks,count);assert.equal(r.publicConnections,0);
 for(const k of ['success','sourceUnchanged','armed'])assert.equal(d[k],true,k);
 for(const k of ['exception','engineOrLifetimeError'])assert.equal(d[k],false,k);
 assert.equal(d.debuggerExit,0);await sources(d.sourceSha256);nativeChecks+=count;
}
const run='native-delete-ipc-production-v1',r=await read('reports/'+run+'.json'),n=await read('reports/'+run+'.native.json');
for(const k of ['success','sourceUnchanged','debuggerArmed'])assert.equal(r[k],true,k);
assert.equal(r.nativeException,false);assert.equal(r.nativeExit,0);assert.equal(r.publicConnections,0);assert.equal(r.endpoint,'127.0.0.1:5125');await sources(r.sourceSha256);
assert.equal(r.nativeAdmission.success,true);assert.equal(Object.keys(r.nativeAdmission.checks).length,7);assert.ok(Object.values(r.nativeAdmission.checks).every(v=>v===true));nativeChecks+=7;
for(const[section,count]of [[r.localDelete,33],[r.characterPreviewProof.record_input,12],[r.actions,170]]){assert.equal(section.success,true);assert.equal(section.checks.length,count);assert.ok(section.checks.every(c=>c.passed===true));nativeChecks+=count;}
assert.equal(r.localDelete.observerSubmitted,false);assert.equal(r.localDelete.observerWorldObjects,0);
assert.equal(r.characterPreviewProof.key,'local:nwn_local_ui.bic');assert.equal(r.characterPreviewProof.success,true);assert.equal(proof.previewProofMatches(r.characterPreviewProof,r.characterPreviewProof,r.characterPreviewExpected),true);
assert.equal(r.localDeleteRefresh.length,2);assert.deepEqual(r.localDeleteRefresh.map(v=>v.key),['local:nwn_delete_a.bic','local:nwn_delete_b.bic']);
assert.equal(new Set(r.localDeleteRefresh.map(v=>v.requestId)).size,2);
for(const row of r.localDeleteRefresh){assert.equal(row.accepted,true);assert.equal(row.absent,true);assert.equal(row.listed,false);assert.ok(Number.isSafeInteger(row.requestId)&&row.requestId>0);}
assert.equal(r.characterPreviewStorage.closed,true);assert.equal(r.characterPreviewStorage.files,0);
assert.equal(n.success,true);assert.equal(n.workers_remaining,0);assert.equal(n.protocol_finish_ack,true);assert.equal(n.local_delete.success,true);assert.equal(n.local_character_catalog.closed,true);assert.equal(n.local_character_catalog.worker_running,false);
assert.doesNotMatch(r.engineErrors??'',/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m);
for(const stem of ['nwn_delete_a','nwn_delete_b','nwn_local_ui'])await assert.rejects(fs.access(path.join(home,'../runtime-logs/native-playability-actions-server/client/localvault',stem+'.bic')),e=>e.code==='ENOENT');
for(const[suffix,visualReview]of [['delete-confirmation','Original bounded confirmation, complete source artwork and OK/Cancel reviewed.'],['delete-settled','Production chooser membership/selection after actual Delete IPC reviewed; portrait is independent of optional model readiness.']]){
 const file='reports/'+run+'.native.'+suffix+'.png',b=await fs.readFile(path.join(home,file));assert.equal(b.subarray(1,4).toString(),'PNG');evidence.push({file,sha256:hash(b),visualReview});
}
for(const failed of ['native-delete-ipc-local-v1','native-delete-ipc-local-v2']){const p=await read('reports/'+failed+'.json');assert.equal(p.success,false);assert.equal(p.publicConnections,0);}
const unit=execFileSync(process.execPath,['--test','--test-reporter=tap',path.join(home,'tools/native-lobby.test.mjs')],{encoding:'utf8',windowsHide:true,maxBuffer:1024*1024});assert.match(unit,/# tests 25\r?\n/);assert.match(unit,/# fail 0\r?\n/);
const archive='backups/native-local-delete-live-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(hash(await fs.readFile(path.join(home,archive))),checkpoint.sha256);
for(const entry of checkpoint.manifest){const file=entry.sourceScope==='workspace'?path.join(home,'..',entry.source):path.join(home,entry.file);assert.equal(hash(await fs.readFile(file)),entry.sha256,entry.file+' changed since checkpoint');}
const result={success:true,goalComplete:false,fullUiParity:false,coveredLiveDeleteIpcAccepted:true,customizeImplemented:false,nativeChecks,lobbyUnitChecks:25,publicGameplayConnections:0,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},evidence,limits:'Owned profile-vault copies in original-style and production pickers on one loopback connection. DM management, exported metadata, duplicate aliases, other disk failures, prompt sound, remaining modal keys, UI scales and full picker/UI acceptance remain open. Existing scene wind warning is unrelated and unresolved.'};
await fs.writeFile(path.join(home,'reports/native-local-delete-live-audit-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({...result,evidence:undefined}));
