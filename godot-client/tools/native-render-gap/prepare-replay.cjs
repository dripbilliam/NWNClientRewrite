'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto'),{pathToFileURL}=require('url');
const project=path.resolve(__dirname,'../..'),[label,variant,...inputs]=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(label??'')||!['installed','engine-control','probe','light','light-probe','skin','boundary','combined','combined-probe','motion','motion-probe','childless','childless-probe','sample','sample-probe','sample-feats','sample-feats-probe','activity-probe','activity-detail-probe'].includes(variant))throw Error('Fresh label and known variant required');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const helper=require('../native-production-selection.cjs'),identity=require('../native-feature-manifest.cjs').sourceIdentity;
const root=path.join(project,'.cache/native-render-gap/replays',label);
if(fs.existsSync(root))throw Error('Existing replay stage retained');
const trainingOnly=inputs.includes('--training-only');
const overrides=[];const extraFlags=inputs.filter(x=>['--skeleton-upload-guard=exact','--skeleton-pair-guard=exact','--pair-record-reuse=exact','--light-pair-layer-repair=exact','--light-pair-filter=consumers','--light-input-read=typed','--particle-scene-boundary=native','--particle-scene-boundary=legacy','--frame-pacing-metrics=on','--particle-sparse-timing','--particle-coarse-timing','--particle-setup-boundary=bound','--particle-chunk-admission=childless','--particle-scene-direct=pod','--particle-scene-direct=legacy','--skeleton-force-pass=once','--visibility-chain-cache=epochs','--light-input-proof=segments','--particle-hot-parameters=bound','--particle-hot-parameters=legacy','--rig-skin-publisher=native'].includes(x)||['--window-feature-counters','--script-owner-trace=on','--particle-resident-text=borrow','--particle-resident-text=legacy','--particle-empty-clips=skip','--particle-empty-clips=legacy','--light-dictionary-read=single','--particle-core-survey','--light-input-lifetime=guarded','--light-member-read=indices','--particle-key-survey','--particle-hit-normal=bound','--particle-hit-normal=legacy'].includes(x));
const capsuleArg=inputs.find(x=>x.startsWith('--engine-capsule='))?.slice('--engine-capsule='.length);
if(inputs.filter(x=>x.startsWith('--engine-capsule=')).length>1||(capsuleArg&&inputs.some(x=>x.startsWith('--engine-build='))))throw Error('Choose one explicit engine capsule or engine build');
if(capsuleArg!==undefined&&(capsuleArg!=='light-member-c'||variant==='installed'))throw Error('Unknown or incompatible engine capsule');
const buildArg=inputs.find(x=>x.startsWith('--engine-build='))?.slice('--engine-build='.length)??'build-1794129649064';
const kernelArg=inputs.find(x=>x.startsWith('--kernel-stage='))?.slice('--kernel-stage='.length);
const reuseBase=inputs.find(x=>x.startsWith('--reuse-base='))?.slice('--reuse-base='.length);
if(reuseBase&&!/^[a-z0-9-]+$/.test(reuseBase))throw Error('Explicit sealed base label required');
if((kernelArg&&!['boundary-skin-b','childless-chunk-a','setup-boundary-a','direct-scene-b','coarse-sampler-b','coarse-mapped-a','coarse-mapped-b','hot-parameters-c','hot-mapped-a','resident-text-b','empty-clips-b','core-survey-a','combined-b','key-survey-b','combined-ob3-b','normal-binding-a'].includes(kernelArg))||!/^build-[0-9]+$/.test(buildArg)||inputs.some(x=>!extraFlags.includes(x)&&x!=='--engine-build='+buildArg&&x!=='--engine-capsule='+capsuleArg&&x!=='--kernel-stage='+kernelArg&&x!=='--reuse-base='+reuseBase&&x!=='--training-only'))throw Error('Unsupported preparation input');
if(extraFlags.includes('--particle-core-survey')){
 if(kernelArg!=='core-survey-a'||variant==='installed')throw Error('Core survey requires the explicit private core-survey-a capsule and a diagnostic engine');
 if(!extraFlags.includes('--frame-pacing-metrics=on'))extraFlags.push('--frame-pacing-metrics=on');
}
if(extraFlags.includes('--particle-key-survey')&&(kernelArg!=='key-survey-b'||variant==='installed'))throw Error('Key survey requires explicit private key-survey-b capsule and diagnostic engine');
if(extraFlags.some(x=>x.startsWith('--particle-hit-normal='))&&(kernelArg!=='normal-binding-a'||variant==='installed'))throw Error('Normal location mode requires explicit private normal-binding-a capsule and diagnostic engine');
const adapter=path.join(__dirname,'replay-adapter-v20.cjs');
function override(relative,file){
 const bytes=fs.readFileSync(file),frozen=path.join(root,'inputs',relative);
 fs.mkdirSync(path.dirname(frozen),{recursive:true});fs.writeFileSync(frozen,bytes,{flag:'wx'});
 overrides.push({relative,file:frozen,origin:path.resolve(file),sha256:sha(bytes)});return bytes;
}
async function main(){
 const priorFile=path.join(project,'.cache/native-presentation-parity/production-replay/fps-max-v1-ordinary-workers-b/production-selection.json'),prior=JSON.parse(fs.readFileSync(priorFile));
 const profile=variant.includes('probe');
 const seeds={version:1,expected:prior.preferences.expected,description:prior.preferences.description};
 for(const name of ['render','layout'])seeds[name]={file:path.join(path.dirname(priorFile),prior.preferences[name].relative),sha256:prior.preferences[name].sha256};
 const options=prior.options.map(a=>a==='--world-snapshot-preparation=workers'?'--world-snapshot-preparation=script':a==='--detailed-profiling=off'&&profile?'--detailed-profiling=on':a);
 let base;
 if(reuseBase){const file=path.join(project,'.cache/native-presentation-parity/production-replay',reuseBase,'production-selection.json'),digest=sha(fs.readFileSync(file)),selection=await helper.readProductionSelection(file,digest);if(selection.mainSourceIdentity.sha256!==identity(project).sha256||JSON.stringify(selection.options)!==JSON.stringify(options))throw Error('Sealed base differs from current subject/options');for(const name of ['render','layout'])if(selection.preferences[name].sha256!==seeds[name].sha256)throw Error('Sealed common preferences differ');base={file,sha256:digest,selection};}
 else base=await helper.stageProductionSelection({project,label:'render-gap-'+label,argv:options,preferenceSeeds:seeds});
 const destination=path.join(root,'project'); fs.mkdirSync(destination,{recursive:true});
 const data=new Map(base.selection.pins.map(p=>[p.relative,fs.readFileSync(path.join(base.selection.sourceProject,p.relative))]));
 if(variant==='sample-feats'||variant==='sample-feats-probe'){
  const stage=path.join(project,'.cache/native-render-gap/pose-pure-feats/source-a'),m=JSON.parse(fs.readFileSync(path.join(stage,'proposal.json')));
  for(const p of m.pins){const f=path.join(stage,p.relative);if(sha(data.get(p.relative))!==p.originalSha256||sha(fs.readFileSync(f))!==p.sha256)throw Error('Pure feat source drift');data.set(p.relative,override(p.relative,f));}
 }
 if(extraFlags.includes('--window-feature-counters')){
  const relative='native_session_world.gd';let code=data.get(relative).toString();
  const anchor='\t\t\tsamples.clear(); previous=0';if(code.split(anchor).length!==2)throw Error('Window reset seam');
  code=code.replace(anchor,'\t\t\tvar gap_window_features: Dictionary={}\n\t\t\tif ClassDB.class_exists("NwnFrameProbe") and ClassDB.class_has_method("NwnFrameProbe","feature_totals"):gap_window_features=ClassDB.class_call_static("NwnFrameProbe","feature_totals")\n\t\t\tvar gap_window_frame:=Engine.get_process_frames()\n'+anchor);
  const view='\t\t\treport.performance_window.view_begin=runtime_features_snapshot().presentation';if(code.split(view).length!==2)throw Error('Window begin seam');
  code=code.replace(view,view+'\n\t\t\treport.performance_window.engine_features_begin=gap_window_features\n\t\t\treport.performance_window.engine_process_frame_begin=gap_window_frame');
  const f=path.join(root,'native_session_world.gd');fs.writeFileSync(f,code,{flag:'wx'});data.set(relative,override(relative,f));
 }
 if(variant==='activity-probe'||variant==='activity-detail-probe'){
  const mf=path.join(project,'.cache/native-render-gap/scene',variant==='activity-detail-probe'?'effect-activity-probe-b':'effect-activity-probe-a','manifest.json'),m=JSON.parse(fs.readFileSync(mf));
  for(const row of m.rows){if(sha(fs.readFileSync(row.file))!==row.sha256)throw Error('Activity proposal drift');if(row.originalSha256&&sha(data.get(row.relative).toString().replace(/\r\n/g,'\n'))!==row.originalSha256)throw Error('Activity original differs');data.set(row.relative,override(row.relative,row.file));}
 }
 if(extraFlags.includes('--light-input-read=typed')){
  const relative='systems/native_render/native_light_input_registry.gd',f=path.join(project,'.cache/native-render-gap/scene/light-live-b/native_light_input_registry.gd');
  data.set(relative,override(relative,f));
 }
 if(['motion','motion-probe'].includes(variant)){
  const f=path.join(project,'.cache/native-render-gap/motion/facing-a/project/systems/network_motion.gd');
  data.set('systems/network_motion.gd',override('systems/network_motion.gd',f));extraFlags.push('--motion-facing=native');
 }
 if(['light','light-probe','combined','combined-probe'].includes(variant)){
  const f=path.join(project,'.cache/native-render-gap/scene/world-light-overlays-a',variant==='light-probe'?'diagnostic':'candidate','systems/native_render/model_point_light.gd');
  data.set('systems/native_render/model_point_light.gd',override('systems/native_render/model_point_light.gd',f));
 }
 if(['skin','combined','combined-probe'].includes(variant)||extraFlags.includes('--rig-skin-publisher=native')){
  const f=path.join(project,'.cache/native-render-gap/particles/boundary-skin-v2-b/systems/model_rigs.gd');data.set('systems/model_rigs.gd',override('systems/model_rigs.gd',f)); if(!extraFlags.includes('--rig-skin-publisher=native'))extraFlags.push('--rig-skin-publisher=native');
 }
 const sample=['sample','sample-probe','sample-feats','sample-feats-probe'].includes(variant),childless=['childless','childless-probe'].includes(variant)||extraFlags.includes('--particle-chunk-admission=childless');
 if(kernelArg||['boundary','combined','combined-probe'].includes(variant)||childless||sample){
  const kernelStage=path.join(project,'.cache/native-render-gap/particles',kernelArg??(extraFlags.some(x=>x.startsWith('--particle-hot-parameters='))?'hot-parameters-c':extraFlags.includes('--particle-coarse-timing')?'coarse-sampler-b':extraFlags.some(x=>x.startsWith('--particle-scene-direct='))?'direct-scene-b':sample?'setup-boundary-a':childless?'childless-chunk-a':'boundary-skin-b'));
  const build=path.join(kernelStage,'kernel-build/build-receipt.json'),r=JSON.parse(fs.readFileSync(build));
  if(r.success!==true||r.exit!==0||sha(fs.readFileSync(r.binary))!==r.binarySha256)throw Error('Boundary DLL proof unavailable');
  for(const p of r.sourcePins){const f=path.join(kernelStage,'kernel-project',p.relative);if(sha(fs.readFileSync(f))!==p.sha256)throw Error('Boundary build input changed');}
  for(const p of r.sourcePins){
   if(!p.relative.startsWith('native/'))continue;
   if(!data.has(p.relative)||sha(data.get(p.relative))!==p.sha256){const f=path.join(kernelStage,'kernel-project',p.relative);data.set(p.relative,override(p.relative,f));}
  }
  data.set('.cache/native-kernel/nwn-particle-kernel.dll',override('.cache/native-kernel/nwn-particle-kernel.dll',r.binary));
  const original=JSON.parse(data.get('.cache/native-kernel/build-manifest.json'));
  const nativeManifest={engineSha256:original.engineSha256,binarySha256:r.binarySha256,flags:r.flags,api:original.api,compiler:'14.50.35717',scope:'Private exact-call-boundary proposal; focused logic/lifetime/callback checks passed. No FPS acceptance or installed promotion.',sources:Object.fromEntries(r.sourcePins.map(p=>[p.relative,p.sha256])),privateBuildProof:{file:build,sha256:sha(fs.readFileSync(build))}};
  const f=path.join(root,'kernel-build-manifest.json');fs.writeFileSync(f,JSON.stringify(nativeManifest,null,2)+'\n',{flag:'wx'});data.set('.cache/native-kernel/build-manifest.json',override('.cache/native-kernel/build-manifest.json',f));
  if(childless||sample){
   const relative='systems/native_render/particle_stream_group.gd',f=path.join(kernelStage,relative);data.set(relative,override(relative,f));
   if(childless&&!extraFlags.includes('--particle-chunk-admission=childless'))extraFlags.push('--particle-chunk-admission=childless');
  }else if(!extraFlags.includes('--particle-scene-boundary=native'))extraFlags.push('--particle-scene-boundary=native');
 }
 if(variant!=='installed'&&(variant!=='engine-control'||extraFlags.length>0)){
  // Cold source/activation inspection runs after the measurement window ends.
  const helpers=[['tools/native-render-gap/particles/source_census.gd',path.join(project,'tools/native-render-gap/particles/source_census.gd')],['tools/native-render-gap/scene/rig_topology_census.gd',path.join(project,'tools/native-render-gap/scene/rig_topology_census.gd')],['tools/native-render-gap/scene/rig_topology_census_v2.gd',path.join(project,'tools/native-render-gap/scene/rig_topology_census_v2.gd')]];
  for(const [relative,f]of helpers)data.set(relative,override(relative,f));
  const relative='native_live_world.gd';let code=data.get(relative).toString();
  const from='\tif is_instance_valid(world): report.world=world.snapshot()';
  if(code.split(from).length!==2)throw Error('Cold report seam changed');
  const hook='\n\tif is_instance_valid(world):\n\t\treport.render_gap={"source_census":load("res://tools/native-render-gap/particles/source_census.gd").capture(world.particle_stream_group),"rig_topology":load("res://tools/native-render-gap/scene/rig_topology_census_v2.gd").capture(world),"skin_owners":[]}\n\t\tif ClassDB.class_exists("NwnMotionNumeric"):report.render_gap.motion=ClassDB.class_call_static("NwnMotionNumeric","inspect")\n\t\tif ClassDB.class_has_method("NwnFrameProbe","dirty_instance_sample"):report.render_gap.dirty_instances=ClassDB.class_call_static("NwnFrameProbe","dirty_instance_sample")\n\t\tfor owner: Node in world.find_children("*","Node",true,false):\n\t\t\tif owner.has_method("native_skin_publication_snapshot"):report.render_gap.skin_owners.append(owner.call("native_skin_publication_snapshot"))\n'+(extraFlags.includes('--particle-scene-boundary=native')?'\t\tif is_instance_valid(world.particle_stream_group) and world.particle_stream_group.native!=null:report.render_gap.particle_boundary=world.particle_stream_group.native.call("dispatch",13,{})\n':'');
  let diagnostics='\t\tif ClassDB.class_has_method("NwnFrameProbe","feature_totals"):report.render_gap.engine_features=ClassDB.class_call_static("NwnFrameProbe","feature_totals")\n';
  if(extraFlags.includes('--light-input-read=typed'))diagnostics+='\t\tif is_instance_valid(world.focus_lighting) and world.focus_lighting._input_registry.native!=null:report.render_gap.light_inputs=world.focus_lighting._input_registry.native.call("dispatch",9,{})\n';
  if(childless)diagnostics+='\t\tif is_instance_valid(world.particle_stream_group) and world.particle_stream_group.native!=null:report.render_gap.chunk_admission=world.particle_stream_group.native.call("dispatch",14,{})\n';
  if(sample)diagnostics+='\t\tif is_instance_valid(world.particle_stream_group) and world.particle_stream_group.native!=null:\n\t\t\treport.render_gap.particle_sample=world.particle_stream_group.native.call("dispatch",16,{})\n\t\t\treport.render_gap.admission_survey=world.particle_stream_group.native.call("dispatch",17,{})\n';
  if(kernelArg==='hot-parameters-c'||extraFlags.some(x=>x.startsWith('--particle-hot-parameters=')))diagnostics+='\t\tif is_instance_valid(world.particle_stream_group) and world.particle_stream_group.native!=null:report.render_gap.hot_parameters=world.particle_stream_group.native.call("dispatch",18,{})\n';
  if(extraFlags.includes('--script-owner-trace=on'))diagnostics+='\t\tif ClassDB.class_has_method("NwnFrameProbe","script_context"):report.render_gap.script_context=ClassDB.class_call_static("NwnFrameProbe","script_context")\n';
  if(extraFlags.some(x=>x.startsWith('--particle-resident-text=')))diagnostics+='\t\tif is_instance_valid(world.particle_stream_group) and world.particle_stream_group.native!=null:report.render_gap.resident_text=world.particle_stream_group.native.call("dispatch",21,{})\n';
  if(extraFlags.some(x=>x.startsWith('--particle-empty-clips=')))diagnostics+='\t\tif is_instance_valid(world.particle_stream_group) and world.particle_stream_group.native!=null:report.render_gap.empty_clips=world.particle_stream_group.native.call("dispatch",22,{})\n';
  if(extraFlags.some(x=>x.startsWith('--particle-hit-normal=')))diagnostics+='\t\tif is_instance_valid(world.particle_stream_group) and world.particle_stream_group.native!=null:report.render_gap.hit_normal=world.particle_stream_group.native.call("dispatch",25,{})\n';
  if(extraFlags.includes('--particle-key-survey'))diagnostics+='\t\tif is_instance_valid(world.particle_stream_group) and world.particle_stream_group.native!=null:report.render_gap.key_survey=world.particle_stream_group.native.call("dispatch",23,{})\n';
  if(extraFlags.includes('--particle-core-survey'))diagnostics+='\t\tif is_instance_valid(world.particle_stream_group) and world.particle_stream_group.native!=null:\n\t\t\treport.render_gap.core_survey=world.particle_stream_group.native.call("dispatch",24,{})\n\t\t\treport.render_gap.core_survey.process_creation_100ns_exact=str(report.render_gap.core_survey.process_creation_100ns)\n\t\t\treport.render_gap.core_survey.report_thread_creation_100ns_exact=str(report.render_gap.core_survey.report_thread_creation_100ns)\n';
  if(extraFlags.includes('--frame-pacing-metrics=on'))diagnostics+='\t\tif ClassDB.class_exists("NwnFramePacing"):\n\t\t\treport.render_gap.pacing=ClassDB.class_call_static("NwnFramePacing","snapshot",4096)\n\t\t\tfor gap_lane: String in ["main_thread_policy","render_thread_policy"]:\n\t\t\t\tvar gap_policy: Dictionary=report.render_gap.pacing.get(gap_lane,{})\n\t\t\t\tif gap_policy.has("expected_creation_100ns"):gap_policy.expected_creation_100ns_exact=str(gap_policy.expected_creation_100ns)\n\t\t\t\tif gap_policy.has("observed_creation_100ns"):gap_policy.observed_creation_100ns_exact=str(gap_policy.observed_creation_100ns)\n';
  if(variant==='activity-probe'||variant==='activity-detail-probe')diagnostics+='\t\treport.render_gap.effect_activity=load("res://tools/native-render-gap/scene/effect_activity_census.gd").capture(world)\n';
  code=code.replace(from,from+hook+diagnostics);
  if(extraFlags.includes('--window-feature-counters')){
   const anchor='\t\treport.performance_window.view_end=runtime_features_snapshot().presentation';if(code.split(anchor).length!==2)throw Error('Window end seam');
   code=code.replace(anchor,anchor+'\n\t\tif ClassDB.class_exists("NwnFrameProbe") and ClassDB.class_has_method("NwnFrameProbe","feature_totals"):report.performance_window.engine_features_end=ClassDB.class_call_static("NwnFrameProbe","feature_totals")\n\t\treport.performance_window.engine_process_frame_end=Engine.get_process_frames()');
  }
  const f=path.join(root,'native_live_world.gd');fs.writeFileSync(f,code,{flag:'wx'});data.set(relative,override(relative,f));
 }
 if(profile){
  const relative='systems/native_render/frame_profile.gd',old=data.get(relative).toString();let code=old;
  const once=(a,b)=>{if(code.split(a).length!==2)throw Error('Profile seam differs');code=code.replace(a,b);};
  once('var viewport: Viewport','var probe_last_frame:=-1\nvar viewport: Viewport');
  once('func set_enabled(value: bool) -> void:','func set_enabled(value: bool) -> void:\n\tClassDB.class_call_static("NwnFrameProbe","set_enabled",value)');
  once('\treturn row\nfunc _process(', '\tvar probe: Dictionary=ClassDB.class_call_static("NwnFrameProbe","completed_frame")\n\tif probe.get("available",false):\n\t\trow.rt_duplicate=1 if int(probe.frame_id)==probe_last_frame else 0\n\t\tif int(probe.frame_id)!=probe_last_frame:\n\t\t\tfor key in probe:\n\t\t\t\tif key.ends_with("_us") or key not in ["available","frame_id","writer_thread","units"]:row["rt_"+str(key)]=probe[key]\n\t\t\tprobe_last_frame=int(probe.frame_id)\n\treturn row\nfunc _process(');
  const f=path.join(root,'frame_profile.gd');fs.writeFileSync(f,code,{flag:'wx'});data.set(relative,override(relative,f));
 }
 const immutableDossiers=new Set(['native-actor-alpha-propagation-v1.json','native-actor-alpha-propagation-v2.json','native-static-mesh-membership-fields-v1.json','native-static-placeable-spawntile-v1.json','native-static-placeable-spawntile-v2.json']),basePins=new Map(base.selection.pins.map(p=>[p.relative,p.sha256])),changed=new Set(overrides.map(p=>p.relative)),storage={reusedBase:reuseBase??null,linkedDossiers:0,linkedLogicalBytes:0};
 // All overrides are resolved before the single destination write. Only five
 // static REA evidence JSON files may link, and only to an immutable base.
 // Runtime/code/metadata/DLL paths remain independent writable copies.
 const pins=[];for(const [relative,bytes]of data){const f=path.join(destination,relative),digest=sha(bytes);fs.mkdirSync(path.dirname(f),{recursive:true});if(relative.startsWith('tools/native_parity/visibility/evidence/')&&immutableDossiers.has(path.basename(relative))&&!changed.has(relative)&&basePins.get(relative)===digest){fs.linkSync(path.join(base.selection.sourceProject,relative),f);storage.linkedDossiers++;storage.linkedLogicalBytes+=bytes.length;}else fs.writeFileSync(f,bytes,{flag:'wx'});pins.push({relative,sha256:digest});}
 fs.mkdirSync(path.join(root,'preference-seeds'));for(const name of ['render','layout'])fs.copyFileSync(path.join(path.dirname(base.file),base.selection.preferences[name].relative),path.join(root,'preference-seeds',name+'.cfg'),fs.constants.COPYFILE_EXCL);
 let runtime=base.selection.runtime,engine=base.selection.engine,engineProof=null;
 if(variant!=='installed'){
  const file=capsuleArg?path.join(project,'.cache/native-render-gap/scene/light-member-build-c-a/candidate/receipt.json'):path.join(project,'.cache/native-render-gap/engine',buildArg,'receipt.json'),receipt=JSON.parse(fs.readFileSync(file));
  if((receipt.trainingOnly===true)!==trainingOnly)throw Error('Explicit matching training-only preparation required');
  if(receipt.exitCode!==0||sha(fs.readFileSync(receipt.output))!==receipt.outputSha256)throw Error('Private engine unavailable');
  engine=receipt.output;runtime={...runtime,executable:engine,executableSha256:receipt.outputSha256};engineProof={file,sha256:sha(fs.readFileSync(file))};
  for(const [key,name]of [['invocation','invocation.json'],['manifest','source-manifest.json']]){const f=path.join(receipt.run,name);engineProof[key]={file:f,sha256:sha(fs.readFileSync(f))};}
 }
 const performanceOptions=structuredClone(base.selection.performanceOptions),particleSha256=sha(fs.readFileSync(path.join(destination,'.cache/native-kernel/nwn-particle-kernel.dll')));
 if(performanceOptions.renderCore)performanceOptions.renderCore={...performanceOptions.renderCore,engineSha256:runtime.executableSha256,nativeKernelSha256:particleSha256,scope:'Private experimental derivative of the accepted functional bundle; exact engine and DLL overrides are independently pinned. Not a production promotion.'};
 runtime={...runtime,experimentalOverrides:{engineSha256:runtime.executableSha256,particleSha256}};
 const selection={...base.selection,performanceOptions,renderCore:performanceOptions.renderCore,kind:'private-render-gap-selection',production:false,experimental:true,sourceProject:destination,mainSourceIdentity:identity(destination),pins,engine,runtime,flags:[...base.selection.flags,...extraFlags],renderGap:{variant,trainingOnly,engineCapsule:capsuleArg??null,base:{file:base.file,sha256:base.sha256},overrides,extraFlags,engineProof},particleLoop:{module:{file:path.join(destination,'.cache/native-kernel/nwn-particle-kernel.dll'),sha256:sha(fs.readFileSync(path.join(destination,'.cache/native-kernel/nwn-particle-kernel.dll')))}}};
 const file=path.join(root,'selection.json');fs.writeFileSync(file,JSON.stringify(selection,null,2)+'\n',{flag:'wx'});
 const driverBase=path.join(project,'tools/replay-native-loading.mjs');let code=fs.readFileSync(driverBase,'utf8');
 const replace=(from,to)=>{if(code.split(from).length!==2)throw Error('Replay seam differs '+from.slice(0,75));code=code.replace(from,to);};
 code=code.replace(/from '(\.\/[^']+)'/g,(_,name)=>'from '+JSON.stringify(pathToFileURL(path.resolve(path.dirname(driverBase),name)).href));
 replace('createRequire(import.meta.url)','createRequire('+JSON.stringify(pathToFileURL(driverBase).href)+')');
 replace("const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');",'const project='+JSON.stringify(project)+';');
 replace("const productionSelection=await readReplayProductionSelection(arg('production-selection'),arg('production-selection-sha256'),project);",'const gapAdapter=require('+JSON.stringify(adapter)+");\nconst productionSelection=await gapAdapter.readSelection(arg('production-selection'),arg('production-selection-sha256'));");
 replace("await readReplayProductionSelection(arg('production-selection'),arg('production-selection-sha256'),project)","await gapAdapter.readSelection(arg('production-selection'),arg('production-selection-sha256'))");
 replace('Object.assign(runtimeFiles,sceneEngineFiles);','Object.assign(runtimeFiles,sceneEngineFiles,gapAdapter.runtimeFiles(productionSelection));');
 replace(" await fs.writeFile(reportPath,JSON.stringify(report,null,2)+'\\n',{flag:'wx'});"," report.renderGapVerification=gapAdapter.verifyNative(productionSelection,report.native);\n if(report.renderGapVerification.status!=='observed'){report.success=false;report.failure??='Private render-gap source/engine rejected';}\n await fs.writeFile(reportPath,JSON.stringify(report,null,2)+'\\n',{flag:'wx'});");
 if(code.includes('await readReplayProductionSelection('))throw Error('Final selection reader not replaced');
 const driver=path.join(root,'driver.mjs');fs.writeFileSync(driver,code,{flag:'wx'});
 await require(adapter).readSelection(file,sha(fs.readFileSync(file)));
 const result={root,variant,storage,adapter:{file:adapter,sha256:sha(fs.readFileSync(adapter))},selection:{file,sha256:sha(fs.readFileSync(file))},base:{file:driverBase,sha256:sha(fs.readFileSync(driverBase))},driver:{file:driver,sha256:sha(fs.readFileSync(driver))},mainBefore:base.selection.mainSourceIdentity.sha256,mainAfter:identity(project).sha256,profile};
 if(result.mainBefore!==result.mainAfter)throw Error('Installed application changed');
 fs.writeFileSync(path.join(root,'preparation.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
}
main().catch(e=>{console.error(e.stack);process.exitCode=1;});
