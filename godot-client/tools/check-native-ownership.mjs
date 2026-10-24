import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const read=async file=>JSON.parse((await fs.readFile(file,'utf8')).replace(/^\uFEFF/,''));
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
const accepted='godot-client/backups/native-retirement-tested-v1.zip';
const acceptedSha='578a8b295d0b7818559f6247fe15cfa2b7cb32213d4ea848ee104fa617c4c3d8';
for(const [name,checks]of [['native-data-v5',79],['native-installed-model-v2',199]]){
 const report=await read('godot-client/reports/'+name+'.json');
 assert.ok(report.passed&&report.native_only&&report.failures.length===0);assert.equal(report.checks,checks);
 for(const[name,sha]of Object.entries(report.sourceSha256)){const file='godot-client/'+(name.endsWith('_test.gd')?'tests/':'systems/native_data/')+name;assert.equal(digest(await fs.readFile(file)),sha,file);}
}
assert.equal(digest(await fs.readFile(accepted)),acceptedSha);
const start='godot-client/backups/native-ownership-start-wip-v1.zip';
assert.equal(digest(await fs.readFile(start)),'77f5bfb34bb70e40c59845d49e2f66c85db9db343fe51f8c166f14bd850b6894');
const stage={status:'partial native data foundation; live bridge still in use',fullyNativeRuntime:false,complete:false,nativeSources:['systems/native_data/binary_data.gd','systems/native_data/archive_index.gd','systems/native_data/resource_catalog.gd','systems/native_data/gff_document.gd','systems/native_data/two_da.gd','systems/native_data/binary_model.gd','systems/native_data/asset_service.gd'],authoredChecks:79,installedChecks:199,noPublicTest:true,remaining:['direct original texture/material and scene construction','full model animation/skin/reference/emitter data','all content/override/Workshop/NWSync mounts','native encrypted UDP/session/game replication','remaining JS gameplay/rules/audio/particle/services','full moving-world and performance acceptance','unresolved native shutdown access violation']};
const inventoryPath='godot-client/migration-inventory.json',inventory=await read(inventoryPath);
assert.equal(inventory.modules.length,866);assert.equal(inventory.testFiles.length,747);
if(process.argv.includes('--inventory')){
 for(const file of ['src/resource_archive.js','electron/indexed_erf.mjs','src/gff.js','src/gff_text.js','src/area.js','src/binary_mdl.js']){const row=inventory.modules.find(row=>row.file===file);assert.ok(row,file);row.nativeFullOwnership=stage;}
 inventory.nativeOwnershipTarget={runtime:'Godot GDScript/native extensions; no JS/Electron runtime endpoint',referenceOnly:'Preserved JS client and offline test/oracle tooling',baselineModules:866,baselineTestFiles:747};
 await fs.writeFile(inventoryPath,JSON.stringify(inventory,null,2)+'\n');console.log(JSON.stringify({complete:false,authoredChecks:79,installedChecks:199,inventoryAnnotated:true}));process.exit(0);
}
const checkpoint='godot-client/backups/native-resource-core-wip-v1.zip',verified=await read(checkpoint+'.verified.json');
assert.ok(verified.verified);assert.equal(digest(await fs.readFile(checkpoint)),verified.sha256);
for(const row of verified.manifest)assert.equal(digest(await fs.readFile(row.sourceScope==='workspace'?row.source:'godot-client/'+row.file)),row.sha256,row.file);
const contractPath='scripts/performance-queue/source-contract.json',contract=await read(contractPath);
assert.equal(contract.godotMigration.lastAcceptedCheckpoint,accepted);assert.equal(contract.godotMigration.lastAcceptedCheckpointSha256,acceptedSha);
for(const row of verified.manifest)contract.sha256[row.sourceScope==='workspace'?row.source:'godot-client/'+row.file]=row.sha256;
contract.preparedAt=new Date().toISOString();
Object.assign(contract.godotMigration,{status:'work in progress; fully native runtime requested; native resource/model data foundation verified',complete:false,checkpoint,checkpointSha256:verified.sha256,checkpointAcceptance:'WORK IN PROGRESS: native data/worker checks only; no live-area switch, complete native runtime, public/performance acceptance or shutdown fault resolution',nativeFullOwnership:{...stage,checkpoint,checkpointSha256:verified.sha256,startingCheckpoint:start,startingCheckpointSha256:'77f5bfb34bb70e40c59845d49e2f66c85db9db343fe51f8c166f14bd850b6894',lastAcceptedCheckpoint:accepted,lastAcceptedCheckpointSha256:acceptedSha}});
await fs.writeFile(contractPath,JSON.stringify(contract,null,2)+'\n');
console.log(JSON.stringify({complete:false,checkpoint,files:verified.files,sha256:verified.sha256,authoredChecks:79,installedChecks:199,lastAcceptedCheckpoint:accepted}));
