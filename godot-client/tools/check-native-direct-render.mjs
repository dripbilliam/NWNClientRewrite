import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const read=async p=>JSON.parse((await fs.readFile(p,'utf8')).replace(/^\uFEFF/,''));
const sha=async p=>createHash('sha256').update(await fs.readFile(p)).digest('hex');
const base='godot-client/';
async function pins(records){for(const [file,hash] of Object.entries(records))assert.equal(await sha(base+file),hash,file);}
for(const [name,checks]of [['native-data-v6',80],['native-installed-model-v3',199]]){
 const r=await read(base+'reports/'+name+'.json');assert.ok(r.passed&&r.native_only&&!r.failures.length);assert.equal(r.checks,checks);
 await pins(Object.fromEntries(Object.entries(r.sourceSha256).map(([n,v])=>[(n.endsWith('_test.gd')?'tests/':'systems/native_data/')+n,v])));
}
for(const [name,checks,file]of [['native-texture-data-v2',369,'texture_data.gd'],['native-prepared-cache-v1',15,'prepared_cache.gd']]){
 const r=await read(base+'reports/'+name+'.json');assert.ok(r.passed&&!r.failures.length);assert.equal(r.checks,checks);await pins({['systems/native_data/'+file]:r.sourceSha256});
}
const gpu=await read(base+'reports/native-direct-render-v5.debugger.json');assert.ok(gpu.passed&&gpu.debuggerArmed&&gpu.sourceUnchanged&&!gpu.nativeException&&!gpu.scriptEngineOrLifetimeErrors);assert.equal(gpu.checks,153);await pins(gpu.sourceSha256);
const entry=await read(base+'reports/native-model-entry-v2.json'),verification=await read(base+'reports/native-model-entry-v2.verification.json');
assert.ok(entry.success&&entry.native_rendering&&!entry.complete_migration&&entry.cache_hit);assert.equal(entry.frames,90);assert.equal(entry.worker_tasks_remaining,0);
assert.ok(verification.passed&&verification.debuggerArmed&&verification.sourceUnchanged&&!verification.nativeException);await pins(verification.sourceSha256);
const accepted=base+'backups/native-retirement-tested-v1.zip',acceptedSha='578a8b295d0b7818559f6247fe15cfa2b7cb32213d4ea848ee104fa617c4c3d8';assert.equal(await sha(accepted),acceptedSha);
assert.equal(await sha(base+'backups/native-resource-core-wip-v1.zip'),'10fe4e4544f1e1fb67b74d01851bc5e90b5b98716af9f2e5f33ab1db0adb62b8');
const stage={complete:false,fullyNativeRuntime:false,status:'Direct native static model/raster/cache entry verified; multiplayer still uses JS preparation',nativeShutdownFaultResolved:false,checks:{data:80,installed:199,textures:369,cache:15,gpu:153},noPublicTest:true,nativeEntry:'native-model.ps1',remaining:['native area streaming','animation/skin/reference/emitter/equipment','complete material and content formats','native content/Workshop/override/NWSync mounts','default multiplayer render-path integration','full moving-world and sustained performance acceptance','historical native shutdown access violation']};
const inventoryPath=base+'migration-inventory.json',inventory=await read(inventoryPath);assert.equal(inventory.modules.length,866);assert.equal(inventory.testFiles.length,747);
if(process.argv.includes('--inventory')){
 for(const file of ['src/resource_archive.js','electron/indexed_erf.mjs','src/gff.js','src/gff_text.js','src/area.js','src/binary_mdl.js','src/native_tga.js','src/bioware_dds.js','src/raster_texture.js','src/texture_resource.js','src/prepared_model_geometry.js','src/model_hierarchy.js','src/model_material.js']){const row=inventory.modules.find(r=>r.file===file);assert.ok(row,file);row.nativeFullOwnership=stage;}
 await fs.writeFile(inventoryPath,JSON.stringify(inventory,null,2)+'\n');console.log(JSON.stringify({...stage,inventoryAnnotated:true}));process.exit(0);
}
const checkpoint=base+'backups/native-direct-render-wip-v1.zip',verified=await read(checkpoint+'.verified.json');assert.ok(verified.verified);assert.equal(await sha(checkpoint),verified.sha256);
for(const row of verified.manifest)assert.equal(await sha(row.sourceScope==='workspace'?row.source:base+row.file),row.sha256,row.file);
const contractPath='scripts/performance-queue/source-contract.json',contract=await read(contractPath);assert.equal(contract.godotMigration.lastAcceptedCheckpoint,accepted);assert.equal(contract.godotMigration.lastAcceptedCheckpointSha256,acceptedSha);
for(const row of verified.manifest)contract.sha256[row.sourceScope==='workspace'?row.source:base+row.file]=row.sha256;
contract.preparedAt=new Date().toISOString();Object.assign(contract.godotMigration,{complete:false,status:stage.status,checkpoint,checkpointSha256:verified.sha256,checkpointAcceptance:'WORK IN PROGRESS: direct static native rendering only; not full area/gameplay, shutdown fault resolution or performance acceptance',nativeFullOwnership:{...stage,checkpoint,checkpointSha256:verified.sha256,lastAcceptedCheckpoint:accepted,lastAcceptedCheckpointSha256:acceptedSha}});
await fs.writeFile(contractPath,JSON.stringify(contract,null,2)+'\n');console.log(JSON.stringify({...stage,checkpoint,files:verified.files,sha256:verified.sha256}));
