'use strict';
// App-code provenance and startup evidence, never game assets or credential files.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function sourceIdentity(project){
 const rows=[];
 const allowed=/\.(?:gd|gdshader|gdshaderinc|tscn|tres|json|gdextension)$/;
 const visit=(relative)=>{
  for(const entry of fs.readdirSync(path.join(project,relative),{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))){
   const name=path.posix.join(relative.replaceAll('\\','/'),entry.name);
   if(entry.isSymbolicLink()||entry.name.startsWith('.'))continue;
   if(entry.isDirectory())visit(name);
   else if(allowed.test(entry.name))rows.push({file:name,sha256:digest(fs.readFileSync(path.join(project,name)))});
  }
 };
 for(const root of ['systems','tools/native_parity'])if(fs.existsSync(path.join(project,root)))visit(root);
 for(const entry of fs.readdirSync(project,{withFileTypes:true}))if(entry.isFile()&&(allowed.test(entry.name)||entry.name==='project.godot'))rows.push({file:entry.name,sha256:digest(fs.readFileSync(path.join(project,entry.name)))});
 for(const name of ['join-native.ps1','tools/native-session-host.cjs','tools/native-session-bootstrap.cjs','tools/native-client-flags.cjs','tools/native-feature-manifest.cjs','tools/native-loading-pipeline.cjs','tools/native-render-configuration.cjs','tools/native-performance-runtime.cjs','tools/native-engine-runtime.cjs','native/particle_kernel.gdextension','native/resource_index.gdextension','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-resource-index/nwn-resource-index.dll'])if(fs.existsSync(path.join(project,name)))rows.push({file:name,sha256:digest(fs.readFileSync(path.join(project,name)))});
 rows.sort((a,b)=>a.file.localeCompare(b.file));
 return {sha256:digest(Buffer.from(JSON.stringify(rows))),files:rows,scope:'Current Godot root/systems/native-parity source and launch/native-library inputs. Excludes original assets, server content, credentials, user settings and test-only source; not a whole-repository signature.'};
}
function createStartupManifest({run,project,runtime,options,renderConfiguration,engineAndNativeArguments}){
 return {version:1,run,created:new Date().toISOString(),registry:structuredClone(options.registry),requested:structuredClone(options.requested),renderCore:options.renderCore?structuredClone(options.renderCore):null,runtime:structuredClone(runtime),project:path.resolve(project),source:sourceIdentity(project),renderConfiguration:structuredClone(renderConfiguration),arguments:engineAndNativeArguments.map(value=>value.startsWith('--ticket=')?'--ticket=<private>':value),nativeStartup:null,worldSelections:null,verification:{status:'awaiting-native-observation',errors:[]},scope:'Configuration/provenance and observed capability/owner evidence only. No performance or visual acceptance.'};
}
function verifyNativeObservation(manifest,observation,{requireObservedThread=false}={}){
 const errors=[];
 if(!observation||observation.version!==1||observation.valid!==true){errors.push('Native feature observation is missing or invalid');return {status:'rejected',errors};}
 if(observation.registry?.sha256!==manifest.registry.sha256)errors.push('Native feature registry differs from launcher registry');
 if(path.resolve(observation.executable??'').toLowerCase()!==path.resolve(manifest.runtime.executable).toLowerCase())errors.push('Observed native executable differs from selected executable');
 const requested=manifest.requested;
 if(manifest.renderCore){
  const actual=observation.render_core;
  if(!actual||JSON.stringify(actual.flags)!==JSON.stringify(manifest.renderCore.flags))errors.push("Actual accepted render-core flags differ from the selected bundle");
  if(manifest.renderCore.enabled&&manifest.runtime.executableSha256!==manifest.renderCore.engineSha256)errors.push("Accepted render-core engine differs from selected executable");
 }
 for(const name of ['drive-collision','light-input-registry'])if(observation.parsed_native_options?.[name]?.value!==requested[name].value)errors.push('Native option was not applied: '+name);
 const snapshotPolicy=requested['world-snapshot-preparation'];
 if(snapshotPolicy){
  if(observation.parsed_native_options?.['world-snapshot-preparation']?.value!==snapshotPolicy.value)errors.push('Native option was not applied: world-snapshot-preparation');
  // Workers must never be inferred from a parsed option. Normal Session
  // observations also carry the replay/live FOV policy; generic non-Session
  // script fixtures can omit this Session-only owner diagnostic.
  const actual=observation.snapshot_preparation,sessionObservation=observation.presentation&&Object.hasOwn(observation.presentation,'replay_fov_policy');
  if(snapshotPolicy.value==='workers'||actual!==undefined||sessionObservation){
   if(!actual||actual.requested!==snapshotPolicy.value||actual.enabled!==(snapshotPolicy.value==='workers')||!actual.diagnostic||typeof actual.diagnostic!=='object'||Array.isArray(actual.diagnostic))errors.push('Actual world snapshot preparation is missing or differs from requested policy');
  }
 }
 const thread=observation.rendering?.render_thread_requirement;
 const allowedThreadStates=['not-requested','headless-not-a-gpu-thread-proof','pending','matched','mismatch'];
 if(!allowedThreadStates.includes(thread))errors.push('Native render-thread requirement evidence is missing or unknown');
 if(thread==='mismatch')errors.push('Actual render thread differs from requested mode');
 if(requireObservedThread&&requested['render-thread'].value!=='default'&&thread==='pending')errors.push('Requested render thread has not been observed');
 const threadInfo=observation.rendering?.render_thread;
 if(thread==='headless-not-a-gpu-thread-proof'&&observation.rendering?.display!=='headless')errors.push('Headless thread limitation is invalid for a graphical runtime');
 if(thread==='matched'){
  if(threadInfo?.observed!==true||!Number.isSafeInteger(threadInfo.thread_id)||!Number.isSafeInteger(threadInfo.main_thread_id)||typeof threadInfo.separate!=='boolean'||threadInfo.separate!==(threadInfo.thread_id!==threadInfo.main_thread_id))errors.push('Actual render-thread ID evidence is missing or inconsistent');
  else if(threadInfo.separate!==(requested['render-thread'].value==='separate'))errors.push('Observed render thread does not satisfy the requested mode');
 }
 if(requested['light-input-registry'].value==='builtin'&&observation.capabilities?.light_input_registry?.available!==true)errors.push('Requested native light input registry is unavailable');
 for(const expected of manifest.runtime.expectedCapabilities??[]){
  const actual=observation.capabilities?.classes?.[expected.class];
  if(!actual?.present){errors.push('Selected engine capability is absent: '+expected.class);continue;}
  if(expected.instantiable===true&&!actual.instantiable)errors.push('Engine capability is not instantiable: '+expected.class);
  if(expected.parent==='RefCounted'&&!actual.ref_counted)errors.push('Engine capability parent differs: '+expected.class);
  for(const method of expected.methods??[]){const observed=actual.methods?.[method.name];if(!observed||observed.arguments!==method.arguments||method.static!==undefined&&observed.static!==method.static||method.returns==='Dictionary'&&observed.return_type!==27)errors.push('Engine capability method differs: '+expected.class+'.'+method.name);}
  for(const [method,wanted]of Object.entries(expected.abiVersions??{}))if(actual.abi_versions?.[method]!==wanted)errors.push('Selected engine ABI differs: '+expected.class+'.'+method);
 }
 const profile=requested['detailed-profiling']?.value;
 if(profile&&profile!=='saved'&&observation.presentation?.detailed_profiling!==(profile==='on'))errors.push('Actual detailed profiling is missing or differs from requested policy');
 return {status:errors.length?'rejected':thread==='pending'?'pending':'observed',errors};
}
function worldSelection(state,scope){
 const light=state.focus_lighting?.light_input_registry;
 return {scope:structuredClone(scope),collision:state.drive_collision_configuration?structuredClone(state.drive_collision_configuration):{effective:'unavailable',reason:'No collision owner observation supplied'},renderCoreCounters:light?.render_core_counters?structuredClone(light.render_core_counters):null,lighting:light?structuredClone(light):{effective:'unavailable',reason:'No lighting input owner observation supplied'},modelConstruction:state.pool?.template_construction?structuredClone(state.pool.template_construction):null,cache:state.pool?.native_draw_cache?structuredClone(state.pool.native_draw_cache):null};
}
function verifyWorldSelection(manifest,selection){
 const errors=[];
 if(selection.collision.effective!==manifest.requested['drive-collision'].value)errors.push('Actual collision owner differs from requested route');
 if(selection.lighting.effective!==manifest.requested['light-input-registry'].value)errors.push('Actual light-input owner differs from requested route');
 if(manifest.renderCore?.typed){
  const typed=selection.lighting.typed_reader;
  if(!typed||!Number.isSafeInteger(typed.plain_claims)||typed.plain_claims<1||!Number.isSafeInteger(typed.plain_rows)||typed.plain_rows<0)errors.push('Actual typed light enrollment/use evidence is unavailable');
  if(!selection.renderCoreCounters||typeof selection.renderCoreCounters.available!=='boolean')errors.push('Accepted render-core cold actual-use counters are unavailable');
 }
 return {status:errors.length?'rejected':'observed',errors};
}
function verifyAcceptedBundleUse(renderCore,actual,{requireBusyUse=true}={}){
 const errors=[],features={};
 if(!renderCore||!actual)return {status:'rejected',errors:['Accepted normal bundle evidence is missing'],features};
 if(JSON.stringify(actual.flags)!==JSON.stringify(renderCore.flags))errors.push('Actual normal bundle flags differ');
 if(!renderCore.enabled)return {status:errors.length?'rejected':'observed',errors,features,scope:'Conservative bundle disabled; no optimized work is inferred'};
 if(actual.diagnostics?.profiling!==false||actual.diagnostics?.pacing?.enabled!==false||actual.particle_setup?.enabled!==false||actual.particle_setup?.coarse_phases!==false||actual.particle_setup?.scheduled_clock_pairs!==0)errors.push('Normal bundle diagnostic timers must remain OFF');
 const flags=renderCore.flags,engine=actual.engine_features??{},light=actual.light_inputs??{},boundary=actual.particle_boundary?.boundary??actual.particle_boundary,setup=actual.particle_setup??{},hot=actual.hot_parameters?.owners??[];
 const requireUse=(flag,name,value)=>{if(flags.includes(flag)){features[name]=value===true;if(requireBusyUse&&value!==true)errors.push('Actual accepted normal feature work was not observed: '+name);}};
 requireUse('--particle-scene-boundary=native','sceneBoundary',boundary?.eligibility_reads>0);
 requireUse('--particle-scene-direct=pod','directScene',boundary?.direct_enabled===true&&boundary?.direct_eligibility_calls>0&&boundary?.direct_pose_reads>0);
 requireUse('--particle-setup-boundary=bound','setupBoundary',setup.setup_boundary===true&&setup.animating_key_binds>0&&setup.static_noncallable_uses+setup.static_null_callable_uses>0);
 requireUse('--particle-hot-parameters=bound','hotFields',hot.some(owner=>owner.enabled===true&&(owner.fields??[]).some(field=>field.reads>0&&field.hits>0)));
 const visibility=engine.visibility_chain_cache;
 requireUse('--visibility-chain-cache=epochs','visibilityCache',visibility?.enabled===true&&visibility?.disabled===false&&visibility?.queries>10000&&visibility?.hits+visibility?.ancestor_hits>10000);
 requireUse('--light-input-read=typed','typedLight',light.plain_claims>0&&light.plain_rows>0&&light.plain_field_reads>0);
 requireUse('--light-input-proof=segments','segmentedLight',light.plain_segment_proofs>0&&light.plain_segment_reuses>0);
 requireUse('--light-pair-layer-repair=exact','layerRepairPrerequisite',flags.includes('--light-pair-filter=consumers')&&engine.light_filter_passes>0);
 requireUse('--light-pair-filter=consumers','lightFilter',engine.light_excluded>0&&engine.light_filter_passes>0);
 requireUse('--pair-record-reuse=exact','pairReuse',engine.pair_reused>0&&engine.pair_reuse_passes>0);
 requireUse('--rig-skin-publisher=native','rigSkin',(actual.skin_owners??[]).some(owner=>owner.totals?.completed>0));
 requireUse('--skeleton-force-pass=once','skeletonForce',engine.skeleton_force_once?.stable_calls>0&&engine.skeleton_force_once?.avoided_offsets>0);
 requireUse('--particle-resident-text=borrow','residentTextBorrow',actual.resident_text?.borrowed===true&&actual.resident_text?.borrowed_reads>0);
 requireUse('--particle-empty-clips=skip','emptyClipLookup',(actual.empty_clips?.owners??[]).some(owner=>owner.configured===true&&owner.enabled===true&&owner.map_sealed===true&&owner.configure_depth===0&&owner.copied_channel_count===0&&owner.lookup_skips>0));
 requireUse('--light-dictionary-read=single','singleDictionaryRead',light.dictionary_single_requested===true&&light.dictionary_single_reads>0);
 requireUse('--light-input-lifetime=guarded','lightLifetimeGuard',light.lifetime_guard_requested===true&&light.lifetime_staged_rows>0&&light.lifetime_post_checks>0);
 requireUse('--light-member-read=indices','lightMemberIndices',light.plain_member_index_requested===true&&light.plain_member_index_active===true&&light.plain_member_index_reads>0&&light.plain_member_index_proofs>0);
 return {status:errors.length?'rejected':'observed',errors,features,requireBusyUse,scope:requireBusyUse?'Final heavy-world acceptance; every selected route needs observed work':'Capabilities and selected modes only; zero work in an empty/unsupported cohort is not an admission failure'};
}

module.exports={sourceIdentity,createStartupManifest,verifyNativeObservation,worldSelection,verifyWorldSelection,verifyAcceptedBundleUse};
