// Independent installed chooser and active data binding, not a live latency claim.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const evidence=[];
async function read(file){const bytes=await fs.readFile(path.join(home,file));evidence.push({file,sha256:sha(bytes)});return JSON.parse(bytes);}
async function sources(value){for(const [file,digest]of Object.entries(value.sourceSha256))assert.equal(sha(await fs.readFile(path.join(home,file))),digest,file+': stale evidence');}
let checks=0;
for(const [name,count]of [['independent-final-v1',17],['frame-final-v1',31],['preferences-final-v1',26],['keyboard-final-v1',19],['pages-final-v1',32],['record-final-v1',28],['feats-final-v1',61]]){
 const stem='reports/native-lobby-prewarm-'+name,result=await read(stem+'.json'),proof=await read(stem+'.debugger.json');
 assert.equal(result.success,true,name);assert.deepEqual(result.failures,[],name);assert.equal(result.checks,count,name);
 for(const key of ['success','sourceUnchanged','armed'])assert.equal(proof[key],true,name+': '+key);
 for(const key of ['exception','engineOrLifetimeError'])assert.equal(proof[key],false,name+': '+key);
 assert.equal(proof.debuggerExit,0);assert.equal(proof.publicConnections,0);await sources(proof);checks+=count;
}
const startup=await read('reports/native-lobby-prewarm-startup-v2.json');
for(const key of ['success','sourceUnchanged','debuggerArmed'])assert.equal(startup[key],true,key);
assert.equal(startup.nativeException,false);assert.equal(startup.nativeExit,0);assert.equal(startup.publicConnections,0);
assert.deepEqual(startup.startupMainMenu,{ready:true,mainVisible:true,browserHidden:true,lobbyHidden:true});await sources(startup);
const log='reports/native-lobby-prewarm-startup-v2.engine.log',text=await fs.readFile(path.join(home,log),'utf8');
assert.ok(text.includes('NATIVE_CHOOSER_READY base_only=true'));assert.ok(!text.includes('NATIVE_SESSION_SETUP_RECEIVED'));assert.ok(!/SCRIPT ERROR|^ERROR:/m.test(text));evidence.push({file:log,sha256:sha(text)});
const picture='reports/native-lobby-prewarm-independent-final-v1.png',pixels=await fs.readFile(path.join(home,picture));assert.equal(pixels.subarray(1,4).toString(),'PNG');evidence.push({file:picture,sha256:sha(pixels),review:'Original roster frame with active custom class text; the fixture has no selected BIC portrait/record payload.'});
const archive='backups/native-lobby-prewarm-v1.zip',checkpoint=await read(archive+'.verified.json');
assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(home,archive))),checkpoint.sha256);
for(const entry of checkpoint.manifest){const file=entry.sourceScope==='workspace'?path.join(home,'..',entry.source):path.join(home,entry.file);assert.equal(sha(await fs.readFile(file)),entry.sha256,entry.file);}
const result={success:true,checks,fullUiParity:false,goalComplete:false,publicConnections:0,liveLatencyAccepted:false,installedFrameRetained:true,serverDataBindingAccepted:true,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},evidence,scope:'Independent warm original picker, data-only server binding with stable controls, real native UI requests and full no-network launcher check. The reported live25second wait was not fully timed; this does not certify a public reconnect or complete UI parity.'};
await fs.writeFile(path.join(home,'reports/native-character-frontend-audit-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({...result,evidence:undefined}));
