// Focused CPU correctness only. Defaults to staging; never builds/ensures native outputs.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {selectClientLaunchEngine,verifyClientLaunchEngine} from '../../loading/client_launch_engine.mjs';

const here=path.dirname(fileURLToPath(import.meta.url));
const projectRoot=path.resolve(here,'../../../..');
const authorityHash='7ec10c40839dc67b91dd44ff6e877cee5ebed35c0901d7da60e6d0afa8bb7fa7';
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const own=(file,bytes)=>{fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});};
const json=(file,value)=>own(file,JSON.stringify(value,null,2)+'\n');
function contained(base,file){const relative=path.relative(base,file);return relative!==''&&relative!=='..'&&!relative.startsWith('..'+path.sep)&&!path.isAbsolute(relative);}
function pinned(file,expected){const bytes=fs.readFileSync(file);if(sha(bytes)!==expected)throw Error('Reviewed input changed: '+file);return bytes;}
function once(text,seam){if(text.split(seam).length!==2)throw Error('Reviewed extraction seam changed: '+seam);}
function method(text,name){const needle='func '+name+'(';once(text,needle);const start=text.indexOf(needle),next=/\n(?:static )?func /.exec(text.slice(start+1)),end=next?start+1+next.index:text.length;return text.slice(start,end).replace(/\n+$/,'')+'\n';}
function safeOutput(out){
 const cache=path.join(projectRoot,'.cache');
 if(!contained(cache,out))throw Error('Fresh output must stay below the project .cache directory');
 if(fs.existsSync(out))throw Error('Existing stage or receipt is preserved: '+out);
 let ancestor=path.dirname(out);while(!fs.existsSync(ancestor)){const parent=path.dirname(ancestor);if(parent===ancestor)throw Error('Output parent unavailable');ancestor=parent;}
 const realCache=fs.realpathSync(cache),realAncestor=fs.realpathSync(ancestor);
 if(realAncestor!==realCache&&!contained(realCache,realAncestor))throw Error('Output parent resolves outside the project cache');
}

export function parseOptions(args){
 const options={run:false};let stage=false,run=false;
 for(const arg of args){
  if(arg==='--stage-only')stage=true;
  else if(arg==='--run')run=true;
  else if(arg.startsWith('--out=')){if(options.out!==undefined)throw Error('Repeated output argument');options.out=arg.slice(6);}
  else if(arg.startsWith('--report=')){if(options.report!==undefined)throw Error('Repeated report argument');options.report=arg.slice(9);}
  else if(arg.startsWith('--source-root=')){if(options.sourceRoot!==undefined)throw Error('Repeated source argument');options.sourceRoot=arg.slice(14);}
  else throw Error('Unknown argument: '+arg);
 }
 if(stage&&run)throw Error('Choose either --stage-only or --run');
 options.run=run;return options;
}

export function stageBaseWorldLaneChecks(options={}){
 const out=path.resolve(options.out||path.join(projectRoot,'.cache/native-presentation-parity/performance/base-world-lane',new Date().toISOString().replaceAll(':','-')+'-'+crypto.randomBytes(4).toString('hex')));
 safeOutput(out);
 const report=options.report===undefined?path.join(out,'result.json'):options.report;
 if(!path.isAbsolute(report)||!contained(out,report))throw Error('Explicit report must be an absolute new path below this fresh output');
 if(fs.existsSync(report))throw Error('Existing report is preserved');
 const source=path.resolve(options.sourceRoot||projectRoot);
 if(source!==projectRoot&&!contained(path.join(projectRoot,'.cache'),source))throw Error('Reviewed source must be the project or a private capsule below its .cache');
 const authorityFile=path.join(here,'authority.json'),authority=JSON.parse(pinned(authorityFile,authorityHash));
 if(authority.expectedChecks!==120||authority.sourceFiles.length!==4||authority.generated.length!==7||authority.sourceProfiles?.length!==2)throw Error('Reviewed focused scope changed');
 const sources=authority.sourceFiles.map(pin=>{
  const bytes=fs.readFileSync(path.join(source,pin.relative)),actual=sha(bytes);
  if(!(pin.allowedSha256||[pin.sha256]).includes(actual))throw Error('Reviewed source changed: '+pin.relative);
  return {relative:pin.relative,sha256:actual,bytes};
 });
 const sourceProfile=authority.sourceProfiles.find(profile=>profile.sources.length===sources.length&&profile.sources.every(pin=>sources.some(source=>source.relative===pin.relative&&source.sha256===pin.sha256)));
 if(!sourceProfile)throw Error('Reviewed source combination changed; main/capsule files cannot be mixed');
 const fixtures=authority.files.map(pin=>({...pin,bytes:pinned(path.join(here,pin.relative),pin.sha256)}));
 const get=relative=>sources.find(pin=>pin.relative===relative).bytes;
 const fixture=relative=>fixtures.find(pin=>pin.relative===relative).bytes.toString();
 const world=get('systems/native_render/live_world.gd').toString(),objects=get('systems/native_render/object_stream.gd').toString();
 once(world,'func pending_plan(');once(world,'func ready_for_control() -> bool:');
 const body=world.slice(world.indexOf('func pending_plan('),world.indexOf('func ready_for_control() -> bool:',world.indexOf('func pending_plan(')));
 const planner=fixture('planner_fixture_prefix.gd')+body;
 const memoLine='\tif base_owner_active and (before_control or base_live_idle_revision==base_live_revision):return plan\n';once(planner,memoLine);
 const snapshotPrefix=method(world,'snapshot').split('\tvar skins:=')[0];once(world,'\tstate.object_visuals_complete=');
 const completeness=world.split('\n').find(line=>line.startsWith('\tstate.object_visuals_complete='));
 const generated={
  'candidate_planner.gd':planner,
  'no_memo_planner.gd':planner.replace(memoLine,''),
  'configure_owner.gd':fixture('configure_fixture_prefix.gd')+method(objects,'configure')+method(objects,'base_static_snapshot'),
  'object_pose.gd':'extends RefCounted\nstatic '+method(objects,'pose'),
  'receive_owner.gd':fixture('receive_fixture_prefix.gd')+method(world,'retire_replaced_lifetime')+method(world,'receive')+method(world,'receive_delta')+snapshotPrefix+completeness+'\n\treturn state\n',
  'base_world_scenery.gd':get('systems/native_render/base_world_scenery.gd'),
  'entity_lifetime.gd':get('systems/native_data/entity_presentation_lifetime.gd')
 };
 for(const pin of authority.generated)if(sha(generated[pin.relative])!==(sourceProfile.generatedOverrides[pin.relative]||pin.sha256))throw Error('Actual source extraction no longer matches reviewed body: '+pin.relative);
 // Existing proof/engine selection is read-only. It has no build/ensure/launch hook.
 const engine=selectClientLaunchEngine(projectRoot);
 const certificates=pinned(path.join(projectRoot,authority.caBundle.relative),authority.caBundle.sha256);
 const project=path.join(out,'project'),stagedFiles=[];
 fs.mkdirSync(out,{recursive:true});
 const stageFile=(relative,bytes)=>{own(path.join(project,relative),bytes);stagedFiles.push({relative,sha256:sha(bytes)});};
 for(const [relative,bytes] of Object.entries(generated))stageFile(relative,bytes);
 for(const pin of fixtures)if(pin.target)stageFile(pin.target,pin.bytes);
 stageFile('fixture-ca-bundle.crt',certificates);
 stageFile('.godot/global_script_class_cache.cfg','list=[]\n');
 stageFile('project.godot','config_version=5\n[application]\nconfig/name="Focused actual-source base world lane correctness"\n[network]\ntls/certificate_bundle_override="res://fixture-ca-bundle.crt"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
 const args=['--headless','--render-thread','safe','--path',project,'--script','res://check.gd','--log-file',path.join(out,'engine.log'),'--','--report='+report];
 const receipt={version:1,out,project,report,stageOnly:options.run!==true,authority:{file:authorityFile,sha256:authorityHash},runner:{file:fileURLToPath(import.meta.url),sha256:sha(fs.readFileSync(fileURLToPath(import.meta.url)))},sourceProject:source,sourceProfile:sourceProfile.name,sources:sources.map(({relative,sha256})=>({relative,sha256})),fixtures:authority.files,stagedFiles,engine,args,expectedChecks:120,historicalCorrectness:authority.historicalReceipt,historicalChecksRerun:false,engineStarts:0,nativeBuilds:0,ensureCalls:0,assets:0,worlds:0,gpuTests:0,benchmarks:0,sharedSourceEdits:0,liveSessionTouched:false,scope:authority.scope};
 json(path.join(out,'stage.json'),receipt);return {out,project,receipt,engine};
}

// Pure filesystem validation for Node refusal checks; never starts a process.
export function validateStageForRun(stage){
 const {out,project,receipt}=stage;
 if(receipt.stageOnly)throw Error('A stage-only output remains unexecuted; choose a fresh --run output');
 const runFile=path.join(out,'run.json');
 if(fs.existsSync(receipt.report)||fs.existsSync(runFile))throw Error('Existing result or receipt is preserved');
 const stageBytes=fs.readFileSync(path.join(out,'stage.json'));if(JSON.stringify(JSON.parse(stageBytes))!==JSON.stringify(receipt))throw Error('Stage receipt changed');
 const changed=()=>({
  sourceChanged:receipt.sources.filter(pin=>sha(fs.readFileSync(path.join(receipt.sourceProject,pin.relative)))!==pin.sha256).map(pin=>pin.relative),
  fixtureChanged:receipt.fixtures.filter(pin=>sha(fs.readFileSync(path.join(here,pin.relative)))!==pin.sha256).map(pin=>pin.relative),
  stagedChanged:receipt.stagedFiles.filter(pin=>sha(fs.readFileSync(path.join(project,pin.relative)))!==pin.sha256).map(pin=>pin.relative)
 });
 if(Object.values(changed()).some(rows=>rows.length))throw Error('Pinned stage/input changed before execution');
 pinned(path.join(here,'authority.json'),authorityHash);pinned(receipt.runner.file,receipt.runner.sha256);
 return {stageBytes,changed};
}

export function runBaseWorldLaneChecks(stage){
 const {out,project,receipt,engine}=stage;
 const runFile=path.join(out,'run.json');
 const {stageBytes,changed}=validateStageForRun(stage);
 verifyClientLaunchEngine(engine);
 const userdata=path.join(out,'userdata');fs.mkdirSync(userdata);
 const began=Date.now(),child=spawnSync(engine.path,receipt.args,{cwd:project,encoding:'utf8',windowsHide:true,timeout:15000,maxBuffer:2*1024*1024,env:{...process.env,APPDATA:userdata,LOCALAPPDATA:userdata}});
 const stdout=child.stdout||'',stderr=child.stderr||'';own(path.join(out,'stdout.log'),stdout);own(path.join(out,'stderr.log'),stderr);
 const diagnostics=(stdout+'\n'+stderr).split(/\r?\n/).filter(line=>/^(?:ERROR|SCRIPT ERROR|WARNING):|^Parse Error/.test(line));
 let result=null;try{result=JSON.parse(fs.readFileSync(receipt.report,'utf8'));}catch{}
 const drift=changed(),success=child.status===0&&!child.error&&diagnostics.length===0&&result?.success===true&&result.checks===120&&result.failures?.length===0&&Object.values(drift).every(rows=>rows.length===0)&&sha(fs.readFileSync(path.join(here,'authority.json')))===authorityHash;
 const final={version:1,success,exit:child.status,error:child.error?.message??null,elapsedMs:Date.now()-began,diagnostics,result,...drift,engine:{path:engine.path,sha256:engine.sha256},args:receipt.args,stageSha256:sha(stageBytes),engineStarts:1,nativeBuilds:0,ensureCalls:0,assets:0,worlds:0,gpuTests:0,benchmarks:0,sharedSourceEdits:0,liveSessionTouched:false,scope:receipt.scope};
 json(runFile,final);return final;
}

function main(){
 const options=parseOptions(process.argv.slice(2)),stage=stageBaseWorldLaneChecks(options);
 if(!options.run){console.log(JSON.stringify({stageOnly:true,out:stage.out,report:stage.receipt.report,files:stage.receipt.stagedFiles.length,engineStarts:0,nativeBuilds:0}));return;}
 const result=runBaseWorldLaneChecks(stage);console.log(JSON.stringify({out:stage.out,success:result.success,checks:result.result?.checks,diagnostics:result.diagnostics}));process.exitCode=result.success?0:1;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))try{main();}catch(error){console.error(String(error?.stack||error));process.exitCode=1;}
