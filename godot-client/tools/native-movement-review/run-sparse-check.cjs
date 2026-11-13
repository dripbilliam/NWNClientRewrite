'use strict';
// Bounded correctness check only. No world loading, native compilation, GPU
// workload, server, user settings, or FPS/performance sampling.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),os=require('node:os');
const {spawn}=require('node:child_process');
const project=path.resolve(__dirname,'../..'),[label,version,run]=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(label??'')||!/^v[0-9]+$/.test(version??'')||!/^[a-z0-9-]+$/.test(run??''))throw Error('Explicit review, prototype version and fresh check label required');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const identity=require('../native-feature-manifest.cjs').sourceIdentity;
const experiment=path.join(project,'.cache/native-presentation-parity/root/fps-max-v1','movement-native-review-'+label,'sparse-pending-'+version);
const proofFile=path.join(experiment,'proof.json'),proof=JSON.parse(fs.readFileSync(proofFile));
const before=identity(project).sha256;
if(before!==proof.mainAfter)throw Error('Main application has drifted');
for(const pin of proof.pins)if(sha(fs.readFileSync(path.join(experiment,pin.variant,pin.relative)))!==pin.sha256)throw Error('Frozen prototype changed: '+pin.relative);
for(const pin of proof.guarded)if(sha(fs.readFileSync(path.join(project,pin.relative)))!==pin.sha256)throw Error('Guarded main source changed: '+pin.relative);
const selectionFile=path.join(project,'.cache/native-presentation-parity/production-replay/fps-max-v1-merged-workers-b/production-selection.json');
const runtime=JSON.parse(fs.readFileSync(selectionFile)).runtime;
if(sha(fs.readFileSync(runtime.executable))!==runtime.executableSha256)throw Error('Exact test engine differs');
const output=path.join(experiment,'check-'+run),stage=path.join(output,'project');
if(fs.existsSync(output))throw Error('Existing check preserved');
fs.mkdirSync(stage,{recursive:true});
const overlay=new Map(proof.pins.filter(p=>p.variant==='candidate').map(p=>[p.relative,path.join(experiment,'candidate',p.relative)]));
const mode=process.argv[6]??'candidate',unchangedControl=['current','old-gpu'].includes(mode),graphical=['gpu','old-gpu'].includes(mode);
if(!['candidate','current','gpu','old-gpu'].includes(mode))throw Error('Unknown focused variant');
if(unchangedControl)overlay.delete('systems/native_render/live_world.gd');
if(unchangedControl)overlay.delete('systems/native_render/native_light_palette.gd');
const selected=process.argv[5]??'sparse_pending_test';
const cases=['native_world_delta_test','native_world_publication_test','native_world_retirement_test','native_world_snapshot_sidecar_test','native_live_world_name_signature_test','native_world_quiescent_test','native_perf140_render_palette_upload_test','native_perf140_render_palette_upload_gpu_test'];
if(selected!=='sparse_pending_test'&&!cases.includes(selected))throw Error('Unsupported focused case');
const pins=[],seen=new Set();
function copy(relative){
 if(seen.has(relative))return;
 if(path.isAbsolute(relative)||relative.split('/').includes('..'))throw Error('Unsafe dependency path');
 seen.add(relative);
 const source=overlay.get(relative)??path.join(project,relative);
 if(!fs.existsSync(source)||!fs.statSync(source).isFile())throw Error('Missing literal dependency: '+relative);
 const original=fs.readFileSync(source);let bytes=original;
 if(!unchangedControl&&relative==='tests/native_world_quiescent_test.gd'){
  bytes=Buffer.from(original.toString('utf8').replace('const Original=preload("res://systems/native_render/live_world.gd")','const Original=preload("res://tools/native-movement-review/authoritative_world.gd")').replace('const Candidate=preload("res://systems/native_render/live_world_quiescent_candidate.gd")','const Candidate=preload("res://systems/native_render/live_world_pending_appearances.gd")'));
 }else if(!unchangedControl&&(cases.some(name=>relative==='tests/'+name+'.gd')||relative==='tests/native_static_pose_test.gd')){
  bytes=Buffer.from(original.toString('utf8').replaceAll('res://systems/native_render/live_world.gd','res://systems/native_render/live_world_pending_appearances.gd'));
 }
 const dest=path.join(stage,relative);
 fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes,{flag:'wx'});
 pins.push({relative,source,sourceSha256:sha(original),sha256:sha(bytes),adapted:!bytes.equals(original)});
 if(/\.(gd|tscn|tres|gdshader|gdshaderinc|gdextension)$/.test(relative)){
  for(const match of bytes.toString('utf8').matchAll(/["']res:\/\/([^"'\r\n]+)["']/g)){
   const dep=match[1];
   // Dynamic prefixes and directories are not resources. Runtime-only assets
   // are deliberately absent from this receiver/planner fixture.
   const sourceDep=overlay.get(dep)??path.join(project,dep);
   if(fs.existsSync(sourceDep)&&fs.statSync(sourceDep).isFile())copy(dep);
  }
 }
}
const fixture=selected==='sparse_pending_test'?'tools/native-movement-review/sparse_pending_test.gd':'tests/'+selected+'.gd';copy(fixture);
if(selected!=='sparse_pending_test'){
 copy('native/particle_kernel.gdextension');copy('native/resource_index.gdextension');
 fs.mkdirSync(path.join(stage,'.godot'),{recursive:true});const extensions=Buffer.from('res://native/particle_kernel.gdextension\nres://native/resource_index.gdextension\n');
 fs.writeFileSync(path.join(stage,'.godot/extension_list.cfg'),extensions,{flag:'wx'});
 pins.push({relative:'.godot/extension_list.cfg',source:'generated normal active extension list',sha256:sha(extensions)});
}
// Use the engine source's bundled public CA file in this offline fixture, as
// supported by Godot. The Windows sandbox cannot read its system ROOT store.
// This is confined to the private project; normal TLS settings stay untouched.
const certSource=path.join(project,'.cache/native-140fps/render-agent/engine-rd-thread-return-v1/source/thirdparty/certs/ca-bundle.crt');
const certBytes=fs.readFileSync(certSource),certRelative='tools/native-movement-review/ca-bundle.crt';
fs.mkdirSync(path.dirname(path.join(stage,certRelative)),{recursive:true});fs.writeFileSync(path.join(stage,certRelative),certBytes,{flag:'wx'});
pins.push({relative:certRelative,source:certSource,sha256:sha(certBytes)});
const config='config_version=5\n[application]\nconfig/name="Private pending planner correctness"\n[display]\nwindow/size/no_focus=true\n[network]\ntls/certificate_bundle_override="res://'+certRelative+'"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';
fs.writeFileSync(path.join(stage,'project.godot'),config,{flag:'wx'});
pins.push({relative:'project.godot',source:'generated minimal fixture project; no autoload or main scene',sha256:sha(Buffer.from(config))});
const scriptCache=Buffer.from('list=[]\n');
fs.mkdirSync(path.join(stage,'.godot'),{recursive:true});fs.writeFileSync(path.join(stage,'.godot/global_script_class_cache.cfg'),scriptCache,{flag:'wx'});
pins.push({relative:'.godot/global_script_class_cache.cfg',source:'generated empty script class cache',sha256:sha(scriptCache)});
const manifest={version:1,variant:unchangedControl?'unchanged-current':'candidate',proof:{file:proofFile,sha256:sha(fs.readFileSync(proofFile))},mainBefore:before,engine:{executable:runtime.executable,sha256:runtime.executableSha256},fixture,pins,scope:'Private literal dependency closure; selected receiver/planner, authored workers and explicit fixture doubles. No real-world/graphics/FPS acceptance.'};
fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
function verify(){
 for(const pin of pins)if(sha(fs.readFileSync(path.join(stage,pin.relative)))!==pin.sha256)throw Error('Private check source drift: '+pin.relative);
 if(identity(project).sha256!==before)throw Error('Main application changed during check');
}
async function main(){
 const report=path.join(output,'report.json'),log=path.join(output,'engine.log');
 let displayArgs=['--headless'];
 if(graphical){
  const {spawnSync}=require('node:child_process'),ps=". '"+path.join(project,'tools/native-window-screen.ps1').replaceAll("'","''")+"'; Get-NativeSecondaryScreen";
  const topology=spawnSync('pwsh.exe',['-NoProfile','-NonInteractive','-Command',ps],{windowsHide:true,encoding:'utf8'}),screen=Number(topology.stdout?.trim());
  if(topology.status!==0||!Number.isInteger(screen)||screen<0)throw Error('Current nonprimary screen required');
  displayArgs=['--rendering-method','forward_plus','--rendering-driver','vulkan','--render-thread','separate','--screen',String(screen),'--resolution','320x240'];
 }
 const child=spawn(runtime.executable,[...displayArgs,'--path',stage,'--script','res://'+fixture,'--log-file',log,'--','--report='+report],{cwd:stage,windowsHide:true,env:{...process.env,NWN_PARTICLE_KERNEL:'compiled',APPDATA:path.join(output,'appdata'),LOCALAPPDATA:path.join(output,'localappdata')}});
 let priority='below-normal';try{os.setPriority(child.pid,os.constants.priority.PRIORITY_BELOW_NORMAL);}catch(error){priority='unavailable: '+error.message;}
 let stdout='',stderr='',timedOut=false,launchError=null;
 child.stdout.on('data',b=>{stdout+=b;if(stdout.length>2*1024*1024)child.kill();});
 child.stderr.on('data',b=>{stderr+=b;if(stderr.length>2*1024*1024)child.kill();});
 child.on('error',error=>{launchError=error.message;});
 const timeout=setTimeout(()=>{timedOut=true;child.kill();},selected==='sparse_pending_test'?15000:45000);
 const exit=await new Promise(resolve=>child.on('close',(code,signal)=>resolve({code,signal})));
 clearTimeout(timeout);
 fs.writeFileSync(path.join(output,'stdout.log'),stdout,{flag:'wx'});fs.writeFileSync(path.join(output,'stderr.log'),stderr,{flag:'wx'});
 let result=null;try{result=JSON.parse(fs.readFileSync(report));}catch{}
 const errors=[stdout,stderr,fs.existsSync(log)?fs.readFileSync(log,'utf8'):''].join('\n').split(/\r?\n/).filter(line=>/SCRIPT ERROR|Parse Error|(?:^|\s)ERROR:|WARNING:|ObjectDB.*leak|resources still in use|CrashHandler|Unhandled exception/.test(line)&&!line.startsWith('WARNING: The separate rendering thread feature is experimental.'));
 verify();
 const summary={success:exit.code===0&&!timedOut&&!launchError&&errors.length===0&&result?.success===true&&(!graphical||result.gated_separate_render_thread===true&&result.main_on_render_thread===false),exit,timedOut,launchError,priority,errors,checks:result?.checks??0,reportSha256:result?sha(fs.readFileSync(report)):null,manifestSha256:sha(fs.readFileSync(path.join(output,'manifest.json'))),mainBefore:before,mainAfter:identity(project).sha256,engineStarts:1,graphicalProcesses:graphical?1:0,serverConnections:0,fpsTests:0,installed:false,scope:manifest.scope};
 fs.writeFileSync(path.join(output,'summary.json'),JSON.stringify(summary,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({output,...summary}));if(!summary.success)process.exitCode=1;
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
