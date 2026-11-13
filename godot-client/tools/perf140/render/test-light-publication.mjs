import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const baselineRelative='systems/native_render/model_point_light.gd';
const baselineSha='e803135ef951ea13d3d83267f0d671d2072e2df4d676bdf320a98fd9b4d1b9f6';
const candidateRelative='tools/perf140/render/model_point_light_candidate.gd';
const paletteSuite=process.argv.includes('--palette');
const testRelative=paletteSuite?'tests/native_perf140_render_light_palette_test.gd':'tests/native_perf140_render_light_publication_test.gd';
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const inputs=new Map();
function read(relative){
  const bytes=fs.readFileSync(path.join(project,relative));
  const previous=inputs.get(relative);
  if(previous&&previous!==hash(bytes))throw new Error(`Source changed during preparation: ${relative}`);
  inputs.set(relative,hash(bytes));return bytes;
}
if(hash(read(baselineRelative))!==baselineSha)throw new Error('The production ModelPointLight changed; inspect and explicitly repin rather than substituting an oracle.');
const id=process.argv.find(arg=>arg.startsWith('--id='))?.slice(5)??`light-publication-${Date.now()}`;
if(!/^[a-z0-9-]+$/i.test(id))throw new Error('Invalid private run identifier');
const directory=path.join(project,'.cache/native-140fps/render-agent',id);
if(fs.existsSync(directory))throw new Error('Refusing to reuse a private test directory');
fs.mkdirSync(directory,{recursive:true});
const renderer=path.join(directory,'renderer');
fs.mkdirSync(renderer);
const copied=new Map();
function put(relative,bytes){
  const target=path.join(renderer,relative);fs.mkdirSync(path.dirname(target),{recursive:true});
  fs.writeFileSync(target,bytes,{flag:'wx'});copied.set(relative,hash(bytes));
}
const pending=['systems/native_render/native_light_policy.gd','systems/native_render/native_light_palette.gd'];
while(pending.length){
  const relative=pending.shift();if(copied.has(relative))continue;
  const bytes=read(relative);put(relative,bytes);
  for(const match of bytes.toString('utf8').matchAll(/(?:preload|load)\("res:\/\/([^"\n]+)"\)/g)){
    if(!copied.has(match[1]))pending.push(match[1]);
  }
}
put('baseline/model_point_light.gd',read(baselineRelative));
put('candidate/model_point_light.gd',read(candidateRelative));
// A second, explicitly instrumented copy counts the property calls made by
// exactly these algorithms while still invoking each real native setter.
// The unmodified copies above remain the final-state equivalence oracle.
function trace(bytes){
  const replaced=bytes.toString('utf8').replace(/\b(light_color|light_energy|omni_range|omni_attenuation|light_specular|visible|shadow_enabled)=(?!=)([^;\r\n]+)/g,(_match,name,value)=>`traced_set("${name}",${value})`);
  return Buffer.from(replaced+'\nvar publication_trace: Array=[]\nfunc traced_set(property: String,value: Variant)->void:\n\tpublication_trace.append([property,get(property),value])\n\tset(property,value)\n');
}
put('baseline/traced_model_point_light.gd',trace(read(baselineRelative)));
put('candidate/traced_model_point_light.gd',trace(read(candidateRelative)));
const paletteRelative='systems/native_render/native_light_palette.gd';
if(hash(read(paletteRelative))!=='2485df8c97d8ede450aa85ca8407812d35ecf5fd456c47d524b8921a22d3eb21')throw new Error('Production palette changed; inspect and explicitly repin');
put('baseline/native_light_palette.gd',read(paletteRelative));
put('candidate/native_light_palette.gd',read('tools/perf140/render/native_light_palette_candidate.gd'));
put(testRelative,read(testRelative));
put('project.godot',Buffer.from('config_version=5\n\n[application]\nconfig/name="Private light publication equivalence"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'));
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe');
const log=path.join(directory,'engine.log');
const nativeReport=path.join(directory,'native.json');
const args=['--headless','--path',renderer,'--log-file',log,'--script',`res://${testRelative}`,'--',`--report=${nativeReport}`];
const manifest={version:1,createdAtUtc:new Date().toISOString(),directory,renderer,engine,engineSha256:hash(fs.readFileSync(engine)),baselineSha256:baselineSha,inputs:Object.fromEntries(inputs),copies:Object.fromEntries(copied),command:[engine,...args],scope:'Isolated headless native Godot component equivalence only. No shared project import, native build, process stop, graphics, server or FPS result.'};
fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2),{flag:'wx'});
if(!process.argv.includes('--run')){
  console.log(JSON.stringify({prepared:true,directory,command:manifest.command},null,2));process.exit(0);
}
const run=spawnSync(engine,args,{encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:8*1024*1024});
fs.writeFileSync(path.join(directory,'stdout.log'),run.stdout??'',{flag:'wx'});
fs.writeFileSync(path.join(directory,'stderr.log'),run.stderr??'',{flag:'wx'});
const changed=[...inputs].filter(([relative,sha])=>hash(fs.readFileSync(path.join(project,relative)))!==sha).map(([relative])=>relative);
const changedCopies=[...copied].filter(([relative,sha])=>hash(fs.readFileSync(path.join(renderer,relative)))!==sha).map(([relative])=>relative);
const native=fs.existsSync(nativeReport)?JSON.parse(fs.readFileSync(nativeReport,'utf8')):null;
const errors=(run.stdout??'')+'\n'+(run.stderr??'')+'\n'+(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'');
const certificatePattern=/ERROR: Failed to read the root certificate store\.\r?\n\s+at: get_system_ca_certificates \(platform\/windows\/os_windows\.cpp:2582\)/g;
const permittedWarnings=[...errors.matchAll(certificatePattern)].map(match=>match[0]);
const clean=!/SCRIPT ERROR|ERROR:|leaked|still in use|crash/i.test(errors.replace(certificatePattern,''));
const success=run.status===0&&native?.success===true&&changed.length===0&&changedCopies.length===0&&clean;
const receipt={success,exitCode:run.status,error:run.error?.message??null,engineHasNoUnexpectedErrors:clean,permittedEnvironmentWarnings:permittedWarnings,changedInputs:changed,changedCopies,native,manifest:'manifest.json',gpu:false,serverConnections:0};
fs.writeFileSync(path.join(directory,'receipt.json'),JSON.stringify(receipt,null,2),{flag:'wx'});
console.log(JSON.stringify({directory,...receipt,native:native?{...native,baseline:undefined,candidate:undefined}:null},null,2));
process.exitCode=success?0:1;
