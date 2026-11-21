// Narrow candidate launcher: exact V6 plus accepted highlight sources and an
// optional independently validated two-file surface capacity fix. Parked
// fog/camera drafts and unrelated current-main changes are not
// copied. Manual mode opens Main Menu; it never selects/joins a public server.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn,spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {verifyClientLaunchEngine} from '../loading/client_launch_engine.mjs';
import {verifyClientLaunchDisplay} from '../loading/client_launch_proofs.mjs';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),workspace=path.dirname(source);
const [label,action,argument]=process.argv.slice(2);
if(!/^whole-character-client-[a-z0-9-]+$/.test(label??'')||!['stage','menu-check','manual'].includes(action))throw Error('Explicit whole-character-client label and stage|menu-check|manual required');
const directory=path.join(source,'.cache/native-presentation-parity/root',label),project=path.join(directory,'project');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const json=file=>JSON.parse(fs.readFileSync(file));
const write=(file,value)=>fs.writeFileSync(file,JSON.stringify(value,null,2)+'\n',{flag:'wx'});
const surfaceRecovery=process.argv.includes('--surface-recovery');
const overlays=['systems/native_render/selection_highlight.gd','systems/entity_registry.gd','tools/native_parity/highlighting/whole_character_selection.gd','tools/native_parity/highlighting/whole_character_glow.gd',...(surfaceRecovery?['systems/native_render/native_model_material.gd','systems/native_render/native_surface_transfer.gd']:[])];
const baseFile=path.join(source,'.cache/native-presentation-parity/loading-agent/parity-launch-seven-fixes-v6/manifest.json');
const baseBytes=fs.readFileSync(baseFile),base=json(baseFile);
if(sha(baseBytes)!=='8dc208537d602078c588f49e59dd4a81aed9b90c38b2a02a2326b1515db3f3e7')throw Error('Frozen V6 manifest changed');
verifyClientLaunchEngine(base.engine);verifyClientLaunchDisplay(base.launch.display);
const baseLaunch=json(path.join(path.dirname(baseFile),'launch.json'));
if(action==='stage'){
 if(!argument||fs.existsSync(directory))throw Error('Fresh candidate and accepted graphical receipt required');
 const proofFile=path.resolve(argument),proof=json(proofFile);
 const stageFile=proof.stage?.file,stage=stageFile?json(stageFile):null;
 if(!proof.success||proof.exit!==0||proof.errors?.length||proof.sourceChanged?.length||proof.candidateChanged?.length||proof.originalChanged?.length||!proof.result?.success||proof.result.checks<45||!stage||sha(fs.readFileSync(stageFile))!==proof.stage.sha256||stage.parent?.sha256!==sha(baseBytes))throw Error('Clean actual-model graphical proof required');
 for(const relative of overlays){const pin=stage.overlays.find(row=>row.relative===relative);if(!pin||sha(fs.readFileSync(path.join(source,relative)))!==pin.sha256)throw Error('Graphically tested highlight source changed: '+relative);}
 let recoveryProof=null;
 if(surfaceRecovery){
  const file=path.join(source,'.cache/native-presentation-parity/root/surface-capacity-candidate-v2/review.json'),bytes=fs.readFileSync(file),review=JSON.parse(bytes);
  if(sha(bytes)!=='17c66f5e5a2d12ee2b557756cef7d565aa473331c9b7f8df567b2896389495a2'||review.accepted!==true||review.cases.length!==3||review.primaryBackstopLargeImageEqual!==true)throw Error('Actual large-scene capacity comparison required');
  const cases=review.cases.map(row=>{if(sha(fs.readFileSync(row.file))!==row.sha256)throw Error('Capacity receipt changed');const result=json(row.file);if(result.success!==true||result.exit!==0||result.unexpectedErrors?.length||result.sourceChanged?.length||result.inputSourceChanged?.length)throw Error('Capacity case not accepted');return {file:row.file,sha256:row.sha256};});
  recoveryProof={file,sha256:sha(bytes),cases,bufferEntries:1048576,defaultPerMeshFogCarrier:false};
 }
 fs.mkdirSync(project,{recursive:true});const pins=[];
 for(const original of base.pins){
  const from=path.join(base.project,original.relative),bytes=fs.readFileSync(from);
  if(sha(bytes)!==original.sha256)throw Error('Frozen V6 source changed: '+original.relative);
  if(overlays.includes(original.relative))continue;
  const dest=path.join(project,original.relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes,{flag:'wx'});pins.push({...original});
 }
 for(const relative of overlays){const bytes=fs.readFileSync(path.join(source,relative)),dest=path.join(project,relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes,{flag:'wx'});pins.push({relative,sha256:sha(bytes),overlay:true});}
 if(surfaceRecovery){
  const file=path.join(project,'project.godot'),text=fs.readFileSync(file,'utf8');
  if(text.split('[rendering]').length!==2||text.includes('limits/global_shader_variables/buffer_size'))throw Error('Exact project buffer-setting seam differs');
  const corrected=text.replace('[rendering]','[rendering]\n\nlimits/global_shader_variables/buffer_size=1048576');fs.writeFileSync(file,corrected);const pin=pins.find(row=>row.relative==='project.godot');pin.sha256=sha(Buffer.from(corrected));pin.overlay=true;
 }
 const settings=path.join(directory,'render-preferences.cfg');fs.copyFileSync(base.settings.file,settings,fs.constants.COPYFILE_EXCL);
 const manifest={version:1,label,project,base:{file:baseFile,sha256:sha(baseBytes)},engine:base.engine,display:base.launch.display,pins,overlays,visualProof:{file:proofFile,sha256:sha(fs.readFileSync(proofFile)),stage:proof.stage,checks:proof.result.checks},recoveryProof,settings:{file:settings,initialSha256:sha(fs.readFileSync(settings)),mutableAfterUserLaunch:true},mode:'--highlight=whole-character',parkedWorkIncluded:false,serverConnections:0,nativeBuilds:0,launchState:'unlaunched'};
 const manifestFile=path.join(directory,'manifest.json');write(manifestFile,manifest);const manifestSha=sha(fs.readFileSync(manifestFile));
 const hostFile=baseLaunch.wrapperPins.find(pin=>path.basename(pin.file)==='host-source.cjs');
 const bootFile=baseLaunch.wrapperPins.find(pin=>path.basename(pin.file)==='bootstrap-source.cjs');
 for(const pin of [...baseLaunch.wrapperPins,baseLaunch.originalHost,baseLaunch.originalBootstrap])if(sha(fs.readFileSync(pin.file))!==pin.sha256)throw Error('Original launcher/protocol pin changed');
 const replace=(text,before,after,count)=>{const needle=JSON.stringify(before);if(text.split(needle).length!==count+1)throw Error('Exact launcher seam differs: '+before);return text.split(needle).join(JSON.stringify(after));};
 let host=fs.readFileSync(hostFile.file,'utf8');
 host=replace(host,base.project,project,2);host=replace(host,baseFile,manifestFile,2);host=replace(host,sha(baseBytes),manifestSha,2);host=replace(host,'--render-preferences='+base.settings.file,'--render-preferences='+settings,1);host=replace(host,'--highlight=native-bounds','--highlight=whole-character',1);
 const hostSource=path.join(directory,'host-source.cjs'),hostLoader=path.join(directory,'host-loader.cjs');fs.writeFileSync(hostSource,host,{flag:'wx'});
 const loader=(original,file)=>`const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),Module=require('node:module');const original=${JSON.stringify(original.file)},file=${JSON.stringify(file)},sha=b=>crypto.createHash('sha256').update(b).digest('hex');if(sha(fs.readFileSync(original))!==${JSON.stringify(original.sha256)}||sha(fs.readFileSync(file))!==${JSON.stringify(sha(fs.readFileSync(file)))})throw Error('Candidate launcher source changed');const owner=new Module(original,module);owner.filename=original;owner.paths=Module._nodeModulePaths(path.dirname(original));owner._compile(fs.readFileSync(file,'utf8'),original);\n`;
 fs.writeFileSync(hostLoader,loader(baseLaunch.originalHost,hostSource),{flag:'wx'});
 const oldHostLoader=baseLaunch.wrapperPins.find(pin=>path.basename(pin.file)==='host-loader.cjs').file;
 const boot=replace(fs.readFileSync(bootFile.file,'utf8'),oldHostLoader,hostLoader,1),bootSource=path.join(directory,'bootstrap-source.cjs'),bootstrap=path.join(directory,'bootstrap-loader.cjs');
 fs.writeFileSync(bootSource,boot,{flag:'wx'});fs.writeFileSync(bootstrap,loader(baseLaunch.originalBootstrap,bootSource),{flag:'wx'});
 write(path.join(directory,'launch.json'),{manifest:manifestFile,manifestSha,bootstrap,wrapperPins:[hostSource,hostLoader,bootSource,bootstrap].map(file=>({file,sha256:sha(fs.readFileSync(file))})),originalPins:[...baseLaunch.wrapperPins.filter(pin=>!['host-source.cjs','host-loader.cjs','bootstrap-source.cjs','bootstrap-loader.cjs'].includes(path.basename(pin.file))),baseLaunch.originalHost,baseLaunch.originalBootstrap]});
 console.log(JSON.stringify({staged:true,directory,sourcePins:pins.length,overlays,parkedWorkIncluded:false,launched:false}));
}else{
 if(!/^[a-z0-9-]{6,100}$/.test(argument??''))throw Error('Explicit fresh run label required');
 const launch=json(path.join(directory,'launch.json')),manifest=json(launch.manifest);
 if(sha(fs.readFileSync(launch.manifest))!==launch.manifestSha||manifest.mode!=='--highlight=whole-character'||manifest.parkedWorkIncluded!==false)throw Error('Candidate identity changed');
 for(const pin of [...manifest.pins.map(pin=>({file:path.join(project,pin.relative),sha256:pin.sha256})),...launch.wrapperPins,...launch.originalPins,manifest.visualProof,manifest.visualProof.stage,...(manifest.recoveryProof?[manifest.recoveryProof,...manifest.recoveryProof.cases]:[])])if(sha(fs.readFileSync(pin.file))!==pin.sha256)throw Error('Candidate/proof source pin changed: '+pin.file);
 const menuProof=path.join(directory,'menu-check.json');
 if(action==='manual'&&(!fs.existsSync(menuProof)||json(menuProof).success!==true||json(menuProof).manifestSha!==launch.manifestSha))throw Error('Actual Main Menu check must pass before user launch');
 const output=path.join(source,'reports',argument+'.json'),receipt=path.join(directory,argument+'.launch.json');for(const file of [output,receipt,path.join(source,'reports',argument+'.native.json')])if(fs.existsSync(file))throw Error('Existing run preserved');
 const args=[launch.bootstrap,'--run='+argument,'--native-runtime=editor','--native-profile','--render-profile=gameplay','--native-screen='+manifest.display.screen,...(action==='manual'?['--public-servers']:['--menu-check','--menu-exit-check'])];
 if(args.some(arg=>arg.startsWith('--server=')||arg.startsWith('--private-login-pipe=')))throw Error('Automatic login forbidden');
 const env={...process.env,NWN_PARTICLE_KERNEL:'compiled'};for(const key of ['ELECTRON_RUN_AS_NODE','NWN_RECORD_LOADING','NWN_NATIVE_SOCKET_TRACE'])delete env[key];
 const stdout=fs.openSync(path.join(directory,argument+'.stdout.log'),'wx'),stderr=fs.openSync(path.join(directory,argument+'.stderr.log'),'wx'),executable=path.join(workspace,'node_modules/electron/dist/electron.exe');
 const detail={action,run:argument,manifestSha:launch.manifestSha,automaticConnections:0,mode:manifest.mode};
 if(action==='manual'){
  const child=spawn(executable,args,{cwd:workspace,env,windowsHide:true,detached:true,stdio:['ignore',stdout,stderr]});fs.closeSync(stdout);fs.closeSync(stderr);child.unref();write(receipt,{...detail,pid:child.pid,started:true});console.log(JSON.stringify({...detail,pid:child.pid,started:true}));
 }else{
  if(fs.existsSync(menuProof))throw Error('Previous Main Menu proof preserved');
  const child=spawnSync(executable,args,{cwd:workspace,env,windowsHide:true,timeout:90000,stdio:['ignore',stdout,stderr]});fs.closeSync(stdout);fs.closeSync(stderr);
  let report=null;try{report=json(output);}catch{}
  const text=fs.readFileSync(path.join(directory,argument+'.stdout.log'),'utf8')+'\n'+fs.readFileSync(path.join(directory,argument+'.stderr.log'),'utf8')+'\n'+(report?.engineErrors??'');
  const errors=text.split(/\r?\n/).filter(line=>/^ERROR:|SCRIPT ERROR|Parse Error|ObjectDB.*leak|resources still in use|Invalid call/.test(line));
  const surface=report?.startupMainMenu,success=child.status===0&&!child.error&&report?.success===true&&report?.publicConnections===0&&surface?.ready===true&&surface?.mainVisible===true&&surface?.browserHidden===true&&surface?.lobbyHidden===true&&!errors.length;
  const proof={...detail,success,exit:child.status,error:child.error?.message??null,errors,surface,publicConnections:report?.publicConnections,scope:'Actual headed Main Menu readiness and Exit; no server connection, world/FPS claim'};write(menuProof,proof);write(receipt,proof);console.log(JSON.stringify(proof));if(!success)process.exitCode=1;
 }
}
