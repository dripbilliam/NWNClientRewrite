'use strict';
// Source-only fixture factory. No game assets, credentials, engine launch or build.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const project = path.resolve(__dirname, '../..');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const read = file => fs.readFileSync(file);
const json = file => JSON.parse(read(file));
const safe = name => typeof name === 'string' && name && !path.isAbsolute(name) && !name.split(/[\\/]/).some(p=>!p||p==='.'||p==='..');
function target(root, relative) {
  if (!safe(relative)) throw Error('Unsafe relative source: ' + relative);
  const file = path.resolve(root, relative);
  if (path.relative(root,file).startsWith('..')) throw Error('Source escaped input');
  return file;
}
function put(root, relative, bytes) {
  const file = target(root, relative);fs.mkdirSync(path.dirname(file),{recursive:true});
  fs.writeFileSync(file,bytes);return {file:relative,bytes:bytes.length,sha256:sha(bytes)};
}
function once(text, needle, replacement) {
  if (text.split(needle).length!==2) throw Error('Wrapper anchor is missing or ambiguous: '+needle);
  return text.replace(needle,replacement);
}
function wrappers(bytes, proposalBytes) {
  const original=bytes.toString('utf8'),eol=original.includes('\r\n')?'\r\n':'\n';
  const proposal=proposalBytes.toString('utf8').replaceAll('\r\n','\n');
  const constants=proposal.slice(proposal.indexOf('const ReceivedSnapshotCommit='),proposal.indexOf('\n\nAdd before receive')).trim().replaceAll('\n',eol)+eol;
  const delegates=proposal.slice(proposal.indexOf('func begin_received_snapshot('),proposal.indexOf('\n\nFirst line in begin_retirement')).trim().replaceAll('\n',eol)+eol;
  if (!constants.startsWith('const ReceivedSnapshotCommit=') || !delegates.startsWith('func begin_received_snapshot(')) throw Error('Unexpected reviewed wrapper proposal');
  const anchor='var _boundary_received_metadata: Dictionary={}'+eol;
  let output=once(original,anchor,anchor+constants);
  output=once(output,'func receive(objects: Array,controlled: int) -> void:'+eol,delegates+'func receive(objects: Array,controlled: int) -> void:'+eol);
  for(const name of ['begin_retirement','close'])output=once(output,`func ${name}() -> void:${eol}`,`func ${name}() -> void:${eol}\tcancel_received_snapshot()${eol}`);
  let inverse=output.replace(constants,'').replace(delegates,'');
  for(const name of ['begin_retirement','close'])inverse=once(inverse,`func ${name}() -> void:${eol}\tcancel_received_snapshot()${eol}`,`func ${name}() -> void:${eol}`);
  if(inverse!==original)throw Error('Thin wrapper inverse differs from exact reviewed pre62 source');
  return Buffer.from(output);
}
async function buildPair(label,{stage=false}={}) {
  if(!/^[a-z0-9][a-z0-9-]{0,59}$/.test(label??''))throw Error('Fresh safe pair label required');
  const base=path.join(project,'.cache/native-live-review/reviewed-arelith-b/project');
  const baselineManifestFile=path.join(base,'../manifest.json'),reviewFile=path.join(project,'.cache/nwn61/review-b/manifest.json');
  const baseline=json(baselineManifestFile),review=json(reviewFile);
  const directory=path.join(project,'.cache/nwn62/entry-pairs',label);
  if(fs.existsSync(directory))throw Error('Pair destination already exists');
  const control=path.join(directory,'control-input'),candidate=path.join(directory,'candidate-input');
  const sourceRows=baseline.files.map(row=>({row,relative:path.relative(base,row.file).replaceAll('\\','/')})).filter(item=>safe(item.relative));
  if(sourceRows.length<1000)throw Error('Reviewed source inventory unexpectedly small');
  const allowed=/\.(gd|gdshader|gdshaderinc|gdextension|tscn|tres|json|cfg|godot|ps1|cjs|exe|dll)$/;
  // Validate every source and overlay BEFORE making either new input.
  for(const item of sourceRows){
    if(!allowed.test(item.relative))throw Error('Not an application source/native file: '+item.relative);
    const bytes=read(target(base,item.relative));
    if(bytes.length!==item.row.bytes||sha(bytes)!==item.row.sha256)throw Error('Reviewed baseline changed: '+item.relative);
  }
  const overlay=review.files.filter(row=>row.file!=='systems/native_render/live_world.gd');
  const overlayBytes=new Map();
  for(const row of overlay){const bytes=read(target(project,row.file));if(bytes.length!==row.bytes||sha(bytes)!==row.sha256)throw Error('Frozen61 source changed: '+row.file);overlayBytes.set(row.file,bytes);}
  const proposal=overlayBytes.get('tools/nwn61/base-wrapper-proposal.txt');
  const baseWorld=read(path.join(base,'systems/native_render/live_world.gd')),patchedWorld=wrappers(baseWorld,proposal);
  fs.mkdirSync(directory,{recursive:true});
  const baselinePins=[];
  for(const item of sourceRows){
    const bytes=read(target(base,item.relative));
    for(const input of [control,candidate]){
      const file=target(input,item.relative);fs.mkdirSync(path.dirname(file),{recursive:true});
      if(/\.(exe|dll)$/.test(item.relative))fs.linkSync(target(base,item.relative),file);
      else fs.writeFileSync(file,bytes,{flag:'wx'});
    }
    baselinePins.push({file:item.relative,bytes:bytes.length,sha256:sha(bytes),kind:/\.(exe|dll)$/.test(item.relative)?'immutable-native-hardlink':'copied-source-bytes'});
  }
  // Selection helper is source-only staging infrastructure, excluded from the
  // application's comparable sourceIdentity; the same exact bytes go in both.
  const selectionHelper='tools/native-production-selection.cjs',helperBytes=read(path.join(project,selectionHelper));
  put(control,selectionHelper,helperBytes);put(candidate,selectionHelper,helperBytes);
  const overlayPins=[];
  for(const [relative,bytes] of overlayBytes)overlayPins.push(put(candidate,relative,bytes));
  overlayPins.push(put(candidate,'systems/native_render/live_world.gd',patchedWorld));
  const fixturePins=[];
  const fixtureRoot=path.join(project,'.cache/nwn61/baseline');
  const fixtureRows=[...json(path.join(fixtureRoot,'manifest.json')).files,...json(path.join(fixtureRoot,'renderer-manifest.json'))];
  for(const row of fixtureRows){const bytes=read(target(fixtureRoot,row.file));if(bytes.length!==row.bytes||sha(bytes)!==row.sha256)throw Error('Frozen61 original test fixture changed: '+row.file);fixturePins.push(put(candidate,'.cache/nwn61/baseline/'+row.file,bytes));}
  for(const name of ['manifest.json','renderer-manifest.json'])fixturePins.push(put(candidate,'.cache/nwn61/baseline/'+name,read(path.join(fixtureRoot,name))));
  const changed=[];
  const expectedChanges=new Set(overlayPins.map(row=>row.file));
  for(const pin of baselinePins){
    if(sha(read(target(control,pin.file)))!==pin.sha256)throw Error('Control is not byte-exact: '+pin.file);
    const candidateSHA=sha(read(target(candidate,pin.file)));
    if(candidateSHA!==pin.sha256){if(!expectedChanges.has(pin.file))throw Error('Unrelated candidate difference: '+pin.file);changed.push({file:pin.file,control_sha256:pin.sha256,candidate_sha256:candidateSHA});}
  }
  const preserved=['systems/native_data/asset_service.gd','systems/native_data/prework_store.gd','systems/network_motion.gd','systems/native_render/resource_pool.gd','systems/native_render/model_template.gd','systems/native_render/model_instance.gd','systems/native_render/native_model_recipe.gd','systems/native_render/actor_instance.gd','systems/native_render/area_stream.gd','systems/native_render/object_stream.gd','systems/native_render/creature_stream.gd','systems/model_rigs.gd','systems/native_render/skeletal_rigs.gd'];
  for(const relative of preserved)if(sha(read(target(control,relative)))!==sha(read(target(candidate,relative))))throw Error('Excluded62/70/72 source leaked into61 pair: '+relative);
  const seeds={version:1,description:'Reviewed Arelith B preference bytes, source-only61 pair; gamma1.2/FOV45/CPU particles true',expected:{gamma:1.2,particles:true,fovDegrees:45,compactScenery:true}};
  for(const [name,fileName] of [['render','native-render-preferences.cfg'],['layout','native-menu-layout.cfg']]){
    const source=path.join(base,'../working-settings',fileName),bytes=read(source);
    const file=path.join(directory,'preference-seeds',name+'.cfg');fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});seeds[name]={file,sha256:sha(bytes)};
  }
  const render=read(seeds.render.file).toString('utf8');
  if(!/^gamma=1\.2\s*$/m.test(render)||!/^fov_degrees=45(?:\.0)?\s*$/m.test(render)||!/^particles_enabled=true\s*$/m.test(render))throw Error('Reviewed preference seed does not satisfy common gamma/FOV/particles');
  const seedFile=path.join(directory,'preference-seeds.json');fs.writeFileSync(seedFile,JSON.stringify(seeds,null,2)+'\n',{flag:'wx'});
  const argv=['--performance-runtime=verified-native','--render-profile=gameplay','--detailed-profiling=off'];
  const selection=require(path.join(project,'tools/native-production-selection.cjs'));
  const configurationControl=selection.configuration(control,argv,{env:{}}),configurationCandidate=selection.configuration(candidate,argv,{env:{}});
  // The exact same pinned registry necessarily has different absolute paths
  // in the two inputs; its SHA and every resolved functional value still match.
  configurationControl.performance.registry.file='<paired-project>/systems/native_data/client_feature_registry.json';
  configurationCandidate.performance.registry.file='<paired-project>/systems/native_data/client_feature_registry.json';
  if(JSON.stringify(configurationControl)!==JSON.stringify(configurationCandidate))throw Error('Paired functional options differ');
  const identities={control:require(path.join(control,'tools/native-feature-manifest.cjs')).sourceIdentity(control),candidate:require(path.join(candidate,'tools/native-feature-manifest.cjs')).sourceIdentity(candidate)};
  const output={version:1,kind:'source-only-entry-pair',ticket:'NWN-61',created:new Date().toISOString(),directory,control,candidate,baseline:{manifest:baselineManifestFile,sha256:sha(read(baselineManifestFile)),sourceProject:base,pins:baselinePins},review61:{manifest:reviewFile,sha256:sha(read(reviewFile)),overlayPins,wrapperProof:{proposal_sha256:sha(proposal),baseline_sha256:sha(baseWorld),patched_sha256:sha(patchedWorld),inverseByteExact:true}},commonInfrastructure:{file:selectionHelper,sha256:sha(helperBytes),reason:'Identical source-only staging helper; excluded from comparable application sourceIdentity'},testOnlyOriginalFixtures:fixturePins,changedOriginalPaths:changed,assertions:{controlExactForEveryReviewedSource:true,candidateChangesRestrictedTo61:true,pre62ConstructionPreserved:true,pre70AssetWorkerPreserved:true,networkMotion72Excluded:true,thinWrapperInverseByteExact:true,noEntryBudgetExperiment:true,noOriginalAssetsCopied:true,noCredentialsCopied:true,noBuildsOrLaunches:true},preferences:{file:seedFile,sha256:sha(read(seedFile)),expected:seeds.expected},argv,identities:{control:identities.control.sha256,candidate:identities.candidate.sha256},stageCommand:`node tools/nwn62/entry-pair.cjs stage ${label}`,staged:[]};
  const manifestFile=path.join(directory,'pair.json');fs.writeFileSync(manifestFile,JSON.stringify(output,null,2)+'\n',{flag:'wx'});
  if(stage)throw Error('Use separately audited stage subcommand after source preparation');
  return {manifestFile,sha256:sha(read(manifestFile)),control,candidate,files:baselinePins.length,changed:changed.length};
}
function composeCompletionOnly(originalBytes,frozenBytes){
 const original=originalBytes.toString('utf8'),frozen=frozenBytes.toString('utf8');
 const work='func _work(job: Dictionary) -> void:',process='func _process(_delta: float) -> void:';
 checkBoundary(original,work,process);checkBoundary(frozen,work,process);
 const middle=original.slice(original.indexOf(work),original.indexOf(process));
 const result=Buffer.from(frozen.slice(0,frozen.indexOf(work))+middle+frozen.slice(frozen.indexOf(process)));
 const actual=result.toString('utf8').slice(result.toString('utf8').indexOf(work),result.toString('utf8').indexOf(process));
 if(actual!==middle)throw Error('Worker/decode middle was not byte exact');
 const functions=[];const matches=[...middle.matchAll(/^func ([a-zA-Z0-9_]+)\(/gm)];
 for(let index=0;index<matches.length;index++){const begin=matches[index].index,end=matches[index+1]?.index??middle.length;functions.push({name:matches[index][1],sha256:sha(Buffer.from(middle.slice(begin,end))),byteExactPre70:true});}
 return {bytes:result,proof:{strategy:'Frozen62service prefix + exact reviewed pre70 worker/decode middle + frozen62completion/lifecycle suffix',middleSHA256:sha(Buffer.from(middle)),functions,workerDecoderSemanticsUnchanged:true}};
}
function checkBoundary(text,work,process){if(text.split(work).length!==2||text.split(process).length!==2||text.indexOf(work)>=text.indexOf(process))throw Error('Asset service composition anchors differ');}
function privateEntryPoolSource(bytes){
 let text=bytes.toString('utf8');const end=text.indexOf('var entry_publication_budget_us:=');
 if(end<0)throw Error('Frozen private entry configuration anchor missing');
 let prefix=text.slice(0,end),at=prefix.lastIndexOf('\treturn 0\n');if(at<0)throw Error('Entry default anchor missing');
 prefix=prefix.slice(0,at)+'\tvar setting: Variant=ProjectSettings.get_setting("nwn/private/publication_entry_budget_us",0)\n\treturn clampi(int(setting),3000,12000) if setting is int and setting>0 else 0\n'+prefix.slice(at+'\treturn 0\n'.length);
 text=prefix+text.slice(end);
 const start=text.indexOf('func bind_publication_world('),finish=text.indexOf('func publication_callback_budget_us(');
 if(start<0||finish<=start)throw Error('Private world binding anchors missing');
 const helper=`var _private_entry_last_effective_us:=3000
var _private_entry_last_reason:="unobserved"
var _private_entry_activations:=0
var _private_entry_clears:=0
var _private_entry_clear_reasons: Dictionary={}
var _private_entry_history: Array=[]
var _private_entry_maximum_us:=3000
func bind_publication_world(world: Node) -> void:publication_world=weakref(world) if is_instance_valid(world) else null
func _observe_private_entry_budget(effective: int,reason: String) -> void:
\tif effective==_private_entry_last_effective_us and reason==_private_entry_last_reason:return
\tif effective>publication_budget_us and _private_entry_last_effective_us<=publication_budget_us:_private_entry_activations+=1
\tif effective<=publication_budget_us and _private_entry_last_effective_us>publication_budget_us:
\t\t_private_entry_clears+=1;_private_entry_clear_reasons[reason]=int(_private_entry_clear_reasons.get(reason,0))+1
\t_private_entry_last_effective_us=effective;_private_entry_last_reason=reason;_private_entry_maximum_us=maxi(_private_entry_maximum_us,effective)
\tif _private_entry_history.size()<16:_private_entry_history.append({"effective_us":effective,"reason":reason,"frame":Engine.get_process_frames()})
func publication_budget_limit_us() -> int:
\tvar effective:=publication_budget_us;var reason:="not-configured"
\tif entry_publication_budget_us>publication_budget_us:
\t\tvar world: Node=publication_world.get_ref() if publication_world!=null else null
\t\tif not is_instance_valid(world):reason="world-unavailable"
\t\telif world.is_queued_for_deletion():reason="queued-for-deletion"
\t\telif world.get("closed")==true:reason="world-closed"
\t\telif world.get("retiring")==true:reason="world-retiring"
\t\telif world.get_meta("native_entry_loading",false):effective=entry_publication_budget_us;reason="entry-loading"
\t\telse:reason="loading-mark-cleared"
\t_observe_private_entry_budget(effective,reason)
\treturn effective
func private_entry_budget_snapshot() -> Dictionary:
\tvar effective:=publication_budget_limit_us()
\treturn {"requested_us":entry_publication_budget_us,"project_setting_us":ProjectSettings.get_setting("nwn/private/publication_entry_budget_us",0),"ordinary_us":publication_budget_us,"effective_us":effective,"maximum_effective_us":_private_entry_maximum_us,"activations":_private_entry_activations,"clears":_private_entry_clears,"clear_reasons":_private_entry_clear_reasons.duplicate(),"last_reason":_private_entry_last_reason,"history":_private_entry_history.duplicate(true),"scope":"Pinned PRIVATE project-setting experiment; only explicit one-way new-world loading mark admits extra publication work"}
`;
 text=text.slice(0,start)+helper+text.slice(finish);
 const line=text.split('\n').find(value=>value.startsWith('\tstate.publication_budget='));if(!line)throw Error('Budget snapshot anchor missing');
 text=once(text,line+'\n',line+'\n\tstate.publication_budget.private_entry=private_entry_budget_snapshot()\n');return Buffer.from(text);
}
function projectSetting(bytes,value){
 let text=bytes.toString('utf8');if(text.includes('private/publication_entry_budget_us='))throw Error('Private setting already present');
 const eol=text.includes('\r\n')?'\r\n':'\n';
 if(text.includes('[nwn]'+eol))text=once(text,'[nwn]'+eol,'[nwn]'+eol+`private/publication_entry_budget_us=${value}`+eol);
 else text+=eol+'[nwn]'+eol+eol+`private/publication_entry_budget_us=${value}`+eol;
 return Buffer.from(text);
}
async function build62Pair(label,snapshotTag,parentLabel='entry61-pair-b',policyOnly=false){
 for(const value of [label,parentLabel])if(!/^[a-z0-9][a-z0-9-]{0,59}$/.test(value??''))throw Error('Safe fresh pair/parent labels required');
 if(!['review-small-native-v4','review-entry-experiment-v5'].includes(snapshotTag))throw Error('Only approved frozen62versions may be layered');
 const parentFile=path.join(project,'.cache/nwn62/entry-pairs',parentLabel,'pair.json'),parent=json(parentFile);verifyPair(parent);
 const snapshotFile=path.join(project,'.cache/nwn62',snapshotTag+'.json'),snapshot=json(snapshotFile),snapshotRoot=path.join(project,'.cache/nwn62',snapshotTag+'-source');
 const directory=path.join(project,'.cache/nwn62/entry-pairs',label),control=path.join(directory,'control-input'),candidate=path.join(directory,'candidate-input');
 if(fs.existsSync(directory))throw Error('Pair destination already exists');
 const expected=new Map(parent.baseline.pins.map(row=>[row.file,row.sha256]));
 expected.set(parent.commonInfrastructure.file,parent.commonInfrastructure.sha256);
 for(const row of [...parent.review61.overlayPins,...parent.testOnlyOriginalFixtures])expected.set(row.file,row.sha256);
 const frozen=new Map();for(const row of snapshot.files){const bytes=read(target(snapshotRoot,row.file));if(bytes.length!==row.bytes||sha(bytes)!==row.sha256)throw Error('Frozen62source changed: '+row.file);frozen.set(row.file,bytes);}
 // Every pre62 baseline must still be the reviewed pre61 control. This rejects
 // hidden prerequisites before applying a frozen62implementation to61.
 for(const row of snapshot.files.filter(row=>row.file.startsWith('systems/'))){const before=path.join(project,'.cache/nwn62/before',row.file),reviewed=path.join(parent.control,row.file);if(fs.existsSync(before)&&fs.existsSync(reviewed)&&sha(read(before))!==sha(read(reviewed)))throw Error('62before baseline differs from reviewed original: '+row.file);}
 fs.mkdirSync(directory,{recursive:true});const baselinePins=[];
 for(const [relative,expectedSHA]of expected){const source=target(parent.candidate,relative),bytes=read(source);if(sha(bytes)!==expectedSHA)throw Error('Audited61candidate changed: '+relative);for(const input of [control,candidate]){const file=target(input,relative);fs.mkdirSync(path.dirname(file),{recursive:true});if(/\.(exe|dll)$/.test(relative))fs.linkSync(source,file);else fs.writeFileSync(file,bytes,{flag:'wx'});}baselinePins.push({file:relative,bytes:bytes.length,sha256:expectedSHA,kind:/\.(exe|dll)$/.test(relative)?'immutable-native-hardlink':'copied-audited61-source'});}
 const service='systems/native_data/asset_service.gd',composition=composeCompletionOnly(read(target(control,service)),frozen.get(service));frozen.set(service,composition.bytes);
 const overlayPins=[];for(const [relative,bytes]of frozen)overlayPins.push(put(candidate,relative,bytes));
 const beforePins=[];const fixtureWalk=relative=>{for(const entry of fs.readdirSync(path.join(project,'.cache/nwn62/before',relative),{withFileTypes:true})){const name=path.posix.join(relative,entry.name);if(entry.isDirectory())fixtureWalk(name);else if(entry.isFile()&&name.endsWith('.gd'))beforePins.push(put(candidate,'.cache/nwn62/before/'+name,read(path.join(project,'.cache/nwn62/before',name))));}};fixtureWalk('');
 overlayPins.push(...beforePins);
 let policyProof=null;
 if(policyOnly){
  if(snapshotTag!=='review-entry-experiment-v5')throw Error('Policy pair requires identicalV5algorithm');
  // Both legs get the SAME implementation/helper. Only the pinned setting
  // differs; current root algorithms and normal project defaults stay intact.
  for(const row of overlayPins)put(control,row.file,read(target(candidate,row.file)));
  const relative='systems/native_render/resource_pool.gd',helper=privateEntryPoolSource(read(target(candidate,relative)));
  const helperControl=put(control,relative,helper),helperCandidate=put(candidate,relative,helper);overlayPins.splice(overlayPins.findIndex(row=>row.file===relative),1,helperCandidate);
  const originalProject=read(target(control,'project.godot'));
  const controlProject=put(control,'project.godot',projectSetting(originalProject,0)),candidateProject=put(candidate,'project.godot',projectSetting(originalProject,8000));overlayPins.push(candidateProject);
  const controlExpected=new Map(baselinePins.map(row=>[row.file,row]));for(const row of overlayPins)controlExpected.set(row.file,{...row,sha256:sha(read(target(control,row.file)))});controlExpected.set(relative,helperControl);controlExpected.set('project.godot',controlProject);baselinePins.splice(0,baselinePins.length,...controlExpected.values());
  for(const row of baselinePins)if(row.file!=='project.godot'&&sha(read(target(control,row.file)))!==sha(read(target(candidate,row.file))))throw Error('Policy pair algorithm source differs: '+row.file);
  policyProof={privateOnly:true,setting:'nwn/private/publication_entry_budget_us',control:0,candidate:8000,resourcePoolHelperSHA256:sha(helper),controlProjectSHA256:controlProject.sha256,candidateProjectSHA256:candidateProject.sha256,onlyProjectSettingDiffers:true,ordinaryRootProjectUnchanged:true,managedRegistryUnchanged:true,noCLIOrEnvironmentIngress:true};
 }
 const preserved61=parent.review61.overlayPins.filter(row=>row.file!=='systems/native_render/live_world.gd');
 for(const row of preserved61)if(sha(read(target(candidate,row.file)))!==row.sha256)throw Error('62overlay changed61helper/subclass/source: '+row.file);
 for(const relative of ['systems/network_motion.gd','systems/native_data/prework_store.gd'])if(sha(read(target(control,relative)))!==sha(read(target(candidate,relative))))throw Error('72/70source leaked: '+relative);
 const baseWorld=read(target(control,'systems/native_render/live_world.gd')).toString('utf8'),candidateWorld=read(target(candidate,'systems/native_render/live_world.gd')).toString('utf8');
 const wrapper=text=>text.slice(text.indexOf('func begin_received_snapshot('),text.indexOf('func receive(objects: Array,controlled: int) -> void:'));
 if(wrapper(baseWorld)!==wrapper(candidateWorld))throw Error('62overlay changed61thin receive wrappers');
 const preferencesFile=path.join(directory,'preference-seeds.json'),seeds=json(parent.preferences.file);fs.writeFileSync(preferencesFile,JSON.stringify(seeds,null,2)+'\n',{flag:'wx'});
 const changed=[];const overlaySet=new Set(overlayPins.map(row=>row.file));for(const pin of baselinePins){const actual=sha(read(target(candidate,pin.file)));if(actual!==pin.sha256){if(!overlaySet.has(pin.file))throw Error('Unexpected62source difference: '+pin.file);changed.push({file:pin.file,control_sha256:pin.sha256,candidate_sha256:actual});}}
 const identity=leg=>require(path.join(leg,'tools/native-feature-manifest.cjs')).sourceIdentity(leg).sha256;
 const output={version:1,kind:'source-only-entry-pair',ticket:'NWN-62',created:new Date().toISOString(),directory,control,candidate,baseline:{manifest:parentFile,sha256:sha(read(parentFile)),sourceProject:parent.candidate,pins:baselinePins},review62:{manifest:snapshotFile,sha256:sha(read(snapshotFile)),snapshot:snapshotTag,assetServiceCompletionOnly:composition.proof,preserved61:preserved61.map(row=>({file:row.file,sha256:row.sha256})),thin61WrappersByteExact:true},overlayPins,commonInfrastructure:parent.commonInfrastructure,testOnlyOriginalFixtures:[],changedOriginalPaths:changed,assertions:{controlExactAudited61Candidate:true,candidateChangesRestrictedToFrozen62:true,workerDecodeFunctionsByteExactPre70:true,all61HelperSubclassSourcesPreserved:true,no72GuardOrCurrentMotion:true,noCurrent65Or73Experiments:true,entryBudgetExperimentEnabled:false,ordinaryBudgetUs:3000,noOriginalAssetsCopied:true,noCredentialsCopied:true,noBuildsOrLaunches:true},preferences:{file:preferencesFile,sha256:sha(read(preferencesFile)),expected:parent.preferences.expected},argv:parent.argv,identities:{control:identity(control),candidate:identity(candidate)},stageCommand:`node tools/nwn62/entry-pair.cjs stage ${label}`,staged:[]};
 if(policyProof){output.review62.privateEntryPolicy=policyProof;output.baseline.parentSourceProject=output.baseline.sourceProject;output.baseline.sourceProject=control;output.baseline.scope='Identical frozenV5algorithm control with private helper and ordinary setting0; parent61 provenance retained';output.assertions.controlExactAudited61Candidate=false;output.assertions.candidateChangesRestrictedToFrozen62=false;output.assertions.identicalAlgorithmsOnlyProjectSettingDiffers=true;output.assertions.entryBudgetExperimentEnabled=true;}
 const file=path.join(directory,'pair.json');fs.writeFileSync(file,JSON.stringify(output,null,2)+'\n',{flag:'wx'});verifyPair(output);
 return {manifestFile:file,sha256:sha(read(file)),control,candidate,changed:changed.length,workerFunctionsPreserved:composition.proof.functions.length,snapshot:snapshotTag};
}
function verifyPair(pair){
  for(const leg of ['control','candidate']){
    const expected=new Map(pair.baseline.pins.map(row=>[row.file,row.sha256]));
    expected.set(pair.commonInfrastructure.file,pair.commonInfrastructure.sha256);
    if(leg==='candidate')for(const row of [...(pair.overlayPins??pair.review61.overlayPins),...pair.testOnlyOriginalFixtures])expected.set(row.file,row.sha256);
    for(const [relative,expectedSHA] of expected)if(sha(read(target(pair[leg],relative)))!==expectedSHA)throw Error('Prepared input changed: '+leg+'/'+relative);
    const walk=relative=>{for(const item of fs.readdirSync(path.join(pair[leg],relative),{withFileTypes:true})){
      const name=path.posix.join(relative,item.name);
      if(name==='.cache/native-presentation-parity')continue;
      if(item.isSymbolicLink())throw Error('Unexpected source symlink: '+name);
      if(item.isDirectory())walk(name);else if(!expected.has(name))throw Error('Unexpected input file: '+leg+'/'+name);
    }};walk('');
    if(require(path.join(pair[leg],'tools/native-feature-manifest.cjs')).sourceIdentity(pair[leg]).sha256!==pair.identities[leg])throw Error('Comparable input identity changed: '+leg);
  }
  if(sha(read(pair.preferences.file))!==pair.preferences.sha256)throw Error('Seed manifest changed');
  return {verified:true,identities:pair.identities,assertions:pair.assertions};
}
async function stagePair(label){
  if(!/^[a-z0-9][a-z0-9-]{0,59}$/.test(label??''))throw Error('Safe prepared pair label required');
  const file=path.join(project,'.cache/nwn62/entry-pairs',label,'pair.json'),pair=json(file);
  if(pair.staged.length||fs.existsSync(path.join(path.dirname(file),'staged.json')))throw Error('Pair already staged');
  verifyPair(pair);
  if(sha(read(path.join(project,pair.commonInfrastructure.file)))!==pair.commonInfrastructure.sha256)throw Error('Audited staging helper changed');
  const helper=require(path.join(project,'tools/native-production-selection.cjs')),seeds=json(pair.preferences.file),receipts=[];
  if(sha(read(pair.preferences.file))!==pair.preferences.sha256)throw Error('Seed manifest changed');
  for(const leg of ['control','candidate'])receipts.push(await helper.stageProductionSelection({project:pair[leg],label:`${label}-${leg}`,argv:pair.argv,preferenceSeeds:seeds,env:{}}));
  const output={pair:file,pair_sha256:sha(read(file)),selections:receipts.map(row=>({file:row.file,sha256:row.sha256,source:row.selection.sourceProject,engine:row.selection.engine})),noLaunches:true,noBuilds:true};
  fs.writeFileSync(path.join(path.dirname(file),'staged.json'),JSON.stringify(output,null,2)+'\n',{flag:'wx'});return output;
}
if(require.main===module){const [operation,label]=process.argv.slice(2);(operation==='prepare'?buildPair(label):operation==='prepare62-v4'?build62Pair(label,'review-small-native-v4'):operation==='prepare62-v5'?build62Pair(label,'review-entry-experiment-v5'):operation==='prepare62-policy'?build62Pair(label,'review-entry-experiment-v5','entry61-pair-b',true):operation==='stage'?stagePair(label):operation==='verify'&&/^[a-z0-9][a-z0-9-]{0,59}$/.test(label??'')?Promise.resolve(verifyPair(json(path.join(project,'.cache/nwn62/entry-pairs',label,'pair.json')))):Promise.reject(Error('Use prepare|prepare62-v4|prepare62-v5|verify|stage and a safe pair label'))).then(value=>console.log(JSON.stringify(value))).catch(error=>{console.error(error.stack);process.exitCode=1;});}
module.exports={buildPair,build62Pair,composeCompletionOnly,verifyPair,stagePair,wrappers};
