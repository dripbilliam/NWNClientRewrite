// Materializes a reviewed seven-fix/140-performance composition. Staging only:
// no Electron/Godot launch, credential access, settings writes or native build.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {stageHighlightRuntime} from '../highlighting/stage_highlight_runtime.mjs';
import {stageRevealClockRuntime} from '../visibility/stage_reveal_clock_runtime.mjs';
import {selectClientLaunchEngine} from './client_launch_engine.mjs';
import {selectClientLaunchDisplay,selectMotionBoundaryProof} from './client_launch_proofs.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),root=path.dirname(project);
const label=process.argv[2];if(!/^parity-launch-[a-z0-9-]+$/.test(label??''))throw Error('Explicit launch label required');
const folder=path.join(project,'.cache/native-presentation-parity/loading-agent',label),copy=path.join(folder,'project');
if(fs.existsSync(copy)||fs.existsSync(path.join(folder,'manifest.json')))throw Error('Existing capsule preserved');
const sha=raw=>crypto.createHash('sha256').update(raw).digest('hex');
const auditFile=path.join(folder,'audit.json'),compositionFile=path.join(folder,'composition.json');
const audit=JSON.parse(fs.readFileSync(auditFile)),composition=JSON.parse(fs.readFileSync(compositionFile));
if(composition.conflicts.length)throw Error('Unresolved three-way conflicts');
if(sha(fs.readFileSync(audit.parent.file))!==audit.parent.sha256)throw Error('Frozen source parent changed');
const parent=JSON.parse(fs.readFileSync(audit.parent.file));
for(const row of composition.beforeOwners){
 if(sha(fs.readFileSync(row.before.file))!==row.before.sha256||sha(fs.readFileSync(row.current.file))!==row.current.sha256||sha(fs.readFileSync(row.output.file))!==row.output.sha256)throw Error('Composition proof changed: '+row.relative);
}
const engine=selectClientLaunchEngine(project),engineDescriptor=engine.descriptor;
const display=selectClientLaunchDisplay(project);
fs.mkdirSync(copy,{recursive:true});const pins=[],changes=[],retained=[];
for(const pin of parent.pins){
 const raw=fs.readFileSync(path.join(parent.project,pin.relative));if(sha(raw)!==pin.sha256)throw Error('Frozen parent source changed: '+pin.relative);
 const file=path.join(copy,pin.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,raw);pins.push({...pin});
}
for(const row of composition.beforeOwners){
 const file=path.join(copy,row.relative),raw=fs.readFileSync(row.output.file);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,raw);
 const pin=pins.find(value=>value.relative===row.relative);if(pin)pin.sha256=sha(raw);else pins.push({relative:row.relative,sha256:sha(raw)});
 changes.push({relative:row.relative,kind:'exact-before-feature-three-way',before:row.before,current:row.current,frozen:row.frozen,after:sha(raw)});
}
for(const row of audit.rows.filter(row=>row.status==='current-only')){
 if(row.relative.includes('/backups/')||row.relative.includes('/before-'))continue;
 const source=path.join(project,row.relative),raw=fs.readFileSync(source);if(sha(raw)!==row.currentSha256)throw Error('New source changed since audit: '+row.relative);
 const file=path.join(copy,row.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,raw);pins.push({relative:row.relative,sha256:sha(raw)});changes.push({relative:row.relative,kind:'new-parity-source',source,after:sha(raw)});
}
const changed=new Set(changes.map(row=>row.relative));for(const row of audit.rows)if(row.status==='different'&&!changed.has(row.relative))retained.push(row.relative);
const dll=pins.find(pin=>pin.relative==='.cache/native-kernel/nwn-particle-kernel.dll');
if(dll?.sha256!=='672bd24ae23f0be06bb209bc40ec5083fbe8ac14e92b2dd6b10f836255a840ea')throw Error('Compatible frozen DLL672 missing');
// Add the independently reviewed highlight module before the immutable capsule
// manifest. Particle/pose DLL672 and all frozen render defaults stay intact.
const highlightRuntime=stageHighlightRuntime(copy);
const clockRuntime=stageRevealClockRuntime(copy);
for(const pin of [...highlightRuntime.pins,...clockRuntime.pins]){
 if(pins.some(row=>row.relative===pin.relative))throw Error('Unexpected existing reviewed runtime pin');
 pins.push(pin);changes.push({relative:pin.relative,kind:highlightRuntime.pins.includes(pin)?'reviewed-highlight-runtime':'reviewed-native-clock-runtime',after:pin.sha256});
}
const noFocus=fs.readFileSync(path.join(copy,'project.godot'),'utf8').includes('window/size/no_focus=true');if(!noFocus)throw Error('Non-activating startup lost');
const settingsFile=path.join(folder,'render-preferences.cfg');fs.copyFileSync(path.join(copy,'benchmark-options.cfg'),settingsFile);
const settingsText=fs.readFileSync(settingsFile,'utf8');if(!settingsText.includes('gamma=1.2')||!settingsText.includes('profiling_enabled=true'))throw Error('Known user gamma/profiling profile lost');
const transportProofs=['tools/raw-tile-visibility.cjs','tools/raw-creature-visibility-permission.cjs','tools/raw-entity-lifetime.cjs'].map(relative=>{
 const file=path.join(project,relative);return {file,sha256:sha(fs.readFileSync(file)),role:'fresh-native-visibility-event-transport'};
});
const motionBoundary=selectMotionBoundaryProof(project,pins.find(pin=>pin.relative==='systems/network_motion.gd')?.sha256);
const toolProofs=['compose_client_launch_sources.mjs','prepare_client_launch_audit.mjs','stage_client_launch_capsule.mjs','check_client_launch_capsule.mjs','run_client_launch_capsule.mjs','client_launch_engine.mjs','client_launch_proofs.mjs'].map(name=>{const file=path.join(project,'tools/native_parity/loading',name);return {file,sha256:sha(fs.readFileSync(file))};});
const manifest={version:2,label,project:copy,created:new Date().toISOString(),parent:audit.parent,priorCapsule:audit.priorCapsule,audit:{file:auditFile,sha256:sha(fs.readFileSync(auditFile))},composition:{file:compositionFile,sha256:sha(fs.readFileSync(compositionFile))},changes,pins,retainedFrozenOverrides:retained,engine:{...engine,descriptor:engineDescriptor,descriptorSha256:sha(fs.readFileSync(engineDescriptor))},highlightRuntime,clockRuntime,transportProofs,toolProofs,motionBoundary,nativeBinary:{relative:dll.relative,sha256:dll.sha256,sourceProject:parent.project,relocatedWithoutBuild:true},settings:{file:settingsFile,initialSha256:sha(Buffer.from(settingsText)),mutableAfterUserLaunch:true,gamma:1.2,source:'Exact frozen last manual profile; normal protected login/profile settings broker remains owner'},launch:{mainMenu:true,manualServerSelection:true,screen:display.screen,display,startUnfocusable:true,pointerCapture:false,profile:true,renderThread:'separate',profileName:'gameplay',lighting:'enhanced',lightHistory:true,surfaceOutput:true,maxLights:32,postprocess:{mask:28,midpoint:0.4,intensity:0.15,vibrance:0.7}},sharedFilesChanged:0,nativeBuilds:0,serverConnections:0,credentialsRead:0,compiled:false,launched:false};
const manifestFile=path.join(folder,'manifest.json');fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
const host=path.join(project,'tools/native-session-host.cjs'),bootstrap=path.join(project,'tools/native-session-bootstrap.cjs');
const hostText=fs.readFileSync(host,'utf8'),bootText=fs.readFileSync(bootstrap,'utf8');
const once=(text,from,to)=>{if(text.split(from).length!==2)throw Error('Launch seam differs: '+from);return text.replace(from,to);};
const selection={kind:'editor',executable:engine.path,directory:root,executableSha256:engine.sha256,privateCandidate:true,rendererManifest:manifestFile,rendererManifestSha256:sha(fs.readFileSync(manifestFile))};
let patched=once(hostText,"const runtimeSelection=await require('./native-engine-runtime.cjs').selectNativeRuntime(project,engineRuntime,enginePackage);",'const runtimeSelection='+JSON.stringify(selection)+';');
patched=once(patched,"['--path',project]","['--path',"+JSON.stringify(copy)+']');
const modes=['--particle-random=native','--particle-clocks=native','--particle-pose-leases=managed','--light-input-registry=builtin','--drive-collision=indexed','--highlight=native-bounds','--native-overhead-clocks=true','--render-preferences='+settingsFile];
patched=once(patched,'let launch=executable,launchArgs=nativeArgs;',`nativeArgs.splice(nativeArgs.indexOf('--'),0,'--render-thread','separate');nativeArgs.push(...${JSON.stringify(modes)});report.parityLaunchCapsule=${JSON.stringify({file:manifestFile,sha256:sha(fs.readFileSync(manifestFile)),renderer:copy,engine:engine.sha256,dll:dll.sha256})};\n let launch=executable,launchArgs=nativeArgs;`);
const hostSource=path.join(folder,'host-source.cjs'),hostLoader=path.join(folder,'host-loader.cjs'),bootSource=path.join(folder,'bootstrap-source.cjs'),bootLoader=path.join(folder,'bootstrap-loader.cjs');
fs.writeFileSync(hostSource,patched,{flag:'wx'});
const loader=(original,source,originalSha,sourceSha)=>`const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),Module=require('node:module');\nconst original=${JSON.stringify(original)},source=${JSON.stringify(source)},sha=b=>crypto.createHash('sha256').update(b).digest('hex');\nif(sha(fs.readFileSync(original))!==${JSON.stringify(originalSha)}||sha(fs.readFileSync(source))!==${JSON.stringify(sourceSha)})throw Error('Protected capsule launcher source changed');\nconst owner=new Module(original,module);owner.filename=original;owner.paths=Module._nodeModulePaths(path.dirname(original));owner._compile(fs.readFileSync(source,'utf8'),original);\n`;
fs.writeFileSync(hostLoader,loader(host,hostSource,sha(Buffer.from(hostText)),sha(Buffer.from(patched))),{flag:'wx'});
const patchedBoot=once(bootText,"[path.join(__dirname,'native-session-host.cjs'),...args]",'['+JSON.stringify(hostLoader)+',...args]');
fs.writeFileSync(bootSource,patchedBoot,{flag:'wx'});fs.writeFileSync(bootLoader,loader(bootstrap,bootSource,sha(Buffer.from(bootText)),sha(Buffer.from(patchedBoot))),{flag:'wx'});
const launch={version:2,label,bootstrap:bootLoader,rendererManifest:manifestFile,rendererManifestSha256:sha(fs.readFileSync(manifestFile)),engine,normalBroker:true,server:null,arguments:['--native-runtime=editor','--native-profile','--render-profile=gameplay','--native-screen='+display.screen,'--public-servers'],modes,wrapperPins:[...[hostSource,hostLoader,bootSource,bootLoader].map(file=>({file,sha256:sha(fs.readFileSync(file))})),...transportProofs],originalHost:{file:host,sha256:sha(Buffer.from(hostText))},originalBootstrap:{file:bootstrap,sha256:sha(Buffer.from(bootText))},sharedNativeBuilds:0,launched:false};
fs.writeFileSync(path.join(folder,'launch.json'),JSON.stringify(launch,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({folder,sourcePins:pins.length,featureFiles:composition.beforeOwners.length,newFiles:changes.filter(row=>row.kind==='new-parity-source').length,conflicts:[],rendererManifest:manifestFile,bootstrap:bootLoader,retainedFrozenOverrides:retained,launched:false}));
