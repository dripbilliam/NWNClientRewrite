'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{spawnSync}=require('node:child_process');
const flags=require('../tools/native-client-flags.cjs'),proof=require('../tools/native-feature-manifest.cjs');
const project=path.resolve(__dirname,'..');
test('ordinary preserves engine and native selection; loading is independent',()=>{
 const ordinary=flags.resolvePerformanceOptions([]),streamed=flags.resolvePerformanceOptions(['--loading-pipeline=merged','--native-draw-cache=prepared']);
 assert.equal(ordinary.runtime,'standard');assert.equal(ordinary.renderThread,'default');assert.deepEqual(ordinary.engineArguments,[]);assert.deepEqual(ordinary.nativeArguments,[]);assert.deepEqual(ordinary.requested['drive-collision'],{value:'indexed',explicit:false});
 assert.deepEqual(flags.resolvePerformanceOptions(['--drive-collision=legacy']).nativeArguments,['--drive-collision=legacy']);assert.deepEqual(flags.resolvePerformanceOptions(['--drive-collision=legacy']).requested['drive-collision'],{value:'legacy',explicit:true});
 assert.deepEqual(streamed.requested,ordinary.requested);assert.deepEqual(streamed.engineArguments,[]);
});
test('explicit runtime/thread/owners reach distinct engine and native arguments',()=>{
 const result=flags.resolvePerformanceOptions(['--performance-runtime=verified-native','--render-thread=separate','--drive-collision=indexed','--light-input-registry=builtin']);
 assert.equal(result.runtime,'verified-native');assert.deepEqual(result.engineArguments,['--render-thread','separate']);assert.deepEqual(result.nativeArguments,['--drive-collision=indexed','--light-input-registry=builtin']);
 assert(Object.values(result.requested).filter(row=>row.explicit).length===4);
});
test('profile policy can explicitly override saved preferences without changing other settings',()=>{
 assert.deepEqual(flags.resolvePerformanceOptions(['--detailed-profiling=off']).nativeArguments,['--profile=false']);
 assert.deepEqual(flags.resolvePerformanceOptions(['--detailed-profiling=on']).nativeArguments,['--profile=true']);
 assert.throws(()=>flags.resolvePerformanceOptions(['--native-profile','--detailed-profiling=off']));
});
test('world snapshot preparation is a managed normal-launch selector with explicit script rollback',()=>{
 const ordinary=flags.resolvePerformanceOptions([]);
 assert.deepEqual(ordinary.requested['world-snapshot-preparation'],{value:'script',explicit:false});
 assert.deepEqual(ordinary.nativeArguments,[]);
 const definition=flags.catalogue().features.find(row=>row.name==='world-snapshot-preparation');
 assert.equal(definition.target,'native');assert.equal(definition.default,'script');assert.deepEqual(definition.choices,['script','workers']);assert.equal(definition.forwarder,'performance');assert.equal(definition.powershell,'WorldSnapshotPreparation');
 for(const value of ['script','workers']){
  const args=['--world-snapshot-preparation='+value],result=flags.resolvePerformanceOptions(args);
  assert.deepEqual(result.nativeArguments,args);assert.deepEqual(result.requested['world-snapshot-preparation'],{value,explicit:true});
  assert.equal(flags.validateHostOptions(args).values['world-snapshot-preparation'],value);
  assert.equal(flags.parseManagedOptions(args,{native:true}).values['world-snapshot-preparation'],value);
  assert.deepEqual(result.engineArguments,[]);assert.equal(result.runtime,'standard');
 }
 for(const args of [['--world-snapshot-preparation'],['--world-snapshot-preparation=worker'],['--world-snapshot-preparation=true'],['--world-snapshot-preparation=workers','--world-snapshot-preparation=script'],['--world-snapshop-preparation=workers']])assert.throws(()=>flags.validateHostOptions(args),args.join(' '));
 const combined=flags.resolvePerformanceOptions(['--world-snapshot-preparation=workers','--drive-collision=legacy','--light-input-registry=builtin','--detailed-profiling=off']);
 assert.deepEqual(combined.nativeArguments,['--drive-collision=legacy','--light-input-registry=builtin','--world-snapshot-preparation=workers','--profile=false']);
 assert.equal(flags.catalogue().features.filter(row=>row.name==='world-snapshot-preparation').length,1);
});
test('entry commit can explicitly select the synchronous comparison and rollback route',()=>{
 const ordinary=flags.resolvePerformanceOptions([]);
 assert.deepEqual(ordinary.requested['entry-commit'],{value:'staged',explicit:false});
 assert(!ordinary.nativeArguments.some(value=>value.startsWith('--entry-commit=')));
 for(const value of ['staged','sync']){
  const argument='--entry-commit='+value,selected=flags.resolvePerformanceOptions([argument]);
  assert(selected.nativeArguments.includes(argument));
  assert.deepEqual(selected.requested['entry-commit'],{value,explicit:true});
  assert.equal(flags.validateHostOptions([argument]).values['entry-commit'],value);
 }
 for(const args of [['--entry-commit'],['--entry-commit=unknown'],['--entry-commit=staged','--entry-commit=sync']])assert.throws(()=>flags.validateHostOptions(args));
});
test('entry commit budget preserves 4ms default and forwards bounded opt-in choices',()=>{
 const ordinary=flags.resolvePerformanceOptions([]);
 assert.deepEqual(ordinary.requested['entry-commit-budget'],{value:'4ms',explicit:false});
 assert(!ordinary.nativeArguments.some(value=>value.startsWith('--entry-commit-budget=')));
 for(const value of ['4ms','6ms','8ms']){
  const argument='--entry-commit-budget='+value,selected=flags.resolvePerformanceOptions([argument]);
  assert(selected.nativeArguments.includes(argument));
  assert.deepEqual(selected.requested['entry-commit-budget'],{value,explicit:true});
  assert.equal(flags.validateHostOptions([argument]).values['entry-commit-budget'],value);
 }
 for(const args of [['--entry-commit-budget'],['--entry-commit-budget=9ms'],['--entry-commit-budget=6ms','--entry-commit-budget=8ms']])assert.throws(()=>flags.validateHostOptions(args));
});
test('drive height plan is explicit and forwards to the native client',()=>{
 const row=flags.catalogue().features.find(value=>value.name==='drive-height-plan');
 assert.equal(row.default,'off');assert.deepEqual(row.choices,['off','worker']);assert.equal(row.powershell,'DriveHeightPlan');
 assert.deepEqual(flags.resolvePerformanceOptions([]).requested['drive-height-plan'],{value:'off',explicit:false});
 for(const value of ['off','worker']){
  const args=['--drive-height-plan='+value],selected=flags.resolvePerformanceOptions(args);
  assert(selected.nativeArguments.includes(args[0]));
  assert.deepEqual(selected.requested['drive-height-plan'],{value,explicit:true});
  assert.equal(flags.validateHostOptions(args).values['drive-height-plan'],value);
 }
 for(const args of [['--drive-height-plan'],['--drive-height-plan=true'],['--drive-height-plan=workers'],['--drive-height-plan=worker','--drive-height-plan=off']])assert.throws(()=>flags.validateHostOptions(args));
});
test('bad, duplicate, misspelled and research-only host options reject',()=>{
 for(const args of [['--render-thread=worker'],['--drive-collision'],['--drive-collision=indexed','--drive-collision=legacy'],['--drive-collison=indexed'],['--performance-runtime=made-up'],['--particle-clocks=native'],['--base-scenery-stream=continuous'],['--garbage=true']])assert.throws(()=>flags.validateHostOptions(args),args.join(' '));
 assert.doesNotThrow(()=>flags.validateHostOptions(['--native-runtime=editor','--native-screen=1','--public-servers','--render-profile=gameplay','--loading-pipeline=ordinary']));
});
test('legacy switches cannot silently ignore scalar values and canonical overhead clocks are consumed',()=>{
 assert.throws(()=>flags.validateHostOptions(['--native-profile=false']));
 assert.throws(()=>flags.validateHostOptions(['--public-servers=true']));
 assert.equal(flags.validateHostOptions(['--native-overhead-clocks=true']).values['native-overhead-clocks'],'true');
 assert.equal(flags.validateHostOptions(['--native-overhead-clocks=false']).values['native-overhead-clocks'],'false');
 assert.equal(flags.validateHostOptions(['--native-overhead-clocks']).values['native-overhead-clocks'],'true');
 const host=fs.readFileSync(path.join(project,'tools/native-session-host.cjs'),'utf8');assert(host.includes("nativeOverheadClocks=managedClientOptions.values['native-overhead-clocks']==='true'"));
});
test('cache budget validation is canonical and dependency order independent',()=>{
 assert.doesNotThrow(()=>flags.parseManagedOptions(['--native-draw-cache-gib=25','--native-draw-cache=prepared']));
 for(const value of ['24','1025','25.0','25.5','025','NaN','-25'])assert.throws(()=>flags.parseManagedOptions(['--native-draw-cache=prepared','--native-draw-cache-gib='+value]));
 assert.throws(()=>flags.parseManagedOptions(['--native-draw-cache-gib=25']));
});
test('catalogue and returned configuration do not expose mutable registry data',()=>{
 const a=flags.catalogue();a.features[0].choices.push('mutated');a.features[0].default='mutated';
 const b=flags.catalogue();assert(!b.features[0].choices.includes('mutated'));assert.equal(b.features[0].default,'standard');
 const x=flags.resolvePerformanceOptions([]);x.requested['drive-collision'].value='mutated';assert.equal(flags.resolvePerformanceOptions([]).requested['drive-collision'].value,'indexed');
 assert(b.nativeSourceFlags.some(row=>row.name==='drive-collision'));assert(b.powershellParameters.includes('ListFlags'));assert(b.powershellParameters.includes('RenderThread'));
});
function manifest(){return {registry:{sha256:'registry'},runtime:{executable:path.join(project,'fake-engine.exe'),expectedCapabilities:[]},requested:flags.resolvePerformanceOptions(['--render-thread=separate','--drive-collision=indexed','--light-input-registry=builtin','--detailed-profiling=off']).requested};}
function observation(){return {version:1,valid:true,registry:{sha256:'registry'},executable:path.join(project,'fake-engine.exe'),parsed_native_options:{'drive-collision':{value:'indexed'},'light-input-registry':{value:'builtin'},'world-snapshot-preparation':{value:'script'}},snapshot_preparation:{enabled:false,requested:'script',diagnostic:{worker:{active:false}}},capabilities:{light_input_registry:{available:true},classes:{}},presentation:{detailed_profiling:false},rendering:{display:'windows',render_thread_requirement:'matched',render_thread:{observed:true,thread_id:5,main_thread_id:1,separate:true}}};}
test('explicit drive height plan requires matching native startup evidence',()=>{
 const selected=manifest(),actual=observation();selected.requested['drive-height-plan']={value:'worker',explicit:true};
 assert.equal(proof.verifyNativeObservation(selected,actual).status,'rejected');
 actual.parsed_native_options['drive-height-plan']={value:'off'};assert.equal(proof.verifyNativeObservation(selected,actual).status,'rejected');
 actual.parsed_native_options['drive-height-plan']={value:'worker'};assert.equal(proof.verifyNativeObservation(selected,actual).status,'observed');
});

test('snapshot preparation startup proof verifies parsed policy and actual Session enabled owner',()=>{
 const selected=manifest();selected.requested['world-snapshot-preparation']={value:'workers',explicit:true};
 const observed=observation();observed.parsed_native_options['world-snapshot-preparation'].value='workers';observed.snapshot_preparation={enabled:true,requested:'workers',diagnostic:{worker:{active:false}}};observed.presentation.replay_fov_policy='live-preferences';
 assert.equal(proof.verifyNativeObservation(selected,observed).status,'observed');
 for(const mutate of [x=>delete x.parsed_native_options['world-snapshot-preparation'],x=>x.parsed_native_options['world-snapshot-preparation'].value='script',x=>delete x.snapshot_preparation,x=>x.snapshot_preparation.enabled=false,x=>delete x.snapshot_preparation.enabled,x=>x.snapshot_preparation.enabled='true',x=>x.snapshot_preparation.requested='script',x=>delete x.snapshot_preparation.diagnostic,x=>x.snapshot_preparation.diagnostic=[]]){
  const x=structuredClone(observed);mutate(x);assert.equal(proof.verifyNativeObservation(selected,x).status,'rejected');
 }
 const script=observation();script.presentation.replay_fov_policy='live-preferences';
 assert.equal(proof.verifyNativeObservation(manifest(),script).status,'observed');
 delete script.snapshot_preparation;assert.equal(proof.verifyNativeObservation(manifest(),script).status,'rejected');
 delete script.presentation.replay_fov_policy;assert.equal(proof.verifyNativeObservation(manifest(),script).status,'observed');
 const nonSessionWorkers=structuredClone(observed);delete nonSessionWorkers.presentation.replay_fov_policy;delete nonSessionWorkers.snapshot_preparation;
 assert.equal(proof.verifyNativeObservation(selected,nonSessionWorkers).status,'rejected');
});
test('startup proof rejects ignored selections, wrong executable/registry/thread and capabilities',()=>{
 assert.equal(proof.verifyNativeObservation(manifest(),observation()).status,'observed');
 for(const mutate of [x=>x.registry.sha256='wrong',x=>x.executable=path.join(project,'other.exe'),x=>x.parsed_native_options['drive-collision'].value='legacy',x=>x.capabilities.light_input_registry.available=false,x=>x.rendering.render_thread_requirement='mismatch',x=>x.presentation.detailed_profiling=true]){const x=observation();mutate(x);assert.equal(proof.verifyNativeObservation(manifest(),x).status,'rejected');}
 const x=observation();x.rendering.render_thread_requirement='pending';assert.equal(proof.verifyNativeObservation(manifest(),x).status,'pending');assert.equal(proof.verifyNativeObservation(manifest(),x,{requireObservedThread:true}).status,'rejected');
 x.rendering.render_thread_requirement='headless-not-a-gpu-thread-proof';x.rendering.display='headless';assert.equal(proof.verifyNativeObservation(manifest(),x,{requireObservedThread:true}).status,'observed');
});
test('missing actual thread IDs, unknown thread states and missing profiling observations reject',()=>{
 for(const mutate of [x=>delete x.rendering,x=>delete x.rendering.render_thread_requirement,x=>x.rendering.render_thread_requirement='guessed',x=>delete x.rendering.render_thread,x=>x.rendering.render_thread.separate=false,x=>delete x.presentation,x=>delete x.presentation.detailed_profiling]){const x=observation();mutate(x);assert.equal(proof.verifyNativeObservation(manifest(),x,{requireObservedThread:true}).status,'rejected');}
});
test('selected engine method contracts cannot be satisfied by a class name alone',()=>{
 const m=manifest();m.runtime.expectedCapabilities=[{class:'Example',parent:'RefCounted',instantiable:true,methods:[{name:'dispatch',arguments:2,returns:'Dictionary'}]}];
 const x=observation();assert.equal(proof.verifyNativeObservation(m,x).status,'rejected');
 x.capabilities.classes.Example={present:true,ref_counted:true,instantiable:true,methods:{dispatch:{arguments:2,return_type:27,static:false}}};assert.equal(proof.verifyNativeObservation(m,x).status,'observed');
 x.capabilities.classes.Example.methods.dispatch.arguments=1;assert.equal(proof.verifyNativeObservation(m,x).status,'rejected');
});
test('actual world owners are detached and mismatches reject',()=>{
 const state={drive_collision_configuration:{effective:'indexed',scope:{generation:4}},focus_lighting:{light_input_registry:{effective:'builtin',counts:{members:20}}}};
 const selected=proof.worldSelection(state,{connection:1,generation:4,areaId:10});assert.equal(proof.verifyWorldSelection(manifest(),selected).status,'observed');
 selected.collision.scope.generation=9;selected.lighting.counts.members=0;assert.equal(state.drive_collision_configuration.scope.generation,4);assert.equal(state.focus_lighting.light_input_registry.counts.members,20);
 selected.collision.effective='legacy';assert.equal(proof.verifyWorldSelection(manifest(),selected).status,'rejected');
});
test('source identity detects relevant source/library changes and excludes server assets',()=>{
 const folder=fs.mkdtempSync(path.join(os.tmpdir(),'nwn-feature-identity-'));
 try{fs.mkdirSync(path.join(folder,'systems'));fs.writeFileSync(path.join(folder,'systems','test.gd'),'extends RefCounted\n');fs.writeFileSync(path.join(folder,'private.key'),'SECRET');const a=proof.sourceIdentity(folder);assert.equal(a.files.length,1);assert(!JSON.stringify(a).includes('SECRET'));fs.writeFileSync(path.join(folder,'systems','test.gd'),'extends Node\n');assert.notEqual(proof.sourceIdentity(folder).sha256,a.sha256);}finally{const target=path.resolve(folder);if(path.dirname(target)!==path.resolve(os.tmpdir())||!path.basename(target).startsWith('nwn-feature-identity-'))throw Error('Refusing cleanup outside the exact owned test directory');fs.rmSync(target,{recursive:true,force:true});}
});
test('listing through the real host exits before bootstrap, engine or network startup',()=>{
 const result=spawnSync(process.execPath,[path.join(project,'tools/native-session-host.cjs'),'--list-flags','--json'],{encoding:'utf8',timeout:10000});
 assert.equal(result.status,0,result.stderr);const data=JSON.parse(result.stdout);assert(data.features.some(row=>row.name==='render-thread'));assert(data.applicationIngress.some(row=>row.name==='public-servers'));assert(!result.stdout.includes('DIRECT NATIVE GODOT'));
});
test('normal launch seams forward exact performance arguments and native evidence',()=>{
 const host=fs.readFileSync(path.join(project,'tools/native-session-host.cjs'),'utf8'),native=fs.readFileSync(path.join(project,'native_live_world.gd'),'utf8'),session=fs.readFileSync(path.join(project,'native_session_world.gd'),'utf8');
 for(const token of ['performanceOptions.engineArguments','performanceOptions.nativeArguments','selectPerformanceRuntime(project,performanceOptions.runtime)','featureSelection:performanceOptions.requested','verifyNativeObservation','verifyWorldSelection'])assert(host.includes(token),token);
 assert(native.includes('runtime_feature_report.configure(OS.get_cmdline_user_args()'));assert(native.includes('"runtimeFeatures":runtime_features_snapshot()'));assert(session.includes('"runtimeFeatures":runtime_features_snapshot()'));
});
