// Read-only scoped merchant evidence audit. Never launches a game or connects.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url)),evidence=[],receipts=[],sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const output=process.argv.find(v=>v.startsWith('--report='))?.slice(9)??'native-store-acceptance-v1.json';assert.match(output,/^native-store-[a-z0-9-]+\.json$/);
async function bytes(file){const value=await fs.readFile(path.join(home,file));evidence.push({file,sha256:sha(value),bytes:value.length});return value;}
async function read(file){return JSON.parse(await bytes(file));}
async function sources(proof){const entries=Object.entries(proof.sourceSha256);assert.ok(entries.length>100);for(const[file,digest]of entries)assert.equal(sha(await fs.readFile(path.join(home,file))),digest,file+' changed since receipt');return entries.length;}
async function kernel(name,count){
 const r=await read('reports/'+name+'.json'),p=await read('reports/'+name+'.debugger.json');assert.equal(r.success,true,name);assert.equal(r.checks,count);assert.deepEqual(r.failures,[]);
 for(const key of ['success','armed','normalHeap','sourceUnchanged'])assert.equal(p[key],true,name+'/'+key);
 for(const key of ['exception','engineOrLifetimeError'])assert.equal(p[key],false,name+'/'+key);
 assert.equal(p.debuggerExit,0);assert.equal(p.publicConnections,0);receipts.push({name,checks:count,sourceEntries:await sources(p)});return r;
}
async function live(name,count){
 const b=await bytes('reports/'+name+'.json');assert.ok(!/(?:[A-Z0-9]{5}-){6}[A-Z0-9]{5}/.test(b.toString()),'Credential-shaped material in evidence');const r=JSON.parse(b);
 for(const key of ['success','debuggerArmed','sourceUnchanged'])assert.equal(r[key],true,name+'/'+key);
 assert.equal(r.nativeException,false);assert.equal(r.nativeExit,0);assert.equal(r.publicConnections,0);assert.equal(r.renderingPrepared,false);assert.equal(r.native.success,true);assert.equal(r.native.workersRemaining,0);
 assert.deepEqual(r.actions.failures,[]);assert.equal(r.actions.checks.length,count);assert.ok(r.actions.checks.every(row=>row.passed));assert.ok(!/SCRIPT ERROR:|^ERROR:|ObjectDB instances leaked/m.test(r.engineErrors??''));
 assert.equal(r.endpoint,'127.0.0.1:5125');receipts.push({name,checks:count,sourceEntries:await sources(r)});return r;
}
const ui=await kernel('native-store-ui-final-v1',28);assert.ok(ui.aspect.length>0&&ui.aspect.every(row=>row.error<0.000001));assert.equal(ui.merchant.confirmation_text_parity,true);
await kernel('native-store-text-final-v1',1025);await kernel('native-store-playability-final-v1',1314);await kernel('native-store-frame-regression-v1',157);await kernel('native-store-barter-ui-v1',28);
const actions=await live('native-store-actions-final-v1',88);await live('native-store-barter-regression-v1',48);
for(const label of ['Actual local merchant uses the original native store GUI and confirmation meshes','Actual server merchant uses the native10×10 bottom-origin grid','Original native confirmation displays the actual server-context purchase price','Buy changes actual item ownership and server gold','Server purchase charge matches displayed price','Sell returns the same item to actual merchant ownership','Server sale credit matches displayed price'])assert.ok(actions.actions.checks.some(row=>row.label===label&&row.passed),label);
assert.equal(actions.native.gameplayUi.inventory.store_skin.ready,true);assert.equal(actions.native.gameplayUi.inventory.store_skin.failure,'');
for(const file of ['../backups/animations/rea-native-store-layout-v1.json','../backups/animations/rea-native-store-confirm-v1.json']){const record=await read(file);assert.ok(record.rows.length>0);assert.ok(record.rows.every(row=>row.subject.digest.sha256==='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'));}
for(const file of ['reports/native-store-resources-v3.json','reports/native-store-confirm-resources-v1.json']){const r=await read(file);assert.equal(r.success,true);assert.ok(Object.keys(r.layouts).length>0);}
await bytes('reports/native-store-ui-final-v1-buy.png');
const archive='backups/native-store-frame-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(home,archive))),checkpoint.sha256);
let verifiedSources=0;for(const entry of checkpoint.manifest){const file=entry.sourceScope==='workspace'?path.join(home,'..',entry.source):path.join(home,entry.file);assert.equal(sha(await fs.readFile(file)),entry.sha256,entry.file+' changed since checkpoint');verifiedSources++;}
const result={success:true,goalComplete:false,fullStoreParity:false,mixedClientAccepted:false,publicConnections:0,receipts,visibleArtworkRectangles:ui.aspect.length,maximumAxisScaleError:Math.max(...ui.aspect.map(row=>row.error)),checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files,verifiedSources},evidence,limits:'Original merchant/grid/tab/confirmation art and TLK wording, injected native UI controls and real owned-server transactions with regressions. Original identify/examine placement, scrollbar/font parity, full callback/stack/quantity/context/failed-transaction coverage and mixed original-client acceptance remain open. Rectangle measurements do not prove all texture UVs or visual parity.'};
await fs.writeFile(path.join(home,'reports',output),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,goalComplete:false,report:'reports/'+output,checkpoint:result.checkpoint}));
