// Isolated CPU acceptance of an already composed renderer, never current-main
// production sources. No GUI, server, native build, or ordinary autoload.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {verifyClientLaunchEngine} from './client_launch_engine.mjs';
import {verifyMotionBoundaryProof} from './client_launch_proofs.mjs';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const workspace=path.dirname(source),[label,phase]=process.argv.slice(2);
if(!/^parity-launch-[a-z0-9-]+$/.test(label??'')||!['stage','run','continue-stage','continue-run'].includes(phase))throw Error('Explicit capsule label and stage/run or continue-stage/continue-run required');
const capsule=path.join(source,'.cache/native-presentation-parity/loading-agent',label);
const manifestFile=path.join(capsule,'manifest.json'),manifest=JSON.parse(fs.readFileSync(manifestFile));
verifyClientLaunchEngine(manifest.engine);
if(manifest.motionBoundary)verifyMotionBoundaryProof(manifest.motionBoundary,manifest.pins.find(pin=>pin.relative==='systems/network_motion.gd')?.sha256);
const continuing=phase.startsWith('continue-');
const directory=path.join(capsule,continuing?'acceptance-continuation-v1':'acceptance'),project=path.join(directory,'project');
const sha=raw=>crypto.createHash('sha256').update(raw).digest('hex');
const write=(file,data)=>fs.writeFileSync(file,JSON.stringify(data,null,2)+'\n',{flag:'wx'});
const fixtures=[
 {name:'door',file:'tests/native_parity_door_asset_pick_test.gd',checks:139,assets:true,report:true,expectedWarnings:{'Native explosion point-wind registration is pending':2,'Native reference catalog scope is unavailable: fx_ref':4,'Native point-to-point particle movement is pending':4}},
 {name:'placeable',file:'tests/native_parity_placeable_animation_test.gd',checks:22,assets:true,report:true},
 {name:'perception',file:'tests/native_perception_visuals_test.gd',checks:12,marker:'NATIVE_PERCEPTION_VISUALS'},
 {name:'type5',file:'tests/native_visual_alpha_runtime_test.gd',checks:12,marker:'NATIVE_VISUAL_ALPHA_RUNTIME'},
 {name:'actor',file:'tests/native_parity_actor_alpha_test.gd',checks:131,marker:'NATIVE_PARITY_ACTOR_ALPHA',args:['--existing-kernel']},
 {name:'binary-trans',file:'tests/native_transition_door_hover_test.gd',checks:83,assets:true,assetKernel:'compiled',report:true},
 {name:'ascii-trans',file:'tests/native_ascii_transition_door_test.gd',checks:54,assets:true,assetKernel:'compiled',report:true,expectedWarnings:{'Native reference catalog scope is unavailable: fx_ref':4,'Native point-to-point particle movement is pending':4}},
 {name:'reveal-clock',file:'tests/native_reveal_clock_test.gd',checks:24,report:true},
 {name:'tile-fog',file:'tests/native_tile_fog_test.gd',checks:36,report:true},
 {name:'visibility-lowers',file:'tests/native_visibility_lowers_test.gd',checks:47,report:true},
 {name:'visibility-bridge',file:'tests/native_scene_visibility_bridge_test.gd',checks:51,report:true,marker:'NATIVE_SCENE_VISIBILITY_BRIDGE',args:['--existing-kernel']},
 {name:'visibility-runtime',file:'tests/native_scene_visibility_runtime_test.gd',checks:37,report:true,marker:'NATIVE_SCENE_VISIBILITY_RUNTIME',bootstrapParticle:true},
 {name:'visibility-runtime-json',file:'tests/native_scene_visibility_runtime_json_test.gd',checks:37,report:true,marker:'NATIVE_SCENE_VISIBILITY_RUNTIME',bootstrapParticle:true},
 {name:'visibility-fields-json',file:'tests/native_visibility_json_fields_test.gd',checks:22,report:true,marker:'NATIVE_VISIBILITY_JSON_FIELDS'},
 {name:'visibility-motion',file:'tests/native_scene_visibility_motion_test.gd',checks:25,report:true,marker:'NATIVE_SCENE_VISIBILITY_MOTION',bootstrapParticle:true},
 {name:'disclosure-carrier',file:'tests/native_disclosure_carrier_test.gd',checks:16,report:true},
 {name:'visibility-adoption',file:'tests/native_scene_visibility_adoption_test.gd',checks:45,report:true,marker:'NATIVE_SCENE_VISIBILITY_ADOPTION',bootstrapParticle:true,assets:true,args:['--existing-kernel']},
 {name:'shadow-option',file:'tests/native_creature_shadow_option_test.gd',checks:11,report:true},
 {name:'highlight-kernel',file:'tests/native_highlight_kernel_test.gd',checks:386,marker:'NATIVE_HIGHLIGHT_KERNEL',report:true,dataFiles:[{relative:'tools/native_parity/highlighting/original_leaf_corpus.json',sha256:'4148e67faaedaaa08ed35ae0ee77b050dd822530c5c9b99875026b539c24035d'}]},
 {name:'highlight-owner',file:'tests/native_highlight_kernel_owner_test.gd',checks:12,marker:'NATIVE_HIGHLIGHT_KERNEL_OWNER',report:true},
];
const productionChanged=()=>manifest.pins.filter(pin=>sha(fs.readFileSync(path.join(manifest.project,pin.relative)))!==pin.sha256).map(pin=>pin.relative);
const rerunNames=['compile','binary-trans','ascii-trans','visibility-runtime','highlight-kernel'];
function priorAcceptance(){
 const directory=path.join(capsule,'acceptance'),runFile=path.join(directory,'run.json'),stageFile=path.join(directory,'stage.json');
 const rawRun=fs.readFileSync(runFile),rawStage=fs.readFileSync(stageFile),run=JSON.parse(rawRun),stage=JSON.parse(rawStage);
 if(run.capsule?.sha256!==sha(fs.readFileSync(manifestFile))||stage.capsule?.sha256!==run.capsule.sha256||run.stage?.sha256!==sha(rawStage)||
    run.engine?.sha256!==manifest.engine.sha256||stage.engine?.sha256!==manifest.engine.sha256||
    run.sourceChanged?.length!==0||run.capsuleChanged?.length!==0||run.originalChanged?.length!==0||
    run.results?.length!==fixtures.length+1||JSON.stringify(run.results.filter(row=>!row.success).map(row=>row.name))!==JSON.stringify(rerunNames.slice(1)))throw Error('Previous four-failure receipt differs');
 for(const pin of stage.pins)if(sha(fs.readFileSync(path.join(stage.project,pin.relative)))!==pin.sha256)throw Error('Previous isolated fixture changed: '+pin.relative);
 return {run,stage,proof:{run:{file:runFile,sha256:sha(rawRun)},stage:{file:stageFile,sha256:sha(rawStage)},rerunNames}};
}
if(phase==='stage'||phase==='continue-stage'){
 if(fs.existsSync(directory))throw Error('Existing acceptance preserved');
 if(productionChanged().length||sha(fs.readFileSync(manifest.engine.path))!==manifest.engine.sha256)throw Error('Capsule/engine changed');
 fs.mkdirSync(project,{recursive:true});
 const pins=[],seen=new Set(),testFiles=new Set(fixtures.map(row=>row.file));
 // Compile the actual normal entry and its literal runtime closure. Unused
 // private prototypes are not loaded into the client or claimed as accepted.
 const entryRoots=['native_session_world.gd'];
 const queue=[...entryRoots,...testFiles];let bytes=0;
 while(queue.length){
  const relative=queue.shift();if(seen.has(relative))continue;seen.add(relative);
  if(relative.includes('..')||seen.size>1800)throw Error('Unexpected literal closure');
  // Dedicated tests may be current. Every non-test dependency MUST come from
  // the reviewed capsule, even when a same-named main file is newer.
  const from=path.join(testFiles.has(relative)?source:manifest.project,relative);
  if(!fs.existsSync(from))throw Error('Capsule dependency absent: '+relative);
  const raw=fs.readFileSync(from);bytes+=raw.length;if(bytes>32*1024*1024)throw Error('Literal closure exceeds32MiB');
  const target=path.join(project,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,raw);
  pins.push({relative,source:from,sha256:sha(raw),kind:testFiles.has(relative)?'dedicated-test':'capsule-production'});
  if(relative.endsWith('.gd'))for(const match of raw.toString('utf8').matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']\s*\)|extends\s+["']res:\/\/([^"']+)["']/g))queue.push(match[1]??match[2]);
 }
 for(const relative of ['native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll',...[...(manifest.highlightRuntime?.pins??[]),...(manifest.clockRuntime?.pins??[])].map(pin=>pin.relative)]){
  if(seen.has(relative))continue;
  const raw=fs.readFileSync(path.join(manifest.project,relative)),target=path.join(project,relative);
  fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,raw);pins.push({relative,source:path.join(manifest.project,relative),sha256:sha(raw),kind:'capsule-production'});
 }
 for(const row of fixtures){
  for(const data of row.dataFiles??[]){
   const from=path.join(source,data.relative),raw=fs.readFileSync(from);if(sha(raw)!==data.sha256)throw Error('Pinned test-only corpus changed');
   if(seen.has(data.relative))throw Error('Unexpected existing test-only corpus');seen.add(data.relative);
   const target=path.join(project,data.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,raw);
   pins.push({relative:data.relative,source:from,sha256:data.sha256,kind:'dedicated-test-data'});
  }
  if(row.bootstrapParticle){
   const relative='tests/capsule_'+row.name.replaceAll('-','_')+'.gd';
   const script='extends '+JSON.stringify('res://'+row.file)+'\nvar capsule_particle_extension: Resource\nfunc _initialize() -> void:\n\tcapsule_particle_extension=load("res://native/particle_kernel.gdextension")\n\tif capsule_particle_extension==null or not ClassDB.class_exists("NwnLightInputRegistry"):\n\t\tpush_error("Exact capsule particle/light registry bootstrap unavailable");quit(1);return\n\tsuper()\n';
   fs.writeFileSync(path.join(project,relative),script,{flag:'wx'});pins.push({relative,sha256:sha(script),kind:'fixture-only'});row.invocationFile=relative;
  }
 }
 const checker='extends SceneTree\n'+entryRoots.map((relative,i)=>'const Source'+i+'=preload('+JSON.stringify('res://'+relative)+')').join('\n')+'\n';
 fs.writeFileSync(path.join(project,'capsule_compile.gd'),checker);pins.push({relative:'capsule_compile.gd',sha256:sha(checker),kind:'fixture-only'});
 const config='config_version=5\n[application]\nconfig/name="Merged capsule isolated CPU acceptance"\nconfig/features=PackedStringArray("4.7")\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';
 fs.writeFileSync(path.join(project,'project.godot'),config);pins.push({relative:'project.godot',sha256:sha(config),kind:'fixture-only'});
 fs.mkdirSync(path.join(project,'.godot'),{recursive:true});fs.writeFileSync(path.join(project,'.godot/global_script_class_cache.cfg'),'list=[]\n');
 const install=path.resolve(workspace,'../FullDecomp/NwnRootInstall');
 const keys=['data/nwn_base.key','data/nwn_retail.key','lang/en/data/nwn_base_loc.key'].map(relative=>path.join(install,relative)).filter(file=>fs.existsSync(file)).map(file=>({file,sha256:sha(fs.readFileSync(file))}));
 let continuation=null;
 if(continuing){
  const prior=priorAcceptance();
  // Every previously successful fixture retains the exact original dependency
  // bytes. Only an additional data file and an explicit test bootstrap differ.
  for(const pin of prior.stage.pins)if(!pins.some(next=>next.relative===pin.relative&&next.sha256===pin.sha256))throw Error('Previously checked dependency differs: '+pin.relative);
  for(const row of fixtures.filter(row=>!rerunNames.includes(row.name)))if(JSON.stringify(prior.stage.fixtures.find(old=>old.name===row.name))!==JSON.stringify(row))throw Error('Previously accepted fixture contract differs: '+row.name);
  continuation=prior.proof;
 }
 write(path.join(directory,'stage.json'),{success:true,capsule:{file:manifestFile,sha256:sha(fs.readFileSync(manifestFile))},project,pins,fixtures,entryRoots,engine:manifest.engine,nativeBinary:manifest.nativeBinary,install:{directory:install,keys},continuation,sharedWrites:0,nativeBuilds:0,serverConnections:0,gameLaunches:0});
 console.log(JSON.stringify({success:true,phase,pins:pins.length,bytes,productionChanged:[],receipt:path.join(directory,'stage.json')}));process.exit(0);
}
const output=path.join(directory,'run.json');if(fs.existsSync(output))throw Error('Existing run preserved');
const stage=JSON.parse(fs.readFileSync(path.join(directory,'stage.json')));
const prior=continuing?priorAcceptance():null;
if(continuing&&JSON.stringify(prior.proof)!==JSON.stringify(stage.continuation))throw Error('Continuation reference differs');
const changed=()=>stage.pins.filter(pin=>sha(fs.readFileSync(path.join(project,pin.relative)))!==pin.sha256).map(pin=>pin.relative);
if(sha(fs.readFileSync(manifestFile))!==stage.capsule.sha256||changed().length||productionChanged().length||sha(fs.readFileSync(stage.engine.path))!==stage.engine.sha256)throw Error('Acceptance pin differs');
const results=[];
for(const row of [{name:'compile',file:'capsule_compile.gd',checks:stage.entryRoots.length,compile:true},...stage.fixtures]){
 if(continuing&&!rerunNames.includes(row.name)){
  const old=prior.run.results.find(result=>result.name===row.name);
  if(!old?.success||old.checks!==row.checks||old.errors?.length||old.failures?.length)throw Error('Cannot reuse failed fixture: '+row.name);
  results.push({...old,reusedFrom:prior.proof.run});continue;
 }
 const folder=path.join(directory,row.name);fs.mkdirSync(folder,{recursive:true});
 const report=path.join(folder,'result.json'),userdata=path.join(folder,'userdata');fs.mkdirSync(userdata,{recursive:true});
 const args=['--headless','--path',project];if(row.compile)args.push('--check-only');args.push('--script','res://'+(row.invocationFile??row.file),'--','--report='+report);
 if(row.assets)args.push('--install='+stage.install.directory,'--cache='+path.join(folder,'prepared'),'--prepared-cache-write=sync','--particle-kernel='+(row.assetKernel??'gd'),'--particles=false');
 if(row.args)args.push(...row.args);
 const started=new Date().toISOString();
 const child=spawnSync(stage.engine.path,args,{cwd:workspace,encoding:'utf8',windowsHide:true,timeout:row.assets?120000:40000,maxBuffer:4*1024*1024,env:{...process.env,APPDATA:userdata,LOCALAPPDATA:userdata,NWN_PARTICLE_KERNEL:row.assets?(row.assetKernel??'gd'):(process.env.NWN_PARTICLE_KERNEL??'native')}});
 const stdout=child.stdout??'',stderr=child.stderr??'',combined=stdout+'\n'+stderr;
 fs.writeFileSync(path.join(folder,'stdout.log'),stdout,{flag:'wx'});fs.writeFileSync(path.join(folder,'stderr.log'),stderr,{flag:'wx'});
 const errors=combined.split(/\r?\n/).filter(line=>/SCRIPT ERROR|^ERROR:|Parse Error|ObjectDB instances (?:were )?leaked|resources still in use|Invalid call/.test(line));
 const warnings=[...combined.matchAll(/^WARNING: (.+)$/gm)].map(match=>match[1]);
 const expectedWarnings=row.expectedWarnings??{};
 if(warnings.some(message=>!Object.hasOwn(expectedWarnings,message))||Object.entries(expectedWarnings).some(([message,count])=>warnings.filter(actual=>actual===message).length!==count))errors.push('Unexpected or missing bounded warning message/count');
 let detail=null;if(fs.existsSync(report))try{detail=JSON.parse(fs.readFileSync(report));}catch{}
 let checks=row.compile?stage.entryRoots.length:detail?.checks;
 let failures=detail?.failures??[];
 if(row.marker){const match=combined.match(new RegExp(row.marker+'\\s+(\\d+) checks (\\d+) failures'));checks=match?Number(match[1]):null;if(!match||Number(match[2])!==0)failures=[...failures,'Missing or failed strict fixture marker'];}
 if(row.name==='actor'&&!/NATIVE_PARITY_ACTOR_ALPHA_NATIVE_STORAGE\s+4/.test(combined))failures.push('Actual four existing native storage cases not witnessed');
 const success=child.status===0&&!child.error&&!errors.length&&!failures.length&&checks===row.checks&&(!row.report||detail!==null);
 const result={name:row.name,success,started,finished:new Date().toISOString(),exit:child.status,error:child.error?.message??null,checks,expectedChecks:row.checks,errors,warnings,expectedWarnings,failures,args,detail};
 write(path.join(folder,'run.json'),result);results.push(result);
 console.log(JSON.stringify({name:row.name,success,exit:child.status,checks,errors:errors.slice(0,5),failures}));
 // Independent fixtures retain their own strict failures/logs. A failed entry
 // compile blocks all subsequent cases; one fixture does not hide the rest.
 if(!success&&row.compile)break;
}
const sourceChanged=changed(),capsuleChanged=productionChanged(),originalChanged=stage.install.keys.filter(pin=>sha(fs.readFileSync(pin.file))!==pin.sha256).map(pin=>pin.file);
const success=results.length===stage.fixtures.length+1&&results.every(row=>row.success)&&!sourceChanged.length&&!capsuleChanged.length&&!originalChanged.length;
write(output,{success,stage:{file:path.join(directory,'stage.json'),sha256:sha(fs.readFileSync(path.join(directory,'stage.json')))},capsule:stage.capsule,engine:stage.engine,nativeBinary:stage.nativeBinary,continuation:stage.continuation,results,sourceChanged,capsuleChanged,originalChanged,serverConnections:0,nativeBuilds:0,gpuDraws:0,scope:'Merged frozen-performance + seven-fix capsule isolated headless compilation and CPU fixtures; no live-client, visual, FPS or server acceptance.'});
console.log(JSON.stringify({success,completed:results.length,checks:results.reduce((sum,row)=>sum+(row.checks??0),0),receipt:output}));process.exit(success?0:1);
