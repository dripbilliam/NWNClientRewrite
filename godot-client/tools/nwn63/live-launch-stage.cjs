'use strict';
// Final NWN-63 candidate only. Preparation and verification never launch a client.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),hash=file=>sha(fs.readFileSync(file));
const core='753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b',kernel='485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d';
const pinned=(file,want)=>assert.equal(hash(file),want,'Pin changed: '+file);
const pin=file=>({file,sha256:hash(file)});
function put(from,to){fs.mkdirSync(path.dirname(to),{recursive:true});fs.copyFileSync(from,to,fs.constants.COPYFILE_EXCL);return pin(to);}
function replaceOnce(source,before,after){assert.equal(source.split(before).length-1,1,'Host seam changed: '+before.slice(0,80));return source.replace(before,after);}
async function selectionFor(receiptFile){
 const {verifyStage}=require('./final-stage-pair.cjs');await verifyStage(receiptFile);
 const receipt=JSON.parse(fs.readFileSync(receiptFile));const row=receipt.selections.candidate;
 const selection=await require('../native-production-selection.cjs').readProductionSelection(row.file,row.sha256);
 assert.equal(selection.runtime.executableSha256,core);assert.equal(selection.evidence.particleSha256,kernel);
 assert.deepEqual(selection.options,['--performance-runtime=verified-native','--render-profile=gameplay','--detailed-profiling=off']);
 assert.deepEqual(selection.preferences.expected,{gamma:1.2,particles:true,fovDegrees:45,compactScenery:true});
 return {receipt,selection,row};
}
async function rollbackSelectionFor(pairFile,label){
 const baseline=await selectionFor(pairFile),current=require('../native-feature-manifest.cjs').sourceIdentity(root);
 const prior=new Map(baseline.selection.mainSourceIdentity.files.map(x=>[x.file,x.sha256]));
 const differences=current.files.filter(x=>prior.get(x.file)!==x.sha256).map(x=>x.file).sort();
 assert.deepEqual(differences,['systems/native_render/drive_collision_indexed.gd'],'Working source differs beyond the collision rollback');
 assert.equal(current.files.length,prior.size,'Working source file set changed');
 const collision='systems/native_render/drive_collision_indexed.gd',control=JSON.parse(fs.readFileSync(baseline.receipt.manifestFile)).collisionReversals.find(x=>x.relative===collision);
 assert(control,'Frozen collision reversal missing');pinned(path.join(root,collision),control.controlSha256);
 const world=fs.readFileSync(path.join(root,'native_live_world.gd'),'utf8');
 assert.equal(world.split('bool(ProjectSettings.get_setting("nwn/private/keyboard_frame_admission",true))').length-1,2,'Keyboard admission must remain default on');
 const seeds=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn63/frame-input-live-graphics-e/preference-seeds.json')));
 require('../native-production-selection.cjs').preferenceSeeds(seeds);
 const result=await require('../native-production-selection.cjs').stageProductionSelection({project:root,label:'nwn63-live-'+label+'-source',argv:['--performance-runtime=verified-native','--render-profile=gameplay','--detailed-profiling=off'],preferenceSeeds:seeds,env:{}});
 assert.equal(result.selection.mainSourceIdentity.sha256,current.sha256,'Working source changed during selection staging');
 return {selection:result.selection,row:{file:result.file,sha256:result.sha256},kind:'working-rollback',basePair:pin(pairFile),controlCollisionSha256:control.controlSha256};
}
async function prepare(receiptFile,label,sourceOverride=null){
 assert.match(label,/^[a-z0-9][a-z0-9-]{0,45}$/);
 const {selection,row}=sourceOverride??await selectionFor(receiptFile),out=path.join(root,'.cache/nwn63/live-'+label),view=path.join(out,'project'),source=path.join(out,'launcher');
 assert(!fs.existsSync(out),'Fresh live stage label required');fs.mkdirSync(view,{recursive:true});fs.mkdirSync(source);
 const files=[];
 for(const entry of selection.pins){const from=path.join(selection.sourceProject,entry.relative),to=path.join(view,entry.relative);pinned(from,entry.sha256);files.push({relative:entry.relative,...put(from,to)});}
 for(const relative of ['.tools/native-core/Godot_native_core_e_win64.exe','.tools/native-core/accepted-core-e.json'])files.push({relative,...put(path.join(root,relative),path.join(view,relative))});
 fs.mkdirSync(path.join(view,'reports'));
 pinned(path.join(view,'.tools/native-core/Godot_native_core_e_win64.exe'),core);
 pinned(path.join(view,'.cache/native-kernel/nwn-particle-kernel.dll'),kernel);
 assert.equal(require('../native-feature-manifest.cjs').sourceIdentity(view).sha256,selection.mainSourceIdentity.sha256);
 const seedBase=path.dirname(selection.sourceProject),seedRender=path.join(seedBase,selection.preferences.render.relative),seedLayout=path.join(seedBase,selection.preferences.layout.relative);
 pinned(seedRender,selection.preferences.render.sha256);pinned(seedLayout,selection.preferences.layout.sha256);
 const config={version:1,issue:'NWN-63',sourceKind:sourceOverride?.kind??'pair-candidate',basePair:sourceOverride?.basePair??null,controlCollisionSha256:sourceOverride?.controlCollisionSha256??null,project:root,out,view,executionProject:sourceOverride?.kind==='working-rollback'?root:view,source,run:'nwn63-live-'+label,receipt:receiptFile,receiptSha256:receiptFile?hash(receiptFile):null,candidateSelection:row,sourceIdentity:selection.mainSourceIdentity.sha256,engineSha256:core,kernelSha256:kernel,seedRender:pin(seedRender),seedLayout:pin(seedLayout),electron:path.resolve(root,'../node_modules/electron/dist/electron.exe'),bootstrap:path.join(root,'tools/native-session-bootstrap.cjs'),host:path.join(root,'tools/native-session-host.cjs'),userdata:path.join(out,'working-settings'),appdata:path.join(out,'working-appdata'),localappdata:path.join(out,'working-localappdata'),compiledHost:path.join(source,'host.cjs'),screenHelper:path.join(source,'native-window-screen.ps1'),bootstrapPreload:path.join(source,'bootstrap-preload.cjs'),bootstrapArguments:[path.join(root,'tools/native-session-bootstrap.cjs'),'--run=nwn63-live-'+label,'--public-servers',...selection.options]};
 config.bootstrapSha256=hash(config.bootstrap);config.hostSha256=hash(config.host);
 assert.equal(config.bootstrapSha256,selection.pins.find(x=>x.relative==='tools/native-session-bootstrap.cjs')?.sha256,'Frozen bootstrap differs');
 assert.equal(config.hostSha256,selection.pins.find(x=>x.relative==='tools/native-session-host.cjs')?.sha256,'Frozen host differs');
 let host=fs.readFileSync(config.host,'utf8');
 host=replaceOnce(host,"const project=path.resolve(__dirname,'..'),root=path.dirname(project),loaded=new Set();",'const project='+JSON.stringify(config.executionProject)+',root='+JSON.stringify(path.dirname(root))+',loaded=new Set();');
 host=replaceOnce(host,'nativeArgs.unshift(...performanceOptions.engineArguments);','nativeArgs.push('+[['render-preferences','native-render-preferences.cfg'],['menu-layout','native-menu-layout.cfg'],['lobby-preferences','native-lobby-preferences.cfg']].map(([name,file])=>JSON.stringify('--'+name+'='+path.join(config.userdata,file))).join(',')+');\n nativeArgs.unshift(...performanceOptions.engineArguments);');
 const spawn="native=spawn(launch,launchArgs,{cwd:runtimeSelection.directory,windowsHide:true,env:{...process.env,...renderConfiguration.environment},stdio:['ignore','pipe','pipe']});";
 host=replaceOnce(host,spawn,spawn.replace('...renderConfiguration.environment}','...renderConfiguration.environment,APPDATA:'+JSON.stringify(config.appdata)+',LOCALAPPDATA:'+JSON.stringify(config.localappdata)+'}')+'\n await fs.writeFile('+JSON.stringify(path.join(out,'native-start.json'))+',JSON.stringify({pid:native.pid,hostPid:process.pid,engine:runtimeSelection.executable,engineSha256:runtimeSelection.executableSha256,sourceProject:project,normalEngine:true,automaticLogin:false})+"\\n",{flag:"wx"});');
 new vm.Script(host);fs.writeFileSync(config.compiledHost,host,{flag:'wx'});config.compiledHostSha256=hash(config.compiledHost);
 let broker=fs.readFileSync(path.join(root,'tools/native-tracy/live/bootstrap-preload.cjs'),'utf8').replaceAll('NWN_PRIVATE_TRACY_CONFIG','NWN63_LIVE_CONFIG');
 const original="for (const [from, to] of [['native-options.cfg', 'native-render-preferences.cfg'], ['native-menu-layout.cfg', 'native-menu-layout.cfg'], ['native-character-lobby.cfg', 'native-lobby-preferences.cfg']]) copy(path.join(godot, from), path.join(config.userdata, to));";
 const replacement="copy(config.seedRender.file, path.join(config.userdata, 'native-render-preferences.cfg')); copy(config.seedLayout.file, path.join(config.userdata, 'native-menu-layout.cfg')); copy(path.join(godot, 'native-character-lobby.cfg'), path.join(config.userdata, 'native-lobby-preferences.cfg'));";
 broker=replaceOnce(broker,original,replacement);new vm.Script(broker);fs.writeFileSync(config.bootstrapPreload,broker,{flag:'wx'});
 let hostPreload=fs.readFileSync(path.join(root,'tools/native-live-review/host-preload.cjs'),'utf8').replaceAll('NWN_LIVE_REVIEW_CONFIG','NWN63_LIVE_CONFIG').replace('sourceProject:c.view','sourceProject:c.executionProject');new vm.Script(hostPreload);fs.writeFileSync(path.join(source,'host-preload.cjs'),hostPreload,{flag:'wx'});
 put(path.join(root,'tools/native-window-screen.ps1'),config.screenHelper);
 config.electronSha256=hash(config.electron);
 const configFile=path.join(out,'config.json');fs.writeFileSync(configFile,JSON.stringify(config,null,2)+'\n',{flag:'wx'});
 const sourceFiles=[];function collect(base,relative=''){for(const entry of fs.readdirSync(base,{withFileTypes:true})){assert(!entry.isSymbolicLink());const name=relative?relative+'/'+entry.name:entry.name,file=path.join(base,entry.name);if(entry.isDirectory())collect(file,name);else sourceFiles.push({relative:name,...pin(file)});}}collect(source);
 const proof={version:1,issue:'NWN-63',kind:'frozen-candidate-live-stage',config:pin(configFile),receipt:receiptFile?pin(receiptFile):null,basePair:sourceOverride?.basePair??null,selection:row,files,launcherFiles:sourceFiles,sourceIdentity:config.sourceIdentity,engineSha256:core,kernelSha256:kernel,originalAssetsCopied:false,automaticLogin:false,tracy:false,performanceAccepted:false};
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(proof,null,2)+'\n',{flag:'wx'});
 return verify(configFile);
}
async function verify(configFile){
 const config=JSON.parse(fs.readFileSync(configFile));assert.equal(config.version,1);assert.equal(config.issue,'NWN-63');
 const proof=JSON.parse(fs.readFileSync(path.join(config.out,'manifest.json')));assert.equal(proof.kind,'frozen-candidate-live-stage');pinned(configFile,proof.config.sha256);
 let selection,row;
 if(config.sourceKind==='pair-candidate'){
  pinned(config.receipt,proof.receipt.sha256);({selection,row}=await selectionFor(config.receipt));
 }else if(config.sourceKind==='working-rollback'){
  assert.equal(config.receipt,null);pinned(config.basePair.file,config.basePair.sha256);assert.deepEqual(config.basePair,proof.basePair);
  const baseline=await selectionFor(config.basePair.file),candidate=baseline.selection.mainSourceIdentity.files,previous=new Map(candidate.map(x=>[x.file,x.sha256]));
  row=config.candidateSelection;selection=await require('../native-production-selection.cjs').readProductionSelection(row.file,row.sha256);
  const differences=selection.mainSourceIdentity.files.filter(x=>previous.get(x.file)!==x.sha256).map(x=>x.file).sort();
  assert.deepEqual(differences,['systems/native_render/drive_collision_indexed.gd'],'Live rollback differs beyond collision');
  assert.equal(selection.mainSourceIdentity.files.length,candidate.length);
  assert.equal(selection.pins.find(x=>x.relative==='systems/native_render/drive_collision_indexed.gd')?.sha256,config.controlCollisionSha256);
  const world=fs.readFileSync(path.join(selection.sourceProject,'native_live_world.gd'),'utf8');
  assert.equal(world.split('bool(ProjectSettings.get_setting("nwn/private/keyboard_frame_admission",true))').length-1,2);
 }else throw Error('Unknown live source kind');
 assert.equal(row.file,config.candidateSelection.file);assert.equal(row.sha256,config.candidateSelection.sha256);
 assert.equal(selection.mainSourceIdentity.sha256,config.sourceIdentity);assert.equal(config.engineSha256,core);assert.equal(config.kernelSha256,kernel);
 for(const entry of [...proof.files,...proof.launcherFiles])pinned(entry.file,entry.sha256);
 assert(fs.statSync(path.join(config.view,'reports')).isDirectory(),'Native report directory missing');
 for(const name of ['seedRender','seedLayout'])pinned(config[name].file,config[name].sha256);
 pinned(config.bootstrap,config.bootstrapSha256);pinned(config.host,config.hostSha256);pinned(config.compiledHost,config.compiledHostSha256);pinned(config.electron,config.electronSha256);
 assert.equal(require('../native-feature-manifest.cjs').sourceIdentity(config.view).sha256,config.sourceIdentity);
 if(config.sourceKind==='working-rollback'){
  assert.equal(config.executionProject,root);
  assert.equal(require('../native-feature-manifest.cjs').sourceIdentity(root).sha256,config.sourceIdentity,'Working source changed after live staging');
  pinned(path.join(root,'.tools/native-core/Godot_native_core_e_win64.exe'),core);
  pinned(path.join(root,'.cache/native-kernel/nwn-particle-kernel.dll'),kernel);
 }else assert.equal(config.executionProject,config.view);
 assert(!fs.existsSync(path.join(config.out,'launch.json')),'Live stage already launched');
 return {status:'ready',noClientStarts:true,config:configFile,run:config.run,sourceIdentity:config.sourceIdentity,engineSha256:core,kernelSha256:kernel,preferenceSeeds:{render:config.seedRender.sha256,layout:config.seedLayout.sha256},secondaryScreenRequired:true};
}
async function main(){const [mode,...args]=process.argv.slice(2),arg=name=>args.find(x=>x.startsWith('--'+name+'='))?.slice(name.length+3);assert(args.every(x=>x.startsWith('--receipt=')||x.startsWith('--pair=')||x.startsWith('--label=')||x.startsWith('--config=')));if(mode==='prepare')console.log(JSON.stringify(await prepare(path.resolve(arg('receipt')??''),arg('label'))));else if(mode==='prepare-current'){const label=arg('label'),pair=path.resolve(arg('pair')??'');console.log(JSON.stringify(await prepare(null,label,await rollbackSelectionFor(pair,label))));}else if(mode==='verify-only')console.log(JSON.stringify(await verify(path.resolve(arg('config')??''))));else throw Error('Use prepare --receipt=FILE --label=LABEL, prepare-current --pair=FILE --label=LABEL, or verify-only --config=FILE');}
if(require.main===module)main().catch(error=>{console.error(error.stack);process.exitCode=1;});
