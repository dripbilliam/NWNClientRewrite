import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const base='godot-client/',read=async file=>JSON.parse((await fs.readFile(file,'utf8')).replace(/^\uFEFF/,''));
const sha=async file=>createHash('sha256').update(await fs.readFile(file)).digest('hex');
async function pins(records){for(const [file,digest]of Object.entries(records))assert.equal(await sha(base+file),digest,file);}
for(const [name,count]of [['native-creature-data-v4',90],['native-data-v8',80],['native-installed-model-v6',199]]){
 const report=await read(base+'reports/'+name+'.json');assert.ok(report.passed&&report.native_only&&!report.failures.length);assert.equal(report.checks,count);
 const records=name==='native-creature-data-v4'?report.sourceSha256:Object.fromEntries(Object.entries(report.sourceSha256).map(([file,digest])=>[(file.endsWith('_test.gd')?'tests/':'systems/native_data/')+file,digest]));await pins(records);
}
const gpu=await read(base+'reports/native-creature-parts-render-v1.json'),gpuProof=await read(base+'reports/native-creature-parts-render-v1.debugger.json');
assert.ok(gpu.passed&&gpu.native_only&&!gpu.failures.length&&!gpu.performance_accepted);assert.equal(gpu.checks,18);assert.equal(gpu.resources.meshes_created,1);assert.equal(gpu.resources.textures_created,2);
assert.ok(gpuProof.passed&&gpuProof.debuggerArmed&&!gpuProof.nativeException&&!gpuProof.scriptEngineOrLifetimeErrors&&gpuProof.sourceUnchanged);await pins(gpuProof.sourceSha256);
const world=await read(base+'reports/native-capture-world-v5.json'),worldProof=await read(base+'reports/native-capture-world-v5.verification.json');
assert.ok(world.success&&!world.world_complete&&!world.complete_migration);assert.equal(world.terrain.rendered_tiles,48);assert.equal(world.objects.rendered,889);assert.equal(world.objects.deferred_actors,8);assert.equal(world.objects.deferred_items,1);assert.equal(world.worker_tasks_remaining,0);
assert.ok(worldProof.passed&&worldProof.debuggerArmed&&!worldProof.nativeException&&worldProof.sourceUnchanged&&!worldProof.failures.length);await pins(worldProof.sourceSha256);
const baseline=await read(base+'reports/prelude-baseline-v1.json');assert.equal(baseline.module,'Prelude');assert.equal(baseline.endpoint,'127.0.0.1:5121');assert.ok(baseline.ownedUdpConfirmed&&baseline.moduleLoadLogConfirmed&&!baseline.campaignPlayabilityAccepted);await pins(baseline.sourceSha256);
const input=await read(base+'reports/native-capture-input-v1.json');assert.equal(await sha(input.input),input.sha256);assert.ok(!input.network&&!input.renderingPrepared);
const accepted=base+'backups/native-retirement-tested-v1.zip',acceptedSha='578a8b295d0b7818559f6247fe15cfa2b7cb32213d4ea848ee104fa617c4c3d8';assert.equal(await sha(accepted),acceptedSha);
assert.equal(await sha(base+'backups/native-world-static-wip-v1.zip'),'a7d8fe8c5eac9ecad29e0bf2cf5804974be28af446cdd3900b015ce102a390a1');
const stage={complete:false,fullyNativeRuntime:false,status:'Native original creature appearance and PLT model preparation/drawing verified; full actor scene, animation/equipment and live campaign integration pending',priority:'Complete native game rendering first; local Prelude is the playability baseline; further performance experiments deferred',nativeShutdownFaultResolved:false,noPublicTest:true,playabilityBaseline:{module:'Prelude',endpoint:'127.0.0.1:5121',accepted:false},checks:{creatureData:90,originalPltVariants:12,creaturePartGpu:18,archiveWorkers:80,installedOriginal:199},staticWorld:{terrain:48,objects:889,deferredActors:8,deferredItems:1},performanceAccepted:false,remaining:['complete native actor scene assembly and original animation/skin/supermodel decoding','held/worn equipment and ground items','full model/light/emitter/reference/visual behavior','gameplay/UI and actual local campaign native-render integration','remaining native stability diagnosis and complete playable-world acceptance','further performance work after full rendering']};
const inventoryPath=base+'migration-inventory.json',inventory=await read(inventoryPath);assert.equal(inventory.modules.length,866);assert.equal(inventory.testFiles.length,747);
if(process.argv.includes('--inventory')){
 for(const file of ['src/bioware_plt.js','src/network_creature_models.js','src/resource_worker_tasks.js']){const row=inventory.modules.find(item=>item.file===file);assert.ok(row,file);row.nativeCreatureAssets=stage;}
 inventory.nativeOwnershipPriority=stage.priority;await fs.writeFile(inventoryPath,JSON.stringify(inventory,null,2)+'\n');console.log(JSON.stringify({...stage,inventoryAnnotated:true}));process.exit(0);
}
const checkpoint=base+'backups/native-creature-assets-wip-v1.zip',verified=await read(checkpoint+'.verified.json');assert.ok(verified.verified);assert.equal(await sha(checkpoint),verified.sha256);
for(const row of verified.manifest)assert.equal(await sha(row.sourceScope==='workspace'?row.source:base+row.file),row.sha256,row.file);
const contractPath='scripts/performance-queue/source-contract.json',contract=await read(contractPath);assert.equal(contract.godotMigration.lastAcceptedCheckpoint,accepted);assert.equal(contract.godotMigration.lastAcceptedCheckpointSha256,acceptedSha);
for(const row of verified.manifest)contract.sha256[row.sourceScope==='workspace'?row.source:base+row.file]=row.sha256;
contract.preparedAt=new Date().toISOString();Object.assign(contract.godotMigration,{complete:false,status:stage.status,checkpoint,checkpointSha256:verified.sha256,checkpointAcceptance:'WORK IN PROGRESS: native original creature data/palette assets only; complete actors/live native campaign/render retirement unaccepted; performance deferred',nativeFullOwnership:{...stage,checkpoint,checkpointSha256:verified.sha256,lastAcceptedCheckpoint:accepted,lastAcceptedCheckpointSha256:acceptedSha}});
await fs.writeFile(contractPath,JSON.stringify(contract,null,2)+'\n');console.log(JSON.stringify({...stage,checkpoint,files:verified.files,sha256:verified.sha256}));
