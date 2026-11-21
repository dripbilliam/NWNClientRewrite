import fs from 'node:fs/promises';import assert from 'node:assert/strict';import crypto from 'node:crypto';
import {weatherIntegrationComplete} from './weather-evidence.cjs';import {nativeShutdownComplete} from './shutdown-evidence.cjs';import {integrationComplete} from './integration-evidence.cjs';
const read=async name=>JSON.parse((await fs.readFile(name,'utf8')).replace(/^\uFEFF/,'')),hash=b=>crypto.createHash('sha256').update(b).digest('hex'),prefix='godot-client/reports/';
const state=await read(prefix+'weather-state-v1.json'),owner=await read(prefix+'weather-owner-v2.json');
assert.ok(state.passed&&state.rows===105&&state.comparisons===1077&&state.failures.length===0);assert.ok(owner.passed&&owner.checks.length===13&&owner.checks.every(v=>v.passed));
assert.match(await fs.readFile(prefix+'weather-backend-v2.log','utf8'),/# tests 36\r?\n# suites 0\r?\n# pass 36\r?\n# fail 0/);
const local=await read(prefix+'weather-state-local-v2.json'),normal=await read(prefix+'weather-normal-local-v1.json');
assert.ok(local.success&&weatherIntegrationComplete(local)&&nativeShutdownComplete(local));assert.ok(normal.success&&integrationComplete('text',normal)&&nativeShutdownComplete(normal));
for(const report of [local,normal]){assert.equal(report.endpoint,'127.0.0.1:5121');assert.equal(report.nativeExit,0);assert.equal(report.nativeShutdown.forced,false);assert.equal(report.nativeShutdown.observed.retiredWorldOwners,6);assert.ok(report.particles.epochs.every(v=>v.closed&&v.remainingThreads===0));}
const original={
 '../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe':'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a',
 '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe':'98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6',
 'src/main.js':'7e84f596cc2c13f0d307931f2a90ce541a3e01f292b6be1df7f7a92741f0fb9e',
 'dist/assets/index-DOqjcyKQ.js':'7448b09d205748ab44fe0174a765e36729fa4c88433fcfa33f9c739f87db3a66'
};for(const [file,digest]of Object.entries(original))assert.equal(hash(await fs.readFile(file)),digest,file);
const prior='godot-client/backups/native-retirement-tested-v1.zip',priorSha='578a8b295d0b7818559f6247fe15cfa2b7cb32213d4ea848ee104fa617c4c3d8';assert.equal(hash(await fs.readFile(prior)),priorSha);
const supplemental=[];for(const file of ['src/network_area_weather.js','test/network-area-weather.test.js'])supplemental.push({file,sha256:hash(await fs.readFile(file)),scope:'New weather packet support; supplements the preserved 866-module / 747-test migration baseline'});
const stage={status:'state and packet foundation verified; original precipitation rendering still pending',evidence:'godot-client/NATIVE-WEATHER.md',originalInstructionCases:105,originalComparisons:1077,nativeOwnerChecks:13,backendChecks:36,localWeatherChecks:22,normalGameplayChecks:16,localReport:'weather-state-local-v2.json',normalReport:'weather-normal-local-v1.json',presentationPending:true,sixModelPlanOnly:true,weatherRenderingAccepted:false,nativePauseTimingAccepted:false,fullMigration:false,publicServerAccepted:false,performanceAccepted:false,supplementalSourceFiles:supplemental};
const inventoryPath='godot-client/migration-inventory.json',inventory=await read(inventoryPath);assert.equal(inventory.modules.length,866);assert.equal(inventory.testFiles.length,747);
if(process.argv.includes('--inventory')){
 inventory.supplementalWeatherSources=supplemental;
 for(const file of ['src/network_area.js','src/network_game_messages.js','src/network_world.js']){const row=inventory.modules.find(v=>v.file===file);assert.ok(row,file);row.nativeWeatherState=stage;}
 await fs.writeFile(inventoryPath,JSON.stringify(inventory,null,2)+'\n');console.log(JSON.stringify({state:'work in progress',baselineModules:866,baselineTests:747,supplemental:supplemental.length,stage}));process.exit(0);
}
const checkpoint='godot-client/backups/native-weather-state-wip-v1.zip',verified=await read(checkpoint+'.verified.json');assert.ok(verified.verified);assert.equal(hash(await fs.readFile(checkpoint)),verified.sha256);
for(const row of verified.manifest)assert.equal(hash(await fs.readFile(row.sourceScope==='workspace'?row.source:'godot-client/'+row.file)),row.sha256,row.file);
const contractPath='scripts/performance-queue/source-contract.json',contract=await read(contractPath);assert.equal(contract.godotMigration.lastAcceptedCheckpoint,prior);assert.equal(contract.godotMigration.lastAcceptedCheckpointSha256,priorSha);
for(const row of verified.manifest)contract.sha256[row.sourceScope==='workspace'?row.source:'godot-client/'+row.file]=row.sha256;
contract.preparedAt=new Date().toISOString();Object.assign(contract.godotMigration,{status:'active; weather state foundation tested, precipitation presentation pending',complete:false,checkpoint,checkpointSha256:verified.sha256,checkpointAcceptance:'WORK IN PROGRESS: packets/rules/original numeric weather state locally verified; no actual rain/snow rendering or full weather acceptance',weatherStateWorkInProgress:{...stage,checkpoint,checkpointSha256:verified.sha256,rollbackCheckpoint:prior,rollbackSha256:priorSha}});
await fs.writeFile(contractPath,JSON.stringify(contract,null,2)+'\n');console.log(JSON.stringify({goal:'active',complete:false,checkpoint,sha256:verified.sha256,files:verified.files,weatherRenderingAccepted:false,lastAcceptedCheckpoint:prior}));
