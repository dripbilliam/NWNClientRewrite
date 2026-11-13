'use strict';
// Stage source and immutable replay selections only. This script never launches Godot.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const stage=path.join(root,'.cache/nwn61/entry-menu-split-pair-a');
const candidateInput=path.join(stage,'candidate-input');
const controlInput=path.join(stage,'control-input');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const manifest=require(path.join(root,'tools/native-feature-manifest.cjs'));
const sourceBefore=manifest.sourceIdentity(root);
const baselineFile=path.join(root,'.cache/native-presentation-parity/production-replay/nwn61-current-entry-budget-4ms-c/production-selection.json');
const baseline=JSON.parse(fs.readFileSync(baselineFile,'utf8'));
const frozenPair=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn61/tail-entry-d/pair.json'),'utf8'));
const seedsFile=frozenPair.preferenceSeeds.file;
assert.equal(sha(seedsFile),frozenPair.preferenceSeeds.sha256,'preference seed manifest drift');
const seeds=JSON.parse(fs.readFileSync(seedsFile,'utf8'));
const capture='C:/Users/Niflheim/AppData/Roaming/nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf';
const recordingSha='1913892cd42db0f68dfa1b0edbdd37be4c380bdda50c95c178dc4ca2ba38a463';
assert.equal(sha(path.join(capture,'recording.json')),recordingSha,'recording drift');
assert.equal(baseline.runtime.executableSha256,'753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b');
assert.deepEqual(baseline.options,['--performance-runtime=verified-native','--render-profile=gameplay','--detailed-profiling=off','--entry-commit=staged','--entry-commit-budget=4ms']);
assert(!fs.existsSync(stage),'Never overwrite a staged pair');

const files=new Set(sourceBefore.files.map(row=>row.file));
for(const name of ['join-native.ps1','tools/native-feature-manifest.cjs','tools/native-production-selection.cjs','data/native_text_codepages.json','.godot/global_script_class_cache.cfg','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/build-manifest.json','.tools/native-core/Godot_native_core_e_win64.exe','.tools/native-core/accepted-core-e.json'])files.add(name);
for(const name of ['.cache/native-clock-source-v1/clock_source.gdextension','.cache/native-clock-source-v1/nwn-clock-source.dll'])if(fs.existsSync(path.join(root,name)))files.add(name);
const walkNative=relative=>{for(const entry of fs.readdirSync(path.join(root,relative),{withFileTypes:true})){
 assert(!entry.isSymbolicLink(),'Unsupported native source symlink');
 const name=path.posix.join(relative,entry.name);
 if(entry.isDirectory())walkNative(name);else if(/\.(gd|gdextension|cpp|hpp|h|c)$/.test(name))files.add(name);
}};
walkNative('native');
const excluded=new Set(['node_modules','runtime-logs','reports','backups']);
const walkCode=relative=>{for(const entry of fs.readdirSync(path.join(root,relative),{withFileTypes:true})){
 if(entry.isSymbolicLink()||entry.name.startsWith('.')||excluded.has(entry.name))continue;
 const name=path.posix.join(relative,entry.name);
 if(entry.isDirectory())walkCode(name);else if(/\.(gd|gdshader|gdshaderinc|gdextension|tscn|tres)$/.test(name))files.add(name);
}};
walkCode('');
const copy=(from,to,link=false)=>{fs.mkdirSync(path.dirname(to),{recursive:true});if(link)fs.linkSync(from,to);else fs.copyFileSync(from,to,fs.constants.COPYFILE_EXCL);};
const sorted=[...files].sort();
for(const relative of sorted){
 assert(!path.isAbsolute(relative)&&!relative.split(/[\\/]/).includes('..'),'Unsafe source path');
 const from=path.join(root,relative),to=path.join(candidateInput,relative);
 copy(from,to,/\.(exe|dll)$/i.test(relative));
}
assert.equal(manifest.sourceIdentity(root).sha256,sourceBefore.sha256,'Current source changed during capture');
assert.equal(manifest.sourceIdentity(candidateInput).sha256,sourceBefore.sha256,'Candidate source copy differs');

const frozen={
 'systems/native_main_menu.gd':{file:'.cache/nwn61/core-entry-split-a/candidate-input/systems/native_main_menu.gd',sha256:'2d111f9391bcef8e43fd736aa2963c9d6f19691757e7c4a1227d26c049a064d4'},
 'systems/native_video_options.gd':{file:'.cache/nwn61/tail-entry-d/candidate-input/systems/native_video_options.gd',sha256:'964668aedbdc8b62b86ebeb8c8604db27ab2668b8466165a76c95adc4e021087'},
 'systems/native_key_settings.gd':{file:'.cache/nwn61/tail-entry-d/candidate-input/systems/native_key_settings.gd',sha256:'b573e74e09e38d0855b4faa700a34a7820305d3a17a83c7cc09837c607b89c14'}
};
for(const relative of sorted){
 const to=path.join(controlInput,relative),from=frozen[relative]?path.join(root,frozen[relative].file):path.join(candidateInput,relative);
 if(frozen[relative])assert.equal(sha(from),frozen[relative].sha256,'Frozen control drift '+relative);
 copy(from,to,!frozen[relative]);
}
const candidateHelper=require(path.join(candidateInput,'tools/native-production-selection.cjs'));
const controlHelper=require(path.join(controlInput,'tools/native-production-selection.cjs'));
(async()=>{
 const candidateReceipt=await candidateHelper.stageProductionSelection({project:candidateInput,label:'candidate',argv:baseline.options,preferenceSeeds:seeds,env:{}});
 const controlReceipt=await controlHelper.stageProductionSelection({project:controlInput,label:'control',argv:baseline.options,preferenceSeeds:seeds,env:{}});
 const candidate=await candidateHelper.readProductionSelection(candidateReceipt.file,candidateReceipt.sha256);
 const control=await controlHelper.readProductionSelection(controlReceipt.file,controlReceipt.sha256);
 const cPins=new Map(control.pins.map(row=>[row.relative,row.sha256]));
 const nPins=new Map(candidate.pins.map(row=>[row.relative,row.sha256]));
 assert.deepEqual([...cPins.keys()].sort(),[...nPins.keys()].sort(),'Pin paths differ');
 const changed=[...nPins.keys()].filter(relative=>nPins.get(relative)!==cPins.get(relative)).sort();
 assert.deepEqual(changed,Object.keys(frozen).sort(),'Pair changed-file set differs');
 for(const name of ['options','flags','engineArguments','renderThread','renderConfiguration','loadingPipeline','profiling','renderCore','environment','cameraPolicy'])assert.deepEqual(candidate[name],control[name],name+' differs');
 assert.deepEqual(candidate.preferences.expected,control.preferences.expected);
 for(const name of ['render','layout'])assert.equal(candidate.preferences[name].sha256,control.preferences[name].sha256,'Preference '+name+' differs');
 assert.equal(candidate.runtime.executableSha256,control.runtime.executableSha256);
 assert.equal(candidate.runtime.executableSha256,baseline.runtime.executableSha256);
 assert.equal(candidate.pins.find(row=>row.relative==='.cache/native-kernel/nwn-particle-kernel.dll').sha256,control.pins.find(row=>row.relative==='.cache/native-kernel/nwn-particle-kernel.dll').sha256);
 const sourceAfter=manifest.sourceIdentity(root);
 assert.equal(sourceAfter.sha256,sourceBefore.sha256,'Current source changed while staging');
 const runs=['control','candidate'].map(mode=>{
  const selected=mode==='control'?controlReceipt:candidateReceipt;
  const run='nwn61-menu-split-a-'+mode;
  return {mode,cwd:root,argv:['node','tools/replay-native-loading.mjs','--capture='+capture,'--generation=2','--production-selection='+selected.file,'--production-selection-sha256='+selected.sha256,'--engine=production-selection','--profiling=false','--observe-profile=false','--duration-ms=20000','--run='+run],note:'Prepared command only. Coordinator chooses graphical/headless mode and runs under exclusive PC lease.'};
 });
 const receipt={schema:'nwn61-menu-split-source-pair-v1',created:new Date().toISOString(),private:true,launched:false,sourceIdentityBefore:sourceBefore.sha256,sourceIdentityAfter:sourceAfter.sha256,recording:{directory:capture,recordingJsonSha256:recordingSha},engineSha256:candidate.runtime.executableSha256,preferenceSeeds:{manifest:seedsFile,manifestSha256:sha(seedsFile),renderSha256:candidate.preferences.render.sha256,layoutSha256:candidate.preferences.layout.sha256,expected:candidate.preferences.expected},options:candidate.options,flags:candidate.flags,changed,sourceHashes:{control:Object.fromEntries(changed.map(name=>[name,cPins.get(name)])),candidate:Object.fromEntries(changed.map(name=>[name,nPins.get(name)]))},selections:{control:{file:controlReceipt.file,sha256:controlReceipt.sha256,sourceProject:control.sourceProject,sourceIdentity:control.mainSourceIdentity.sha256,pins:control.pins.length},candidate:{file:candidateReceipt.file,sha256:candidateReceipt.sha256,sourceProject:candidate.sourceProject,sourceIdentity:candidate.mainSourceIdentity.sha256,pins:candidate.pins.length}},runs,scope:'Current source, accepted Core E and native DLL, identical original recording and immutable preferences. Only the three NWN-61 menu-owner scripts differ; no runtime or FPS observation.'};
 const file=path.join(stage,'pair.json');fs.writeFileSync(file,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:sha(file),changed,control:controlReceipt.sha256,candidate:candidateReceipt.sha256,pins:candidate.pins.length}));
})().catch(error=>{console.error(error);process.exitCode=1;});
