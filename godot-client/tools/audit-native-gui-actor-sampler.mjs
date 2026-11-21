import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=fileURLToPath(new URL('../',import.meta.url));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(project,file),'utf8'));
async function pins(items){assert.ok(Object.keys(items).length);for(const [file,digest] of Object.entries(items))assert.equal(sha(await fs.readFile(path.join(project,file))),digest,file);}
const receipts=[];
for(const [run,count] of [['native-gui-actor-sampler-after-v2',23],['native-gui-actor-chooser-v1',63],['native-gui-actor-prework-v1',34]]){
 const r=await read('reports/'+run+'.json'),d=await read('reports/'+run+'.debugger.json');
 assert.equal(r.success,true);assert.equal(r.checks,count);assert.deepEqual(r.failures,[]);assert.equal(r.publicConnections,0);
 for(const field of ['success','sourceUnchanged','armed','normalHeap'])assert.equal(d[field],true);
 assert.equal(d.exception,false);assert.equal(d.engineOrLifetimeError,false);await pins(d.sourceSha256);receipts.push({run,checks:count});
}
const before=await read('reports/native-gui-actor-sampler-before-v2.json'),after=await read('reports/native-gui-actor-sampler-after-v2.json');
assert.equal(before.success,false);assert.equal(after.samples.length,5);
for(let index=0;index<5;index++){
 assert.ok(before.samples[index].bright_rows.length>=4);const sample=after.samples[index];assert.deepEqual(sample.bright_rows,[0]);assert.equal(sample.actor,true);assert.equal(sample.clamp,3);assert.deepEqual(sample.meshes.map(v=>v.source),[1,3]);assert.ok(sample.meshes.every(v=>v.repeat===false));
}
const live='native-gui-actor-live-v1',r=await read('reports/'+live+'.json'),n=await read('reports/'+live+'.native.json');
for(const field of ['success','sourceUnchanged','debuggerArmed'])assert.equal(r[field],true);
assert.equal(r.nativeException,false);assert.equal(r.nativeExit,0);assert.equal(r.publicConnections,0);assert.equal(r.endpoint,'127.0.0.1:5125');await pins(r.sourceSha256);
assert.equal(r.nativeAdmission.success,true);assert.equal(Object.keys(r.nativeAdmission.checks).length,7);assert.ok(Object.values(r.nativeAdmission.checks).every(v=>v===true));
for(const [field,count] of [['lobbyPages',18],['actions',170]]){assert.equal(r[field].success,true);assert.equal(r[field].checks.length,count);assert.ok(r[field].checks.every(v=>v.passed));}
assert.equal(r.characterPreviewProof.success,true);assert.equal(r.characterPreviewProof.record_input.checks.length,12);assert.ok(r.characterPreviewProof.record_input.checks.every(v=>v.passed));
assert.equal(r.characterPreviewStorage.closed,true);assert.equal(r.characterPreviewStorage.files,0);assert.equal(r.lobbyParticipant.closed,true);assert.equal(n.success,true);assert.equal(n.workers_remaining,0);assert.equal(n.protocol_finish_ack,true);receipts.push({run:live,checks:207});
await assert.rejects(fs.stat(path.join(project,'../runtime-logs/native-playability-actions-server/client/localvault/nwn_local_ui.bic')),{code:'ENOENT'});
const original=await read('reports/native-lobby-art-source-v2.json');assert.equal(original.models.ctl_pre_btn_tab.sha256,'adc06b7312ae19355a84e222e1392fd1337f449a3113e755e467774f451432f4');assert.match(original.rasters.gui_pre_playtabs.txi.text,/clamp 3/);
const evidence=await read('../backups/animations/rea-native-gui-sampler-v1.json');assert.equal(evidence.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
assert.equal((await read('reports/native-lobby-record-feats-v2.debugger.json')).exception,true);
const archive='backups/native-gui-actor-sampler-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(project,archive))),checkpoint.sha256);
for(const row of checkpoint.manifest)assert.equal(sha(await fs.readFile(path.join(project,row.sourceScope==='workspace'?'../'+row.source:row.file))),row.sha256,row.file);
const sources={};for(const file of ['systems/native_render/actor_instance.gd','systems/native_item_icons.gd','systems/native_data/gui_texture_info.gd','tests/native_gui_actor_sampler_test.gd','NATIVE-GUI-ACTOR-SAMPLER.md','reports/native-lobby-art-source-v2.json','../backups/animations/rea-native-gui-sampler-v1.json'])sources[file]=sha(await fs.readFile(path.join(project,file)));
const result={success:true,checks:327,receipts,sources,checkpoint:{file:archive,files:checkpoint.files,sha256:checkpoint.sha256},animatedGuiSamplerPublicationValidated:true,repeatedTabBorderPixelsFixed:true,publicConnections:0,fullUiParity:false,fullCharacterLobbyParity:false,originalGpuParity:false,startupExceptionResolved:false,headlessPlayerArtworkIssueResolved:false,goalComplete:false};
await fs.writeFile(path.join(project,'reports/native-gui-actor-sampler-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:result.checks,checkpoint:result.checkpoint,fullUiParity:false,goalComplete:false}));
