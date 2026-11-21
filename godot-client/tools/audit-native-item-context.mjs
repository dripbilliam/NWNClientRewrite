// Scoped item-wheel milestone only. No inference of entire UI completion.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url)),workspace=path.resolve(home,'..');
const sha=b=>createHash('sha256').update(b).digest('hex');
const read=async file=>JSON.parse(await fs.readFile(path.join(home,file),'utf8'));
const receipts=[];
async function sources(proof){const rows=Object.entries(proof.sourceSha256);assert.ok(rows.length>100);for(const[file,digest]of rows)assert.equal(sha(await fs.readFile(path.join(home,file))),digest,file+' changed after check');return rows.length;}
for(const [kind,count]of [['rules',4886],['ui',51],['barter',43],['quickbar',43],['startup',16]]){
 const run='native-item-context-'+kind+'-final-v1',r=await read('reports/'+run+'.json'),proof=await read('reports/'+run+'.debugger.json');
 assert.equal(r.success,true);assert.equal(r.checks,count);assert.deepEqual(r.failures,[]);for(const key of ['success','armed','sourceUnchanged','normalHeap'])assert.equal(proof[key],true);for(const key of ['exception','engineOrLifetimeError'])assert.equal(proof[key],false);assert.equal(proof.debuggerExit,0);assert.equal(proof.publicConnections,0);
 receipts.push({run,checks:count,sources:await sources(proof)});
}
for(const [run,count]of [['native-item-context-local-final-v1',154],['native-item-context-barter-local-v1',57]]){
 const r=await read('reports/'+run+'.json');for(const key of ['success','sourceUnchanged','debuggerArmed'])assert.equal(r[key],true);assert.equal(r.nativeExit,0);assert.equal(r.nativeException,false);assert.equal(r.publicConnections,0);assert.equal(r.endpoint,'127.0.0.1:5125');assert.equal(r.native.workersRemaining,0);assert.equal(r.actions.checks.length,count);assert.ok(r.actions.checks.every(row=>row.passed));assert.deepEqual(r.actions.failures,[]);receipts.push({run,checks:count,sources:await sources(r)});
 const native=await read('reports/'+run+'.native.json');assert.equal(native.gameplay_ui.inventory.item_context.native_only,true);assert.equal(native.gameplay_ui.inventory.item_context.full_item_parity,false);
 if(count===154){assert.ok(r.actions.checks.some(row=>row.label==='Server creates a separate potion item and conserves total stack count'));assert.ok(r.actions.checks.some(row=>row.label==='Original server learn reply releases pending even for a non-scroll refusal'));assert.ok(native.gameplay_ui.inventory.learn_acks>=1);}
 else assert.ok(r.actions.checks.some(row=>row.label==='Original two-player server confirms item-wheel removal into the backpack'));
}
const startup=await read('reports/native-item-context-startup-final-v1.json');assert.equal(startup.held.tables_ready,false);assert.equal(startup.held.hud_ready,true);assert.equal(startup.ready.completed_tables,32);
for(const scale of ['1.0','1.5','2.0'])assert.equal((await fs.readFile(path.join(home,'reports/native-item-context-ui-final-v1-family-'+scale+'.png'))).subarray(0,8).toString('hex'),'89504e470d0a1a0a');
const original=[];
for(const file of ['native-item-radial-observations.json','native-item-context-observations-v1.json','native-item-menu-request-observations-v1.json']){const bytes=await fs.readFile(path.join(workspace,'backups/animations',file)),value=JSON.parse(bytes);assert.equal(value.target??value.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');if(file.includes('context'))assert.equal(value.cases.length,2688);if(file.includes('request'))assert.equal(value.cases.length,30);original.push({file,sha256:sha(bytes)});}
const nodeFiles=['test/network-item-menu-requests-native.test.js','test/network-game-session.test.js'],protocolFiles=['src/network_player_requests.js','src/network_inventory_response.js','src/network_game_messages.js','electron/network_game_session.mjs',...nodeFiles];
const protocolHashes={};for(const file of protocolFiles)protocolHashes[file]=sha(await fs.readFile(path.join(workspace,file)));
const node=spawnSync(process.execPath,['--test',...nodeFiles],{cwd:workspace,encoding:'utf8',timeout:30000});await fs.writeFile(path.join(home,'reports/native-item-context-protocol-final-v1.log'),node.stdout+node.stderr,{flag:'wx'});assert.equal(node.status,0,node.stdout+node.stderr);assert.match(node.stdout,/# pass 38/);assert.match(node.stdout,/# fail 0/);for(const[file,digest]of Object.entries(protocolHashes))assert.equal(sha(await fs.readFile(path.join(workspace,file))),digest);
const archive='backups/native-item-context-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(home,archive))),checkpoint.sha256);for(const row of checkpoint.manifest){const file=row.sourceScope==='workspace'?path.join(workspace,row.source):path.join(home,row.file);assert.equal(sha(await fs.readFile(file)),row.sha256);}
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),nodeTests:38,goalComplete:false,fullItemParity:false,nativeItemWheelsAccepted:true,originalContextPowerAndPacketOraclesAccepted:true,nativeInputAndFamilyDragAccepted:true,authoritativeSplitAndUseAccepted:true,authoritativeLearnRefusalAckAccepted:true,positiveScrollLearningVerified:false,twoPlayerOfferWheelAccepted:true,publicConnections:0,manualClientTouched:false,receipts,original,protocolHashes,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},remaining:'Positive scroll learning, alternate/associate/DM restrictions, all tool/family/assignment cases, paired and nested-container equipment, full feedback/state/amount-edit/tooltip/hover behavior and original-client visual comparison. Entire UI objective remains active.'};await fs.writeFile(path.join(home,'reports/native-item-context-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:result.checks,nodeTests:38,goalComplete:false,checkpoint:result.checkpoint}));
