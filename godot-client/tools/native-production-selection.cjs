'use strict';
// Current application code selection only. Never copies game/server assets or launches.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function configuration(project,argv,{env={}}={}){
 const flags=require(path.join(project,'tools/native-client-flags.cjs'));
 argv=flags.canonicalPerformanceArguments(argv,{env});
 flags.validateHostOptions(argv,project);
 const inventory=flags.catalogue(project),allowed=new Set(inventory.features.map(row=>row.name));
 for(const row of inventory.applicationIngress)if(row.parserSources.some(p=>p.file==='tools/native-render-configuration.cjs'))allowed.add(row.name);
 allowed.add("native-runtime");
 for(const value of argv)if(!value.startsWith('--')||!allowed.has(value.slice(2).split('=',1)[0]))throw Error('Production selection accepts declared feature/render options only');
 const performance=flags.resolvePerformanceOptions(argv),loading=require(path.join(project,'tools/native-loading-pipeline.cjs')).resolveNativeLoadingPipeline(argv);
 const arg=name=>argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3);
 const render=require(path.join(project,'tools/native-render-configuration.cjs')).resolveNativeRenderConfiguration({arg,env:{},isolated:false});
 const profile=performance.requested['detailed-profiling'].value;
 if(!performance.requested['detailed-profiling'].explicit||!['on','off'].includes(profile))throw Error('Production replay requires explicit --detailed-profiling=on|off');
 return {performance,loading,render,renderCore:structuredClone(performance.renderCore),profiling:profile==='on'?'true':'false',flags:[...render.arguments,...loading.arguments,...performance.nativeArguments.filter(value=>!value.startsWith('--profile='))]};
}
function safeRelative(name){return typeof name==='string'&&name!==''&&!path.isAbsolute(name)&&!name.split(/[\\/]/).some(part=>part==='..'||part==='.'||part==='');}
function validatePins(manifest){
 if(!Array.isArray(manifest.pins)||manifest.pins.length<1||manifest.pins.length>8192)throw Error('Production source pins missing or excessive');
 const seen=new Set();for(const pin of manifest.pins){if(!safeRelative(pin.relative)||seen.has(pin.relative)||!/^[a-f0-9]{64}$/.test(pin.sha256))throw Error('Invalid production source pin');seen.add(pin.relative);const file=path.resolve(manifest.sourceProject,pin.relative),relative=path.relative(manifest.sourceProject,file);if(relative.startsWith('..')||path.isAbsolute(relative)||hash(fs.readFileSync(file))!==pin.sha256)throw Error('Production source changed: '+pin.relative);}
}
function preferenceSeeds(input){
 if(!input||input.version!==1||!input.render||!input.layout||!Number.isFinite(input.expected?.gamma)||input.expected.gamma<0||input.expected.gamma>1000||typeof input.expected?.particles!=='boolean')throw Error('Explicit reviewed render/layout preference seeds and expected values required');
 if(!Number.isFinite(input.expected?.fovDegrees)||input.expected.fovDegrees<20||input.expected.fovDegrees>120)throw Error('Explicit valid common preference FOV required');
 const rows={};for(const name of ['render','layout']){
  const row=input[name];if(!path.isAbsolute(row.file??'')||!/^[a-f0-9]{64}$/.test(row.sha256??''))throw Error('Preference seed path/SHA256 required');
  const bytes=fs.readFileSync(row.file);if(bytes.length>1024*1024||hash(bytes)!==row.sha256)throw Error('Preference seed changed or exceeds bound');rows[name]={file:row.file,sha256:row.sha256,bytes};
 }return {rows,expected:structuredClone(input.expected),description:String(input.description??'Explicit reviewed fixture')};
}
function validatePreferencePins(selection){
 if(selection.version===1)return;
 const prefs=selection.preferences;if(!prefs||prefs.version!==1||!Number.isFinite(prefs.expected?.gamma)||typeof prefs.expected?.particles!=='boolean')throw Error('Production preference seeds are missing');
 for(const name of ['render','layout']){const row=prefs[name],relative='preference-seeds/'+name+'.cfg';if(row?.relative!==relative||!/^[a-f0-9]{64}$/.test(row.sha256??'')||!Number.isSafeInteger(row.bytes)||row.bytes<0||row.bytes>1024*1024)throw Error('Invalid preference seed pin');const file=path.join(path.dirname(selection.sourceProject),relative),bytes=fs.readFileSync(file);if(bytes.length!==row.bytes||hash(bytes)!==row.sha256)throw Error('Immutable preference seed changed');}
}
function createPreferenceWorkingCopies(selection,directory){
 if(![2,3].includes(selection.version)||!selection.preferences)throw Error('Restage production selection with isolated preference seeds');
 validatePreferencePins(selection);if(!path.isAbsolute(directory)||fs.existsSync(directory))throw Error('Fresh owned absolute preference working directory required');fs.mkdirSync(directory);
 const working={version:1,directory,expected:structuredClone(selection.preferences.expected),seeds:structuredClone(selection.preferences)};
 for(const name of ['render','layout']){const row=selection.preferences[name],file=path.join(directory,name+'.cfg'),seed=path.join(path.dirname(selection.sourceProject),row.relative);fs.copyFileSync(seed,file,fs.constants.COPYFILE_EXCL);working[name]={file,initialSha256:hash(fs.readFileSync(file)),seedSha256:row.sha256};}
 return working;
}
function verifyPreferenceObservation(selection,working,presentation,{viewport,particles,particleCollision,headless=false}={}){
 const errors=[],settings=presentation?.settings,visibility=presentation?.particle_visibility,gamma=presentation?.gamma;
 const samePath=(actual,expected)=>typeof actual==='string'&&path.resolve(actual).toLowerCase()===path.resolve(expected).toLowerCase();
 if(!samePath(settings?.preference_path,working.render.file))errors.push('Native render preferences were not bound to the working copy');
 if(!samePath(settings?.menu_layout_path,working.layout.file))errors.push('Native menu layout was not bound to the working copy');
 const expectedGamma=selection.renderConfiguration.gamma??selection.preferences.expected.gamma;
 if(settings?.gamma!==expectedGamma)errors.push('Actual configured gamma differs from the common seed/explicit configuration');
 if(gamma?.gamma!==undefined&&gamma.gamma!==expectedGamma||!headless&&gamma?.gamma!==expectedGamma)errors.push('Actual gamma effect differs or is unavailable');
 if(!headless&&gamma&&(gamma.failure||gamma.closed===true))errors.push('Actual gamma effect failed or was retired before observation');
 if(settings?.particles_enabled!==selection.preferences.expected.particles)errors.push('Actual saved particle setting differs from common seed');
 if(typeof particles!=='boolean'||visibility?.enabled!==particles)errors.push('Actual particle visibility differs from seed/recorded view');
 if(typeof particleCollision==='boolean'&&visibility?.collision_enabled!==particleCollision)errors.push('Actual particle collision differs from seed/recorded view');
 if(typeof selection.preferences.expected.compactScenery==='boolean'&&settings?.compact_scenery_enabled!==selection.preferences.expected.compactScenery)errors.push('Actual compact scenery differs from common seed');
 if(!Array.isArray(viewport)||viewport.length!==2||!viewport.every(Number.isSafeInteger)||JSON.stringify(presentation?.viewport)!==JSON.stringify(viewport))errors.push('Actual viewport differs from the recorded/common viewport');
 return {status:errors.length?'rejected':'observed',errors,expected:{gamma:expectedGamma,savedParticles:selection.preferences.expected.particles,particles,particleCollision,viewport},actual:{settings:structuredClone(settings??null),gamma:structuredClone(gamma??null),particleVisibility:structuredClone(visibility??null),viewport:structuredClone(presentation?.viewport??null)},scope:headless?'Preference binding/configuration and particle owner evidence; no gamma GPU-pass proof':'Actual preference binding, gamma effect value, particle owner and viewport evidence'};
}
async function stageProductionSelection({project,label,argv=[],preferenceSeeds:seedInput,env=process.env}){
 project=path.resolve(project);if(!/^[a-z0-9][a-z0-9-]{0,79}$/.test(label??''))throw Error('Fresh production selection label required');
 if(!Array.isArray(argv)||argv.some(value=>typeof value!=='string'))throw Error('Production options must be strings');
 argv=require(path.join(project,'tools/native-client-flags.cjs')).canonicalPerformanceArguments(argv,{env});
 const seeds=preferenceSeeds(seedInput),resolved=configuration(project,argv),runtimeSelector=require(path.join(project,'tools/native-performance-runtime.cjs'));
 const runtime=await runtimeSelector.selectPerformanceRuntime(project,resolved.performance.runtime)??{...await require(path.join(project,'tools/native-engine-runtime.cjs')).selectNativeRuntime(project,resolved.performance.nativeRuntime.value),requiresProjectPath:true};
 const identity=require(path.join(project,'tools/native-feature-manifest.cjs')).sourceIdentity(project),stage=path.join(project,'.cache/native-presentation-parity/production-replay',label),sourceProject=path.join(stage,'project');
 if(fs.existsSync(stage))throw Error('Production stage already exists');
 const files=new Set(identity.files.map(row=>row.file));
 for(const name of ['join-native.ps1','tools/native-feature-manifest.cjs','tools/native-production-selection.cjs','data/native_text_codepages.json','.godot/global_script_class_cache.cfg','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/build-manifest.json'])files.add(name);
 for(const name of ['.cache/native-clock-source-v1/clock_source.gdextension','.cache/native-clock-source-v1/nwn-clock-source.dll'])if(fs.existsSync(path.join(project,name)))files.add(name);
 const nativeWalk=relative=>{for(const entry of fs.readdirSync(path.join(project,relative),{withFileTypes:true})){if(entry.isSymbolicLink())throw Error('Native source symlink is unsupported');const name=path.posix.join(relative,entry.name);if(entry.isDirectory())nativeWalk(name);else if(/\.(gd|gdextension|cpp|hpp|h|c)$/.test(name))files.add(name);}};nativeWalk('native');
 // Diagnostic branches also preload test/tool scripts. Preserve their complete
 // code/resource closure while keeping sourceIdentity's comparable subset intact.
 const excluded=new Set(['node_modules','runtime-logs','reports','backups']);
 const codeWalk=relative=>{for(const entry of fs.readdirSync(path.join(project,relative),{withFileTypes:true})){if(entry.isSymbolicLink()||entry.name.startsWith('.')||excluded.has(entry.name))continue;const name=path.posix.join(relative,entry.name);if(entry.isDirectory())codeWalk(name);else if(/\.(gd|gdshader|gdshaderinc|gdextension|tscn|tres)$/.test(name))files.add(name);}};codeWalk('');
 fs.mkdirSync(sourceProject,{recursive:true});const pins=[];
 for(const relative of [...files].sort()){
  if(!safeRelative(relative))throw Error('Source path escaped');const data=fs.readFileSync(path.join(project,relative)),destination=path.join(sourceProject,relative);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,data,{flag:'wx'});pins.push({relative,sha256:hash(data)});
 }
 const stagedIdentity=require(path.join(project,'tools/native-feature-manifest.cjs')).sourceIdentity(sourceProject);
 if(stagedIdentity.sha256!==identity.sha256)throw Error('Current source changed during production staging');
 fs.mkdirSync(path.join(sourceProject,'.godot'),{recursive:true});fs.writeFileSync(path.join(sourceProject,'.godot/extension_list.cfg'),'res://native/particle_kernel.gdextension\nres://native/resource_index.gdextension\n',{flag:'wx'});
 pins.push({relative:'.godot/extension_list.cfg',sha256:hash(fs.readFileSync(path.join(sourceProject,'.godot/extension_list.cfg')))});
 const preferences={version:1,expected:seeds.expected,description:seeds.description};fs.mkdirSync(path.join(stage,'preference-seeds'));
 for(const name of ['render','layout']){const row=seeds.rows[name],relative='preference-seeds/'+name+'.cfg';fs.writeFileSync(path.join(stage,relative),row.bytes,{flag:'wx'});preferences[name]={relative,sha256:row.sha256,bytes:row.bytes.length,source:row.file};}
 const manifest={version:3,kind:'production-replay-selection',complete:true,production:true,created:new Date().toISOString(),originalProject:project,sourceProject,mainSourceIdentity:identity,options:[...argv],runtime,engine:runtime.executable,engineArguments:runtimeSelector.resolveRenderThread(resolved.performance.renderThread).arguments,renderThread:resolved.performance.renderThread,flags:resolved.flags,environment:{...resolved.render.environment,NWN_PARTICLE_KERNEL:'compiled'},featureSelection:resolved.performance.requested,performanceOptions:resolved.performance,renderCore:resolved.renderCore,renderConfiguration:resolved.render.summary,loadingPipeline:resolved.loading.summary,profiling:resolved.profiling,pins,preferences,cameraPolicy:{version:1,fov:'preferences',fovDegrees:preferences.expected.fovDegrees,worldPoseEvidence:true,terminalMotion:'recorded-idle-authority'},originalAssetsCopied:false,nativeBuilds:0,scope:'Exact copied current application source/native libraries; normal configuration helpers; immutable common preferences and explicit active FOV/camera evidence; no captured/private V4 behavior or game assets'};
 const file=path.join(stage,'production-selection.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});return {file,sha256:hash(fs.readFileSync(file)),selection:manifest};
}
async function readProductionSelection(file,expected){
 if(!file&&!expected)return null;
 if(!file||!/^[a-f0-9]{64}$/.test(expected??''))throw Error('Explicit production selection and SHA256 required');
 const bytes=fs.readFileSync(file);if(hash(bytes)!==expected)throw Error('Production selection changed');const m=JSON.parse(bytes);
 if(![1,2,3].includes(m.version)||m.kind!=='production-replay-selection'||m.complete!==true||m.production!==true||m.originalAssetsCopied!==false||path.resolve(m.sourceProject)!==path.join(path.dirname(path.resolve(file)),'project'))throw Error('Production selection policy differs');
 validatePins(m);validatePreferencePins(m);
 if(m.version===3&&(!Number.isFinite(m.preferences?.expected?.fovDegrees)||m.preferences.expected.fovDegrees<20||m.preferences.expected.fovDegrees>120||JSON.stringify(m.cameraPolicy)!==JSON.stringify({version:1,fov:'preferences',fovDegrees:m.preferences.expected.fovDegrees,worldPoseEvidence:true,terminalMotion:'recorded-idle-authority'})))throw Error('Production camera/FOV policy differs from common preferences');
 const c=configuration(m.sourceProject,m.options);
 for(const [actual,wanted,label]of [[m.flags,c.flags,'flags'],[m.featureSelection,c.performance.requested,'feature selection'],[m.renderConfiguration,c.render.summary,'render configuration'],[m.loadingPipeline,c.loading.summary,'loading pipeline'],[m.environment,{...c.render.environment,NWN_PARTICLE_KERNEL:'compiled'},'environment'],[m.renderThread,c.performance.renderThread,'render thread'],[m.profiling,c.profiling,'profiling'],[m.performanceOptions.requested,c.performance.requested,'startup feature selection'],[m.renderCore,c.renderCore,'accepted render-core bundle'],[m.performanceOptions.registry.sha256,c.performance.registry.sha256,'startup registry']])if(JSON.stringify(actual)!==JSON.stringify(wanted))throw Error('Production '+label+' differs from authoritative helpers');
 const selector=require(path.join(m.sourceProject,'tools/native-performance-runtime.cjs'));
 const runtime=await selector.selectPerformanceRuntime(m.originalProject,c.performance.runtime)??{...await require(path.join(m.sourceProject,'tools/native-engine-runtime.cjs')).selectNativeRuntime(m.originalProject,c.performance.nativeRuntime.value),requiresProjectPath:true};
 for(const name of ['kind','executable','executableSha256','requiresProjectPath'])if(m.runtime[name]!==runtime[name])throw Error('Production runtime differs from authoritative selector: '+name);
 if(JSON.stringify(m.runtime.expectedCapabilities??[])!==JSON.stringify(runtime.expectedCapabilities??[])||m.engine!==runtime.executable)throw Error('Production engine capability contract differs');
 const thread=require(path.join(m.sourceProject,'tools/native-performance-runtime.cjs')).resolveRenderThread(c.performance.renderThread);
 if(JSON.stringify(m.engineArguments)!==JSON.stringify(thread.arguments))throw Error('Production engine thread arguments differ');
 return {...structuredClone(m),evidence:{file:path.resolve(file),sha256:expected,sourceProject:m.sourceProject,sourceSignature:m.mainSourceIdentity.sha256,engineSha256:m.runtime.executableSha256,particleSha256:m.pins.find(p=>p.relative==='.cache/native-kernel/nwn-particle-kernel.dll')?.sha256,flags:[...m.flags],production:true}};
}
function validateProductionReplayOptions(selection,arg){
 if(!selection)return;
 if(selection.version!==3||!selection.preferences||!selection.cameraPolicy)throw Error('Production replay requires V3 isolated preferences and active camera/motion evidence; restage the selection');
 if(arg('client-capsule')||arg('client-capsule-sha256'))throw Error('Choose production or legacy capsule selection');
 for(const name of ['render-thread','rendering-method','source-project','light-input-registry','drive-collision','render-preferences','menu-layout'])if(arg(name)!==undefined)throw Error('Production selection fixes '+name+'; stage a separate reviewed selection');
 if(arg('profiling')!==undefined&&arg('profiling')!==selection.profiling)throw Error('Production replay profiling differs from selection');
 // Every managed option is already resolved and pinned. Do not run a second parser route.
 const registry=JSON.parse(fs.readFileSync(path.join(selection.sourceProject,'systems/native_data/client_feature_registry.json'),'utf8'));
 for(const row of [...registry.features,...registry.researchOnly])if(arg(row.name)!==undefined)throw Error('Production selection fixes '+row.name+'; stage another selection');
 const inventory=require(path.join(selection.sourceProject,'tools/native-client-flags.cjs')).catalogue(selection.sourceProject);
 for(const row of [...inventory.nativeSourceFlags,...inventory.applicationIngress.filter(row=>row.parserSources.some(p=>p.file==='tools/native-render-configuration.cjs'))])if(arg(row.name)!==undefined)throw Error('Production selection fixes native/render option '+row.name);
}
module.exports={stageProductionSelection,readProductionSelection,validateProductionReplayOptions,configuration,validatePins,preferenceSeeds,validatePreferencePins,createPreferenceWorkingCopies,verifyPreferenceObservation};
if(require.main===module){const [label,...inputs]=process.argv.slice(2),get=name=>inputs.find(v=>v.startsWith('--'+name+'='))?.slice(name.length+3);const file=get('preferences-seeds'),sha=get('preferences-seeds-sha256');if(!file||!/^[a-f0-9]{64}$/.test(sha??'')||hash(fs.readFileSync(file))!==sha)throw Error('Explicit preference seed manifest and SHA256 required');const argv=inputs.filter(v=>!v.startsWith('--preferences-seeds=')&&!v.startsWith('--preferences-seeds-sha256='));stageProductionSelection({project:path.resolve(__dirname,'..'),label,argv,preferenceSeeds:JSON.parse(fs.readFileSync(file,'utf8'))}).then(r=>console.log(JSON.stringify({file:r.file,sha256:r.sha256,source:r.selection.sourceProject,engine:r.selection.runtime.kind,profiling:r.selection.profiling}))).catch(e=>{console.error(e.message);process.exitCode=1;});}
