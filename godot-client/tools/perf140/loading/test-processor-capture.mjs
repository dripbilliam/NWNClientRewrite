// Functional provenance acceptance for two sealed captured MDLs. No timings,
// server connections, graphical client, capture copies or shared source writes.
import fs from 'node:fs';import path from 'node:path';import {spawn} from 'node:child_process';import {fileURLToPath} from 'node:url';
import {buildDescriptor} from './processor-descriptor.mjs';import {digest} from './processor-graph.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2],checkLabel=process.argv[3]??'capture-provenance-v1';
if(!/^processor-identity-[a-z0-9-]+$/.test(label??'')||!/^capture-provenance-[a-z0-9-]+$/.test(checkLabel))throw Error('Pinned candidate and fresh capture-provenance label required');
const stage=path.join(project,'.cache/native-140fps/loading-agent',label),manifestFile=path.join(stage,'manifest.json'),manifestBytes=fs.readFileSync(manifestFile),manifest=JSON.parse(manifestBytes),checkRoot=path.join(stage,checkLabel),copy=path.join(checkRoot,'project');
if(fs.existsSync(checkRoot))throw Error('Existing evidence is immutable');fs.mkdirSync(copy,{recursive:true});
const pins=[...manifest.pins,...manifest.fixtures].map(v=>({relative:v.relative,sha256:digest(fs.readFileSync(path.join(manifest.candidate,v.relative)))}));
for(const pin of pins){const file=path.join(copy,pin.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.copyFileSync(path.join(manifest.candidate,pin.relative),file);}
fs.writeFileSync(path.join(copy,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Captured Processor Provenance"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const script='native_perf140_loading_processor_capture_test.gd',scriptBytes=fs.readFileSync(path.join(project,'tests',script));fs.writeFileSync(path.join(copy,'tests',script),scriptBytes);
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=digest(fs.readFileSync(engine));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Pinned engine changed');
const catalog='C:/Users/Niflheim/AppData/Roaming/nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf/catalog-1',catalogManifest=path.join(catalog,'manifest.json'),captureSha256=digest(fs.readFileSync(catalogManifest));
if(captureSha256!=='1ef50ed518173a2f172f42a935252c0c3500319c2393286a5773f2de3b28e035')throw Error('Sealed capture manifest differs');
const cache=path.join(checkRoot,'owned-prepared-cache'),baseline=path.join(checkRoot,'owned-cold-checkpoints');fs.mkdirSync(cache);fs.mkdirSync(baseline);
const guards=['.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-resource-index/nwn-resource-index.dll'].map(relative=>({relative,sha256:digest(fs.readFileSync(path.join(project,relative)))}));
const descriptorRelative='systems/native_data/scoped_processor_graph.json',mathRelative='systems/native_render/particle_math.gd',hudRelative='native_live_world.gd',diagnosticRelative='systems/native_render/frame_summary_job.gd',mathOriginal=fs.readFileSync(path.join(copy,mathRelative)),hudOriginal=fs.readFileSync(path.join(copy,hudRelative)),diagnosticOriginal=fs.readFileSync(path.join(copy,diagnosticRelative));
const runs=[];
function regenerate(){const generated=buildDescriptor(copy);fs.writeFileSync(path.join(copy,descriptorRelative),JSON.stringify(generated.descriptor,null,2)+'\n');}
for(const phase of ['cold','warm','hud-warm','relevant-drift','relevant-regenerated','changed-source']){
 if(phase==='hud-warm'){fs.writeFileSync(path.join(copy,hudRelative),Buffer.concat([hudOriginal,Buffer.from('\n# Owned unrelated HUD source mutation\n')]));fs.writeFileSync(path.join(copy,diagnosticRelative),Buffer.concat([diagnosticOriginal,Buffer.from('\n# Owned unrelated HUD diagnostic source mutation\n')]));regenerate();}
 if(phase==='relevant-drift')fs.writeFileSync(path.join(copy,mathRelative),Buffer.concat([mathOriginal,Buffer.from('\n# Owned relevant preparation source mutation\n')]));
 if(phase==='relevant-regenerated')regenerate();
 if(phase==='changed-source'){fs.writeFileSync(path.join(copy,mathRelative),mathOriginal);regenerate();}
 const output=path.join(checkRoot,phase);fs.mkdirSync(output);fs.copyFileSync(path.join(copy,descriptorRelative),path.join(output,'descriptor.json'));
 const appdata=path.join(output,'appdata'),localdata=path.join(output,'localappdata');fs.mkdirSync(appdata);fs.mkdirSync(localdata);
 const proofFile=path.join(output,'proof.json'),log=path.join(output,'engine.log');
 const outcome=await new Promise(resolve=>{
  const child=spawn(engine,['--headless','--path',copy,'--log-file',log,'--script','res://tests/'+script,'--','--phase='+phase,'--recorded-catalog='+catalog,'--cache-root='+cache,'--baseline-root='+baseline,'--prepared-cache-write=sync','--report='+proofFile],{cwd:copy,windowsHide:true,env:{...process.env,APPDATA:appdata,LOCALAPPDATA:localdata},stdio:['ignore','pipe','pipe']});
  let stdout='',stderr='',error=null,killed=false,total=0;const collect=(which,bytes)=>{total+=bytes.length;if(total>2*1024*1024){error='Owned output exceeds 2 MiB';killed=true;child.kill();return;}if(which==='out')stdout+=bytes;else stderr+=bytes;};child.stdout.on('data',bytes=>collect('out',bytes));child.stderr.on('data',bytes=>collect('err',bytes));child.once('error',value=>error=value.message);
  const timer=setTimeout(()=>{error='Owned captured functional gate exceeded 40 seconds';killed=true;child.kill();},40000);child.once('close',(exitCode,signal)=>{clearTimeout(timer);resolve({pid:child.pid,exitCode,signal,error,killed,stdout,stderr});});
 });
 fs.writeFileSync(path.join(output,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(output,'stderr.log'),outcome.stderr);let proof=null;try{proof=JSON.parse(fs.readFileSync(proofFile));}catch{}
 const engineText=(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'')+'\n'+outcome.stderr,engineClean=!/SCRIPT ERROR|Parse Error|^ERROR:|WARNING:|ObjectDB.*leak|resources still in use/m.test(engineText);
 const success=outcome.exitCode===0&&!outcome.signal&&!outcome.error&&!outcome.killed&&engineClean&&proof?.success===true;
 runs.push({phase,success,engineClean,proof,outcome:{...outcome,stdout:undefined,stderr:undefined}});if(!success)break;
}
const changedSources=pins.filter(v=>digest(fs.readFileSync(path.join(manifest.candidate,v.relative)))!==v.sha256).map(v=>v.relative),changedGuards=guards.filter(v=>digest(fs.readFileSync(path.join(project,v.relative)))!==v.sha256).map(v=>v.relative),captureAfter=digest(fs.readFileSync(catalogManifest));
const success=runs.length===6&&runs.every(v=>v.success)&&!changedSources.length&&!changedGuards.length&&captureAfter===captureSha256;
const report={version:1,success,manifestSha256:digest(manifestBytes),scriptSha256:digest(scriptBytes),engineSha256,capture:{catalog,before:captureSha256,after:captureAfter,readOnly:true,copiedPayloads:0},runs,changedSources,changedGuards,serverConnections:0,graphicalProcessesStarted:0,sharedNativeBuilds:0,timingClaim:false};
const file=path.join(checkRoot,'receipt.json');fs.writeFileSync(file,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({file,success,phases:runs.map(v=>({phase:v.phase,success:v.success,checks:v.proof?.checks,failures:v.proof?.failures})),changedSources,changedGuards,captureUnchanged:captureAfter===captureSha256}));if(!success)process.exitCode=1;
