import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn,spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const label=process.argv[2];if(!/^native-creation-owned-stack-[a-z0-9-]+$/.test(label??''))throw Error('Unique owned smoke label required');
const directory=path.join(project,'.cache/creation-owned-stack',label),copy=path.join(directory,'project'),report=path.join(project,'reports',label+'.native.json'),log=path.join(project,'reports',label+'.cdb.log');
for(const file of [directory,report,report+'.ready',log])if(fs.existsSync(file))throw Error('Existing owned evidence retained');
fs.mkdirSync(copy,{recursive:true});
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),debuggerPath='C:/Program Files (x86)/Windows Kits/10/Debuggers/x64/cdb.exe';
if(hash(fs.readFileSync(engine))!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Existing engine identity differs');
const files=['tools/break-owned-creation-native.ps1','tools/native-creation-owned-identity.ps1','tests/native_creation_owned_identity_test.ps1','tools/test-native-creation-owned-stack.mjs','.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json'];
const pins=Object.fromEntries(files.map(file=>[file,hash(fs.readFileSync(path.join(project,file)))]));
for(const file of files){const destination=path.join(directory,'inputs',file);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.copyFileSync(path.join(project,file),destination);}
fs.writeFileSync(path.join(copy,'project.godot'),'config_version=5\n[application]\nconfig/name="No-key owned stack smoke"\n[threading]\nworker_pool/max_threads=2\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
fs.writeFileSync(path.join(copy,'native_session_world.gd'),'extends SceneTree\nfunc _initialize() -> void:\n\tfor arg in OS.get_cmdline_user_args():\n\t\tif arg.begins_with("--report="):\n\t\t\tvar file:=FileAccess.open(arg.trim_prefix("--report=")+".ready",FileAccess.WRITE)\n\t\t\tfile.store_string("owned-no-key-smoke-ready");file.close()\n');
const commands=path.join(directory,'smoke.cdb.txt');fs.writeFileSync(commands,'sxe -c ".echo OWNED_CREATION_SMOKE_BREAK;.exr -1;.ecxr;kv 12;~* k 12;q" bpe\n.echo OWNED_CREATION_SMOKE_ARMED\ng\n');
const launch=['-hd','-G','-sins','-y',path.join(project,'.tools'),'-logo',log,'-cf',commands,engine,'--headless','--path',copy,'--script','res://native_session_world.gd','--','--report='+report];
let child=null,exit=null,output='',failure=null,observed=null,rejected=null,broken=null,identity=null;
const result={success:false,directory,report,scope:'No-key isolated headless Godot/CDB helper smoke only: exact launch observation, wrong real PID rejection, pure parent/start-time fences, bounded thread-stack break and owned cleanup. No application imports, game connection, key acquisition, native build or GPU benchmark.'};
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
function helper(extra,suffix,debuggerId=child.pid){
 const destination=path.join(project,'reports',label+'.'+suffix+'.json');
 const args=['-NoProfile','-File',path.join(project,'tools/break-owned-creation-native.ps1'),'-DebuggerProcessId',String(debuggerId),'-NativeExecutable',engine,'-ReportFile',report,'-Output',destination,...extra];
 const value=spawnSync('pwsh.exe',args,{windowsHide:true,timeout:10000,maxBuffer:64*1024,encoding:'utf8'});
 fs.writeFileSync(path.join(directory,suffix+'.stdout.log'),value.stdout??'');fs.writeFileSync(path.join(directory,suffix+'.stderr.log'),value.stderr??'');
 return {status:value.status,error:value.error?.code??null,result:fs.existsSync(destination)?JSON.parse(fs.readFileSync(destination,'utf8')):null};
}
try{
 const pure=spawnSync('pwsh.exe',['-NoProfile','-File',path.join(project,'tests/native_creation_owned_identity_test.ps1'),'-Report',path.join(directory,'identity.json')],{windowsHide:true,timeout:10000,maxBuffer:64*1024,encoding:'utf8'});
 fs.writeFileSync(path.join(directory,'identity.stdout.log'),pure.stdout??'');fs.writeFileSync(path.join(directory,'identity.stderr.log'),pure.stderr??'');
 identity=fs.existsSync(path.join(directory,'identity.json'))?JSON.parse(fs.readFileSync(path.join(directory,'identity.json'),'utf8')):null;if(pure.status!==0||!identity?.success)throw Error('Pure identity fences failed');
 child=spawn(debuggerPath,launch,{cwd:copy,windowsHide:true,stdio:['ignore','pipe','pipe']});
 child.once('exit',(code,signal)=>{exit={code,signal};});child.once('error',error=>{failure=error.code??error.message;});
 child.stdout.on('data',bytes=>{output=(output+bytes).slice(-1024*1024);});child.stderr.on('data',bytes=>{output=(output+bytes).slice(-1024*1024);});
 const readyBy=Date.now()+25000;while(!fs.existsSync(report+'.ready')&&!exit&&!failure&&Date.now()<readyBy)await wait(100);
 if(!fs.existsSync(report+'.ready')||exit||failure)throw Error('Owned no-key smoke did not reach ready');
 observed=helper(['-ObserveOnly'],'cpu');if(observed.status!==0||!observed.result?.exactLaunchIdentity||!observed.result?.observedOnly||observed.result.breakRequested)throw Error('Exact owned observation failed');
 const actualNative=observed.result.cpu.native.processId;
 rejected=helper(['-ObserveOnly'],'wrong-pid',actualNative);
 if(rejected.status===0||rejected.result)throw Error('Wrong real process ID was not rejected');
 broken=helper([],'break');if(broken.status!==0||!broken.result?.breakRequested||broken.result.nativeProcessId!==actualNative)throw Error('Exact owned diagnostic break failed');
 const stoppedBy=Date.now()+10000;while(!exit&&Date.now()<stoppedBy)await wait(100);
 if(!exit)throw Error('Owned debugger did not exit after its bounded stack trap');
 const stack=fs.readFileSync(log,'utf8');if(Buffer.byteLength(stack)>2*1024*1024||!/^OWNED_CREATION_SMOKE_ARMED\r?$/m.test(stack)||!/^OWNED_CREATION_SMOKE_BREAK\r?$/m.test(stack)||!/Child-SP|RetAddr/.test(stack))throw Error('Bounded all-thread stack evidence is missing');
 result.success=true;result.stackBytes=Buffer.byteLength(stack);result.observedNativeId=actualNative;result.debuggerId=child.pid;result.exit=exit;result.wrongRealPidRejected=true;result.pureIdentityChecks=identity.checks;
}catch(error){failure=error.message;}
finally{
 if(child&&exit===null){
  const cleanupScript=path.join(directory,'cleanup-owned.ps1');fs.writeFileSync(cleanupScript,"param([int]$OwnedDebuggerId,[string]$DebuggerPath,[string]$ReportPath,[string]$EnginePath)\n$ErrorActionPreference='Stop'\n$d=Get-CimInstance Win32_Process -Filter ('ProcessId='+$OwnedDebuggerId)\nif($d.ExecutablePath-eq$DebuggerPath-and$d.CommandLine.Contains($ReportPath)){Get-CimInstance Win32_Process -Filter ('ParentProcessId='+$OwnedDebuggerId)|Where-Object{$_.ExecutablePath-eq$EnginePath-and$_.CommandLine.Contains($ReportPath)}|ForEach-Object{Stop-Process -Id $_.ProcessId -Force};Stop-Process -Id $d.ProcessId -Force}\n");
  const cleanup=spawnSync('pwsh.exe',['-NoProfile','-File',cleanupScript,'-OwnedDebuggerId',String(child.pid),'-DebuggerPath',debuggerPath.replaceAll('/','\\'),'-ReportPath',report,'-EnginePath',engine],{windowsHide:true,timeout:10000,maxBuffer:8192,encoding:'utf8'});
  result.cleanupExit=cleanup.status;
 }
 const ids=[child?.pid,observed?.result?.cpu?.native?.processId].filter(Number.isSafeInteger);
 result.ownedProcessesGone=ids.every(id=>{try{process.kill(id,0);return false;}catch(error){return error.code==='ESRCH';}});
 result.changedInputs=files.filter(file=>hash(fs.readFileSync(path.join(project,file)))!==pins[file]);result.inputs=pins;
 result.failure=failure;result.success=result.success&&!failure&&result.ownedProcessesGone&&!result.changedInputs.length;
 fs.writeFileSync(path.join(directory,'stdout.log'),output);fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify({...result,inputs:files.length}));process.exitCode=result.success?0:1;
}
