'use strict';
// Frozen private Tracy session with the exact candidate particle DLL. The
// accepted project, accepted DLL and pre-existing diagnostic sessions remain
// untouched. Mode is recorded in the generated native launch arguments.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../..');
const {prepare,verify}=require('../native-tracy/live/current-session.cjs');
const {runtimeSource,hostSource,one}=require('../native-tracy/live/source.cjs');
const feature=require('../native-feature-manifest.cjs');
const label=process.argv[2],mode=process.argv[3];
assert(/^frametime-particle-geometry-[a-z0-9-]+$/.test(label??''));assert(['on','off'].includes(mode));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const read=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const candidate=path.join(project,'.cache/particle-geometry-worker/candidate-e/build/nwn-particle-kernel.dll');
const build=read(path.join(path.dirname(candidate),'build-receipt.json'));
assert.equal(sha(fs.readFileSync(candidate)),build.binarySha256);
const made=prepare(label);const c=read(made.config),manifestPath=path.join(c.out,'manifest.json'),m=read(manifestPath);
const view=path.resolve(c.view),relative='.cache/native-kernel/nwn-particle-kernel.dll',target=path.resolve(view,relative);
const preloadPath=path.join(c.source,'bootstrap-preload.cjs');
let preload=fs.readFileSync(preloadPath,'utf8');
preload=one(preload,"const { app } = require('electron'); app.setName('nwn-model-viewer-research');","const { app } = require('electron'); app.disableHardwareAcceleration(); app.setName('nwn-model-viewer-research');");
fs.writeFileSync(preloadPath,preload);
fs.mkdirSync(path.join(view,'reports'),{recursive:true});
// The host's ../../src imports resolve beside the private project. Snapshot
// that shared module tree too, including its ESM package scope.
const sharedSource=path.resolve(project,'../src'),privateSource=path.resolve(c.out,'src');
assert(fs.existsSync(sharedSource)&&!fs.existsSync(privateSource));
fs.cpSync(sharedSource,privateSource,{recursive:true});
const sharedElectron=path.resolve(project,'../electron'),privateElectron=path.resolve(c.out,'electron');
assert(fs.existsSync(sharedElectron)&&!fs.existsSync(privateElectron));
fs.cpSync(sharedElectron,privateElectron,{recursive:true});
const rootPackage=path.resolve(project,'../package.json'),privatePackage=path.resolve(c.out,'package.json');
assert(!fs.existsSync(privatePackage));fs.copyFileSync(rootPackage,privatePackage);
const sharedPins=[];
function pinShared(dir){for(const entry of fs.readdirSync(dir,{withFileTypes:true})){const file=path.join(dir,entry.name);if(entry.isDirectory())pinShared(file);else if(entry.isFile())sharedPins.push({file,sha256:sha(fs.readFileSync(file))});}}
pinShared(privateSource);pinShared(privateElectron);sharedPins.push({file:privatePackage,sha256:sha(fs.readFileSync(privatePackage))});
assert(target.startsWith(view+path.sep));assert(fs.existsSync(target));
// Unlink before copying: the frozen session may have hard-linked its old DLL.
fs.unlinkSync(target);fs.copyFileSync(candidate,target);assert.equal(sha(fs.readFileSync(target)),build.binarySha256);
const descriptorPath=path.resolve(view,c.descriptorRelative);assert(descriptorPath.startsWith(view+path.sep));
const descriptor=read(descriptorPath);descriptor.nativeKernelSha256=build.binarySha256;
descriptor.currentSession={...descriptor.currentSession,geometryWorker:mode,particleCandidate:build.binarySha256,scope:'Private opt-in particle geometry worker comparison; no normal-performance acceptance'};
const descriptorBytes=Buffer.from(JSON.stringify(descriptor,null,2)+'\n');fs.writeFileSync(descriptorPath,descriptorBytes);c.descriptorSha256=sha(descriptorBytes);
const runtimePath=path.join(view,'tools/native-performance-runtime.cjs');
fs.writeFileSync(runtimePath,runtimeSource(fs.readFileSync(path.join(project,'tools/native-performance-runtime.cjs'),'utf8'),descriptor,c.descriptorSha256,c));
let host=hostSource(fs.readFileSync(c.host,'utf8'),c);
host=one(host,'cwd:runtimeSelection.directory,windowsHide:true,env:','cwd:runtimeSelection.directory,windowsHide:false,env:');
if(mode==='on')host=one(host,'nativeArgs.push(...loadingPipeline.arguments);','nativeArgs.push(...loadingPipeline.arguments);nativeArgs.push("--particle-geometry-worker=on");');
fs.writeFileSync(c.compiledHost,host);c.compiledHostSha256=sha(Buffer.from(host));
c.particleSha256=build.binarySha256;c.predictedSourceIdentity=feature.sourceIdentity(view).sha256;
c.geometryWorkerMode=mode;c.particleCandidate={file:candidate,sha256:build.binarySha256};
fs.writeFileSync(made.config,JSON.stringify(c,null,2)+'\n');
const changes=new Map([[target,sha(fs.readFileSync(target))],[descriptorPath,c.descriptorSha256],[runtimePath,sha(fs.readFileSync(runtimePath))],[c.compiledHost,c.compiledHostSha256],[preloadPath,sha(fs.readFileSync(preloadPath))]]);
for(const row of m.files)if(changes.has(path.resolve(row.file)))row.sha256=changes.get(path.resolve(row.file));
for(const file of changes.keys())assert(m.files.some(row=>path.resolve(row.file)===file),'Missing private pin '+file);
m.config={file:made.config,sha256:sha(fs.readFileSync(made.config))};m.particleSha256=build.binarySha256;m.diagnosticSource=c.predictedSourceIdentity;
m.files.push(...sharedPins);m.sharedSource={files:sharedPins.length,scope:'Private copy of root ESM source and Electron imports used by session host'};
m.geometryWorkerMode=mode;m.scope='Private opt-in particle geometry worker Tracy comparison; candidate DLL and launch flag pinned, accepted artifacts untouched';
fs.writeFileSync(manifestPath,JSON.stringify(m,null,2)+'\n');
verify(made.config);
console.log(JSON.stringify({config:made.config,run:c.run,mode,engineSha256:c.engineSha256,particleSha256:c.particleSha256,source:c.predictedSourceIdentity}));
