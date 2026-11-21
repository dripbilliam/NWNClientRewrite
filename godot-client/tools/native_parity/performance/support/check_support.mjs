// Small support-face correctness only. Never builds or ensures native outputs.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {selectClientLaunchEngine} from '../../loading/client_launch_engine.mjs';

const here=path.dirname(fileURLToPath(import.meta.url));
const projectRoot=path.resolve(here,'../../../..');
const authorityHash='9f4f49fa0adec8757abe4b27ec1364c77793b0e953b77c1065513c295bdaff95';
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const own=(file,bytes)=>{fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});};
const json=(file,value)=>own(file,JSON.stringify(value,null,2)+'\n');
function pinned(file,expected){const bytes=fs.readFileSync(file);if(sha(bytes)!==expected)throw Error('Reviewed source/proof changed: '+file);return bytes;}
function contained(base,file){const relative=path.relative(base,file);return relative!==''&&!relative.startsWith('..'+path.sep)&&relative!=='..'&&!path.isAbsolute(relative);}

export function classifyDiagnostics(mode,diagnostics,test,missingDllAbsent){
 const missing=[
  'ERROR: Condition "!FileAccess::exists(path)" is true. Returning: ERR_FILE_NOT_FOUND',
  "ERROR: GDExtension dynamic library not found: 'res://native/particle_kernel.gdextension'.",
  'ERROR: Failed loading resource: res://native/particle_kernel.gdextension.'
 ];
 if(diagnostics.length===0)return {accepted:mode==='native'||mode==='gd',expectedFault:false};
 if(mode==='missing'&&missingDllAbsent&&test?.expected_dependency_diagnostic===true&&JSON.stringify(diagnostics)===JSON.stringify(missing))return {accepted:true,expectedFault:true};
 if(mode==='setup'&&test?.expected_setup_diagnostic==='Native collision vertex index invalid'&&diagnostics.length===1&&diagnostics[0]==='ERROR: Native collision vertex index invalid')return {accepted:true,expectedFault:true};
 return {accepted:false,expectedFault:false};
}

export function stageSupportChecks(options={}){
 const authorityFile=path.join(here,'authority.json');
 const authority=JSON.parse(pinned(authorityFile,authorityHash));
 const sources=authority.sourceFiles.map(pin=>({...pin,bytes:pinned(path.join(projectRoot,pin.relative),pin.sha256)}));
 const templates=authority.files.map(pin=>({...pin,bytes:pinned(path.join(here,pin.relative),pin.sha256)}));
 const descriptor=pinned(path.join(projectRoot,authority.descriptor.relative),authority.descriptor.sha256);
 const dllFile=path.resolve(options.dll||path.join(projectRoot,authority.dll.relative));
 const dll=pinned(dllFile,authority.dll.sha256);
 const originalProofs=[];
 for(const pin of authority.originalPolicy){
  const file=path.join(projectRoot,pin.file),bytes=pinned(file,pin.sha256);
  const row=JSON.parse(bytes).rows.find(value=>value.key===pin.key);
  if(row?.evidence_id!==pin.evidence_id||row.procedure.address!==pin.address||sha(row.pseudocode)!==pin.pseudocodeSha256||sha(JSON.stringify(row.assembly))!==pin.assemblySha256)throw Error('Original policy row differs: '+pin.key);
  originalProofs.push({file,sha256:pin.sha256,key:pin.key,evidence_id:pin.evidence_id,address:pin.address});
 }
 // Read-only reviewed engine selection. No native launcher/build/Ensure call.
 const engine=selectClientLaunchEngine(projectRoot);
 const cacheRoot=path.join(projectRoot,'.cache');
 const defaultOut=path.join(cacheRoot,'native-presentation-parity/performance/support',new Date().toISOString().replaceAll(':','-')+'-'+crypto.randomBytes(4).toString('hex'));
 const out=path.resolve(options.out||defaultOut);
 if(!contained(cacheRoot,out))throw Error('Fresh output must be below the project .cache directory');
 if(fs.existsSync(out))throw Error('Refusing to overwrite an existing stage or receipt: '+out);
 const modes=options.modes||['native','gd','missing','setup'];
 if(!Array.isArray(modes)||modes.length===0||new Set(modes).size!==modes.length||modes.some(mode=>!Object.hasOwn(authority.expectedChecks,mode)))throw Error('Unknown or repeated check mode');
 const stagedFiles=[];
 fs.mkdirSync(path.dirname(out),{recursive:true});fs.mkdirSync(out);
 for(const name of ['project','missing-kernel-project']){
  const target=path.join(out,name);
  for(const source of sources){own(path.join(target,source.relative),source.bytes);stagedFiles.push({project:name,relative:source.relative,sha256:source.sha256});}
  for(const fixture of templates){
   const map={'reference/scene_geometry.gd':'reference_geometry.gd','reference/native_support_triangle.gd':'reference_triangle.gd'};
   const relative=map[fixture.relative]||path.basename(fixture.relative);
   own(path.join(target,relative),fixture.bytes);stagedFiles.push({project:name,relative,sha256:fixture.sha256});
  }
  own(path.join(target,authority.descriptor.relative),descriptor);
  stagedFiles.push({project:name,relative:authority.descriptor.relative,sha256:authority.descriptor.sha256});
  const config='config_version=5\n[application]\nconfig/name="Isolated support face correctness"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';
  own(path.join(target,'project.godot'),config);stagedFiles.push({project:name,relative:'project.godot',sha256:sha(config)});
  own(path.join(target,'.godot/global_script_class_cache.cfg'),'list=[]\n');stagedFiles.push({project:name,relative:'.godot/global_script_class_cache.cfg',sha256:sha('list=[]\n')});
  if(name==='project'){own(path.join(target,'.cache/native-kernel/nwn-particle-kernel.dll'),dll);stagedFiles.push({project:name,relative:'.cache/native-kernel/nwn-particle-kernel.dll',sha256:authority.dll.sha256});}
 }
 const receipt={version:1,out,stageOnly:!options.run,authority:{file:authorityFile,sha256:authorityHash},runner:{file:fileURLToPath(import.meta.url),sha256:sha(fs.readFileSync(fileURLToPath(import.meta.url)))},sourceProject:projectRoot,sources:sources.map(({relative,sha256})=>({relative,sha256})),templates:authority.files,descriptor:{file:path.join(projectRoot,authority.descriptor.relative),sha256:authority.descriptor.sha256},dll:{file:dllFile,sha256:authority.dll.sha256},engine,originalProofs,stagedFiles,modes,expectedChecks:authority.expectedChecks,nativeBuilds:0,ensureCalls:0,engineStarts:0,assets:0,worlds:0,gpuTests:0,benchmarks:0,sharedSourceEdits:0,liveSessionTouched:false};
 json(path.join(out,'stage.json'),receipt);
 return {out,receipt,authority,engine,sources,templates};
}

export function runSupportChecks(stage){
 const {out,receipt,authority,engine}=stage;
 if(receipt.stageOnly)throw Error('Stage-only output stays unexecuted; use a fresh --run invocation');
 const results=[];
 for(const mode of receipt.modes){
  const project=path.join(out,mode==='missing'?'missing-kernel-project':'project');
  const fixture=mode==='missing'?'missing_kernel_test.gd':mode==='setup'?'setup_error_test.gd':'support_unmasked_test.gd';
  const resultFile=path.join(project,'result-'+mode+'.json');
  const receiptFile=path.join(out,'run-'+mode+'.json');
  if(fs.existsSync(resultFile)||fs.existsSync(receiptFile))throw Error('Refusing to overwrite a check receipt');
  const args=['--headless','--path',project,'--script','res://'+fixture,'--','--particle-kernel=compiled'];
  if(mode==='gd')args.push('--scene-geometry=gd');
  const started=Date.now();
  const child=spawnSync(engine.path,args,{encoding:'utf8',timeout:15000,maxBuffer:2*1024*1024,windowsHide:true});
  const stdout=child.stdout||'',stderr=child.stderr||'';
  const test=fs.existsSync(resultFile)?JSON.parse(fs.readFileSync(resultFile,'utf8')):null;
  const diagnostics=(stdout+'\n'+stderr).split(/\r?\n/).filter(line=>/^(?:ERROR|SCRIPT ERROR|WARNING):/.test(line));
  const fault=classifyDiagnostics(mode,diagnostics,test,!fs.existsSync(path.join(project,'.cache/native-kernel/nwn-particle-kernel.dll')));
  const marker=mode==='missing'?'PRIVATE_UNMASKED_MISSING_KERNEL':mode==='setup'?'PRIVATE_UNMASKED_SETUP_ERROR':'PRIVATE_UNMASKED_SUPPORT';
  const passed=child.status===0&&!child.error&&test?.marker===marker&&test.checks===authority.expectedChecks[mode]&&test.errors.length===0&&fault.accepted;
  const row={version:1,mode,passed,engine:{path:engine.path,sha256:engine.sha256},args,elapsedMs:Date.now()-started,status:child.status,error:child.error?String(child.error):null,stdout,stderr,diagnostics,expectedFault: fault.expectedFault,test,authoritySha256:authorityHash,sourcePins:receipt.sources,nativeBuilds:0,ensureCalls:0,assets:0,worlds:0,gpuTests:0,benchmarks:0,liveSessionTouched:false};
  json(receiptFile,row);results.push({relative:path.basename(receiptFile),sha256:sha(fs.readFileSync(receiptFile)),mode,passed,checks:test?.checks||0,diagnostics,expectedFault:fault.expectedFault});
  if(!passed)break;
 }
 // Verify source/template pins again; a concurrent change is reported explicitly.
 const unchanged=receipt.sources.every(pin=>sha(fs.readFileSync(path.join(projectRoot,pin.relative)))===pin.sha256)&&receipt.templates.every(pin=>sha(fs.readFileSync(path.join(here,pin.relative)))===pin.sha256)&&receipt.stagedFiles.every(pin=>sha(fs.readFileSync(path.join(out,pin.project,pin.relative)))===pin.sha256)&&sha(fs.readFileSync(path.join(here,'authority.json')))===authorityHash;
 const final={version:1,passed:results.length===receipt.modes.length&&results.every(row=>row.passed)&&unchanged,results,checks:results.reduce((total,row)=>total+row.checks,0),sourceUnchanged:unchanged,stageSha256:sha(fs.readFileSync(path.join(out,'stage.json'))),engineStarts:results.length,nativeBuilds:0,ensureCalls:0,assets:0,worlds:0,gpuTests:0,benchmarks:0,liveSessionTouched:false};
 json(path.join(out,'run.json'),final);
 return final;
}

function main(){
 const options={run:false};let requestedStage=false,requestedRun=false;
 for(const arg of process.argv.slice(2)){
  if(arg==='--stage-only')requestedStage=true;
  else if(arg==='--run')requestedRun=true;
  else if(arg.startsWith('--out='))options.out=arg.slice(6);
  else if(arg.startsWith('--dll='))options.dll=arg.slice(6);
  else if(arg.startsWith('--modes='))options.modes=arg.slice(8).split(',');
  else throw Error('Unknown argument: '+arg);
 }
 if(requestedStage&&requestedRun)throw Error('Choose either --stage-only or --run');
 options.run=requestedRun;
 const stage=stageSupportChecks(options);
 if(!options.run){console.log(JSON.stringify({stageOnly:true,out:stage.out,engineStarts:0,nativeBuilds:0,files:stage.receipt.stagedFiles.length}));return;}
 const result=runSupportChecks(stage);
 console.log(JSON.stringify({out:stage.out,passed:result.passed,checks:result.checks,results:result.results}));
 process.exitCode=result.passed?0:1;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{main();}catch(error){console.error(String(error?.stack||error));process.exitCode=1;}
}
