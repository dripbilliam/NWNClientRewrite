// Scoped pregame integration acceptance. Full original entry/UI parity is false.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url)),workspace=path.resolve(home,'..');
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const read=async name=>JSON.parse(await fs.readFile(path.join(home,name),'utf8'));
async function pinned(proof){const entries=Object.entries(proof.sourceSha256);assert.ok(entries.length>100);for(const[file,digest]of entries)assert.equal(sha(await fs.readFile(path.join(home,file))),digest,file+' changed');return entries.length;}
const receipts=[];
for(const[run,count]of[['native-pregame-layout-final-v1',136],['native-pregame-input-final-v1',26],['native-pregame-ingame-final-v1',35]]){
 const r=await read('reports/'+run+'.json'),proof=await read('reports/'+run+'.debugger.json');assert.equal(r.success,true);assert.equal(r.checks,count);assert.deepEqual(r.failures,[]);
 for(const key of['success','armed','sourceUnchanged','normalHeap'])assert.equal(proof[key],true);for(const key of['exception','engineOrLifetimeError'])assert.equal(proof[key],false);assert.equal(proof.debuggerExit,0);assert.equal(proof.publicConnections,0);receipts.push({run,checks:count,sources:await pinned(proof)});
}
const input=await read('reports/native-pregame-input-final-v1.json');assert.deepEqual(input.events,['settings','multiplayer','exit']);assert.equal(input.physicalMouseWarped,false);assert.equal(input.fullEntryMenuParity,false);assert.equal(input.pregame.main.kind,'pre_main');assert.equal(input.pregame.options.kind,'options_pregame');assert.equal(input.pregame.keys.hotbar_slots,36);assert.equal(input.pregame.keys.unsupported_actions,28);
for(const run of['native-pregame-startup-final-v2','native-pregame-local-final-v1']){
 const r=await read('reports/'+run+'.json'),native=await read('reports/'+run+'.native.json');for(const key of['success','sourceUnchanged','debuggerArmed'])assert.equal(r[key],true);assert.equal(r.nativeException,false);assert.equal(r.nativeExit,0);assert.equal(r.publicConnections,0);assert.equal(r.protocolOnly,true);assert.equal(r.renderingPrepared,false);
 assert.equal(native.pregame_cleanup.closed,true);assert.equal(native.pregame_cleanup.workers_running,0);assert.equal(native.pregame_cleanup.full_entry_menu_parity,false);
 let checks;
 if(run.includes('startup')){assert.equal(native.network_connections,0);assert.equal(native.pregame_entry.connected,false);assert.equal(native.pregame_entry.success,true);checks=Object.values(native.pregame_entry.checks).length;assert.equal(checks,5);assert.ok(Object.values(native.pregame_entry.checks).every(value=>value===true));assert.equal(native.offline_prework.ready,true);assert.equal(native.offline_ui_preload.ready,true);assert.equal(native.final_window.focused,false);assert.equal(native.final_window.unfocusable,true);assert.equal(native.final_window.mouse_mode,0);if(native.final_window.screens>1)assert.notEqual(native.final_window.screen,native.final_window.primary);}
 else{checks=r.actions.checks.length;assert.equal(checks,170);assert.ok(r.actions.checks.every(row=>row.passed));assert.deepEqual(r.actions.failures,[]);assert.equal(r.endpoint,'127.0.0.1:5125');assert.equal(r.native.workersRemaining,0);assert.equal(native.pregame_ui.failure,'');}
 receipts.push({run,checks,sources:await pinned(r)});
}
const original=[];
for(const file of['native-entry-menu-policy-observations-v1.json','rea-native-entry-menus-v1.json','rea-native-entry-menu-actions-v1.json','rea-native-pregame-news-v1.json']){const bytes=await fs.readFile(path.join(workspace,'backups/animations',file)),r=JSON.parse(bytes);assert.equal(r.target??r.binarySha256??r.rows[0].subject.digest.sha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');original.push({file,sha256:sha(bytes)});}
const screenshots=[];for(const kind of['main','options']){const file='reports/native-pregame-input-final-v1-'+kind+'.png',bytes=await fs.readFile(path.join(home,file));assert.equal(bytes.subarray(0,8).toString('hex'),'89504e470d0a1a0a');screenshots.push({file,sha256:sha(bytes)});}
const archive='backups/native-pregame-menu-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(sha(await fs.readFile(path.join(home,archive))),checkpoint.sha256);for(const row of checkpoint.manifest){const file=row.sourceScope==='workspace'?path.join(workspace,row.source):path.join(home,row.file);assert.equal(sha(await fs.readFile(file)),row.sha256);}
const result={success:true,checks:receipts.reduce((sum,row)=>sum+row.checks,0),goalComplete:false,fullEntryMenuParity:false,fullUiParity:false,originalPregameSourcePresentationAccepted:true,supportedPregameRoutesAccepted:true,interruptedPressRetirementAccepted:true,realNetworkForbiddenStartupRouteAccepted:true,independentCatalogCleanupAccepted:true,localServerRegressionAccepted:true,publicConnections:0,manualClientTouched:false,receipts,original,screenshots,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},remaining:'Campaign New/Load/save browsing, Movies, modern local News/Storage/ConfigWindow, persistent mods/CD-key settings UI, backgrounds/intro/DM/host/role/scale/localization/tooltips/sound and original-client comparison. Browser/login/character-list visual migration remains open; other entire-UI gaps are unchanged. Parallel startup watchdog failure is retained; only the independent final-v2 startup run is accepted.'};
await fs.writeFile(path.join(home,'reports/native-pregame-acceptance-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks:result.checks,goalComplete:false,checkpoint:result.checkpoint}));
