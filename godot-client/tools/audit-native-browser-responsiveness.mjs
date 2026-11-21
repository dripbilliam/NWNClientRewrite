import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url));
const hash=bytes=>createHash('sha256').update(bytes).digest('hex'),evidence=[];
async function read(file){const bytes=await fs.readFile(path.join(home,file));evidence.push({file,sha256:hash(bytes)});return JSON.parse(bytes);}
async function sources(proof){for(const [file,digest]of Object.entries(proof.sourceSha256))assert.equal(hash(await fs.readFile(path.join(home,file))),digest,file+': stale evidence');}
let checks=0,metrics;
for(const [name,count]of [['pages-v1',32],['activation-v1',24],['keyboard-v1',15],['details-v1',31],['filters-v1',23],['retention-v1',16]]){
 const stem='reports/native-browser-responsive-'+name,result=await read(stem+'.json'),proof=await read(stem+'.debugger.json');
 assert.equal(result.success,true);assert.deepEqual(result.failures,[]);assert.equal(result.checks,count);
 for(const key of ['success','sourceUnchanged','armed'])assert.equal(proof[key],true,name+': '+key);
 for(const key of ['exception','engineOrLifetimeError'])assert.equal(proof[key],false,name+': '+key);
 assert.equal(proof.debuggerExit,0);assert.equal(proof.publicConnections,0);await sources(proof);checks+=count;
 if(name==='retention-v1'){metrics=result.metrics;assert.equal(metrics.row_nodes_created,128);assert.ok(metrics.duplicate_views_skipped>=8);assert.ok(metrics.row_updates<128*metrics.view_updates);}
}
const startup=await read('reports/native-browser-responsive-startup-v1.json');
for(const key of ['success','sourceUnchanged','debuggerArmed'])assert.equal(startup[key],true,key);
assert.equal(startup.nativeException,false);assert.equal(startup.nativeExit,0);assert.equal(startup.publicConnections,0);await sources(startup);
for(const file of ['reports/native-browser-responsive-pages-v1-internet.png','reports/native-browser-responsive-details-v1.png']){
 const bytes=await fs.readFile(path.join(home,file));assert.equal(bytes.subarray(1,4).toString(),'PNG');evidence.push({file,sha256:hash(bytes),review:'Original browser/Details geometry, integer fields, selected-row and modal composition reviewed.'});
}
const archive='backups/native-browser-responsiveness-v1.zip',checkpoint=await read(archive+'.verified.json');
assert.equal(checkpoint.verified,true);assert.equal(hash(await fs.readFile(path.join(home,archive))),checkpoint.sha256);
for(const entry of checkpoint.manifest){const file=entry.sourceScope==='workspace'?path.join(home,'..',entry.source):path.join(home,entry.file);assert.equal(hash(await fs.readFile(file)),entry.sha256,entry.file);}
const result={success:true,checks,fullUiParity:false,goalComplete:false,publicConnections:0,liveLatencyAccepted:false,metrics,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},evidence,scope:'Retained source-browser rows, dirty/duplicate presentation updates, current-scope input, JSON integer formatting, original modal/navigation/activation checks and a complete no-network launch. No clean FPS or public-server responsiveness acceptance.'};
await fs.writeFile(path.join(home,'reports/native-browser-responsiveness-audit-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({...result,evidence:undefined,metrics:undefined}));
