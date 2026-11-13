// File-only fixed source/data staging. Does not import child_process or run helpers.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {workspace,project,parityRoot,inside,record,sha,slash,sourceInventory,verifiedFixture,cases} from './native-release-functional-lib.mjs';
import {safeName,inspectEngine,nativeFiles,json,unchanged} from './native-startup-experiment-lib.mjs';

const [mode,label]=process.argv.slice(2);assert.equal(mode,'--stage');safeName(label);
const directory=inside(parityRoot,path.join(parityRoot,label));assert.ok(!fs.existsSync(directory),'Preserve prior stage');
const sourceInputs=sourceInventory(),data=verifiedFixture(),engines={editor:inspectEngine('editor'),release:inspectEngine('release')};
const nativeInputs=nativeFiles.map(file=>record(path.join(project,file)));
const extraInputs=['package.json','src/gff.js','src/gff_text.js','godot-client/tools/native-engine-runtime.cjs','scripts/native-startup-experiment-lib.mjs','scripts/native-release-functional-lib.mjs','scripts/prepare-native-release-functional.mjs','scripts/run-native-release-functional.mjs','scripts/tests/native-release-functional.test.mjs'].map(file=>record(path.join(workspace,file)));
const lookupInputs=['global_script_class_cache.cfg','uid_cache.bin'].map(file=>path.join(project,'.godot',file)).filter(file=>fs.existsSync(file)).map(record);
const fixed=[...sourceInputs,...extraInputs,...nativeInputs,...lookupInputs,...Object.values(engines),...data.files,...data.provenance];
const signature=sha(JSON.stringify(fixed));const privateWorkspace=path.join(directory,'workspace'),copy=path.join(privateWorkspace,'godot-client'),fixture=path.join(directory,'captured-data');
fs.mkdirSync(copy,{recursive:true});fs.mkdirSync(fixture);
const copied=[];
function duplicate(row,destination){inside(directory,destination);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.copyFileSync(path.join(workspace,row.path),destination);assert.equal(record(destination).sha256,row.sha256);copied.push({file:destination,sha256:row.sha256});}
for(const row of [...sourceInputs,...extraInputs,...nativeInputs])duplicate(row,path.join(privateWorkspace,row.path));
for(const row of Object.values(engines))duplicate(row,path.join(copy,slash(path.relative(project,row.file))));
for(const row of data.files)duplicate(row,path.join(fixture,row.relative));
fs.mkdirSync(path.join(copy,'.godot'),{recursive:true});
fs.writeFileSync(path.join(copy,'.godot/extension_list.cfg'),'res://native/particle_kernel.gdextension\nres://native/resource_index.gdextension\n');
const privateLookupSeeds=[];
for(const row of lookupInputs){
 const destination=path.join(copy,'.godot',path.basename(row.path));fs.copyFileSync(path.join(workspace,row.path),destination);assert.equal(record(destination).sha256,row.sha256);privateLookupSeeds.push({file:destination,sha256:row.sha256});
}
const packageDirectory=path.join(copy,'.cache/release-tests',signature.slice(0,16),'project');fs.mkdirSync(packageDirectory,{recursive:true});
// This is the only external native helper copied by the normal release preparer.
const modeSource=nativeInputs.find(row=>row.path.endsWith('/native-window/nwn-window-modes.exe'));duplicate(modeSource,path.join(packageDirectory,'.cache/native-window/nwn-window-modes.exe'));
const executable=path.join(packageDirectory,'NwnReleaseTest.exe');duplicate(engines.release,executable);
assert.deepEqual(unchanged(fixed),[],'Current inputs changed during copy');
json(path.join(directory,'stage.json'),{success:true,status:'STAGED_NOT_EXECUTED',directory,privateWorkspace,copy,fixture,sourceSignature:signature,sourceInputs,extraInputs,nativeInputs,engines,fixed,copied,privateLookupSeeds,privateImportCacheMayBeGenerated:true,dataProvenance:data.provenance,manifest:data.metadata.manifest,resourceCount:data.metadata.resources.length,packageDirectory,executable,cases,productionSourceEdits:0,defaultChanges:0,nativeBuilds:0,engineLaunches:0,keyAccess:0});
console.log(JSON.stringify({success:true,status:'STAGED_NOT_EXECUTED',directory,sourceSignature:signature,sourceInputs:sourceInputs.length,capturedFiles:data.files.length,engines:2,nativeOutputs:6,engineLaunches:0}));
