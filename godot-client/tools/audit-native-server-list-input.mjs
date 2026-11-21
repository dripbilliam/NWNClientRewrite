// Headless preparation checkpoint, deliberately not graphical/live acceptance.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=fileURLToPath(new URL('../',import.meta.url)),workspace=path.resolve(project,'..'),sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(project,file),'utf8'));
const receipts=[];
for(const [run,checks] of [['native-server-list-keys-headless-v1',15],['native-server-labels-headless-v3',28],['native-server-labels-entry-headless-v1',31]]){
 const r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');assert.equal(r.success,true);assert.equal(r.checks,checks);assert.deepEqual(r.failures,[]);assert.equal(r.publicConnections,0);
 for(const key of ['success','sourceUnchanged','armed','normalHeap'])assert.equal(p[key],true);for(const key of ['exception','engineOrLifetimeError','graphical'])assert.equal(p[key],false);assert.equal(p.debuggerExit,0);
 for(const [file,digest] of Object.entries(p.sourceSha256))assert.equal(sha(await fs.readFile(path.join(project,file))),digest,file+' changed');
 receipts.push({run,checks,graphical:false});
}
const inputs=['tools/server-browser.test.mjs','tools/server-browser-service.mjs','tools/server-browser-store.mjs','tools/server-browser-sort.mjs','tools/server-browser-filters.mjs','tools/server-endpoint.mjs','tools/local-protocol.cjs','../src/server_discovery.js','../test/server-discovery.test.js'];
const sources={};for(const file of inputs)sources[file]=sha(await fs.readFile(path.join(project,file)));
const service=spawnSync(process.execPath,['--test','godot-client/tools/server-browser.test.mjs','test/server-discovery.test.js'],{cwd:workspace,encoding:'utf8',windowsHide:true});assert.equal(service.status,0,service.stdout+service.stderr);assert.match(service.stdout,/# tests 58\r?\n/);assert.match(service.stdout,/# pass 58\r?\n/);assert.match(service.stdout,/# fail 0\r?\n/);
for(const [file,digest] of Object.entries(sources))assert.equal(sha(await fs.readFile(path.join(project,file))),digest);
await fs.writeFile(path.join(project,'reports/native-server-list-input-service-audit-v1.tap'),service.stdout,{flag:'wx'});receipts.push({run:'native-server-list-input-service-audit-v1',checks:58});
const binary=sha(await fs.readFile(path.resolve(workspace,'../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe')));assert.equal(binary,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
const bytes=await fs.readFile(path.join(workspace,'backups/animations/native-server-list-key-observations-v1.json')),oracle=JSON.parse(bytes);assert.equal(oracle.binarySha256,binary);assert.equal(oracle.rows.length,240);assert.equal(sha(await fs.readFile(path.join(workspace,'scripts/inspect-native-server-list-keys.py'))),oracle.harnessSha256);
const archive='backups/native-server-list-input-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(project,archive))),checkpoint.sha256);for(const row of checkpoint.manifest)assert.equal(sha(await fs.readFile(row.sourceScope==='workspace'?path.join(workspace,row.source):path.join(project,row.file))),row.sha256);
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),originalListKeyCases:240,oracleSha256:sha(bytes),sources,receipts,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},publicConnections:0,graphicalAccepted:false,localServerAccepted:false,fullUiParity:false,fullServerBrowserParity:false,goalComplete:false,remaining:'Fresh graphical text-placement/scale and startup/local-server checks are pending while manual session remains open; full browser and UI audit still incomplete. See NATIVE-SERVER-LIST-INPUT.md.'};
await fs.writeFile(path.join(project,'reports/native-server-list-input-prepared-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:result.checks,originalListKeyCases:240,graphicalAccepted:false,localServerAccepted:false,goalComplete:false,checkpoint:result.checkpoint}));
