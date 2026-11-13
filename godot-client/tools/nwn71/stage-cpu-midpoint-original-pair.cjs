'use strict';
// One immutable accepted-source selection for both CPU-midpoint modes.
// Stage/verify only. This script never starts Godot or the replay driver.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'.cache/nwn71/cpu-midpoint-original-pair-a');
const stagedFile=path.join(root,'.cache/nwn62/small-recipe-e-pair-a/staged.json');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),read=f=>fs.readFileSync(f);
const stage=JSON.parse(read(stagedFile)),baseFile=stage.selections.control.file,baseBytes=read(baseFile),base=JSON.parse(baseBytes);
assert.equal(sha(baseBytes),stage.selections.control.sha256);
const expectedEngine='753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b';
assert.equal(stage.engineSha256,expectedEngine);
assert.equal(base.runtime.executableSha256,expectedEngine);
assert.equal(sha(read(base.runtime.executable)),expectedEngine);
const overlay={
 'systems/native_render/native_gamma_effect.gd':'8e60a4c334e8c659af10aa4045e811c2f36404541c81d583c18d88b80f4b5468',
 'systems/native_render/native_postprocess.gd':'539878e853a113e59624b9fa33fedb7cba70e192061de4ada4748031abd57b2b'
};
const gamma=read(path.join(root,'systems/native_render/native_gamma_effect.gd')).toString();
assert(gamma.includes('OS.get_environment("NWN71_CPU_MIDPOINT")=="1"'));
for(const [relative,hash] of Object.entries(overlay)){
 assert.equal(sha(read(path.join(root,relative))),hash);
 assert.equal(sha(read(path.join(base.sourceProject,relative))),hash,'Base source incompatible with current overlay');
}
const capture=stage.capture;assert.equal(sha(read(path.join(capture,'recording.json'))),stage.recordingSha256);
const timelineSha=sha(read(path.join(capture,'timeline.jsonl')));
assert.equal(timelineSha,'6ce44bfe52a7bd8c3b08e936206360847cd3bb1ec1713bd1d21c7304882d3920');
assert(!fs.existsSync(out),'Preserve previous NWN-71 stage');
const project=path.join(out,'project');fs.mkdirSync(project,{recursive:true});
let bytesCopied=0;
for(const pin of base.pins){
 assert(!path.isAbsolute(pin.relative)&&!pin.relative.split(/[\\/]/).includes('..'));
 const source=path.join(base.sourceProject,pin.relative),bytes=read(source);assert.equal(sha(bytes),pin.sha256,'Base pin changed: '+pin.relative);
 const destination=path.join(project,pin.relative);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,bytes,{flag:'wx'});bytesCopied+=bytes.length;
}
for(const [relative,hash] of Object.entries(overlay)){
 const destination=path.join(project,relative),bytes=read(path.join(root,relative));assert.equal(sha(bytes),hash);
 fs.writeFileSync(destination,bytes);assert.equal(sha(read(destination)),hash);
}
for(const key of ['render','layout']){
 const relative=base.preferences[key].relative,bytes=read(path.join(path.dirname(baseFile),relative));assert.equal(sha(bytes),base.preferences[key].sha256);
 const destination=path.join(out,relative);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,bytes,{flag:'wx'});
}
const selection={...base,created:new Date().toISOString(),sourceProject:project,scope:'NWN-71 immutable accepted-source original-scene CPU-midpoint OFF/ON pair; one source/engine/prefs/assets, child environment only; no launch'};
selection.mainSourceIdentity=require(path.join(project,'tools/native-feature-manifest.cjs')).sourceIdentity(project);
assert.equal(selection.mainSourceIdentity.sha256,base.mainSourceIdentity.sha256,'Overlay changed authoritative source identity');
const selectionFile=path.join(out,'production-selection.json');fs.writeFileSync(selectionFile,JSON.stringify(selection,null,2)+'\n',{flag:'wx'});
const helper=require(path.join(project,'tools/native-production-selection.cjs'));helper.validatePins(selection);helper.validatePreferencePins(selection);
const driver=path.join(root,'tools/replay-native-loading.mjs'),driverText=read(driver).toString();
assert(driverText.includes('env:{...process.env,...(clientCapsule?.environment??{})'));
assert(!Object.hasOwn(selection.environment,'NWN71_CPU_MIDPOINT'));
const plan={issue:'NWN-71',status:'staged-no-launch',selection:{file:selectionFile,sha256:sha(read(selectionFile)),sourceIdentity:selection.mainSourceIdentity.sha256,pins:selection.pins.length,bytesCopied},parent:{file:baseFile,sha256:sha(baseBytes)},overlay,engine:{file:base.runtime.executable,sha256:expectedEngine},capture:{directory:capture,recordingSha256:stage.recordingSha256,timelineSha256:timelineSha,generation:2},preferences:{render:selection.preferences.render,layout:selection.preferences.layout,expected:selection.preferences.expected},argv:['--profiling=true','--steady-ms=5000','--preview'],order:['off','on','on','off'],environmentRoute:{switch:'NWN71_CPU_MIDPOINT',off:'0',on:'1',gammaPrewarm:'0',childProcessInheritance:'replay-native-loading.mjs spreads process.env into Godot child environment; production-selection environment does not override this switch'},runCommand:'node tools/nwn71/run-cpu-midpoint-original-pair.cjs --plan=.cache/nwn71/cpu-midpoint-original-pair-a/plan.json --run-after-exclusive-lease',verifyCommand:'node tools/nwn71/run-cpu-midpoint-original-pair.cjs --plan=.cache/nwn71/cpu-midpoint-original-pair-a/plan.json --verify-only',acceptance:['Same immutable source, Core E, native DLL, recording, installed assets and preference seeds in all four legs','Per-leg observed CPU-midpoint mode, completed source/runtime pins and same camera/FOV/viewport','Same protocol outcome and original-scene visual/pixel checks','Matched first playable/full base, frame mean/p95/p99 and GPU/render CPU with OFF bookends','Reject candidate on crash or source drift'],limitations:['No client/FPS launch during staging','Prior 0xC0000005 cause remains unknown','Candidate remains default off and requires exclusive graphical acceptance']};
const planFile=path.join(out,'plan.json');fs.writeFileSync(planFile,JSON.stringify(plan,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({plan:planFile,planSha256:sha(read(planFile)),selection:selectionFile,selectionSha256:plan.selection.sha256,files:selection.pins.length,bytesCopied,noLaunch:true}));
