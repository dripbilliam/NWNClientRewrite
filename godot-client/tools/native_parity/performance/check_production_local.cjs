'use strict';
// Preparation/verification/analysis only. This module never starts a process,
// opens a game connection, reads protected settings or controls a server.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const project=path.resolve(__dirname,'../../..'),workspace=path.dirname(project);
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const fileHash=file=>hash(fs.readFileSync(file));
const read=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const write=(file,data)=>{fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,data,{flag:'wx'});};
const writeJSON=(file,data)=>write(file,JSON.stringify(data,null,2)+'\n');
const flags=require('../../native-client-flags.cjs');
const provenance=require('../../native-feature-manifest.cjs');
const MODULE_SHA='b8802b74139b896fef05e47042786ae3fdbb36e92991f3d8742c7ef28661a6f9';
const nativeOverlays=[
 {name:'accepted-v4-scoped-pending-abort',before:'\t\t\tif not is_instance_valid(world) or not world.ready_for_control() or character_lobby.disconnect_button.disabled: fail("Native local disconnect probe is unavailable"); return',after:'\t\t\tvar private_pending_probe: bool=args.get("private-pending-abort","")=="true" and message.get("pendingStreamProbe",false)==true\n\t\t\tif not is_instance_valid(world) or (not world.ready_for_control() and not private_pending_probe) or character_lobby.disconnect_button.disabled: fail("Native local disconnect probe is unavailable"); return\n\t\t\tif private_pending_probe and (int(message.get("generation",-1))!=epoch or int(message.get("areaId",-1))!=world.area_id or world.batches.is_empty()): fail("Private pending abort has no scoped real pending batch"); return'},
 {name:'accepted-v4-pending-receipt',before:'"unfinished_workers":unfinished,"cache":render_pool.snapshot()',after:'"unfinished_workers":unfinished,"cache":render_pool.snapshot(),"private_pending_probe":private_pending_probe,"continuous_base_stream":world.continuous_base_stream,"base_stream_schedule":world.base_stream_schedule.snapshot(),"base_stream_refills":int(world.stats.get("base_stream_refills",0))'}
];
const common=['--native-runtime=editor','--local-check','--local-cycles=2','--local-stream-abort','--native-headless','--render-profile=gameplay','--particle-presentation=shared','--particle-lighting=pooled','--detailed-profiling=off','--loading-pipeline=merged','--shared-animation-preparation=true','--native-draw-cache=prepared','--native-draw-cache-gib=25'];
const variants={control:[...common,'--performance-runtime=standard','--render-thread=safe','--light-input-registry=script','--drive-collision=legacy'],candidate:[...common,'--performance-runtime=verified-native','--render-thread=separate','--light-input-registry=builtin','--drive-collision=indexed']};
function inside(root,file){const relative=path.relative(root,file);return relative!==''&&!relative.startsWith('..')&&!path.isAbsolute(relative);}
function exact(text,before,after,label){if(text.split(before).length!==2)throw Error('Guarded production seam differs: '+label);return text.replace(before,after);}
function pin(file){return {file:path.resolve(file),sha256:fileHash(file)};}
function sourceFiles(){
 const files=new Map(provenance.sourceIdentity(project).files.map(row=>[row.file,{relative:row.file,sha256:row.sha256,origin:'production-identity'}]));
 // Native initialization metadata and current DLLs are copied as-is. No V4
 // library substitution or old engine project/cache is selected.
 for(const relative of ['.godot/extension_list.cfg','.godot/global_script_class_cache.cfg'])files.set(relative,{relative,sha256:fileHash(path.join(project,relative)),origin:'current-initialization-metadata'});
 // Production entry scripts preload some diagnostic classes and lazily load
 // the native clock extension. Include their actual literal dependency closure
 // without copying original game assets or an entire historical capsule.
 const queue=[...files.keys()],canonical=new Set(queue.map(relative=>path.resolve(project,relative).toLowerCase()));
 for(let cursor=0;cursor<queue.length;cursor++){
  const relative=queue[cursor];if(!/\.(?:gd|gdshader|gdshaderinc|tscn|tres|json|gdextension)$/.test(relative))continue;
  const text=fs.readFileSync(path.resolve(project,relative),'utf8');
  for(const match of text.matchAll(/["']res:\/\/([^"']+)["']/g)){
   const dependency=match[1].replaceAll('\\','/'),source=path.resolve(project,dependency);
   if(canonical.has(source.toLowerCase())||!fs.existsSync(source)||!fs.statSync(source).isFile())continue;
   if(!inside(workspace,source)||fs.lstatSync(source).isSymbolicLink())throw Error('Literal dependency escaped the owned source workspace');
   const normalized=path.relative(project,source).replaceAll('\\','/');
   canonical.add(source.toLowerCase());files.set(normalized,{relative:normalized,sha256:fileHash(source),origin:'literal-resource-dependency',referencedBy:relative});queue.push(normalized);
  }
 }
 return [...files.values()].sort((a,b)=>a.relative.localeCompare(b.relative));
}
function protocolPins(){
 const rows=new Map();
 const add=file=>rows.set(path.resolve(file),pin(file));
 const walk=folder=>{for(const entry of fs.readdirSync(folder,{withFileTypes:true})){if(entry.isSymbolicLink()||entry.name.startsWith('.'))continue;const full=path.join(folder,entry.name);if(entry.isDirectory())walk(full);else if(/\.(?:js|cjs|mjs)$/.test(entry.name))add(full);}};
 for(const relative of ['src','electron']){const folder=path.join(workspace,relative);if(fs.existsSync(folder))walk(folder);}
 for(const entry of fs.readdirSync(path.join(project,'tools'),{withFileTypes:true}))if(entry.isFile()&&/\.(?:cjs|mjs)$/.test(entry.name))add(path.join(project,'tools',entry.name));
 for(const file of [__filename,path.join(__dirname,'check_production_local.ps1')])add(file);
 return [...rows.values()].sort((a,b)=>a.file.localeCompare(b.file));
}
function prepare({stage,server,serverSha}){
 stage=path.resolve(stage);server=path.resolve(server);
 if(!inside(workspace,stage)||fs.existsSync(stage))throw Error('Fresh owned stage below workspace required');
 if(!/^[a-f0-9]{64}$/.test(serverSha)||fileHash(server)!==serverSha)throw Error('Reviewed server descriptor SHA differs');
 const facts=read(server);
 if(facts.port!==5122||facts.module!=='BaseReuse2'||facts.moduleSha256!==MODULE_SHA||facts.publicAllowed!==false||facts.natPunchDisabled!==true||facts.udpOwned!==true||!Number.isSafeInteger(facts.pid)||facts.pid<=0||!/^\d{18}$/.test(facts.creationUtcTicks??''))throw Error('Reviewed existing BaseReuse2 identity is unavailable');
 for(const [file,sha]of [[facts.executable,facts.sha256],[facts.moduleFile,facts.moduleSha256]])if(fileHash(file)!==sha)throw Error('Reviewed existing server/module bytes differ');
 const settings=path.join(facts.home,'settings.tml');
 const sources=sourceFiles(),protocol=protocolPins(),renderer=path.join(stage,'project');
 const origin=provenance.sourceIdentity(project);
 for(const argv of Object.values(variants))flags.validateHostOptions(argv,project);
 const runtimePins={control:pin(path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe')),candidate:pin(path.join(project,'.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/build-1793998835313/binaries/godot.windows.template_release.x86_64.exe')),node:pin(process.execPath),electron:pin(path.join(workspace,'node_modules/electron/dist/electron.exe'))};
 if(runtimePins.control.sha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'||runtimePins.candidate.sha256!=='62f54a7f7ff4638987730a246833cea4054779e7cb2a333bb5921fd5b0aea6dc')throw Error('Reviewed ordinary/verified executable differs');
 const copied=[];
 for(const row of sources){let bytes=fs.readFileSync(path.join(project,row.relative));if(hash(bytes)!==row.sha256)throw Error('Current source changed while preparing');let edits=[];
  if(row.relative==='native_session_world.gd'){let text=bytes.toString('utf8');const crlf=text.includes('\r\n');text=text.replaceAll('\r\n','\n');for(const patch of nativeOverlays){text=exact(text,patch.before,patch.after,patch.name);edits.push(patch.name);}bytes=Buffer.from(crlf?text.replaceAll('\n','\r\n'):text);}
  const target=path.resolve(renderer,row.relative);if(!inside(stage,target))throw Error('Copied literal dependency escaped owned stage');write(target,bytes);copied.push({...row,copySha256:hash(bytes),edits});
 }
 const hostOriginal=path.join(project,'tools/native-session-host.cjs'),bootstrapOriginal=path.join(project,'tools/native-session-bootstrap.cjs');
 const wrapperPins=[];
 function wrapper(kind,original,transform){const raw=fs.readFileSync(original,'utf8');let text=raw.replaceAll('\r\n','\n');const changes=[];const patch=(before,after,label)=>{text=exact(text,before,after,label);changes.push({label,before,after,count:1});};patch.all=(before,after,label)=>{const count=text.split(before).length-1;if(count<1)throw Error('Guarded production seam is absent: '+label);text=text.replaceAll(before,after);changes.push({label,before,after,count});};transform(patch);
  let restored=text;for(const change of [...changes].reverse()){if(restored.split(change.after).length!==change.count+1)throw Error('Reverse wrapper seam differs: '+change.label);restored=restored.replaceAll(change.after,change.before);}if(restored!==raw.replaceAll('\r\n','\n'))throw Error('Wrapper does not roundtrip to current production');
  text='const __authoritative=require('+JSON.stringify(__filename)+').context('+JSON.stringify(path.join(stage,'plan.json'))+');\n'+text;new vm.Script(text,{filename:original});
  const after=path.join(stage,kind+'.after.cjs'),file=path.join(stage,kind+'-wrapper.cjs');write(after,text);
  const code='const fs=require("node:fs"),crypto=require("node:crypto"),Module=require("node:module"),path=require("node:path");\nconst original='+JSON.stringify(original)+';\nif(crypto.createHash("sha256").update(fs.readFileSync(original)).digest("hex")!=='+JSON.stringify(fileHash(original))+')throw Error("Current production owner changed");\nconst owner=new Module(original,module);owner.filename=original;owner.paths=Module._nodeModulePaths(path.dirname(original));owner._compile(fs.readFileSync('+JSON.stringify(after)+',"utf8"),original);\n';new vm.Script(code);write(file,code);wrapperPins.push({kind,original:pin(original),after:pin(after),wrapper:pin(file),changes,roundtripExact:true,syntaxChecked:true});
 }
 wrapper('host',hostOriginal,patch=>{
  patch('actionCheck?5125:5121;','actionCheck?5125:__authoritative.server.port;','owned-local-port');
  patch(" if(scriptFloatingOwned)policy.allowed.delete('127.0.0.1:5121');"," if(localCheck){policy.allowed.clear();policy.allowed.add('127.0.0.1:'+__authoritative.server.port);}\n if(scriptFloatingOwned)policy.allowed.delete('127.0.0.1:5121');",'loopback-only-policy');
  patch("path.join(root,actionCheck?'runtime-logs/native-playability-actions-server/logs/nwengineLog.txt':'runtime-logs/local-multiplayer-server/logs/nwengineLog.txt')","path.join(__authoritative.server.home,'logs/nwengineLog.txt')",'authoritative-log');
  patch(" let savedKey=startup.cdKey??'';delete startup.cdKey;"," startup.userDirectory=__authoritative.clientDirectory;startup.settingsDirectory=__authoritative.hostSettingsDirectory;\n let savedKey=startup.cdKey??'';delete startup.cdKey;",'isolated-client-data');
  patch("['--path',project]","['--path',__authoritative.rendererProject]",'same-current-renderer-copy');
  patch.all("path.join(project,'reports',","path.join(__authoritative.runDirectory,'reports',",'all-isolated-owned-report-outputs');
  patch("env:{...process.env,...renderConfiguration.environment}","env:{...process.env,...renderConfiguration.environment,APPDATA:__authoritative.appData,LOCALAPPDATA:__authoritative.localAppData}",'native-only-userdata');
  patch("rawPending=null;}return;}\n  if(message.kind==='finished')","rawPending=null;if(localStreamAbort&&!report.localAbortedCycles?.length&&message.generation===session?.areaGeneration&&report.rawWorldUpdates?.full===1){report.localAbortedCycles=[{connection:lobby.connection,generation:session.areaGeneration,nativeProcessId:native.pid,state:{area_id:session.world.areaId},trigger:'first-scoped-raw-world-ack-before-playable',nativeReceiptRequired:true}];lastRetiredConnection=lobby.connection;localCycleEnding=true;send({kind:'probe-session-disconnect',generation:session.areaGeneration,areaId:session.world.areaId,pendingStreamProbe:true});}}return;}\n  if(message.kind==='finished')",'accepted-v4-first-scoped-ack-abort');
  patch(' startupFeatureManifest=featureManifest.createStartupManifest('," nativeArgs.push('--private-pending-abort=true','--entity-api-rest=false','--prepared-cache='+__authoritative.preparedCache);nativeArgs.splice(nativeArgs.indexOf('--'),0,'--audio-driver','Dummy');__authoritative.assertNative(nativeArgs,executable);report.authoritativeLocalHarness=__authoritative.evidence;\n startupFeatureManifest=featureManifest.createStartupManifest(",'bounded-local-native-guard');
 });
 wrapper('bootstrap',bootstrapOriginal,patch=>{
  patch("[path.join(__dirname,'native-session-host.cjs'),...args]",'['+JSON.stringify(path.join(stage,'host-wrapper.cjs'))+',...args]','same-protected-broker-current-host');
  patch("const child=spawn('node',","const child=spawn(__authoritative.nodeExecutable,",'pinned-current-node-child');
 });
 const plan={version:1,kind:'current-production-authoritative-local-preparation',stage,project,workspace,rendererProject:renderer,server:{...facts},serverDescriptor:pin(server),serverSettings:pin(settings),source:{identity:origin.sha256,files:sources},copied,protocol,runtimes:runtimePins,wrappers:wrapperPins,variants,common,authentication:'saved-protected-broker',nativeOverlays,scope:'Current production source with declared copied test-only scoped-abort telemetry; original local server/protected broker. No launch, build, server control, key read, visual/FPS/cache-use acceptance.',preparedAt:new Date().toISOString()};
 if(provenance.sourceIdentity(project).sha256!==origin.sha256||protocol.some(row=>fileHash(row.file)!==row.sha256))throw Error('Current source changed during preparation; incomplete stage preserved');
 writeJSON(path.join(stage,'plan.json'),plan);return {prepared:true,plan:path.join(stage,'plan.json'),sha256:fileHash(path.join(stage,'plan.json')),source:origin.sha256,serverDescriptorSha256:serverSha,engineStarts:0,connections:0,serverStarts:0,keyReads:0};
}
function verify(planFile,expected){if(!/^[a-f0-9]{64}$/.test(expected??'')||fileHash(planFile)!==expected)throw Error('Reviewed plan SHA differs');const plan=read(planFile);if(plan.version!==1||plan.kind!=='current-production-authoritative-local-preparation'||plan.server.port!==5122||plan.server.moduleSha256!==MODULE_SHA)throw Error('Plan identity differs');
 for(const row of plan.source.files)if(fileHash(path.join(plan.project,row.relative))!==row.sha256)throw Error('Current production source changed: '+row.relative);
 for(const row of plan.copied)if(fileHash(path.join(plan.rendererProject,row.relative))!==row.copySha256)throw Error('Copied renderer changed: '+row.relative);
 for(const row of [...plan.protocol,...Object.values(plan.runtimes),plan.serverDescriptor,plan.serverSettings])if(fileHash(row.file)!==row.sha256)throw Error('Input identity changed: '+path.basename(row.file));
 for(const entry of plan.wrappers)for(const row of [entry.original,entry.after,entry.wrapper])if(fileHash(row.file)!==row.sha256)throw Error('Current owner/wrapper changed');
 if(fileHash(plan.server.moduleFile)!==MODULE_SHA||fileHash(plan.server.executable)!==plan.server.sha256)throw Error('Original server/module bytes changed');return plan;
}
function context(planFile){const expected=process.env.NWN_LOCAL_HARNESS_PLAN_SHA,variant=process.env.NWN_LOCAL_HARNESS_VARIANT,run=process.env.NWN_LOCAL_HARNESS_RUN,plan=verify(planFile,expected);if(!Object.hasOwn(plan.variants,variant??'')||!/^native-production-local-[a-z0-9-]{1,48}$/.test(run??''))throw Error('Owned local intent is unavailable');const runDirectory=path.join(plan.stage,'runs',run),intent=read(path.join(runDirectory,'intent.json'));if(intent.planSha256!==expected||intent.variant!==variant||intent.authentication!=='saved-protected-broker'||intent.serverPid!==plan.server.pid)throw Error('Owned local intent differs');const allowed=new Set([...plan.variants[variant],'--run='+run]);if(process.argv.slice(2).length!==allowed.size||process.argv.slice(2).some(argument=>!allowed.has(argument)))throw Error('Owned broker arguments differ');
 const paths=Object.fromEntries(['clientDirectory','hostSettingsDirectory','appData','localAppData','preparedCache'].map((key,i)=>[key,path.join(runDirectory,['client','host-settings','godot-appdata','godot-localappdata','prepared'][i])]));for(const directory of Object.values(paths))if(!fs.statSync(directory).isDirectory())throw Error('Owned runtime directory is unavailable');
 return {...paths,server:plan.server,runDirectory,rendererProject:plan.rendererProject,nodeExecutable:plan.runtimes.node.file,evidence:{planSha256:expected,variant,currentSource:plan.source.identity,rendererProject:plan.rendererProject,authentication:'saved-protected-broker',nativeOverlays:plan.nativeOverlays.map(row=>row.name),serverPid:plan.server.pid,serverPort:5122,headless:true,performanceAccepted:false,visualAccepted:false},assertNative:(args,executable)=>{const selected=plan.runtimes[variant];if(path.resolve(executable)!==selected.file||fileHash(executable)!==selected.sha256||!args.includes('--headless')||args[args.indexOf('--path')+1]!==plan.rendererProject||args[args.indexOf('--script')+1]!=='res://native_session_world.gd')throw Error('Actual native executable/entry/headless scope differs');for(const flag of ['--private-pending-abort=true','--entity-api-rest=false','--prepared-cache='+paths.preparedCache])if(args.filter(value=>value===flag).length!==1)throw Error('Native probe/isolation selection differs');}};
}
function analyze(planFile,expected,run){const plan=verify(planFile,expected),folder=path.join(plan.stage,'runs',run);const owner=read(path.join(folder,'owner.json')),host=read(path.join(folder,'reports',run+'.json')),native=read(path.join(folder,'reports',run+'.native.json')),startup=read(path.join(folder,'reports',run+'.startup.json'));const variant=owner.variant,requested=flags.resolvePerformanceOptions(plan.variants[variant]).requested,cycles=host.localCycles??[],aborts=host.localAbortedCycles??[],retired=native.world_retirement??{},final=native.world??native.last_world?.world??{};
 const abortProof=aborts.map(row=>(native.session_disconnect_probes??[]).filter(probe=>probe.connection===row.connection&&probe.generation===row.generation&&probe.area_id===row.state?.area_id));
 const checks={ownerAccepted:owner.closed===true&&owner.exit===0&&!owner.timedOut,hostAccepted:host.success===true,nativeAccepted:native.success===true&&native.gameplay_success===true&&native.clean_exit===true,sourceStable:owner.sourceUnchanged===true,serverStable:owner.serverPreserved===true,localhostOnly:host.publicConnections===0,twoCompletedJoins:cycles.length===2&&cycles.every(row=>row.state?.ready===true&&row.state.pending_batches===0),sameProcess:cycles.length===2&&aborts.length===1&&new Set([...cycles,...aborts].map(row=>row.nativeProcessId)).size===1,authoritativeMovement:cycles.length===2&&cycles.every(row=>row.nativeDistance>0.2&&row.serverDistance>0.2&&row.serverDistance<2&&Math.abs(row.nativeDistance-row.serverDistance)<0.01),fullDelta:host.rawWorldUpdates?.full>=3&&host.rawWorldUpdates?.delta>0,scopedRealPendingAbort:abortProof.length===1&&abortProof[0].length===1&&abortProof[0][0].private_pending_probe===true&&abortProof[0][0].pending_batches>0,staleScopes:(native.stale_input_probes??0)===2&&(native.stale_session_messages??0)>=8&&(host.retiredCommands??[]).filter(row=>row.kind==='walk').length===2,retirement:retired.retired===2&&retired.released===2&&retired.pending_workers===0&&retired.pending_worlds===0&&retired.forced_drains===0,drain:native.workers_remaining===0&&native.protocol_finish_ack===true,startupObserved:startup.verification?.status==='observed'&&startup.worldVerification?.status==='observed',actualCollision:cycles.length===2&&cycles.every(row=>row.state.drive_collision_configuration?.effective===requested['drive-collision'].value),actualLightInputs:cycles.length===2&&cycles.every(row=>row.state.focus_lighting?.light_input_registry?.effective===requested['light-input-registry'].value),profilingOff:startup.nativeStartup?.presentation?.detailed_profiling===false,errorsEmpty:(host.diagnostics??[]).length===0&&(final.errors??[]).length===0&&Object.keys(final.failed_objects??{}).length===0&&!/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m.test(host.engineErrors??''),noServerControl:owner.serverStarts===0&&owner.processesStopped===0&&owner.builds===0};
 checks.completeWorldPopulation=cycles.length===2&&cycles.every(row=>row.state.entities+row.state.hidden===row.state.desired);
 checks.actualOwnerScope=cycles.length===2&&cycles.every(row=>row.state.drive_collision_configuration?.scope?.generation===row.generation&&row.state.drive_collision_configuration.scope.area_id===row.areaId);
 checks.basePopulationResolved=cycles.length===2&&cycles.every(row=>{const base=row.state.base_scenery;return base?.expected>=128&&base.resolved===base.expected&&base.failed===0&&base.unknown_placeables===0;});
 checks.finalProfilingOff=native.presentation_state?.detailed_profiling===false;
 const removed=host.rawWorldUpdates?.removed;const result={version:1,functionalAccepted:Object.values(checks).every(Boolean),checks,variant,source:plan.source.identity,planSha256:expected,serverRemoval:{count:Number.isSafeInteger(removed)?removed:null,status:Number.isSafeInteger(removed)&&removed>0?'DELIVERED_REMOVAL_OBSERVED':'UNEXERCISED_NO_SERVER_REMOVAL_PROOF'},fullDelta:host.rawWorldUpdates,cycles:cycles.map(row=>({connection:row.connection,generation:row.generation,areaId:row.areaId,nativeProcessId:row.nativeProcessId,nativeDistance:row.nativeDistance,serverDistance:row.serverDistance,collision:row.state.drive_collision_configuration,lighting:row.state.focus_lighting?.light_input_registry})),abortProof,retirement:retired,cache:final.pool?.native_draw_cache??null,scope:'Original local server functional/current-owner correctness only. Server removals are separately explicit if absent. No GPU, visual, FPS, disk-cache-hit or online acceptance.'};writeJSON(path.join(folder,'analysis.json'),result);return result;
}
module.exports={prepare,verify,context,analyze};
if(require.main===module){const [mode,...raw]=process.argv.slice(2),args={};for(const value of raw){const match=/^--([a-z-]+)=(.+)$/.exec(value);if(!match||Object.hasOwn(args,match[1]))throw Error('Use unique --name=value arguments');args[match[1]]=match[2];}const allowed={prepare:['stage','server','server-sha'],verify:['plan','plan-sha'],analyze:['plan','plan-sha','run']}[mode];if(!allowed||Object.keys(args).some(key=>!allowed.includes(key))||allowed.some(key=>!args[key]))throw Error('Use explicit prepare, verify or analyze inputs; no launch mode exists');let result;if(mode==='prepare')result=prepare({stage:args.stage,server:args.server,serverSha:args['server-sha']});else if(mode==='verify'){const plan=verify(args.plan,args['plan-sha']);result={verified:true,source:plan.source.identity,engineStarts:0,connections:0};}else result=analyze(args.plan,args['plan-sha'],args.run);console.log(JSON.stringify(result,null,2));if(mode==='analyze'&&!result.functionalAccepted)process.exitCode=1;}
