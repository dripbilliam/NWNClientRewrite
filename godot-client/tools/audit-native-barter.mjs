// Read-only scoped acceptance audit. Does not launch a client or contact servers.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url)),evidence=[],receipts=[],sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const output=process.argv.find(v=>v.startsWith('--report='))?.slice(9)??'native-barter-acceptance-v1.json';assert.match(output,/^native-barter-[a-z0-9-]+\.json$/);
async function bytes(file){const value=await fs.readFile(path.join(home,file));evidence.push({file,sha256:sha(value),bytes:value.length});return value;}
async function read(file){return JSON.parse(await bytes(file));}
async function source(proof){let count=0;for(const[file,digest]of Object.entries(proof.sourceSha256)){assert.equal(sha(await fs.readFile(path.join(home,file))),digest,file+' changed since receipt');count++;}assert.ok(count>100);return count;}
async function kernel(name,count){
 const r=await read('reports/'+name+'.json'),p=await read('reports/'+name+'.debugger.json');assert.equal(r.success,true,name);assert.equal(r.checks,count);assert.deepEqual(r.failures,[]);
 for(const key of ['success','armed','normalHeap','sourceUnchanged'])assert.equal(p[key],true,name+'/'+key);
 for(const key of ['exception','engineOrLifetimeError'])assert.equal(p[key],false,name+'/'+key);
 assert.equal(p.debuggerExit,0);assert.equal(p.publicConnections,0);receipts.push({name,checks:count,sourceEntries:await source(p)});return r;
}
async function live(name,count){
 const b=await bytes('reports/'+name+'.json');assert.ok(!/(?:[A-Z0-9]{5}-){6}[A-Z0-9]{5}/.test(b.toString()),'Credential-shaped material in evidence');const r=JSON.parse(b);
 for(const key of ['success','debuggerArmed','sourceUnchanged'])assert.equal(r[key],true,name+'/'+key);
 assert.equal(r.nativeException,false);assert.equal(r.nativeExit,0);assert.equal(r.publicConnections,0);assert.equal(r.renderingPrepared,false);assert.equal(r.native.success,true);assert.equal(r.native.workersRemaining,0);
 assert.deepEqual(r.actions.failures,[]);assert.equal(r.actions.checks.length,count);assert.ok(r.actions.checks.every(row=>row.passed));
 assert.ok(!/SCRIPT ERROR:|^ERROR:|ObjectDB instances leaked/m.test(r.engineErrors??''));receipts.push({name,checks:count,sourceEntries:await source(r)});return r;
}
const ui=await kernel('native-barter-ui-v5',28);await kernel('native-barter-playability-final-v1',1314);await kernel('native-barter-frame-regression-v1',157);await kernel('native-barter-art-bindings-v1',8);
assert.equal(ui.artwork_geometry.length,21);assert.ok(ui.artwork_geometry.every(row=>row.axis_scale_error<0.000001));
const trade=await live('native-barter-exchange-final-v2',48);await live('native-barter-gold-regression-v2',85);
for(const label of ['Original server returns examination of the actual remote offer','Both real Accept requests complete the original-server trade','Completed trade transfers the exact canonical items to opposite players','Completed trade transfers exactly five server gold','Peer-initiated real trade opens native recipient-side controls','Cancellation returns each actual item to its previous owner','Cancellation refunds reserved gold without transferring currency'])assert.ok(trade.actions.checks.some(row=>row.label===label&&row.passed),label);
assert.equal(trade.endpoint,'127.0.0.1:5125');assert.equal(trade.barterPeer.metadata.protocolOnly,true);assert.equal(trade.barterPeer.trade.completed,false);assert.equal(trade.barterPeer.trade.open,false);
for(const file of ['tools/private-login.cjs','tools/native-barter-peer.mjs','../src/network_barter.js','../src/network_world.js','../src/network_game_messages.js'])assert.ok(trade.sourceSha256[file],file+' missing from live pins');
const tap=(await bytes('reports/native-barter-protocol-final-v2.tap')).toString();assert.match(tap,/# tests 62\r?\n/);assert.match(tap,/# pass 62\r?\n/);assert.match(tap,/# fail 0\r?\n/);
const oracle=await read('../backups/animations/native-barter-wire-observations-v1.json');assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,288);
await bytes('reports/native-barter-ui-v5-locked.png');
const archive='backups/native-player-barter-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(home,archive))),checkpoint.sha256);
let verifiedSources=0;for(const entry of checkpoint.manifest){const file=entry.sourceScope==='workspace'?path.join(home,'..',entry.source):path.join(home,entry.file);assert.equal(sha(await fs.readFile(file)),entry.sha256,entry.file+' changed since checkpoint');verifiedSources++;}
const result={success:true,goalComplete:false,fullBarterParity:false,mixedClientAccepted:false,publicConnections:0,receipts,protocolTests:62,visibleArtworkRectangles:21,maximumAxisScaleError:Math.max(...ui.artwork_geometry.map(row=>row.axis_scale_error)),checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files,verifiedSources},evidence,limits:'Scoped original-server two-participant item/gold exchange, both roles and cancellation refunds. Native GUI input uses a separate authored-snapshot check. Mixed original/replacement clients, range/area/control changes, stack merging, full failure feedback, custom resources and complete original UI/combat parity remain open. Visible rectangle proportions do not prove every texture/UV correct.'};
await fs.writeFile(path.join(home,'reports',output),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,goalComplete:false,report:'reports/'+output,checkpoint:result.checkpoint}));
