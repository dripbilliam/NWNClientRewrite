import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const id=process.argv[2];
if(!/^[a-z0-9-]+$/i.test(id??''))throw Error('Fresh private candidate identifier required');
const stage=path.join(project,'.cache/native-140fps/render-agent',id);
if(process.argv.includes('--finalize')){
  const file=path.join(stage,'manifest.json'),receipt=JSON.parse(fs.readFileSync(file));
  const proofFile=path.join(stage,'build.json'),proof=JSON.parse(fs.readFileSync(proofFile));
  if(!proof.success||proof.changedGuards.length||receipt.builds!==0)throw Error('Private build does not pass finalization');
  for(const pin of receipt.pins){
    const bytes=fs.readFileSync(path.join(receipt.project,pin.relative));const sha=crypto.createHash('sha256').update(bytes).digest('hex');
    if(!['.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json'].includes(pin.relative)&&pin.sha256!==sha)throw Error('Unexpected private build mutation: '+pin.relative);
    pin.sha256=sha;
  }
  receipt.builds=1;receipt.build={proofFile,binarySha256:proof.binarySha256};
  fs.writeFileSync(file,JSON.stringify(receipt,null,2));console.log(JSON.stringify({finalized:true,stage}));process.exit(0);
}
if(fs.existsSync(stage))throw Error('Existing evidence must be preserved');
const baselineManifest=path.join(project,'.cache/native-140fps/root/common-v1/manifest.json');
const baseline=JSON.parse(fs.readFileSync(baselineManifest));
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const destination=path.join(stage,'project');fs.mkdirSync(destination,{recursive:true});
const pins=[];const inputs=[];const edits=[];
for(const pin of baseline.pins){
  const bytes=fs.readFileSync(path.join(baseline.project,pin.relative));
  if(hash(bytes)!==pin.sha256)throw Error('Witness input changed: '+pin.relative);
  const target=path.join(destination,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});
  pins.push({...pin});
}
function install(relative,bytes,source){
  if(typeof bytes==='string')bytes=Buffer.from(bytes);
  const target=path.join(destination,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);
  let pin=pins.find(value=>value.relative===relative);if(!pin){pin={relative};pins.push(pin);}pin.sha256=hash(bytes);
  edits.push({relative,source,sha256:pin.sha256});
}
function own(relative,dest){const bytes=fs.readFileSync(path.join(project,relative));inputs.push({relative,sha256:hash(bytes)});install(dest,bytes,relative);}
const liveVisibility=process.argv.includes('--live-visibility');
own(liveVisibility?'tools/perf140/render/light_input_registry_pushed_v3.hpp':'tools/perf140/render/light_input_registry_pushed.hpp','native/experimental/light_input_registry.hpp');
own(liveVisibility?'tools/perf140/render/model_point_light_pushed_inputs_v3_candidate.gd':'tools/perf140/render/model_point_light_pushed_inputs_candidate.gd','systems/native_render/model_point_light.gd');
own('tools/perf140/render/focus_lighting_pushed_inputs_candidate.gd','systems/native_render/focus_lighting_native_input_candidate.gd');
const testRelative='tests/native_perf140_render_pushed_inputs_test.gd';own(testRelative,testRelative);
const focus=fs.readFileSync(path.join(baseline.project,'systems/native_render/focus_lighting.gd'));
install('tests/fixtures/perf140_pushed_focus_oracle.gd',focus,'Unmodified common witness original GDScript Focus owner');
const oracleSha256=hash(focus);
const originalProject=fs.readFileSync(path.join(destination,'project.godot'),'utf8');
const headlessProject=originalProject.replace(/\[autoload\][\s\S]*?(?=\n\[|$)/,'');
install('project.godot',headlessProject,'Headless component capsule: no application autoloads or server initialization');
install('.godot/extension_list.cfg','res://native/particle_kernel.gdextension\n','Only the private native kernel is loaded for component tests');
const receipt={version:1,id,project:destination,baselineManifest,baselineManifestSha256:hash(fs.readFileSync(baselineManifest)),baselineProject:baseline.project,oracleSha256,pins,inputs,edits,builds:0,enginesStarted:0,gpu:false,serverConnections:0,scope:'Private source candidate derived from the exact common witness. Source changes only until an explicitly coordinated private build/test.'};
fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify(receipt,null,2),{flag:'wx'});
console.log(JSON.stringify({prepared:true,stage,project:destination,pins:pins.length,oracleSha256},null,2));
