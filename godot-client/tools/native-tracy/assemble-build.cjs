'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {project,sha,child,read}=require('./prepare-engine.cjs');
const stage=path.join(project,'.cache/native-tracy/engine-msvc-a');
const reconstructionFile=path.join(stage,'reconstruction.json'),reconstruction=read(reconstructionFile,'bfb8d1ee2783fc10d5b3c438f849ca8ecad878d1582f5205d7c0d26720f271a0');
const overlayFile=path.join(project,'.cache/native-tracy/instrumentation-source-d/manifest.json'),overlay=read(overlayFile,'a7753445b3bf7fd257c20e6987aceee14b16311a93a70363cdf35ebe07096267');
const source=reconstruction.source,particle=path.join(stage,'particle/native'),planFile=path.join(stage,'build-plan.json');assert(!fs.existsSync(planFile),'Preserve previous build plan');assert(!fs.existsSync(path.join(stage,'particle')));
assert.equal(path.resolve(overlay.engine),path.resolve(source));
for(const row of reconstruction.overrides)assert.equal(sha(child(source,row.relative)),row.sha256,'Reconstructed D differs before trace overlay');
for(const row of overlay.inputs)assert.equal(sha(row.absolute),row.sha256,'Trace transform input changed');
fs.cpSync(path.join(project,'native'),particle,{recursive:true,errorOnExist:true,force:false});
const changed=[];
for(const row of overlay.outputs){
 const from=child(overlay.output,row.relative);assert.equal(sha(from),row.sha256);
 if(row.relative.startsWith('engine/')||row.relative.startsWith('particle/')){
  const engine=row.relative.startsWith('engine/'),relative=row.relative.slice(engine?7:9),target=child(engine?source:particle,relative);
  fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(from,target);changed.push({kind:engine?'engine':'particle',relative,file:target,sha256:row.sha256});
 }
}
function patch(relative,needle,replacement){const file=child(source,relative),before=fs.readFileSync(file,'utf8');assert.equal(before.split(needle).length,2,'Exact Tracy configuration seam changed');fs.writeFileSync(file,before.replace(needle,replacement));changed.push({kind:'engine-config',relative,file,sha256:sha(file)});}
patch('core/profiling/SCsub','env_tracy.Append(CPPDEFINES=["TRACY_ENABLE"])','env_tracy.Append(CPPDEFINES=["TRACY_ENABLE", "TRACY_NO_SYSTEM_TRACING", "TRACY_ONLY_LOCALHOST", ("TRACY_PORT", 48135)])');
patch('core/profiling/profiling_builders.py','file.write("#define GODOT_USE_TRACY\\n")','file.write("#define GODOT_USE_TRACY\\n#define TRACY_NO_SYSTEM_TRACING\\n#define TRACY_ONLY_LOCALHOST\\n#define TRACY_PORT 48135\\n")');
const tracked=new Map(reconstruction.overrides.map(row=>[row.relative,{relative:row.relative,file:child(source,row.relative),sha256:row.sha256}]));for(const row of changed.filter(x=>x.kind.startsWith('engine')))tracked.set(row.relative,row);
const particlePins=[];function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){assert(!e.isSymbolicLink(),'No source links');const file=path.join(dir,e.name);if(e.isDirectory())walk(file);else particlePins.push({relative:path.relative(particle,file),file,sha256:sha(file)});}}walk(particle);
const audit=JSON.parse(fs.readFileSync(path.join(project,'.cache/native-tracy/source-audit-a/receipt.json'))),python=audit.build.python;assert.equal(sha(python.file),python.expectedSha256);
const args=['-m','SCons','platform=windows','target=template_release','arch=x86_64','use_mingw=no','msvc_version=14.5','disable_path_overrides=no','d3d12=no','debug_symbols=yes','optimize=speed','lto=none','profiler=tracy','profiler_path='+reconstruction.vendor.source,'profiler_sample_callstack=no','profiler_track_memory=no','profiler_record_on_demand=yes','-j','8'];
const plan={version:1,kind:'private-source-equivalent-d-tracy-build',stage,source,particle,createdUtc:new Date().toISOString(),reconstruction:{file:reconstructionFile,sha256:sha(reconstructionFile)},overlay:{file:overlayFile,sha256:sha(overlayFile)},python:{file:python.file,sha256:python.expectedSha256},engineArguments:args,engineTrackedSources:[...tracked.values()],particlePins,changes:changed,output:path.join(stage,'engine-build'),port:48135,installedSourceIdentity:require('../native-feature-manifest.cjs').sourceIdentity(project).sha256,scope:'Private source-equivalent D with MSVC/PDB and explicit on-demand named CPU tracing. Single engine Tracy client, no kernel/system tracing, no memory tracing or statistical sampling. New compiler and trace instrumentation are diagnostic changes, not an accepted FPS improvement or normal runtime replacement.'};assert.equal(plan.installedSourceIdentity,'ea3469f0b87fa346acd28c0ffe97bba646601ed567e80d5f8eee03068989ebda');
fs.writeFileSync(planFile,JSON.stringify(plan,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file:planFile,sha256:sha(planFile),engineSources:plan.engineTrackedSources.length,particleFiles:particlePins.length,compiled:false}));
