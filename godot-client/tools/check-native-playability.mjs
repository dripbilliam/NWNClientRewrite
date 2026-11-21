// Current local playability milestone. Historical render/capture reports remain
// evidence of their own source revisions, not assertions about this source tree.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const base='godot-client/',read=async file=>JSON.parse((await fs.readFile(file,'utf8')).replace(/^\uFEFF/,''));
const sha=async file=>createHash('sha256').update(await fs.readFile(file)).digest('hex');
const headless=await read(base+'reports/native-light-motion-v6.json');
assert.ok(headless.passed&&headless.sourceUnchanged&&!headless.failures.length);
for(const [file,digest]of Object.entries(headless.sourceSha256))assert.equal(await sha(base+file),digest,file);
const counts={integration:141,'play-input':29,'binary-motion':47421,'binary-tile-lights':1322,'original-surfaces':33081,'native-ui-text':1025,'native-ui-skin':203,'native-inventory':607};
for(const [name,count]of Object.entries(counts)){
 const row=headless.results.find(row=>row.name===name);assert.ok(row&&row.exit===0&&!row.engineErrors);assert.equal(row.checks,count);
 const child=await read(row.report);assert.equal(child.failures.length,0);
}
const live=await read(base+'reports/native-prelude-world-v21.json');
assert.ok(live.success&&live.sourceUnchanged&&live.protocolOnly&&!live.renderingPrepared&&live.publicConnections===0&&!live.performanceAccepted);
assert.ok(live.debuggerArmed&&!live.nativeException&&!live.engineErrors&&live.debuggerExit===0&&live.nativeUiReady);
for(const [file,digest]of Object.entries(live.sourceSha256))assert.equal(await sha(base+file),digest,file);
for(const [file,digest]of Object.entries(live.loadedProtocolModules))assert.equal(await sha(file),digest,file);
assert.ok(Math.abs(live.authoritativeClickDistance-1.5)<0.01&&live.authoritativeDriveDistance>0.2);
assert.ok(live.native.keyboard_probe.released&&live.keyboardOperations.includes('stop')&&live.native.camera.valid);
assert.equal(live.admittedAreas.length,2);assert.notEqual(live.admittedAreas[0].id,live.admittedAreas[1].id);
assert.ok(live.native.door_probe.opened_by_server&&live.native.door_probe.new_area_ready&&live.native.interaction_probe.server_dialog_closed);
assert.ok(live.uiMessages.examine>=2&&live.uiMessages['dialog-entry']>=2&&live.uiMessages['dialog-close']>=2);
assert.equal(live.native.retired_areas[0].terrain.rendered_tiles,9);assert.equal(live.native.world.terrain.rendered_tiles,100);assert.equal(live.native.world.entities,92);
assert.ok(live.native.pointer_probe.terrain_hit&&live.native.pointer_probe.error<0.001&&live.native.pointer_probe.runtime_geometry_reads===0);
assert.ok(live.native.keyboard_probe.inventory_open&&live.native.inventory_probe.rendered_equipment_roundtrip&&live.native.inventory_probe.creature_slots_hidden);
assert.ok(live.native.inventory_probe.visible_pixels>0&&live.native.inventory_reopen_probe.visible_pixels>0);
assert.equal(live.native.inventory_probe.icons.errors.length,0);assert.equal(live.native.inventory_reopen_probe.icons.errors.length,0);
assert.equal(live.native.inventory_probe.icons.rendered,live.native.inventory_reopen_probe.icons.rendered);assert.ok(live.native.inventory_reopen_probe.icons.reused>live.native.inventory_probe.icons.reused);
assert.equal(live.inventoryProofs.length,2);assert.equal(live.inventoryProofs[0].itemId,live.inventoryProofs[1].itemId);assert.ok(live.uiMessages['inventory-result']>=2);
const iconOracle=await read(base+'reports/native-item-icon-oracle-v1.json');assert.equal(iconOracle.cases.length,192);
for(const [file,digest]of Object.entries(iconOracle.sources))assert.equal(await sha(file),digest,file);
assert.ok(!/^(?:ERROR:|SCRIPT ERROR)|ObjectDB instances leaked|resources still in use/m.test(await fs.readFile(base+'reports/native-prelude-world-v21.engine.log','utf8')));
const accepted=base+'backups/native-retirement-tested-v1.zip',acceptedSha='578a8b295d0b7818559f6247fe15cfa2b7cb32213d4ea848ee104fa617c4c3d8';assert.equal(await sha(accepted),acceptedSha);
const stage={complete:false,fullyNativeRuntime:false,performanceAccepted:false,nativeShutdownFaultResolved:false,status:'Native inventory/equipment/icons, movement with inventory open, NPC dialogue and server-owned Prelude transition pass; NUI deferred for playability',publicConnections:0,liveReport:base+'reports/native-prelude-world-v21.json',headlessReport:base+'reports/native-light-motion-v6.json',headlessChecks:Object.values(counts).reduce((a,b)=>a+b,0),authoritativeClickMetres:live.authoritativeClickDistance,authoritativeKeyboardMetres:live.authoritativeDriveDistance,areas:[{tiles:9,entities:20},{tiles:100,entities:92}],unhandledMessages:live.diagnostics.filter(row=>row.code==='network.game-message-unhandled').map(({major,minor})=>({major,minor})),remaining:['Inventory item abilities/stores, spellbook/casting, combat/action UI and other essential native gameplay systems','Door/placeable controller animation, effects/weather and lighting/roof cutaway parity','Complete native walkmesh collision and responsive reconciled prediction','Profile/Workshop/NWSync native mounting and normal launcher replacement','Return transitions, reconnect/save persistence, sustained moving-scene performance and historical shutdown fault'],nuiDeferred:true,interactiveLauncher:'godot-client/play-native-local.ps1',interactiveLauncherAcceptance:'Same native entry; unlimited interactive lifetime/manual close mode added, no separate manual play acceptance',cleanupAcceptance:'Native close ran with no engine/lifetime error or trapped exception; not a new full survivor/worker audit'};
if(process.argv.includes('--inventory')){
 const file=base+'migration-inventory.json',inventory=await read(file);
 inventory.nativeLocalPlayability=stage;inventory.nativeOwnershipPriority='Original-server playable native Prelude: essential gameplay first, NUI deferred, preserve native binary compatibility';
 for(const row of inventory.modules){
  if(row.nativeActorScene){row.nativeActorScene.status=stage.status;row.nativeActorScene.remaining=stage.remaining;row.nativeLightMotion={...row.nativeLightMotion,status:stage.status,latestLocalAttempt:{report:stage.liveReport,worldVerified:true,loginRejected:false},remaining:stage.remaining};}
  if(row.file==='electron/network_peer.mjs')row.sha256=await sha(row.file);
 }
 await fs.writeFile(file,JSON.stringify(inventory,null,2)+'\n');console.log(JSON.stringify({verified:true,stage}));
}else{
 const checkpoint=base+'backups/native-inventory-wip-v1.zip',verified=await read(checkpoint+'.verified.json');assert.ok(verified.verified);assert.equal(await sha(checkpoint),verified.sha256);
 for(const row of verified.manifest)assert.equal(await sha(row.sourceScope==='workspace'?row.source:base+row.file),row.sha256,row.file);
 const file='scripts/performance-queue/source-contract.json',contract=await read(file);assert.equal(contract.godotMigration.lastAcceptedCheckpoint,accepted);assert.equal(contract.godotMigration.lastAcceptedCheckpointSha256,acceptedSha);
 for(const row of verified.manifest)contract.sha256[row.sourceScope==='workspace'?row.source:base+row.file]=row.sha256;
 contract.preparedAt=new Date().toISOString();Object.assign(contract.godotMigration,{complete:false,status:stage.status,checkpoint,checkpointSha256:verified.sha256,checkpointAcceptance:'WIP: real original-server Prelude movement, NPC interaction and one native area transition; full gameplay/rendering/stability/performance remain incomplete',nativeFullOwnership:{...stage,checkpoint,checkpointSha256:verified.sha256,lastAcceptedCheckpoint:accepted,lastAcceptedCheckpointSha256:acceptedSha}});
 await fs.writeFile(file,JSON.stringify(contract,null,2)+'\n');console.log(JSON.stringify({verified:true,checkpoint,files:verified.files,sha256:verified.sha256}));
}
