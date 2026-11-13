// File-only staging. No child_process import, engine launch, exporter or native build.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {workspace,project,stageRoot,sourceClosure,record,sha,json,inside,safeName,privateProject,presets,inspectEngine,nativeFiles,unchanged,slash} from './native-startup-experiment-lib.mjs';

const [mode,label]=process.argv.slice(2);
assert.equal(mode,'--stage','File-only operation: --stage UNIQUE-LABEL. Engine execution is separate and requires its approved lane.');safeName(label);
const directory=inside(stageRoot,path.join(stageRoot,label));assert.ok(!fs.existsSync(directory),'Preserve earlier evidence');
const closure=sourceClosure(),engines={editor:inspectEngine('editor'),release:inspectEngine('release')};
const guards=nativeFiles.map(file=>record(path.join(project,file)));
const controls=['scripts/native-startup-experiment-lib.mjs','scripts/prepare-native-startup-experiment.mjs','scripts/run-native-startup-experiment.mjs','godot-client/tests/native_startup_load_probe.gd'];
const controlRows=controls.map(file=>record(path.join(workspace,file)));
const signature=sha(JSON.stringify({files:closure.files,controls:controlRows,engines,guards}));
const copy=path.join(directory,'project');fs.mkdirSync(copy,{recursive:true});
// Windows editor exports shadow-copy GDExtensions beside their DLL. Keep even
// those engine-created temporary files entirely inside this new private stage.
const libraryDirectory=path.join(directory,'native-libraries');fs.mkdirSync(libraryDirectory);
const privateLibraries=[];
for(const source of ['.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-resource-index/nwn-resource-index.dll']){
 const origin=path.join(project,source),file=path.join(libraryDirectory,path.basename(source));fs.copyFileSync(origin,file);
 const row=record(file);assert.equal(row.sha256,guards.find(guard=>guard.path==='godot-client/'+source).sha256);privateLibraries.push(row);
}
for(const row of closure.files){const file=inside(copy,path.join(copy,row.relative));fs.mkdirSync(path.dirname(file),{recursive:true});fs.copyFileSync(path.join(project,row.relative),file);assert.equal(record(file).sha256,row.sha256);}
const originalProject=fs.readFileSync(path.join(project,'project.godot'),'utf8');
fs.writeFileSync(path.join(copy,'project.godot'),privateProject(originalProject));
for(const name of ['particle_kernel','resource_index']){
 const relative='native/'+name+'.gdextension',original=fs.readFileSync(path.join(project,relative),'utf8');
 assert.ok(!original.includes('[dependencies]'),'Review native dependencies before copying an expanded extension config');
 let replacements=0;
 const transformed=original.replace(/"res:\/\/(\.cache\/[^\"]+\.dll)"/g,(_all,relativeDll)=>{replacements++;return '"'+slash(path.join(libraryDirectory,path.basename(relativeDll)))+'"';});
 assert.equal(replacements,1,'Expected one independently pinned library per native extension');
 assert.notEqual(transformed,original,'Expected exact native library rewrite');fs.writeFileSync(path.join(copy,relative),transformed);
}
fs.copyFileSync(path.join(project,'tests/native_startup_load_probe.gd'),path.join(copy,'__startup_probe.gd'));
fs.writeFileSync(path.join(copy,'__startup_probe.tscn'),'[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://__startup_probe.gd" id="1"]\n[node name="OwnedStartupLoadProbe" type="Node"]\nscript = ExtResource("1")\n');
fs.writeFileSync(path.join(copy,'export_presets.cfg'),presets());
fs.mkdirSync(path.join(copy,'.godot'),{recursive:true});
fs.writeFileSync(path.join(copy,'.godot/extension_list.cfg'),'res://native/particle_kernel.gdextension\nres://native/resource_index.gdextension\n');
const stagedInputs=[],initialPrivateCache=[];
function inventory(folder){for(const entry of fs.readdirSync(folder,{withFileTypes:true})){const file=path.join(folder,entry.name);assert.ok(!entry.isSymbolicLink());if(entry.isDirectory())inventory(file);else{const row={relative:slash(path.relative(copy,file)),bytes:fs.statSync(file).size,sha256:record(file).sha256};(row.relative.startsWith('.godot/')?initialPrivateCache:stagedInputs).push(row);}}}
inventory(copy);stagedInputs.sort((a,b)=>a.relative.localeCompare(b.relative));
const changed=unchanged([...closure.files,...controlRows,...guards,...Object.values(engines)]);assert.deepEqual(changed,[],'Current source changed during private copy');
json(path.join(directory,'stage.json'),{success:true,status:'STAGED_NOT_EXECUTED',directory,copy,sourceSignature:signature,closure,controls:controlRows,engines,guards,privateLibraries,stagedInputs,initialPrivateCache,privateImportCacheMayBeGenerated:true,projectAdaptations:['Private probe main scene and app/user-data identity only','Native extension references target exact pinned DLL copies in stage/native-libraries; all editor temporary copies stay private'],profilesRead:0,engineLaunches:0,exports:0,nativeBuilds:0,productionSourceEdits:0});
console.log(JSON.stringify({success:true,status:'STAGED_NOT_EXECUTED',directory,sourceSignature:signature,sourceFiles:closure.files.length,engines:2,guards:guards.length,engineLaunches:0,exports:0}));
