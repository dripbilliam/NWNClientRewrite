import fs from 'node:fs';import path from 'node:path';import net from 'node:net';import crypto from 'node:crypto';import {spawn,spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
import tracer from './native-creation-socket-trace.cjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),label=process.argv[2];
if(!/^native-creation-socket-smoke-[a-z0-9-]+$/.test(label??''))throw Error('Unique owned socket smoke label required');
const directory=path.join(project,'.cache/creation-socket-smoke',label);if(fs.existsSync(directory))throw Error('Existing smoke retained');fs.mkdirSync(directory,{recursive:true});
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),cdb='C:\\Program Files (x86)\\Windows Kits\\10\\Debuggers\\x64\\cdb.exe';
if(hash(fs.readFileSync(engine))!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing engine');
const files=['tools/native-creation-socket-trace.cjs','tools/test-native-creation-socket-trace.mjs','.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json'];
const inputs=Object.fromEntries(files.map(file=>[file,hash(fs.readFileSync(path.join(project,file)))]));
for(const file of files){const out=path.join(directory,'inputs',file);fs.mkdirSync(path.dirname(out),{recursive:true});fs.copyFileSync(path.join(project,file),out);}
const copy=path.join(directory,'project');fs.mkdirSync(copy);fs.writeFileSync(path.join(copy,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned no-key IPC close smoke"\n[threading]\nworker_pool/max_threads=2\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
fs.writeFileSync(path.join(copy,'native_session_world.gd'),`extends SceneTree
var socket:=StreamPeerTCP.new()
var report_path:=""
var scenario:=""
var port:=0
var connected:=false
var cycles:=0
var started:=0
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  var pair:=arg.trim_prefix("--").split("=",true,1)
  if pair.size()!=2:continue
  if pair[0]=="report":report_path=pair[1]
  elif pair[0]=="scenario":scenario=pair[1]
  elif pair[0]=="port":port=int(pair[1])
 started=Time.get_ticks_msec()
 var identity:=FileAccess.open(report_path+".pid",FileAccess.WRITE);identity.store_string(str(OS.get_process_id()));identity.close()
 if socket.connect_to_host("127.0.0.1",port)!=OK:finish(false);return
 process_frame.connect(tick)
func tick() -> void:
 socket.poll()
 if not connected and socket.get_status()==StreamPeerTCP.STATUS_CONNECTED:
  connected=true
  socket.put_data("owned-no-key-smoke\\n".to_utf8_buffer())
  if scenario!="host-fin":
   socket.disconnect_from_host();cycles+=1
   if scenario=="cap" and cycles<20:
    connected=false
    if socket.connect_to_host("127.0.0.1",port)!=OK:finish(false)
    return
   finish(true);return
 if connected and socket.get_status()==StreamPeerTCP.STATUS_NONE:finish(true);return
 if Time.get_ticks_msec()-started>12000:finish(false)
func finish(ok: bool) -> void:
 var file:=FileAccess.open(report_path,FileAccess.WRITE)
 file.store_string(JSON.stringify({"success":ok,"connected":connected,"scenario":scenario,"cycles":cycles,"status":socket.get_status(),"ticks_ms":Time.get_ticks_msec(),"process_id":OS.get_process_id()}));file.close()
 quit(0 if ok else 1)
`);
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const processGone=id=>{try{process.kill(id,0);return false;}catch(e){return e.code==='ESRCH';}};
const all=[];let failure=null;
async function run(scenario){
 const name=label+'-'+scenario,report=path.join(project,'reports',name+'.native.json'),log=path.join(directory,scenario+'.cdb.log');
 if(fs.existsSync(report)||fs.existsSync(log))throw Error('Existing case evidence retained');
 const events=[],sockets=new Set();
 const accept=socket=>{sockets.add(socket);socket.on('data',bytes=>{events.push({kind:'data',at:Date.now(),bytes:bytes.length});if(scenario==='host-fin'){events.push({kind:'intentional-host-fin',at:Date.now()});socket.end();}});socket.on('end',()=>events.push({kind:'end',at:Date.now()}));socket.on('error',error=>events.push({kind:'error',at:Date.now(),code:error.code}));socket.on('close',()=>{events.push({kind:'close',at:Date.now()});sockets.delete(socket);});};
 const server=net.createServer(accept),other=net.createServer(accept);
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
 await new Promise((resolve,reject)=>{other.once('error',reject);other.listen(0,'127.0.0.1',resolve);});
 const expectedPort=server.address().port,actualPort=scenario==='wrong-endpoint'?other.address().port:expectedPort,spec=tracer.creationSocketTrace(expectedPort),commands=path.join(directory,scenario+'.cdb.txt');
 fs.writeFileSync(commands,[...spec.commands,'.echo OWNED_SOCKET_SMOKE_ARMED','g'].join('\n')+'\n');
 let child=null,exit=null,output='',error=null,nativeId=null;
 const result={scenario,success:false,expectedPort,actualPort,events,traceSpec:{cap:spec.cap,breakpointIds:spec.breakpointIds}};
 try{
  child=spawn(cdb,['-hd','-G','-sins','-y',path.join(project,'.tools'),'-logo',log,'-cf',commands,engine,'--headless','--path',copy,'--script','res://native_session_world.gd','--','--report='+report,'--scenario='+scenario,'--port='+actualPort],{cwd:copy,windowsHide:true,stdio:['ignore','pipe','pipe']});
  child.once('exit',(code,signal)=>{exit={code,signal};});child.once('error',value=>{error=value.code??value.message;});
  child.stdout.on('data',bytes=>{output=(output+bytes).slice(-512*1024);});child.stderr.on('data',bytes=>{output=(output+bytes).slice(-512*1024);});
  const deadline=Date.now()+25000;while(!exit&&!error&&Date.now()<deadline)await pause(100);
  if(!exit||error)throw Error('Owned socket smoke did not exit under its deadline');
  const native=JSON.parse(fs.readFileSync(report,'utf8')),text=fs.readFileSync(log,'utf8');nativeId=native.process_id;
  const rows=[...text.matchAll(/^NATIVE_IPC_TRACE (CONNECT|CLOSE|SHUTDOWN) seq=(\d+) socket=([0-9a-f`]+)\r?$/gmi)].map(m=>({kind:m[1],sequence:Number(m[2]),socket:m[3]}));
  const connected=rows.find(row=>row.kind==='CONNECT'),closed=rows.find(row=>row.kind==='CLOSE');
  if(!native.success||!native.connected||native.status!==0||exit.code!==0||!/OWNED_SOCKET_SMOKE_ARMED/.test(text)||Buffer.byteLength(text)>2*1024*1024||/SCRIPT ERROR|^ERROR:/m.test(output))throw Error('Owned socket smoke native/lifecycle evidence failed');
  if(scenario==='wrong-endpoint'){if(rows.length)throw Error('Wrong endpoint was traced');}
  else if(scenario==='cap'){if(rows.length!==32||native.cycles!==20||!/^NATIVE_IPC_TRACE_CAP\r?$/m.test(text))throw Error('Finite trace breakpoint cap failed');}
  else if(!connected||!closed||closed.socket!==connected.socket||closed.sequence<=connected.sequence||!/Debug session time:/.test(text)||!/Child-SP|RetAddr/.test(text))throw Error('Matched close/timestamp/stack evidence missing');
  if(scenario==='host-fin'&&!events.some(row=>row.kind==='intentional-host-fin'))throw Error('Explicit host FIN not issued');
  result.success=true;result.native=native;result.exit=exit;result.trace=rows;result.stackLogBytes=Buffer.byteLength(text);
 }catch(value){result.failure=value.message;}
 finally{
  if(!nativeId&&fs.existsSync(report+'.pid'))nativeId=Number(fs.readFileSync(report+'.pid','utf8'));
  if(child&&!exit){
   const cleanup=path.join(directory,scenario+'.cleanup.ps1');fs.writeFileSync(cleanup,"param([int]$OwnedPid,[string]$Cdb,[string]$Engine,[string]$Report)\n$ErrorActionPreference='Stop'\n$p=Get-CimInstance Win32_Process -Filter ('ProcessId='+$OwnedPid)\nif($p.ExecutablePath-eq$Cdb-and$p.CommandLine.Contains($Report)){Get-CimInstance Win32_Process -Filter ('ParentProcessId='+$OwnedPid)|Where-Object{$_.ExecutablePath-eq$Engine-and$_.CommandLine.Contains($Report)}|ForEach-Object{Stop-Process -Id $_.ProcessId -Force};Stop-Process -Id $OwnedPid -Force}\n");
   result.cleanupExit=spawnSync('pwsh.exe',['-NoProfile','-File',cleanup,'-OwnedPid',String(child.pid),'-Cdb',cdb,'-Engine',engine,'-Report',report],{windowsHide:true,timeout:10000,maxBuffer:8192}).status;
  }
  for(const socket of sockets)socket.destroy();await Promise.all([new Promise(resolve=>server.close(resolve)),new Promise(resolve=>other.close(resolve))]);
  result.debuggerId=child?.pid??null;result.nativeId=nativeId;result.debuggerGone=!child||processGone(child.pid);result.nativeGone=!nativeId||processGone(nativeId);result.success=result.success&&result.debuggerGone&&result.nativeGone;
  fs.writeFileSync(path.join(directory,scenario+'.output.log'),output);fs.writeFileSync(path.join(directory,scenario+'.json'),JSON.stringify(result,null,2)+'\n');
 }
 return result;
}
const only=process.argv.find(value=>value.startsWith('--case='))?.slice(7);if(only&&only!=='cap')throw Error('Only explicit cap-stress extension is supported');
const scenarios=only?['cap']:['host-fin','native-disconnect','wrong-endpoint'];
for(const scenario of scenarios){const result=await run(scenario);all.push(result);if(!result.success){failure=result.failure??'Owned cleanup failed';break;}}
const changed=files.filter(file=>hash(fs.readFileSync(path.join(project,file)))!==inputs[file]);
const result={success:!failure&&!changed.length&&all.length===scenarios.length&&all.every(row=>row.success),failure,changed,inputs,cases:all,gameNetworkConnections:0,protectedKeyReads:0,nativeBuilds:0,gpu:false,scope:'No-resource/no-key headless Godot/CDB/private-loopback tracer cases: explicit Host FIN, native-owned disconnect, ignored wrong endpoint, or targeted32-event cap stress. Endpoint/handle/timestamp/bounded close stacks only; no normal transport change.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({...result,inputs:files.length,cases:all.map(row=>({scenario:row.scenario,success:row.success,failure:row.failure,trace:row.trace,stackLogBytes:row.stackLogBytes}))}));process.exitCode=result.success?0:1;
