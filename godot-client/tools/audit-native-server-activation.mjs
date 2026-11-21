// Prepared native activation receipts; no full browser/UI acceptance claim.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=fileURLToPath(new URL('../',import.meta.url)),workspace=path.resolve(project,'..'),sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(project,file),'utf8'));
const receipts=[];
for(const [run,checks] of [['native-server-activation-headless-v1',24],['native-server-activation-keys-v1',15],['native-server-activation-details-v1',28],['native-server-activation-entry-v1',31],['native-server-activation-pages-v1',28]]){
 const r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');assert.equal(r.success,true);assert.equal(r.checks,checks);assert.deepEqual(r.failures,[]);assert.equal(r.publicConnections,0);
 for(const key of ['success','sourceUnchanged','armed','normalHeap'])assert.equal(p[key],true);for(const key of ['exception','engineOrLifetimeError','graphical'])assert.equal(p[key],false);assert.equal(p.debuggerExit,0);
 for(const [file,digest] of Object.entries(p.sourceSha256))assert.equal(sha(await fs.readFile(path.join(project,file))),digest,file+' changed');receipts.push({run,checks,graphical:false});
}
const inputs=['tools/server-browser.test.mjs','tools/server-browser-service.mjs','tools/server-browser-store.mjs','tools/server-browser-sort.mjs','tools/server-browser-filters.mjs','tools/server-endpoint.mjs','tools/local-protocol.cjs','../src/server_discovery.js','../test/server-discovery.test.js'];const sources={};
for(const file of inputs)sources[file]=sha(await fs.readFile(path.join(project,file)));
const service=spawnSync(process.execPath,['--test','godot-client/tools/server-browser.test.mjs','test/server-discovery.test.js'],{cwd:workspace,encoding:'utf8',windowsHide:true});assert.equal(service.status,0,service.stdout+service.stderr);assert.match(service.stdout,/# tests 59\r?\n/);assert.match(service.stdout,/# pass 59\r?\n/);assert.match(service.stdout,/# fail 0\r?\n/);
for(const [file,digest] of Object.entries(sources))assert.equal(sha(await fs.readFile(path.join(project,file))),digest);receipts.push({run:'native-server-activation-service-audit-v1',checks:59});
const dossier=await fs.readFile(path.join(workspace,'backups/animations/rea-native-server-activation-v1.json')),evidence=JSON.parse(dossier);assert.equal(evidence.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
for(const key of ['browser-native-connect','0x1401f5300','0x1401e5d20'])assert.ok(evidence.rows[key].normalized_result?.pseudocode);assert.equal(evidence.rows['browser-key-router-full-view'].normalized_result.coverage.exhausted,true);
const archive='backups/native-server-activation-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(project,archive))),checkpoint.sha256);for(const row of checkpoint.manifest)assert.equal(sha(await fs.readFile(row.sourceScope==='workspace'?path.join(workspace,row.source):path.join(project,row.file))),row.sha256);
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),sources,receipts,evidenceSha256:sha(dossier),checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},publicConnections:0,graphicalAccepted:false,localServerAccepted:false,fullUiParity:false,fullServerBrowserParity:false,goalComplete:false,remaining:'Fresh graphical and startup/local-server checks pending while manual session stays open. Complete original Enter/default-button/role comparison and full UI ledger remain open. See NATIVE-SERVER-ACTIVATION.md.'};
await fs.writeFile(path.join(project,'reports/native-server-activation-service-audit-v1.tap'),service.stdout,{flag:'wx'});await fs.writeFile(path.join(project,'reports/native-server-activation-prepared-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:result.checks,graphicalAccepted:false,localServerAccepted:false,goalComplete:false,checkpoint:result.checkpoint}));
