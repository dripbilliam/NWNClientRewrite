'use strict';
// Fresh diagnostic session using the current client and the previously validated
// Tracy engine/DLL. It does not promote binaries or assert new FPS acceptance.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {hostSource,runtimeSource,manualArguments}=require('./source.cjs');
const {verifyPlanLineage}=require('./lineage.cjs');
const {mayLink}=require('./storage-policy.cjs');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const read=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const pin=file=>({file,sha256:sha(fs.readFileSync(file))});
function prepare(label,project=path.resolve(__dirname,'../../..'),reviewSource=null,keepAllOverlayFiles=false){
 assert(/^frametime-[a-z0-9-]+$/.test(label),'Fresh frametime label required');
 const prior=path.join(project,'.cache/native-tracy/live/manual-cache-a'),old=read(path.join(prior,'config.json')),manifestFile=path.join(prior,'manifest.json'),m=read(manifestFile);
 assert.equal(pin(path.join(prior,'config.json')).sha256,m.config.sha256);
 const accepted=read(path.join(prior,'native-acceptance.json'));
 assert.equal(accepted.stageManifestSha256,pin(manifestFile).sha256);
 for(const key of ['nativeParsed','functionalPassed','bridgePassed','lifetimePassed','manuallyReviewed'])assert.equal(accepted[key],true);
 for(const row of [...m.launchPins,...Object.values(m.sourceReceipts)])assert.equal(pin(row.file).sha256,row.sha256);
 const engine=read(m.sourceReceipts.engine.file),particle=read(m.sourceReceipts.particle.file);
 verifyPlanLineage(engine,particle,old.expectedEngineSourceIdentity);
 const feature=require(path.join(project,'tools/native-feature-manifest.cjs')),current=feature.sourceIdentity(project);
 const reviewed=reviewSource?feature.sourceIdentity(path.resolve(reviewSource)):null;
 const out=path.join(project,'.cache/native-tracy/live',label),view=path.join(out,'project');assert(!fs.existsSync(out),'Keep prior session evidence');
 const c={...old,out,view,run:'native-tracy-'+label,source:path.join(out,'source'),userdata:path.join(out,'working-settings'),appdata:path.join(out,'working-appdata'),localappdata:path.join(out,'working-localappdata'),expectedMainSourceIdentity:current.sha256};
 c.engineLaunch=path.join(view,c.engineRelative);c.hostSha256=pin(c.host).sha256;c.bootstrapSha256=pin(c.bootstrap).sha256;
 c.compiledHost=path.join(view,'tools/native-session-host.cjs');c.screenHelper=path.join(c.source,'native-window-screen.ps1');
 c.bootstrapArguments=[c.bootstrap,...manualArguments(c.run)];
 fs.mkdirSync(view,{recursive:true});fs.mkdirSync(c.source);
 const copies=new Map();
 function put(relative,source,wanted){
  assert(!path.isAbsolute(relative)&&!relative.includes('\\')&&!relative.split('/').some(p=>!p||p==='.'||p==='..'));
  assert(!/native-godot-particles|gpu_particle_architecture_test/.test(relative),'Discarded particle experiment cannot enter session');
  const bytes=fs.readFileSync(source),digest=sha(bytes);if(wanted)assert.equal(digest,wanted);
  const target=path.join(view,relative);fs.mkdirSync(path.dirname(target),{recursive:true});
  if(mayLink({relative,sha256:digest})){if(!fs.existsSync(target))fs.linkSync(source,target);else assert.equal(pin(target).sha256,digest);}else fs.writeFileSync(target,bytes);
  copies.set(relative,{relative,sha256:digest,source});
 }
 const base=read(m.base.file);assert.equal(pin(m.base.file).sha256,m.base.sha256);
 for(const row of base.pins){
  if(/native-godot-particles|gpu_particle_architecture_test/.test(row.relative))continue;
  const source=path.join(project,row.relative);if(fs.existsSync(source)&&fs.statSync(source).isFile())put(row.relative,source);
 }
 for(const row of current.files)put(row.file,path.join(project,row.file),row.sha256);
 // Session scripts preload their optional probes during parsing, even when the
 // probes are not enabled. Include the current test dependency closure too.
 function tests(dir,relative){for(const e of fs.readdirSync(dir,{withFileTypes:true})){if(e.name.startsWith('.')||e.isSymbolicLink())continue;const f=path.join(dir,e.name),r=relative+'/'+e.name;if(e.isDirectory())tests(f,r);else if(!/gpu_particle_architecture_test/.test(r))put(r,f);}}
 tests(path.join(project,'tests'),'tests');
 // Application data can be introduced with a script change; the historical
 // capsule and sourceIdentity do not enumerate this directory.
 function data(dir,relative){for(const e of fs.readdirSync(dir,{withFileTypes:true})){if(e.name.startsWith('.')||e.isSymbolicLink())continue;const f=path.join(dir,e.name),r=relative+'/'+e.name;if(e.isDirectory())data(f,r);else put(r,f);}}
 if(fs.existsSync(path.join(project,'data')))data(path.join(project,'data'),'data');
 if(reviewed){
  // Use already-verified application source without copying its normal DLL
  // over the separately identified diagnostic DLL below.
  for(const row of reviewed.files)if(!row.file.endsWith('.dll'))put(row.file,path.join(reviewSource,row.file),row.sha256);
  if(!keepAllOverlayFiles)for(const relative of ['systems/native_render/rig_construction.gd','systems/native_render/model_placement_job.gd']){const file=path.join(view,relative);if(fs.existsSync(file)){assert(file.startsWith(view+path.sep));fs.unlinkSync(file);copies.delete(relative);}}
  c.reviewedSource={project:path.resolve(reviewSource),sha256:reviewed.sha256,scope:'Reviewed application overlay; unfinished publication/commit and unselected native experiments excluded.'};
 }
 const regenerate=new Set([c.descriptorRelative,'tools/native-performance-runtime.cjs','tools/native-session-host.cjs']);
 for(const row of m.overlayPins)if(!regenerate.has(row.relative)&&row.relative!=='native_live_world.gd'&&row.relative!=='native_session_world.gd'&&!m.scriptUpdates.some(x=>x.relative===row.relative))put(row.relative,path.join(old.view,row.relative),row.sha256);
 for(const row of m.binaries)put(row.relative,path.join(old.view,row.relative),row.sha256);
 // Use current imported class metadata; no editor import or original game assets.
 for(const relative of ['.godot/global_script_class_cache.cfg','.godot/extension_list.cfg'])put(relative,path.join(project,relative));
 const descriptor=read(path.join(old.view,c.descriptorRelative));
 descriptor.currentScriptSource=reviewed?.sha256??current.sha256;descriptor.currentSession={run:c.run,source:reviewed?.sha256??current.sha256,priorAcceptance:pin(path.join(prior,'native-acceptance.json')),performanceAccepted:false,scope:'Selected client script snapshot with unchanged validated Core D Tracy engine/DLL. Later normal-engine lighting changes are absent from this diagnostic binary; startup and live capture are observed separately.'};
 const descriptorBytes=Buffer.from(JSON.stringify(descriptor,null,2)+'\n'),descriptorPath=path.join(view,c.descriptorRelative);fs.mkdirSync(path.dirname(descriptorPath),{recursive:true});fs.writeFileSync(descriptorPath,descriptorBytes);c.descriptorSha256=sha(descriptorBytes);
 fs.writeFileSync(path.join(view,'tools/native-performance-runtime.cjs'),runtimeSource(fs.readFileSync(path.join(project,'tools/native-performance-runtime.cjs'),'utf8'),descriptor,c.descriptorSha256,c));
 fs.writeFileSync(c.compiledHost,hostSource(fs.readFileSync(c.host,'utf8'),c));c.compiledHostSha256=pin(c.compiledHost).sha256;
 for(const name of ['bootstrap-preload.cjs','host-preload.cjs'])fs.copyFileSync(path.join(__dirname,name),path.join(c.source,name));
 fs.copyFileSync(path.join(project,'tools/native-window-screen.ps1'),c.screenHelper);
 c.predictedSourceIdentity=feature.sourceIdentity(view).sha256;
 assert.equal(feature.sourceIdentity(project).sha256,current.sha256,'Current client changed while snapshotting');
 const file=path.join(out,'config.json');fs.writeFileSync(file,JSON.stringify(c,null,2)+'\n');
 const files=[];function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const f=path.join(dir,e.name);if(e.isDirectory())walk(f);else files.push(pin(f));}}walk(view);walk(c.source);
 const proof={version:1,kind:'current-client-tracy-session',config:pin(file),files,priorManifest:pin(manifestFile),priorAcceptance:pin(path.join(prior,'native-acceptance.json')),sourceReceipts:m.sourceReceipts,currentSource:current.sha256,reviewedSource:c.reviewedSource??null,diagnosticSource:c.predictedSourceIdentity,engineSha256:c.engineSha256,particleSha256:c.particleSha256,performanceAccepted:false,originalParticleSystem:true,scope:'Fresh selected source snapshot and diagnostic provenance; inherited binary acceptance does not establish performance of this session.'};
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(proof,null,2)+'\n');
 return {config:file,run:c.run,files:files.length,source:current.sha256,engine:c.engineSha256,particle:c.particleSha256};
}
function verify(file){const c=read(file),m=read(path.join(c.out,'manifest.json'));assert.equal(pin(file).sha256,m.config.sha256);for(const r of m.files)assert.equal(pin(r.file).sha256,r.sha256);assert.equal(pin(c.host).sha256,c.hostSha256);assert.equal(pin(c.bootstrap).sha256,c.bootstrapSha256);assert.equal(require(path.join(c.project,'tools/native-feature-manifest.cjs')).sourceIdentity(c.project).sha256,c.expectedMainSourceIdentity);return c;}
module.exports={prepare,verify};
if(require.main===module){const mode=process.argv[2];if(mode==='prepare')console.log(JSON.stringify(prepare(process.argv[3],undefined,process.argv[4]??null,process.argv.includes('--keep-all-overlay-files'))));else if(mode==='verify'){const c=verify(process.argv[3]);console.log(JSON.stringify({success:true,run:c.run,source:c.predictedSourceIdentity}));}else throw Error('Expected prepare or verify');}
