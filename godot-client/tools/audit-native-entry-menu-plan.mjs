// Read-only data/research gate. Never accepts a visible menu from this plan.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url)),evidence=[];
const sha=b=>createHash('sha256').update(b).digest('hex');
async function bytes(file){const b=await fs.readFile(path.join(home,file));evidence.push({file,sha256:sha(b),bytes:b.length});return b;}
async function read(file){return JSON.parse(await bytes(file));}
const run='native-entry-menu-plan-v3',r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');
assert.equal(r.success,true);assert.equal(r.checks,136);assert.deepEqual(r.failures,[]);assert.equal(r.fullEntryMenuParity,false);assert.equal(r.visibleMenuAccepted,false);assert.equal(r.publicConnections,0);
for(const key of ['success','armed','normalHeap','sourceUnchanged'])assert.equal(p[key],true,key);
for(const key of ['exception','engineOrLifetimeError'])assert.equal(p[key],false,key);
assert.equal(p.debuggerExit,0);assert.equal(p.publicConnections,0);
const sources=Object.entries(p.sourceSha256);assert.ok(sources.length>100);
for(const[file,digest]of sources)assert.equal(sha(await fs.readFile(path.join(home,file))),digest,file+' changed after test');
for(const file of ['systems/native_data/entry_menu_layout.gd','tests/native_entry_menu_layout_test.gd'])assert.ok(p.sourceSha256[file],file+' missing from source proof');
assert.doesNotMatch((await bytes('reports/'+run+'.engine.log')).toString(),/(?:SCRIPT ERROR|^ERROR:|ObjectDB.*leak|resources still in use)/m);
const installed=await read('reports/native-ui-resources-inventory-v1.json');
for(const[name,count]of [['pre_main',7],['options_main',10],['options_pregame',7]]){
 assert.equal(Object.keys(r.menus[name].actions).length,count);
 assert.equal(r.resourceSha256[name],installed.resources.find(v=>v.name===name).sha256,name+' differs from installed GUI inventory');
 for(const action of Object.values(r.menus[name].actions)){assert.match(action.callback,/^0x140[0-9a-f]+$/);assert.ok(action.resource);assert.ok(action.rect);}
}
assert.equal(r.menus.options_main.actions.savecharbutton.sourceRef,50);assert.equal(r.menus.options_main.actions.savecharbutton.runtimeRef,0x19a0);
for(const[name,tag]of [['options_main','videooptionsbutton'],['options_pregame','videooptsbutton']])assert.equal(r.menus[name].actions[tag].runtimeRef,0x1baf);
const target='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
const initial=await read('../backups/animations/rea-native-entry-menus-v1.json'),follow=await read('../backups/animations/rea-native-entry-menu-actions-v1.json');
assert.equal(initial.rows.length,18);assert.equal(initial.observations.length,9);assert.equal(follow.rows.length,9);assert.equal(follow.observations.length,8);
for(const row of [...initial.rows,...follow.rows]){assert.equal(row.subject.digest.sha256,target);assert.ok(row.pseudocode);assert.ok(row.assembly.length);assert.ok(row.procedure.body.ranges.length);}
for(const address of ['0x140714140','0x140830b50','0x1408be9f0','0x14070e7f0','0x1406daa40','0x1407bfbe0'])assert.ok([...initial.rows,...follow.rows].some(v=>v.procedure.address===address),address+' missing');
assert.equal(follow.observations.filter(v=>v.operation==='resolve_containing_procedure'&&v.normalized_result.found===false).length,4,'Unanalyzed callback boundaries must remain explicit');
const oracleBytes=await bytes('../backups/animations/native-entry-menu-policy-observations-v1.json'),oracle=JSON.parse(oracleBytes);assert.equal(sha(oracleBytes),r.oracleSha256);assert.equal(oracle.target,target);assert.equal(oracle.main.length,4);assert.equal(oracle.localSaveLoad.length,32);
assert.equal(new Set(oracle.localSaveLoad.map(v=>JSON.stringify([v.clientServerMode,v.connected,v.appServerPresent,v.localhost,v.clientField5a4]))).size,32);
assert.equal(oracle.localSaveLoad.filter(v=>v.allowed).length,1);
assert.ok(oracle.main.every(v=>Object.keys(v.enabled).length===7&&Object.keys(v.colors).length===7));
await bytes('../scripts/inspect-native-entry-menu-policy.py');await bytes('../scripts/inspect-native-intratile-coordinator.py');
const failed=await read('reports/native-entry-menu-plan-candidate-v1.debugger.json');assert.equal(failed.success,false);assert.equal(failed.engineOrLifetimeError,true);assert.equal(failed.sourceUnchanged,true);assert.match((await bytes('reports/native-entry-menu-plan-candidate-v1.engine.log')).toString(),/Invalid access.*Obj_X/);
const previous=await read('reports/native-players-frame-acceptance-v1.json');assert.equal(previous.success,true);assert.equal(previous.checks,1683);assert.equal(previous.goalComplete,false);assert.equal(sha(await fs.readFile(path.join(home,previous.checkpoint.file))),previous.checkpoint.sha256);
const archive='backups/native-entry-menu-plan-v1.zip',c=await read(archive+'.verified.json');assert.equal(c.verified,true);assert.equal(sha(await fs.readFile(path.join(home,archive))),c.sha256);
for(const row of c.manifest){const file=row.sourceScope==='workspace'?path.join(home,'..',row.source):path.join(home,row.file);assert.equal(sha(await fs.readFile(file)),row.sha256,row.file+' changed since checkpoint');}
for(const file of ['scripts/inspect-native-entry-menu-policy.py','scripts/inspect-native-intratile-coordinator.py'])assert.ok(c.manifest.some(v=>v.source===file),file+' missing from rollback');
const result={success:true,checks:136,goalComplete:false,fullEntryMenuParity:false,visibleEntryMenuAccepted:false,authoritativeEntryMenuActionsAccepted:false,directOriginalClientComparisonAccepted:false,originalInstructionCases:36,nativeDataPlanAccepted:true,publicConnections:0,checkpoint:{file:archive,sha256:c.sha256,files:c.files},previous:previous.checkpoint,receipts:[{run,checks:r.checks,sourceEntries:sources.length}],evidence,limits:'Source GUI/model/control geometry and callbacks, runtime caption plan, original DM/menu and local-host Save/Load instruction cases only. Visible main/options owner remains generic. Native child actions, Export outcomes, configuration/storage, callbacks without analyzed boundaries, all role/state/gesture/input/font/scale/current-server catalog variants, direct original-client comparison and the entire UI audit remain open. No general porting acceptance.'};
const output='reports/native-entry-menu-plan-acceptance-v1.json';await fs.writeFile(path.join(home,output),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:136,goalComplete:false,visibleEntryMenuAccepted:false,report:output,checkpoint:result.checkpoint}));
