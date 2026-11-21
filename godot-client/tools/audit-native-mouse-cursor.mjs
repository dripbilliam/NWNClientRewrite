// Scoped cursor milestone. A green result never accepts the full UI goal.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url));
const sha=b=>createHash('sha256').update(b).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(home,file),'utf8'));
const receipts=[];
async function sources(value){const rows=Object.entries(value.sourceSha256);assert.ok(rows.length>100);for(const[file,digest]of rows)assert.equal(sha(await fs.readFile(path.join(home,file))),digest,file+' changed since check');return rows.length;}
for(const [run,count]of [['native-mouse-cursor-final-v3',2798],['native-target-cursor-final-v3',14099],['native-mouse-cursor-startup-final-v3',16]]){
 const r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');
 assert.equal(r.success,true);assert.equal(r.checks,count);assert.deepEqual(r.failures,[]);
 for(const key of ['success','sourceUnchanged','armed','normalHeap'])assert.equal(p[key],true);
 for(const key of ['exception','engineOrLifetimeError'])assert.equal(p[key],false);
 assert.equal(p.debuggerExit,0);assert.equal(p.publicConnections,0);
 receipts.push({run,checks:count,sources:await sources(p)});
}
const cursor=await read('reports/native-mouse-cursor-final-v3.json');
assert.equal(cursor.state.prepared,92);assert.equal(cursor.state.pending,0);assert.equal(cursor.physical_pointer_changes,0);assert.equal(cursor.state.full_cursor_parity,false);
for(const suffix of ['atlas','scales'])assert.equal((await fs.readFile(path.join(home,'reports/native-mouse-cursor-final-v3-'+suffix+'.png'))).subarray(0,8).toString('hex'),'89504e470d0a1a0a');
const held=await read('reports/native-mouse-cursor-startup-final-v3.json');assert.equal(held.held.tables_ready,false);assert.ok(held.held.pending_tables.includes('feat'));assert.equal(held.held.party_visible,true);assert.equal(held.ready.completed_tables,32);
const run='native-mouse-cursor-local-final-v3',server=await read('reports/'+run+'.json');
for(const key of ['success','sourceUnchanged','debuggerArmed'])assert.equal(server[key],true);
assert.equal(server.nativeExit,0);assert.equal(server.nativeException,false);assert.equal(server.publicConnections,0);assert.equal(server.endpoint,'127.0.0.1:5125');assert.equal(server.actions.checks.length,146);assert.ok(server.actions.checks.every(row=>row.passed));assert.deepEqual(server.actions.failures,[]);assert.equal(server.native.workersRemaining,0);
receipts.push({run,checks:146,sources:await sources(server)});
const native=await read('reports/'+run+'.native.json');assert.equal(native.gameplay_ui.mouse_cursor.native_only,true);assert.equal(native.gameplay_ui.mouse_cursor.prepared,92);assert.equal(native.gameplay_ui.mouse_cursor.publications,0);assert.equal(native.gameplay_ui.mouse_cursor.focused,false);
const originals=[];
for(const file of ['native-mouse-cursor-observations-v1.json','native-target-cursor-observations-v1.json']){
 const bytes=await fs.readFile(path.join(home,'../backups/animations',file)),value=JSON.parse(bytes);assert.equal(value.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 if(value.names){assert.equal(value.names.length,293);assert.equal(value.selection.length,2336);assert.equal(value.press.length,32);}else{assert.equal(value.spells.length,128);assert.equal(value.scripts.length,1024);}
 originals.push({file,sha256:sha(bytes)});
}
const archive='backups/native-mouse-cursor-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(home,archive))),checkpoint.sha256);
for(const row of checkpoint.manifest){const file=row.sourceScope==='workspace'?path.join(home,'..',row.source):path.join(home,row.file);assert.equal(sha(await fs.readFile(file)),row.sha256);}
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),goalComplete:false,fullCursorParity:false,nativeContextCursorsAccepted:true,originalMaskAndNameOracleAccepted:true,scopedNativeInputAccepted:true,localAuthoritativeRegressionAccepted:true,hardwareCursorLiveReview:false,publicConnections:0,manualClientTouched:false,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},receipts,originals,remaining:'Full associate/dead/DM/directional/map/modal/lobby cursors, exact SDL scaler and mouse override/software path, receiver cursor alias, broad GUI classification/range/LOS and live original-client comparison; inventory/store/trade item radial layers and the rest of the complete UI audit remain open.'};
await fs.writeFile(path.join(home,'reports/native-mouse-cursor-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,checks:result.checks,goalComplete:false,checkpoint:result.checkpoint}));
