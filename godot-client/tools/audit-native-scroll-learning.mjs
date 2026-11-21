// Scoped native scroll-learning acceptance. Entire UI completion stays false.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url)),workspace=path.resolve(home,'..');
const hash=b=>createHash('sha256').update(b).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(home,file),'utf8'));
const receipts=[];
async function pinned(proof){const entries=Object.entries(proof.sourceSha256);assert.ok(entries.length>100);for(const[file,digest]of entries)assert.equal(hash(await fs.readFile(path.join(home,file))),digest,file+' changed');return entries.length;}
for(const[run,count]of[['native-scroll-feedback-final-v1',726],['native-scroll-general-feedback-final-v1',17]]){
 const r=await read('reports/'+run+'.json'),proof=await read('reports/'+run+'.debugger.json');assert.equal(r.success,true);assert.equal(r.checks,count);assert.deepEqual(r.failures,[]);
 for(const key of['success','armed','sourceUnchanged','normalHeap'])assert.equal(proof[key],true);for(const key of['exception','engineOrLifetimeError'])assert.equal(proof[key],false);assert.equal(proof.debuggerExit,0);assert.equal(proof.publicConnections,0);
 receipts.push({run,checks:count,sources:await pinned(proof)});
}
const run='native-scroll-learning-local-final-v1',r=await read('reports/'+run+'.json');
for(const key of['success','sourceUnchanged','debuggerArmed'])assert.equal(r[key],true);assert.equal(r.nativeException,false);assert.equal(r.nativeExit,0);assert.equal(r.publicConnections,0);assert.equal(r.endpoint,'127.0.0.1:5125');assert.equal(r.native.workersRemaining,0);assert.equal(r.actions.checks.length,169);assert.deepEqual(r.actions.failures,[]);assert.ok(r.actions.checks.every(row=>row.passed));
for(const label of[
 'Original server learning updates known spells, stack, ACK and native success feedback',
 'Original server duplicate refusal is visible and its ACK releases the native pending state',
 'Refused duplicate learning preserves the received scroll and exactly one known spell',
 'Original server consumes the final scroll, removes its UI cell and teaches its spell family',
 'Actual native spellbook displays both server-learned spells and retains family selection',
 'Newly learned native spellbook rows receive their original icons before visual capture',
 'Original server non-scroll refusal appears in native feedback'
])assert.ok(r.actions.checks.some(row=>row.label===label&&row.passed),label);
receipts.push({run,checks:r.actions.checks.length,sources:await pinned(r)});
assert.equal(r.actionFixture.module,'GodotItemUi3');assert.equal(r.actionFixture.scrolls.length,2);
const audio=r.native.world.effects.audio;assert.equal(audio.stats.failed,0);
const learningAudio=audio.history.filter(row=>['gui_failspell','gui_learnspell'].includes(row.name));assert.equal(learningAudio.length,4);
assert.deepEqual(learningAudio.map(row=>row.name),['gui_failspell','gui_learnspell','gui_failspell','gui_learnspell']);
for(const row of learningAudio){assert.equal(row.profile.positional,false);assert.equal(row.profile.priority,9);assert.equal(row.profile.loop,false);assert.ok(row.duration>0&&row.metadata.frames>0);}
const original=[];
for(const file of['native-scroll-feedback-observations-v1.json','rea-native-scroll-feedback-v1.json']){const bytes=await fs.readFile(path.join(workspace,'backups/animations',file)),value=JSON.parse(bytes);assert.equal(value.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');if(value.cases){assert.equal(value.cases.length,144);assert.ok(value.cases.every(row=>row.outputs.length===1));}original.push({file,sha256:hash(bytes)});}
const screenshot='reports/'+run+'.native-scroll-learning.png',png=await fs.readFile(path.join(home,screenshot));assert.equal(png.subarray(0,8).toString('hex'),'89504e470d0a1a0a');assert.ok(png.readUInt32BE(16)>=1280&&png.readUInt32BE(20)>=800);
const archive='backups/native-scroll-learning-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(hash(await fs.readFile(path.join(home,archive))),checkpoint.sha256);
for(const row of checkpoint.manifest){const file=row.sourceScope==='workspace'?path.join(workspace,row.source):path.join(home,row.file);assert.equal(hash(await fs.readFile(file)),row.sha256);}
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),goalComplete:false,fullUiParity:false,positiveStockWizardLearningVerified:true,duplicateAndNonScrollRefusalVerified:true,authoritativeFinalScrollDestructionVerified:true,nativeFeedbackAndSoundVerified:true,publicConnections:0,manualClientTouched:false,receipts,original,screenshot:{file:screenshot,sha256:hash(png),review:'Native viewport manually reviewed: both learned names/icons, success text and duplicate refusal visible. One owned local fixture at its tested scale; no broad visual-parity claim.'},checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},remaining:'Other learnable classes and server-modified tables, all school/ability/level/ownership refusals, sound preferences/localization and the previously listed full item/UI parity gaps. Known scene-wind warning remains recorded; unrelated rendering work is deferred.'};
await fs.writeFile(path.join(home,'reports/native-scroll-learning-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:result.checks,goalComplete:false,checkpoint:result.checkpoint}));
