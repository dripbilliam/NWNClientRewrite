// Local-test overlay only. Reuse the original login/protocol owners and redirect
// the Godot --path argument to a copied private renderer. No shared-file edits.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const [capsule,run]=process.argv.slice(2),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
if(!/^native-dense-pose-[a-z0-9-]+$/.test(capsule??'')||!/^native-world-quiescent-local-pose-[a-z0-9-]+$/.test(run??''))throw Error('Supply private pose capsule and fresh local run');
const stage=path.join(project,'.cache/native-particle-pose-local',run),copy=path.join(stage,'renderer');
if(fs.existsSync(stage))throw Error('Existing local evidence is preserved');
const sourceReceipt=path.join(project,'.cache/native-dense-area',capsule,'candidate-sources.json'),r=JSON.parse(fs.readFileSync(sourceReceipt));
if(!r.isolatedBuildFinalized||r.variant!=='candidate'||r.sourceProject!==path.join(project,'.cache/native-dense-area',capsule,'candidate'))throw Error('Private build not finalized');
fs.mkdirSync(copy,{recursive:true});
for(const pin of r.sourcePins){const source=path.join(r.sourceProject,pin.relative);if(hash(fs.readFileSync(source))!==pin.finalSha256)throw Error('Private source differs');const destination=path.join(copy,pin.relative);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.copyFileSync(source,destination);if(hash(fs.readFileSync(destination))!==pin.finalSha256)throw Error('Local copy differs');}
const originalBootstrap=path.join(project,'tools/native-session-bootstrap.cjs'),originalHost=path.join(project,'tools/native-session-host.cjs');
const originalBootstrapBytes=fs.readFileSync(originalBootstrap),originalHostBytes=fs.readFileSync(originalHost);
const normalize=b=>b.toString().replaceAll('\r\n','\n');
const once=(s,a,b)=>{if(s.split(a).length!==2)throw Error('Local overlay boundary differs');return s.replace(a,b);};
const hostWrapper=path.join(stage,'host-wrapper.cjs'),bootstrapWrapper=path.join(stage,'bootstrap-wrapper.cjs');
const injection='report.nativeRenderProjectOverlay='+JSON.stringify({project:copy,capsule,run,scope:'Only editor Godot --path is redirected; original settings/login/protocol/server checks stay original.'})+';\n ';
let host=once(normalize(originalHostBytes),"const executable=runtimeSelection.executable,nativeArgs=[...(engineRuntime==='editor'?['--path',project]:[])",injection+"const executable=runtimeSelection.executable,nativeArgs=[...(engineRuntime==='editor'?['--path',"+JSON.stringify(copy)+"]:[])");
let bootstrap=once(normalize(originalBootstrapBytes),"path.join(__dirname,'native-session-host.cjs')",JSON.stringify(hostWrapper));
function wrapper(file,original,originalSha,code){
 // Module's filename/lookup paths retain the original relative imports. The
 // exact patched text and original digest are pinned in the overlay receipt.
 const content="const fs=require('node:fs'),crypto=require('node:crypto'),Module=require('node:module'),path=require('node:path');\nconst original="+JSON.stringify(original)+";\nif(crypto.createHash('sha256').update(fs.readFileSync(original)).digest('hex')!=="+JSON.stringify(originalSha)+")throw Error('Original local owner changed');\nconst owner=new Module(original,module);owner.filename=original;owner.paths=Module._nodeModulePaths(path.dirname(original));owner._compile("+JSON.stringify(code)+",original);\n";
 fs.writeFileSync(file,content,{flag:'wx'});return {file,sha256:hash(Buffer.from(content)),original,originalSha256:originalSha,compiledTextSha256:hash(Buffer.from(code))};
}
const wrappers=[wrapper(hostWrapper,originalHost,hash(originalHostBytes),host),wrapper(bootstrapWrapper,originalBootstrap,hash(originalBootstrapBytes),bootstrap)];
const manifest={version:1,kind:'private-particle-pose-local-overlay',run,capsule,sourceProject:r.sourceProject,rendererProject:copy,sourceReceipt:{file:sourceReceipt,sha256:hash(fs.readFileSync(sourceReceipt))},sourcePins:r.sourcePins,wrappers,bootstrapWrapper,server:'127.0.0.1:5121',publicConnections:0,sharedNativeBuilds:0,enginesStarted:0,scope:'A copied renderer/private DLL via one Godot path substitution. Local protocol and protected-key pipeline remain the original owners; wrappers have explicit executable-text hashes.'};
const file=path.join(stage,'overlay.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,file,sha256:hash(fs.readFileSync(file)),bootstrapWrapper,rendererProject:copy}));
