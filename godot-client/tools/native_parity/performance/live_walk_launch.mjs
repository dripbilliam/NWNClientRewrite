// Explicit diagnostic launch only. Preparation never starts an executable.
// prepare -> menu-check FRESH_RUN -> manual FRESH_RUN. No automatic login.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {spawn,spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
import {verifyClientLaunchEngine} from '../loading/client_launch_engine.mjs';
import {verifyClientLaunchDisplay} from '../loading/client_launch_proofs.mjs';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),workspace=path.dirname(source),cache=path.join(source,'.cache/native-presentation-parity/root');
const directory=path.join(cache,'live-walk-candidate-v1'),project=path.join(directory,'project'),manifestFile=path.join(directory,'manifest.json'),manifestSha='92c8c6591d252b480d8afa3297aedcc68fbec1c5d6d997cc5a4869df13a5a504';
const parentDirectory=path.join(cache,'whole-character-client-v3'),parentSha='7a7059598b4f114bba55a44863d7938b6590542c5cfce97a778c3249a0a02c43',parentLaunchSha='70c11d7aeaf8dfde1f81d59e93689026fd5dc65651df53a1f5a6d038c10c1ad4';
const preflightPin={file:path.join(directory,'preflight-v1/run.json'),sha256:'74d26e5330e5a5cec9f033af839f042696a2bfacb9d31f7b3d46846fd31d1f4e'};
const wrapperDirectory=path.join(directory,'launcher-v1'),planFile=path.join(wrapperDirectory,'plan.json'),menuFile=path.join(wrapperDirectory,'menu-check.json');
const [action,run,...extra]=process.argv.slice(2);if(extra.length||!['prepare','menu-check','manual'].includes(action)||action==='prepare'&&run!==undefined||action!=='prepare'&&!/^live-walk-[a-z0-9-]{3,85}$/.test(run??''))throw Error('Use prepare, or menu-check|manual with a fresh live-walk-* run label');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),read=file=>fs.readFileSync(file),json=file=>JSON.parse(read(file)),write=(file,value)=>fs.writeFileSync(file,JSON.stringify(value,null,2)+'\n',{flag:'wx'});
function requireValue(value,message){if(!value)throw Error(message);}
function checked(pin){requireValue(pin&&typeof pin.file==='string'&&/^[a-f0-9]{64}$/.test(pin.sha256??''),'Invalid launch pin');const bytes=read(pin.file);requireValue(sha(bytes)===pin.sha256,'Launch input changed: '+pin.file);return bytes;}
const manifest=JSON.parse(checked({file:manifestFile,sha256:manifestSha})),parent=JSON.parse(checked({file:path.join(parentDirectory,'manifest.json'),sha256:parentSha}));
requireValue(manifest.kind==='live-walk-diagnostic-stage'&&manifest.validationState==='staged-not-validated'&&manifest.releaseReady===false&&manifest.project===project&&manifest.base.sha256===parentSha&&manifest.mode==='--highlight=whole-character'&&manifest.parkedWorkIncluded===false,'Exact diagnostic candidate policy required');
requireValue(manifest.engine.sha256==='62f54a7f7ff4638987730a246833cea4054779e7cb2a333bb5921fd5b0aea6dc'&&manifest.pins.find(p=>p.relative==='.cache/native-kernel/nwn-particle-kernel.dll')?.sha256==='672bd24ae23f0be06bb209bc40ec5083fbe8ac14e92b2dd6b10f836255a840ea','Engine/particle binary differs');
verifyClientLaunchEngine(manifest.engine);verifyClientLaunchDisplay(manifest.display);
for(const pin of manifest.pins)checked({file:path.join(project,pin.relative),sha256:pin.sha256});
for(const pin of manifest.proofPins)checked(pin);
const preflight=JSON.parse(checked(preflightPin));
requireValue(preflight.success===true&&preflight.exit===0&&preflight.error===null&&Array.isArray(preflight.errors)&&preflight.errors.length===0&&Array.isArray(preflight.sourceChanged)&&preflight.sourceChanged.length===0&&preflight.manifestSha===manifestSha&&preflight.stage===directory&&preflight.project===project&&preflight.engineSha===manifest.engine.sha256,'Exact complete composed preflight required');
requireValue(Array.isArray(preflight.args)&&preflight.args.includes('--headless')&&preflight.args.includes('--check-only')&&preflight.args.includes('--render-thread')&&preflight.args[preflight.args.indexOf('--render-thread')+1]==='safe'&&preflight.args.includes('res://native_session_world.gd'),'Preflight must type-check the actual complete client entry');
const parentLaunch=JSON.parse(checked({file:path.join(parentDirectory,'launch.json'),sha256:parentLaunchSha}));
requireValue(parentLaunch.manifestSha===parentSha,'V3 launch ancestry differs');
for(const pin of [...parentLaunch.wrapperPins,...parentLaunch.originalPins])checked(pin);
requireValue(manifest.settings.file===path.join(directory,'render-preferences.cfg')&&manifest.settings.mutableAfterUserLaunch===true,'Exact mutable candidate preferences path required');
const preferenceAtInvocation=sha(read(manifest.settings.file)); // Capture only; never reset or normalize user preferences.
const pinFor=(rows,name)=>{const pin=rows.find(p=>path.basename(p.file)===name);requireValue(pin,'Missing V3 wrapper/original pin: '+name);return pin;};

if(action==='prepare'){
 requireValue(!fs.existsSync(wrapperDirectory),'Existing wrapper plan preserved');
 const hostPin=pinFor(parentLaunch.wrapperPins,'host-source.cjs'),bootPin=pinFor(parentLaunch.wrapperPins,'bootstrap-source.cjs'),oldLoader=pinFor(parentLaunch.wrapperPins,'host-loader.cjs');
 const originalHost=pinFor(parentLaunch.originalPins,'native-session-host.cjs'),originalBootstrap=pinFor(parentLaunch.originalPins,'native-session-bootstrap.cjs');
 const replacements=[];let host=checked(hostPin).toString('utf8');
 const replace=(before,after,count)=>{const a=JSON.stringify(before),b=JSON.stringify(after);requireValue(host.split(a).length===count+1,'V3 JSON seam differs: '+before);host=host.split(a).join(b);replacements.push({before,after,count});};
 replace(parent.project,project,2);replace(parentLaunch.manifest,manifestFile,2);replace(parentSha,manifestSha,2);replace('--render-preferences='+parent.settings.file,'--render-preferences='+manifest.settings.file,1);
 let restored=host;for(const row of [...replacements].reverse())restored=restored.split(JSON.stringify(row.after)).join(JSON.stringify(row.before));requireValue(restored===checked(hostPin).toString('utf8'),'Host changed beyond exact path/hash substitutions');
 const hostSource=path.join(wrapperDirectory,'host-source.cjs'),hostLoader=path.join(wrapperDirectory,'host-loader.cjs'),bootSource=path.join(wrapperDirectory,'bootstrap-source.cjs'),bootstrap=path.join(wrapperDirectory,'bootstrap-loader.cjs');
 const oldNeedle=JSON.stringify(oldLoader.file),newNeedle=JSON.stringify(hostLoader);let boot=checked(bootPin).toString('utf8');requireValue(boot.split(oldNeedle).length===2,'V3 bootstrap seam differs');boot=boot.replace(oldNeedle,newNeedle);requireValue(boot.replace(newNeedle,oldNeedle)===checked(bootPin).toString('utf8'),'Bootstrap changed beyond host-loader path');
 fs.mkdirSync(wrapperDirectory);
 const loader=(original,file,hash)=>`const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),Module=require('node:module');const original=${JSON.stringify(original.file)},file=${JSON.stringify(file)},sha=b=>crypto.createHash('sha256').update(b).digest('hex');if(sha(fs.readFileSync(original))!==${JSON.stringify(original.sha256)}||sha(fs.readFileSync(file))!==${JSON.stringify(hash)})throw Error('Candidate launcher source changed');const owner=new Module(original,module);owner.filename=original;owner.paths=Module._nodeModulePaths(path.dirname(original));owner._compile(fs.readFileSync(file,'utf8'),original);\n`;
 fs.writeFileSync(hostSource,host,{flag:'wx'});fs.writeFileSync(hostLoader,loader(originalHost,hostSource,sha(Buffer.from(host))),{flag:'wx'});fs.writeFileSync(bootSource,boot,{flag:'wx'});fs.writeFileSync(bootstrap,loader(originalBootstrap,bootSource,sha(Buffer.from(boot))),{flag:'wx'});
 const plan={version:1,manifest:{file:manifestFile,sha256:manifestSha},preflight:preflightPin,parentLaunch:{file:path.join(parentDirectory,'launch.json'),sha256:parentLaunchSha},bootstrap,wrapperPins:[hostSource,hostLoader,bootSource,bootstrap].map(file=>({file,sha256:sha(read(file))})),originalPins:parentLaunch.originalPins,replacements,bootstrapReplacement:{before:oldLoader.file,after:hostLoader,count:1},hostRoundtripExact:true,bootstrapRoundtripExact:true,engine:manifest.engine.sha256,particleDll:'672bd24ae23f0be06bb209bc40ec5083fbe8ac14e92b2dd6b10f836255a840ea',display:manifest.display,mode:manifest.mode,settings:manifest.settings.file,settingsShaAtPreparation:preferenceAtInvocation,launched:false,automaticConnections:0,scope:'Private wrapper preparation only. Full preflight passed; actual Main Menu/Exit gate is still required before manual launch. No settings, flags, manifest or existing launcher changes.'};
 write(planFile,plan);console.log(JSON.stringify({prepared:true,launched:false,plan:{file:planFile,sha256:sha(read(planFile))},wrapperPins:plan.wrapperPins,menuCheckRequired:true}));
 process.exit(0);
}

const plan=json(planFile);requireValue(plan.manifest.sha256===manifestSha&&plan.preflight.sha256===preflightPin.sha256&&plan.hostRoundtripExact&&plan.bootstrapRoundtripExact&&plan.bootstrap===path.join(wrapperDirectory,'bootstrap-loader.cjs'),'Reviewed private wrapper plan required');
for(const pin of [...plan.wrapperPins,...plan.originalPins])checked(pin);
let menuPin=null;
if(action==='manual'){
 const menu=json(menuFile);requireValue(menu.success===true&&menu.manifestSha===manifestSha&&menu.preflight.sha256===preflightPin.sha256&&menu.plan.sha256===sha(read(planFile))&&menu.publicConnections===0&&menu.exit===0&&menu.errors.length===0,'Clean exact-candidate Main Menu and Exit required before manual test');menuPin={file:menuFile,sha256:sha(read(menuFile))};
}else requireValue(!fs.existsSync(menuFile),'Existing menu result preserved');
const reportFile=path.join(source,'reports',run+'.json'),receipt=path.join(directory,run+'.launch.json');
requireValue(!fs.existsSync(receipt)&&!fs.readdirSync(path.join(source,'reports')).some(name=>name===run+'.json'||name.startsWith(run+'.')),'Existing run artifacts preserved; choose a fresh label');
const args=[plan.bootstrap,'--run='+run,'--native-runtime=editor','--native-profile','--render-profile=gameplay','--native-screen='+manifest.display.screen,...(action==='manual'?['--public-servers']:['--menu-check','--menu-exit-check'])];
requireValue(!args.some(arg=>/^--(?:server|private-login-pipe|walk|drive|probe|local-check)(?:=|$)/.test(arg)),'Automatic login/movement forbidden');
const env={...process.env,NWN_PARTICLE_KERNEL:'compiled'};for(const name of ['ELECTRON_RUN_AS_NODE','NWN_RECORD_LOADING','NWN_NATIVE_SOCKET_TRACE'])delete env[name];
const stdoutFile=path.join(directory,run+'.stdout.log'),stderrFile=path.join(directory,run+'.stderr.log'),stdout=fs.openSync(stdoutFile,'wx'),stderr=fs.openSync(stderrFile,'wx'),executable=path.join(workspace,'node_modules/electron/dist/electron.exe');
const detail={action,run,manifestSha,preflight:preflightPin,plan:{file:planFile,sha256:sha(read(planFile))},settingsShaAtLaunch:preferenceAtInvocation,automaticConnections:0,mode:manifest.mode,display:manifest.display,menuProof:menuPin,diagnosticOnly:true,performanceAccepted:false};
if(action==='manual'){
 const child=spawn(executable,args,{cwd:workspace,env,windowsHide:true,detached:true,stdio:['ignore',stdout,stderr]});fs.closeSync(stdout);fs.closeSync(stderr);child.unref();write(receipt,{...detail,pid:child.pid,started:true});console.log(JSON.stringify({...detail,pid:child.pid,started:true,scope:'Main Menu/public server selection only. User controls any connection; startup must be observed from application readiness, not absence of buffered logs.'}));
}else{
 const child=spawnSync(executable,args,{cwd:workspace,env,windowsHide:true,timeout:90000,stdio:['ignore',stdout,stderr]});fs.closeSync(stdout);fs.closeSync(stderr);let report=null;try{report=json(reportFile);}catch{}
 const engineLog=path.join(source,'reports',run+'.engine.log'),text=read(stdoutFile).toString()+'\n'+read(stderrFile).toString()+'\n'+(fs.existsSync(engineLog)?read(engineLog).toString():'')+'\n'+(Array.isArray(report?.engineErrors)?report.engineErrors.join('\n'):String(report?.engineErrors??''));
 const errors=text.split(/\r?\n/).filter(line=>/^ERROR:|SCRIPT ERROR|Parse Error|ObjectDB.*leak|resources still in use|Invalid call/.test(line)),surface=report?.startupMainMenu;
 const sourceChanged=manifest.pins.filter(pin=>sha(read(path.join(project,pin.relative)))!==pin.sha256).map(pin=>pin.relative);
 const success=child.status===0&&!child.error&&report?.success===true&&report?.publicConnections===0&&surface?.ready===true&&surface.mainVisible===true&&surface.browserHidden===true&&surface.lobbyHidden===true&&!errors.length&&!sourceChanged.length&&sha(read(manifestFile))===manifestSha;
 const proof={...detail,success,exit:child.status,error:child.error?.message??null,errors,sourceChanged,surface,publicConnections:report?.publicConnections,scope:'Actual headed Main Menu readiness and Exit with zero connections; not gameplay, visual-parity or performance acceptance'};write(menuFile,proof);write(receipt,proof);console.log(JSON.stringify(proof));if(!success)process.exitCode=1;
}
