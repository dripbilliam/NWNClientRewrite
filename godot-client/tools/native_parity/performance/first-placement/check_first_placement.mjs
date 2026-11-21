// Tiny authored first-placement correctness only. Defaults to staging; no build hooks.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {selectClientLaunchEngine} from '../../loading/client_launch_engine.mjs';

const here=path.dirname(fileURLToPath(import.meta.url));
const source=path.resolve(here,'../../../..');
const authorityHash='08fdeb0685c4b11cd8ed712973f55a8a5fcd68c915d87fecbb2ab7fdd897155c';
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const own=(file,bytes)=>{fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});};
const json=(file,value)=>own(file,JSON.stringify(value,null,2)+'\n');
function pinned(file,expected){const bytes=fs.readFileSync(file);if(sha(bytes)!==expected)throw Error('Reviewed input changed: '+file);return bytes;}
function contained(root,file){const relative=path.relative(root,file);return relative!==''&&relative!=='..'&&!relative.startsWith('..'+path.sep)&&!path.isAbsolute(relative);}

export function stageFirstPlacementChecks(options={}){
 const authorityFile=path.join(here,'authority.json');
 const authority=JSON.parse(pinned(authorityFile,authorityHash));
 const inputs=authority.sourceFiles.map(pin=>({...pin,bytes:pinned(path.join(source,pin.relative),pin.sha256)}));
 const fixtures=authority.files.map(pin=>({...pin,bytes:pinned(path.join(here,pin.relative),pin.sha256)}));
 if(inputs.length!==57||authority.expectedChecks!==40||authority.newerPlacementBodyByteIdentical!==true||
    inputs.find(row=>row.relative==='systems/native_render/model_template.gd')?.sha256!==authority.candidateTemplate||
    fixtures.find(row=>row.target==='baseline_model_template.gd')?.sha256!==authority.beforeTemplate)throw Error('Reviewed tiny fixture scope differs');
 const engine=selectClientLaunchEngine(source); // Read-only existing engine/proof verification.
 const cache=path.join(source,'.cache');
 const out=path.resolve(options.out||path.join(cache,'native-presentation-parity/performance/first-placement',new Date().toISOString().replaceAll(':','-')+'-'+crypto.randomBytes(4).toString('hex')));
 if(!contained(cache,out))throw Error('Fresh output must stay below the project .cache directory');
 if(fs.existsSync(out))throw Error('Existing stage or receipt is preserved: '+out);
 fs.mkdirSync(path.dirname(out),{recursive:true});fs.mkdirSync(out);
 const project=path.join(out,'project'),stagedFiles=[];
 for(const input of inputs){own(path.join(project,input.relative),input.bytes);stagedFiles.push({relative:input.relative,sha256:input.sha256});}
 for(const fixture of fixtures){own(path.join(project,fixture.target),fixture.bytes);stagedFiles.push({relative:fixture.target,sha256:fixture.sha256});}
 const config='config_version=5\n[application]\nconfig/name="Small current first-placement correctness"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';
 own(path.join(project,'project.godot'),config);stagedFiles.push({relative:'project.godot',sha256:sha(config)});
 own(path.join(project,'.godot/global_script_class_cache.cfg'),'list=[]\n');stagedFiles.push({relative:'.godot/global_script_class_cache.cfg',sha256:sha('list=[]\n')});
 const receipt={version:1,out,project,stageOnly:options.run!==true,authority:{file:authorityFile,sha256:authorityHash},runner:{file:fileURLToPath(import.meta.url),sha256:sha(fs.readFileSync(fileURLToPath(import.meta.url)))},sourceProject:source,sources:authority.sourceFiles,fixtures:authority.files,stagedFiles,engine,expectedChecks:40,historicalCorrectness:authority.originalCheck,priorReference:authority.priorReference,historicalChecksRerun:false,engineStarts:0,nativeBuilds:0,ensureCalls:0,assets:0,worlds:0,gpuTests:0,benchmarks:0,sharedSourceEdits:0,liveSessionTouched:false};
 json(path.join(out,'stage.json'),receipt);
 return {out,project,receipt,engine};
}

export function runFirstPlacementChecks(stage){
 const {out,project,receipt,engine}=stage;
 if(receipt.stageOnly)throw Error('A stage-only output remains unexecuted; choose a fresh --run output');
 const resultFile=path.join(out,'result.json'),runFile=path.join(out,'run.json');
 if(fs.existsSync(resultFile)||fs.existsSync(runFile))throw Error('Existing result or receipt is preserved');
 const userdata=path.join(out,'userdata');fs.mkdirSync(userdata);
 const args=['--headless','--render-thread','safe','--path',project,'--script','res://check.gd','--','--particle-kernel=gd','--particle-owner=reference','--report='+resultFile];
 const began=Date.now();
 const child=spawnSync(engine.path,args,{cwd:project,encoding:'utf8',timeout:15000,maxBuffer:2*1024*1024,windowsHide:true,env:{...process.env,APPDATA:userdata,LOCALAPPDATA:userdata,NWN_PARTICLE_KERNEL:'gd'}});
 const stdout=child.stdout||'',stderr=child.stderr||'';
 own(path.join(out,'stdout.log'),stdout);own(path.join(out,'stderr.log'),stderr);
 const diagnostics=(stdout+'\n'+stderr).split(/\r?\n/).filter(line=>/^(?:ERROR|SCRIPT ERROR|WARNING):|^Parse Error/.test(line));
 let result=null;try{result=JSON.parse(fs.readFileSync(resultFile,'utf8'));}catch{}
 const sourceChanged=receipt.sources.filter(pin=>sha(fs.readFileSync(path.join(source,pin.relative)))!==pin.sha256).map(pin=>pin.relative);
 const fixtureChanged=receipt.fixtures.filter(pin=>sha(fs.readFileSync(path.join(here,pin.relative)))!==pin.sha256).map(pin=>pin.relative);
 const stagedChanged=receipt.stagedFiles.filter(pin=>sha(fs.readFileSync(path.join(project,pin.relative)))!==pin.sha256).map(pin=>pin.relative);
 const expectedObservations=result?.observations?.length===2&&result.observations[0].compact===false&&result.observations[1].compact===true&&result.observations.every(row=>row.parts===3&&row.meshes===1&&row.hidden===1);
 const success=child.status===0&&!child.error&&diagnostics.length===0&&result?.success===true&&result.checks===40&&result.failures.length===0&&expectedObservations&&sourceChanged.length===0&&fixtureChanged.length===0&&stagedChanged.length===0&&sha(fs.readFileSync(path.join(here,'authority.json')))===authorityHash;
 const final={version:1,success,exit:child.status,error:child.error?.message??null,elapsedMs:Date.now()-began,diagnostics,result,sourceChanged,fixtureChanged,stagedChanged,engine:{path:engine.path,sha256:engine.sha256},args,stageSha256:sha(fs.readFileSync(path.join(out,'stage.json'))),engineStarts:1,nativeBuilds:0,ensureCalls:0,assets:0,worlds:0,gpuTests:0,benchmarks:0,liveSessionTouched:false,scope:'One tiny actual current template/instance/pool headless check. No original assets, native DLL, loading, rendered scene or FPS acceptance.'};
 json(runFile,final);return final;
}

function main(){
 const options={run:false};let requestedStage=false,requestedRun=false;
 for(const arg of process.argv.slice(2)){
  if(arg==='--stage-only')requestedStage=true;
  else if(arg==='--run')requestedRun=true;
  else if(arg.startsWith('--out='))options.out=arg.slice(6);
  else throw Error('Unknown argument: '+arg);
 }
 if(requestedStage&&requestedRun)throw Error('Choose stage-only or run');
 options.run=requestedRun;
 const stage=stageFirstPlacementChecks(options);
 if(!options.run){console.log(JSON.stringify({stageOnly:true,out:stage.out,files:stage.receipt.stagedFiles.length,engineStarts:0,nativeBuilds:0}));return;}
 const result=runFirstPlacementChecks(stage);
 console.log(JSON.stringify({out:stage.out,success:result.success,checks:result.result?.checks,diagnostics:result.diagnostics}));
 process.exitCode=result.success?0:1;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{main();}catch(error){console.error(String(error?.stack||error));process.exitCode=1;}
}
