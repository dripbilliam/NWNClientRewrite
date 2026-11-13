// Starts only a previously composed and headless-tested launch capsule.
// `menu-check` is a bounded no-server/headless handshake; `manual` opens Main
// Menu for the user without selecting or joining a server. `local-check` uses
// only the existing host's bounded127.0.0.1:5121 original-server fixture.
// `menu-visual-check` uses the actual headed menu/art readiness/Exit route,
// without exposing public endpoints or logging into any server.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn,spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {verifyClientLaunchEngine} from './client_launch_engine.mjs';
import {verifyClientLaunchDisplay,verifyMotionBoundaryProof} from './client_launch_proofs.mjs';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),root=path.dirname(source);
const [label,mode,run]=process.argv.slice(2);
if(!/^parity-launch-[a-z0-9-]+$/.test(label??'')||!['menu-check','menu-visual-check','manual','local-check'].includes(mode)||!/^[a-z0-9-]{6,100}$/.test(run??''))throw Error('Explicit capsule label, supported launch/check mode and unique run required');
const folder=path.join(source,'.cache/native-presentation-parity/loading-agent',label),launchFile=path.join(folder,'launch.json'),launch=JSON.parse(fs.readFileSync(launchFile)),manifest=JSON.parse(fs.readFileSync(launch.rendererManifest));
verifyClientLaunchEngine(manifest.engine);
if(launch.engine.path!==manifest.engine.path||launch.engine.sha256!==manifest.engine.sha256||launch.engine.descriptorSha256!==manifest.engine.descriptorSha256)throw Error('Launch engine differs from accepted renderer');
const hash=raw=>crypto.createHash('sha256').update(raw).digest('hex');
if(hash(fs.readFileSync(launch.rendererManifest))!==launch.rendererManifestSha256)throw Error('Renderer manifest differs');
const pins=[...manifest.pins.map(pin=>({file:path.join(manifest.project,pin.relative),sha256:pin.sha256})),...launch.wrapperPins,launch.originalHost,launch.originalBootstrap,...(manifest.toolProofs??[])];
const changed=()=>pins.filter(pin=>hash(fs.readFileSync(pin.file))!==pin.sha256).map(pin=>pin.file);
if(changed().length||hash(fs.readFileSync(launch.engine.path))!==launch.engine.sha256)throw Error('Protected runtime/source pins differ');
const acceptedDirectory=path.join(folder,fs.existsSync(path.join(folder,'acceptance-continuation-v1/run.json'))?'acceptance-continuation-v1':'acceptance');
const accepted=JSON.parse(fs.readFileSync(path.join(acceptedDirectory,'run.json')));
const acceptedStageFile=path.join(acceptedDirectory,'stage.json'),acceptedStage=JSON.parse(fs.readFileSync(acceptedStageFile));
if(accepted.continuation)for(const pin of [accepted.continuation.run,accepted.continuation.stage])if(hash(fs.readFileSync(pin.file))!==pin.sha256)throw Error('Prior fixture evidence changed');
const acceptedOrder=['compile',...acceptedStage.fixtures.map(row=>row.name)];
if(accepted.success!==true||accepted.capsule.sha256!==launch.rendererManifestSha256||accepted.stage?.sha256!==hash(fs.readFileSync(acceptedStageFile))||acceptedStage.capsule.sha256!==launch.rendererManifestSha256||accepted.results.length!==acceptedOrder.length||accepted.results.some((row,index)=>!row.success||row.name!==acceptedOrder[index]))throw Error('Merged-capsule headless compatibility receipt not accepted');
const screen=manifest.launch.screen;
if(manifest.launch.display){verifyClientLaunchDisplay(manifest.launch.display);if(screen!==manifest.launch.display.screen)throw Error('Display selector differs');}
else if(screen!==1)throw Error('Legacy display configuration differs');
if(manifest.motionBoundary)verifyMotionBoundaryProof(manifest.motionBoundary,manifest.pins.find(pin=>pin.relative==='systems/network_motion.gd')?.sha256);
if(!Number.isSafeInteger(screen)||screen<0||launch.arguments.filter(value=>value==='--native-screen='+screen).length!==1||!launch.modes.includes('--highlight=native-bounds')||!launch.modes.includes('--native-overhead-clocks=true')||!manifest.highlightRuntime||!manifest.clockRuntime)throw Error('Reviewed secondary-monitor/highlight/native-clock runtime config missing');
const output=path.join(source,'reports',run+'.json'),nativeOutput=path.join(source,'reports',run+'.native.json'),receipt=path.join(folder,run+'.launch.json');
for(const file of [output,nativeOutput,receipt])if(fs.existsSync(file))throw Error('Existing launch/run evidence preserved');
const electron=path.join(root,'node_modules/electron/dist/electron.exe');
const args=[launch.bootstrap,'--run='+run,...(mode==='manual'?launch.arguments:mode==='local-check'?['--native-runtime=editor','--native-profile','--render-profile=gameplay','--native-screen='+screen,'--local-check','--local-cycles=1']:['--native-runtime=editor','--native-profile','--render-profile=gameplay','--native-screen='+screen,'--menu-check','--menu-exit-check',...(mode==='menu-check'?['--native-headless']:[])])];
if(args.some(value=>value.startsWith('--server=')||value.startsWith('--private-login-pipe=')))throw Error('Automatic login forbidden');
if(mode==='local-check'&&(args.includes('--public-servers')||args.includes('--native-headless')))throw Error('Local acceptance must use original graphical localhost route only');
const env={...process.env,NWN_PARTICLE_KERNEL:'compiled'};
for(const key of ['ELECTRON_RUN_AS_NODE','NWN_RECORD_LOADING','NWN_NATIVE_SOCKET_TRACE'])delete env[key];
const started=new Date().toISOString(),stdoutFile=path.join(folder,run+'.stdout.log'),stderrFile=path.join(folder,run+'.stderr.log');
const stdout=fs.openSync(stdoutFile,'wx'),stderr=fs.openSync(stderrFile,'wx');
const proof={version:1,mode,run,started,executable:electron,args,rendererManifest:launch.rendererManifest,rendererSha256:launch.rendererManifestSha256,engine:launch.engine,nativeBinary:manifest.nativeBinary,output,nativeOutput,automaticConnections:mode==='local-check'?1:0,expectedEndpoint:mode==='local-check'?'127.0.0.1:5121':null,nativeBuilds:0,sharedRuntimeEdits:0};
if(mode==='manual'){
 const child=spawn(electron,args,{cwd:root,env,windowsHide:true,detached:true,stdio:['ignore',stdout,stderr]});
 fs.closeSync(stdout);fs.closeSync(stderr);child.unref();
 fs.writeFileSync(receipt,JSON.stringify({...proof,pid:child.pid,launched:true,scope:'Manual Main Menu launch only; no assertion of subsequent user login/rendering performance.'},null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({started:true,pid:child.pid,run,receipt}));
}else{
 const child=spawnSync(electron,args,{cwd:root,env,windowsHide:true,timeout:mode==='local-check'?150000:90000,stdio:['ignore',stdout,stderr]});fs.closeSync(stdout);fs.closeSync(stderr);
 let report=null,native=null;try{report=JSON.parse(fs.readFileSync(output));}catch{}try{native=JSON.parse(fs.readFileSync(nativeOutput));}catch{}
 const logs=fs.readFileSync(stdoutFile,'utf8')+'\n'+fs.readFileSync(stderrFile,'utf8')+'\n'+(typeof report?.engineErrors==='string'?report.engineErrors:'');
 const errors=logs.split(/\r?\n/).filter(line=>/SCRIPT ERROR|^ERROR:|Parse Error|ObjectDB instances (?:were )?leaked|resources still in use|Invalid call/.test(line));
 const sourceChanged=changed(),first=report?.startupMainMenu;
 const visibility=native?.native_scene_visibility,visibilityActive=(visibility?.stats?.accepted_worlds??0)>0;
 const startupWindow=native?.startup_window??report?.native?.startup_window;
 const displayAccepted=mode==='menu-check'||startupWindow?.screen===screen&&startupWindow?.primary!==screen&&startupWindow?.non_activating===true;
 const specific=mode==='local-check'?report?.endpoint==='127.0.0.1:5121'&&report?.nativeExit===0&&!report?.forcedNativeStop&&report?.sourceUnchanged===true&&report?.localCycles?.length===1&&report?.localWalkDistance>0.2&&report?.authoritativeDistance>0.2&&report?.authoritativeDistance<2&&native?.success===true&&native?.workers_remaining===0&&native?.protocol_finish_ack===true&&native?.clean_exit===true:first?.ready===true&&first?.mainVisible===true&&first?.browserHidden===true&&first?.lobbyHidden===true;
 const success=child.status===0&&!child.error&&report?.success===true&&report?.publicConnections===0&&specific&&displayAccepted&&(mode!=='local-check'||visibilityActive)&&!sourceChanged.length&&!errors.length;
 fs.writeFileSync(receipt,JSON.stringify({...proof,success,finished:new Date().toISOString(),exit:child.status,error:child.error?.message??null,sourceChanged,errors,startupSurface:report?.startupSurface,startupMainMenu:first,startupWindow,displayAccepted,publicConnections:report?.publicConnections,nativeSuccess:native?.success,endpoint:report?.endpoint??null,localWalkDistance:report?.localWalkDistance??null,authoritativeDistance:report?.authoritativeDistance??null,nativeExit:report?.nativeExit??null,visibilityActive,nativeSceneVisibility:visibility,scope:mode==='local-check'?'Actual normal graphical client against existing original localhost server: installed Wizard selection, received world with accepted native visibility inputs, native/server movement, UI/settings probes and graceful lifecycle. No public-server, seven-feature visual or FPS claim.':mode==='menu-visual-check'?'Actual headed normal Main Menu/art readiness/visible-tree and original Exit handshake, no server connection or seven-feature/FPS claim.':'Actual normal native entry and original Main Menu Exit handshake, headless/no server or visual/FPS claim.'},null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({success,exit:child.status,error:child.error?.message??null,startupSurface:report?.startupSurface,startupMainMenu:first,publicConnections:report?.publicConnections,errors:errors.slice(0,6),sourceChanged,receipt}));process.exitCode=success?0:1;
}
