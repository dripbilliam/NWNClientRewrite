// Isolated manual-login launch of an already measured renderer/engine pair.
// The original settings broker/network owner are compiled at their original
// filenames so relative imports and protected settings retain their owners.
// Only the renderer path, executable and explicit rendering modes are changed.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {hash} from './stage_library.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const label=process.argv[2];if(!/^live-threaded-[a-z0-9-]+$/.test(label??''))throw Error('Fresh live launch label required');
const variant=process.argv[3]??'builtin-light-fenced-v2';
const variants={'builtin-light-fenced-v2':'672a89f094e3f8b845175b947556e3ca9b8c3bb4bd0e149a8f79058ad2cdc0d9','drive-envelope-fenced-v1':'cce71cea6e3ae8116d4747c97f1e161eed9350cd85386dc372578d9f6d4cdfc1'};
if(!Object.hasOwn(variants,variant))throw Error('Explicit verified private renderer required');
const folder=path.join(project,'.cache/native-140fps/root',label);if(fs.existsSync(folder))throw Error('Existing live evidence preserved');
const rendererManifest=path.join(project,'.cache/native-140fps/root',variant,'manifest.json');
const renderer=JSON.parse(fs.readFileSync(rendererManifest));
if(hash(fs.readFileSync(rendererManifest))!==variants[variant])throw Error('Verified renderer manifest differs');
for(const p of renderer.pins)if(hash(fs.readFileSync(path.join(renderer.project,p.relative)))!==p.sha256)throw Error('Renderer changed: '+p.relative);
const descriptorFile=path.join(project,'.cache/native-140fps/render-agent/engine-builtin-light-v2/engine-descriptor.json');
if(hash(fs.readFileSync(descriptorFile))!=='0f640f95b3ffc2a0a2cf65695004ea5c77eae36718a6a43ae87199578902991e')throw Error('Engine descriptor differs');
const descriptor=JSON.parse(fs.readFileSync(descriptorFile)),engine=descriptor.engines.candidate;
if(hash(fs.readFileSync(engine.path))!==engine.sha256||engine.sha256!=='ce2d36407d0a6107a3076a00faf7d9f9dae185c86994ccea8dfd7e450c50f12a')throw Error('Measured engine differs');
const boot=path.join(project,'tools/native-session-bootstrap.cjs'),host=path.join(project,'tools/native-session-host.cjs');
const hostText=fs.readFileSync(host,'utf8'),bootText=fs.readFileSync(boot,'utf8');
const once=(s,a,b)=>{if(s.split(a).length!==2)throw Error('Manual launch seam differs: '+a);return s.replace(a,b);};
const selection={kind:'editor',executable:engine.path,directory:path.dirname(project),executableSha256:engine.sha256,privateCandidate:true,rendererManifest,rendererManifestSha256:hash(fs.readFileSync(rendererManifest))};
let patchedHost=once(hostText,"const runtimeSelection=await require('./native-engine-runtime.cjs').selectNativeRuntime(project,engineRuntime,enginePackage);",'const runtimeSelection='+JSON.stringify(selection)+';');
patchedHost=once(patchedHost,"['--path',project]","['--path',"+JSON.stringify(renderer.project)+']');
const nativeModes=['--particle-random=native','--particle-clocks=native','--particle-pose-leases=managed','--light-input-registry=builtin'];
if(variant==='drive-envelope-fenced-v1')nativeModes.push('--drive-collision=indexed');
const trial={renderer:renderer.project,manifestSha256:hash(fs.readFileSync(rendererManifest)),engineSha256:engine.sha256,mode:'Manual login or explicit loopback check only; no automatic public connection',...(variant==='builtin-light-fenced-v2'?{acceptedOfflinePeakFps:112.09}:{driveRoute:'indexed-envelope',walkingReplayAccepted:360,liveWalkingAccepted:false})};
patchedHost=once(patchedHost,'let launch=executable,launchArgs=nativeArgs;',`nativeArgs.splice(nativeArgs.indexOf('--'),0,'--render-thread','separate');nativeArgs.push(...${JSON.stringify(nativeModes)});report.perf140ManualCandidate=${JSON.stringify(trial)};\n let launch=executable,launchArgs=nativeArgs;`);
fs.mkdirSync(folder);const hostSource=path.join(folder,'host-source.cjs'),hostLoader=path.join(folder,'host-loader.cjs'),bootSource=path.join(folder,'bootstrap-source.cjs'),bootLoader=path.join(folder,'bootstrap-loader.cjs');
fs.writeFileSync(hostSource,patchedHost);
const loader=(original,source,originalHash,sourceHash)=>`const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),Module=require('node:module');\nconst original=${JSON.stringify(original)},source=${JSON.stringify(source)},sha=b=>crypto.createHash('sha256').update(b).digest('hex');\nif(sha(fs.readFileSync(original))!==${JSON.stringify(originalHash)}||sha(fs.readFileSync(source))!==${JSON.stringify(sourceHash)})throw Error('Private manual launch source changed');\nconst owner=new Module(original,module);owner.filename=original;owner.paths=Module._nodeModulePaths(path.dirname(original));owner._compile(fs.readFileSync(source,'utf8'),original);\n`;
fs.writeFileSync(hostLoader,loader(host,hostSource,hash(Buffer.from(hostText)),hash(Buffer.from(patchedHost))));
const patchedBoot=once(bootText,"[path.join(__dirname,'native-session-host.cjs'),...args]",'['+JSON.stringify(hostLoader)+',...args]');
fs.writeFileSync(bootSource,patchedBoot);fs.writeFileSync(bootLoader,loader(boot,bootSource,hash(Buffer.from(bootText)),hash(Buffer.from(patchedBoot))));
const result={version:1,label,folder,bootstrap:bootLoader,engine,rendererManifest,rendererManifestSha256:hash(fs.readFileSync(rendererManifest)),rendererProject:renderer.project,originalHostSha256:hash(Buffer.from(hostText)),originalBootstrapSha256:hash(Buffer.from(bootText)),sharedFilesChanged:0,sharedBuilds:0,serverConnections:0,settingsOwner:'Original protected settings broker; no key in launcher or arguments',nativeModes,pins:[hostSource,hostLoader,bootSource,bootLoader].map(file=>({file,sha256:hash(fs.readFileSync(file))}))};
fs.writeFileSync(path.join(folder,'launch.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({folder,bootstrap:bootLoader,run:label,engineSha256:engine.sha256,rendererManifestSha256:result.rendererManifestSha256}));
