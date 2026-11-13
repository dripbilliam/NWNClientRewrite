'use strict';
// PRIVATE source-only proposal. Never edits global selectors or accepted files.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex'),read=f=>fs.readFileSync(f);
const descriptorPath='.tools/native-core/private-clock-review.json';
const receiptPath='.cache/nwn64-clock-review/build-receipt.json',sourcePinsPath='.cache/nwn64-clock-review/source-pins.json';
const receiptSHA='eeae7be9000eab04e5116ae85e15c2c0080053dc7de2d837721902d9c7939f31',sourcePinsSHA='a0eaece63b73bf801d47fab741c22859e53952d10791a1f82f216b9858fa25f7';
const acceptedSHA='485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d',candidateSHA='572289a7c1c023e161d8e476a74f822f475bbb8914926351d197a1d03a5fab7b';
function one(text,before,after){assert.equal(text.split(before).length,2,before.slice(0,120));return text.replace(before,after);}
function runtimeOverlay(bytes,descriptor,kernelSHA){
 let text=bytes.toString();
 text=text.replace(/const proofRelative="[^"]+",proofSha256="[a-f0-9]+";/,`const proofRelative=${JSON.stringify(descriptorPath)},proofSha256=${JSON.stringify(sha(descriptor))};`);
 text=one(text,`const nativeSha256="${acceptedSHA}";`,`const nativeSha256="${kernelSHA}";`);
 text=one(text,'policy:enabled?"accepted-normal-combined-e"','policy:enabled?"private-unaccepted-clock-review"');
 text=one(text,'const artifact=JSON.parse(proof);',`const artifact=JSON.parse(proof);
 if(artifact.kind!=='private-unaccepted-native-clock-review'||artifact.private!==true||artifact.accepted!==false||artifact.production!==false)throw Error('Private clock-review descriptor policy differs');
 for(const pin of artifact.provenancePins){const b=await fs.readFile(path.join(resolved,pin.relative));if(crypto.createHash('sha256').update(b).digest('hex')!==pin.sha256)throw Error('Private clock-review provenance changed');}
 if(artifact.library==='clock-d'){
  const build=JSON.parse(await fs.readFile(path.join(resolved,${JSON.stringify(receiptPath)})));
  if(!build.success||build.binarySha256!==nativeSha256||build.sharedBinaryWrites!==0||build.sharedSourceWrites!==0)throw Error('Private clockD build receipt differs');
  for(const pin of build.sourcePins){const b=await fs.readFile(path.join(resolved,pin.relative));if(crypto.createHash('sha256').update(b).digest('hex')!==pin.sha256)throw Error('Private clockD native source changed: '+pin.relative);}
 }
 `);
 text=one(text,"for(const name of ['project.godot','.godot/global_script_class_cache.cfg'])",`for(const name of ['project.godot','.godot/global_script_class_cache.cfg',${JSON.stringify(descriptorPath)},${JSON.stringify(receiptPath)},${JSON.stringify(sourcePinsPath)}])`);
 text=one(text,"return {kind:'verified-native'","return {kind:'private-unaccepted-clock-review'");
 text=text.replaceAll('verified-native-normal-bundle-e','private-unaccepted-clock-review').replaceAll('accepted component proof','PRIVATE reviewed candidate proof').replaceAll('Exact accepted combined-b DLL plus corresponding native sources; conservative flag-absent branches retained','Exact descriptor-selected accepted-control or unaccepted clockD DLL with frozen provenance; no installed/default promotion');
 text='// PRIVATE NWN64 review overlay; not an accepted selector.\n'+text;return Buffer.from(text);
}
function selectionOverlay(bytes){
 let text=bytes.toString();
 text=one(text,"const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');",`const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function privateReview(project){const bytes=fs.readFileSync(path.join(project,${JSON.stringify(descriptorPath)})),d=JSON.parse(bytes);if(d.kind!=='private-unaccepted-native-clock-review'||d.private!==true||d.accepted!==false||d.production!==false||!['reference','native'].includes(d.clockReadMode))throw Error('Explicit PRIVATE clock-review descriptor required');return{kind:d.kind,private:true,accepted:false,production:false,library:d.library,clockReadMode:d.clockReadMode,descriptorSHA256:hash(bytes),nativeKernelSHA256:d.nativeKernelSha256};}`);
 text=one(text,"return {performance,loading,render,renderCore:structuredClone(performance.renderCore),profiling:profile==='on'?'true':'false',flags:[...render.arguments,...loading.arguments,...performance.nativeArguments.filter(value=>!value.startsWith('--profile='))]};",`const review=privateReview(project);
 return {performance,loading,render,privateReview:review,renderCore:structuredClone(performance.renderCore),profiling:profile==='on'?'true':'false',flags:[...render.arguments,...loading.arguments,...performance.nativeArguments.filter(value=>!value.startsWith('--profile=')),...(review.clockReadMode==='native'?['--particle-clock-read=native']:[])]};`);
 text=one(text,"const files=new Set(identity.files.map(row=>row.file));",`const files=new Set(identity.files.map(row=>row.file));
 for(const name of [${JSON.stringify(descriptorPath)},${JSON.stringify(receiptPath)},${JSON.stringify(sourcePinsPath)}])files.add(name);`);
 text=text.replaceAll('production-replay-selection','private-unaccepted-clock-review-selection');
 text=one(text,'complete:true,production:true,created:','complete:true,production:false,private:true,accepted:false,privateReview:resolved.privateReview,created:');
 text=one(text,'m.production!==true','m.production!==false||m.private!==true||m.accepted!==false');
 text=one(text,"[[m.flags,c.flags,'flags']","[[m.privateReview,c.privateReview,'private reviewed candidate'],[m.flags,c.flags,'flags']");
 text=one(text,'flags:[...m.flags],production:true','flags:[...m.flags],production:false,private:true,accepted:false,privateReview:m.privateReview');
 text=text.replaceAll('production-selection.json','private-clock-selection.json').replaceAll('production-replay\'',"private-clock-review'");
 text=text.replace('Exact copied current application source/native libraries; normal configuration helpers; immutable common preferences and explicit active FOV/camera evidence; no captured/private V4 behavior or game assets','PRIVATE UNACCEPTED clock-review selection. Exact reviewedB normal application/CoreE/flags/env/preferences plus declared native artifact/helper/report-only overlays. Not a production or default promotion.');
 return Buffer.from('// PRIVATE NWN64 review overlay; global production selector stays strict.\n'+text);
}
function prepare(label){
 assert(/^clock-review-[a-z0-9-]+$/.test(label||''));const parentFile=path.join(project,'.cache/nwn64/fog-pair-a/pair.json'),parentBytes=read(parentFile),parent=JSON.parse(parentBytes);require('./fog-pair.cjs').verify(parent);
 const base=parent.before,receiptFile=path.join(project,'.cache/native-render-gap/particles/nwn64-clock-d/kernel-build/build-receipt.json'),pinsFile=path.join(project,'.cache/native-render-gap/particles/nwn64-clock-d/kernel-source-pins.json'),receiptBytes=read(receiptFile),sourcePinsBytes=read(pinsFile),receipt=JSON.parse(receiptBytes),sourcePins=JSON.parse(sourcePinsBytes);
 assert.equal(sha(receiptBytes),receiptSHA);assert.equal(sha(sourcePinsBytes),sourcePinsSHA);assert(receipt.success&&receipt.binarySha256===candidateSHA&&receipt.sourcePins.length===46);const candidate=read(receipt.binary);assert.equal(sha(candidate),candidateSHA);
 const nativeSources=new Map();for(const pin of receipt.sourcePins){assert(pin.relative.startsWith('native/')&&!pin.relative.includes('..'));const bytes=read(path.join(sourcePins.project,pin.relative));assert.equal(sha(bytes),pin.sha256);assert.equal(bytes.length,pin.bytes);nativeSources.set(pin.relative,bytes);}
 const coreBytes=read(path.join(base,'.tools/native-core/accepted-core-e.json')),core=JSON.parse(coreBytes),directory=path.join(project,'.cache/nwn64',label);assert(!fs.existsSync(directory));const views=[];
 for(const mode of ['accepted-control','clock-d-native']){
  const root=path.join(directory,mode,'project'),pins=new Map(),overlays=[];fs.mkdirSync(root,{recursive:true});
  function put(relative,bytes,origin){assert(relative&&!path.isAbsolute(relative)&&!relative.split(/[\\/]/).some(s=>!s||s==='.'||s==='..'));const file=path.join(root,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);pins.set(relative,{relative,bytes:bytes.length,sha256:sha(bytes),origin});}
  for(const row of parent.pins.before){const bytes=read(path.join(base,row.relative));assert.equal(sha(bytes),row.sha256);const file=path.join(root,row.relative);fs.mkdirSync(path.dirname(file),{recursive:true});if(mode==='clock-d-native'&&row.relative==='.cache/native-kernel/nwn-particle-kernel.dll')put(row.relative,candidate,'private reviewed clockD DLL');else if(/\.(exe|dll)$/.test(row.relative)){fs.linkSync(path.join(base,row.relative),file);pins.set(row.relative,{...row,origin:'immutable reviewedB native hardlink'});}else put(row.relative,bytes,'exact reviewedB source');}
  if(mode==='clock-d-native')for(const[relative,bytes]of nativeSources)put(relative,bytes,'exact frozen clockD native source closure');
  put(receiptPath,receiptBytes,'exact frozen clockD build receipt (no path rewriting)');put(sourcePinsPath,sourcePinsBytes,'exact frozen clockD source pins');
  const nativeSHA=mode==='accepted-control'?acceptedSHA:candidateSHA,descriptor={version:1,kind:'private-unaccepted-native-clock-review',private:true,accepted:false,production:false,library:mode==='accepted-control'?'accepted-control':'clock-d',clockReadMode:mode==='accepted-control'?'reference':'native',engineSha256:core.engineSha256,engineBytes:core.engineBytes,nativeKernelSha256:nativeSHA,originalGameAssetsPacked:false,engineBuildProof:core.engineBuildProof,engineBaseline:{relative:'.tools/native-core/accepted-core-e.json',sha256:sha(coreBytes)},provenancePins:[{relative:receiptPath,sha256:receiptSHA},{relative:sourcePinsPath,sha256:sourcePinsSHA}],scope:'PRIVATE controlled review only. CoreE and normal16/gameplay shared+pooled environment remain fixed. Candidate native clock read is opt-in and unaccepted; accepted-control library remains unchanged.'};
  const descriptorBytes=Buffer.from(JSON.stringify(descriptor,null,2)+'\n');put(descriptorPath,descriptorBytes,'explicit PRIVATE unaccepted descriptor');
  for(const[relative,transform]of [['tools/native-performance-runtime.cjs',bytes=>runtimeOverlay(bytes,descriptorBytes,nativeSHA)],['tools/native-production-selection.cjs',selectionOverlay]]){
   const before=read(path.join(base,relative)),after=transform(before);put(relative,after,'declared PRIVATE selector overlay');overlays.push({relative,beforeSHA256:sha(before),afterSHA256:sha(after),bytes:after.length});
  }
  const reportPath='native_live_world.gd',reportBefore=read(path.join(base,reportPath)),anchor='\tif is_instance_valid(world): report.world=world.snapshot()';
  const reportAfter=Buffer.from(one(reportBefore.toString(),anchor,anchor+'\n\t# PRIVATE final-report-only census; no per-frame clock instrumentation.\n\tif is_instance_valid(world) and is_instance_valid(world.particle_stream_group) and world.particle_stream_group.native!=null:\n\t\treport.private_clock_review={"private":true,"accepted":false,"clock_read_native":OS.get_cmdline_user_args().has("--particle-clock-read=native"),"members":world.particle_stream_group.members.size(),"fast_members":world.particle_stream_group.fast_members,"clock_info":world.particle_stream_group.native.call("dispatch",16,{})}'));
  put(reportPath,reportAfter,'identical final-report-only native presenter dispatch16 census');overlays.push({relative:reportPath,beforeSHA256:sha(reportBefore),afterSHA256:sha(reportAfter),bytes:reportAfter.length});
  if(mode==='clock-d-native')put('.cache/native-kernel/build-manifest.json',Buffer.from(JSON.stringify({version:1,kind:'private-unaccepted-clock-d-build',private:true,accepted:false,production:false,binarySha256:candidateSHA,buildReceipt:{relative:receiptPath,sha256:receiptSHA},sourcePins:{relative:sourcePinsPath,sha256:sourcePinsSHA},sourceFiles:receipt.sourcePins,scope:'Frozen private build; no new compilation or accepted/default promotion.'},null,2)+'\n'),'truthful private DLL build manifest');
  const driverClosure=require('./clock-review-driver-closure.cjs').copyClosure(project,root,put);
  const identity=require(path.join(root,'tools/native-feature-manifest.cjs')).sourceIdentity(root);views.push({mode,project:root,descriptor:{relative:descriptorPath,sha256:sha(descriptorBytes)},overlays,pins:[...pins.values()],driverClosure,identity:identity.sha256,nativeKernelSHA256:nativeSHA,driver:path.join(root,'tools/replay-native-loading.mjs'),selectionHelper:path.join(root,'tools/native-production-selection.cjs')});
 }
 const result={version:1,issue:'NWN-64',kind:'private-unaccepted-clock-review-proposal',private:true,accepted:false,production:false,parent:{file:parentFile,sha256:sha(parentBytes),source:base},nativeBuild:{receipt:receiptFile,receiptSHA256:receiptSHA,sourcePins:pinsFile,sourcePinsSHA256:sourcePinsSHA,binarySHA256:candidateSHA,files:nativeSources.size},views,preferences:parent.preferences,argv:parent.argv,capture:path.join(project,'.cache/nwn64/fog-recording-particles-a'),assertions:{allGlobalSelectorsAndAcceptedArtifactsUnchanged:true,noNativeBuilds:true,noEngineStarts:true,normalCore16AndGamePlayEnvironmentUnchanged:true,noPresentationRouteSwitch:true,clockReadFlagOutsideCore16:true,onlyPrivateHelpersAndFinalReportCensusDifferFromNativeArtifactComparison:true}};
 const file=path.join(directory,'proposal.json');fs.writeFileSync(file,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file,sha256:sha(read(file)),views:views.map(v=>({mode:v.mode,project:v.project,pins:v.pins.length,overlays:v.overlays})),nativeBuild:result.nativeBuild}));return result;
}
module.exports={prepare,runtimeOverlay,selectionOverlay};if(require.main===module){try{prepare(process.argv[2]);}catch(error){console.error(error.stack);process.exitCode=1;}}
