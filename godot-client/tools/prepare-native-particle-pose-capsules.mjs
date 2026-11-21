// File-only isolated experiment. The ordinary renderer and shared DLLs stay unchanged.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const label=process.argv[2],operation=process.argv[3]??'prepare';
if(!/^native-dense-pose-[a-z0-9-]+$/.test(label??''))throw Error('Supply a fresh pose capsule label');
const stage=path.join(project,'.cache/native-dense-area',label),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const read=file=>fs.readFileSync(file),text=file=>read(file).toString().replaceAll('\r\n','\n');
const once=(s,a,b)=>{if(s.split(a).length!==2)throw Error('Expected one experimental hook: '+a.slice(0,100));return s.replace(a,b);};
const safe=(root,relative)=>{const p=path.resolve(root,relative),r=path.relative(root,p);if(!r||r==='..'||r.startsWith('..'+path.sep)||path.isAbsolute(r)||relative.includes(':'))throw Error('Escaping copied source');return p;};
if(operation==='finalize'){
 for(const variant of ['baseline','candidate']){
  const file=path.join(stage,variant+'-sources.json'),r=JSON.parse(read(file));
  if(r.variant!==variant||r.sourceProject!==path.join(stage,variant)||r.isolatedBuildFinalized)throw Error('Unexpected build receipt');
  const buildFile=path.join(r.sourceProject,'.cache/native-kernel/pose-build.json'),build=JSON.parse(read(buildFile));
  if(!build.success||build.changedGuards.length||build.output!==path.join(r.sourceProject,'.cache/native-kernel/nwn-particle-kernel.dll')||build.binarySha256!==hash(read(build.output)))throw Error('Private compiler proof failed');
  for(const p of r.sourcePins){const sha=hash(read(safe(r.sourceProject,p.relative)));if(p.relative!=='.cache/native-kernel/nwn-particle-kernel.dll'&&p.relative!=='.cache/native-kernel/build-manifest.json'&&sha!==p.finalSha256)throw Error('Unexpected build mutation: '+p.relative);p.finalSha256=sha;p.bytes=read(safe(r.sourceProject,p.relative)).length;}
  r.isolatedBuildFinalized=true;r.isolatedBuild={file:buildFile,sha256:hash(read(buildFile)),binarySha256:build.binarySha256};r.sourceBytes=r.sourcePins.reduce((n,p)=>n+p.bytes,0);
  fs.writeFileSync(file,JSON.stringify(r,null,2)+'\n');
 }
 console.log(JSON.stringify({success:true,label,finalized:true,sharedNativeBuilds:0}));process.exit(0);
}
if(operation!=='prepare'||fs.existsSync(stage))throw Error('Existing experiment is preserved');
const parentFile=path.join(project,'.cache/native-dense-area/native-dense-quiescent-v2/candidate-sources.json'),parent=JSON.parse(read(parentFile));
for(const p of parent.sourcePins)if(hash(read(safe(parent.sourceProject,p.relative)))!==p.finalSha256)throw Error('Frozen parent changed: '+p.relative);
const poseHeader='native/experimental/particle_pose_cache.hpp',poseProofFile=fs.existsSync(path.join(project,'reports/native-particle-pose-cache-v3.json'))?'reports/native-particle-pose-cache-v3.json':'reports/native-particle-pose-cache-v2.json',poseProof=JSON.parse(read(path.join(project,poseProofFile)));
if(!poseProof.success||poseProof.result.checks!==10166||hash(read(path.join(project,poseHeader)))!==poseProof.sourcePins.find(p=>p.relative===poseHeader).sha256)throw Error('Pure conversion-cache gate differs');
const results=[];
for(const variant of ['baseline','candidate']){
 const destination=path.join(stage,variant),pins=structuredClone(parent.sourcePins),overrides=[];fs.mkdirSync(destination,{recursive:true});
 for(const p of pins){const output=safe(destination,p.relative);fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,read(safe(parent.sourceProject,p.relative)),{flag:'wx'});}
 function install(relative,bytes,reason){if(typeof bytes==='string')bytes=Buffer.from(bytes);const output=safe(destination,relative);fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,bytes);let pin=pins.find(p=>p.relative===relative);if(!pin){pin={relative,capturedSha256:hash(bytes)};pins.push(pin);}pin.finalSha256=hash(bytes);pin.bytes=bytes.length;overrides.push({relative,sha256:pin.finalSha256,reason});}
 // Both paths export existing per-step timers. Seven bounded sums, no second
 // emitter walk and no timer or diagnostic dictionary when profiling is off.
 let presentation=text(path.join(destination,'native/particle_presentation.hpp'));
 presentation=once(presentation,'  std::vector<Entry*> drawing;drawing.reserve(entries.size());','  std::array<double,7> phases{};const auto loop_begin=profile?Clock::now():Clock::time_point{};\n  std::vector<Entry*> drawing;drawing.reserve(entries.size());');
 presentation=once(presentation,'entry.controls.patch=EngineVar();entry.controls.detonate=false;++prepared;','entry.controls.patch=EngineVar();entry.controls.detonate=false;++prepared;\n   if(profile){phases[1]+=entry.step.controls_ms;phases[2]+=entry.step.pose_ms;phases[3]+=entry.step.admission_ms;phases[4]+=entry.step.simulation_ms;}');
 presentation=once(presentation,'  // Match the original\'s separate sorted drawing pass.','  const auto packing_begin=profile?Clock::now():Clock::time_point{};if(profile)phases[0]=std::chrono::duration<double,std::milli>(packing_begin-loop_begin).count()-phases[1]-phases[2]-phases[3]-phases[4];\n  // Match the original\'s separate sorted drawing pass.');
 presentation=once(presentation,'entry->step.geometry(target);if(target.written','entry->step.geometry(target);if(profile)phases[5]+=entry->step.geometry_ms;if(target.written');
 presentation=once(presentation,'entry->step.geometry(target,tint);','entry->step.geometry(target,tint);if(profile)phases[5]+=entry->step.geometry_ms;');
 presentation=once(presentation,'  if(counters)for(const auto id:order)','  const auto counters_begin=profile?Clock::now():Clock::time_point{};\n  if(counters)for(const auto id:order)');
 presentation=once(presentation,'  return summary();\n }\n EngineVar summary()',`  auto result=summary();if(profile){auto measured=EngineVar::dictionary();
   const std::array<const char*,7> names{"particle_native_eligibility_clock_ms","particle_native_controls_ms","particle_native_pose_ms","particle_native_admission_ms","particle_native_simulation_ms","particle_native_geometry_ms","particle_native_pack_sort_ms"};
   phases[6]=std::chrono::duration<double,std::milli>(counters_begin-packing_begin).count()-phases[5];
   for(size_t n=0;n<phases.size();++n)::set(measured,names[n],EngineVar::number(phases[n]));
   ::set(measured,"particle_native_counters_summary_ms",EngineVar::number(std::chrono::duration<double,std::milli>(Clock::now()-counters_begin).count()));::set(result,"phases",measured);
  }return result;
 }
 EngineVar summary()`);
 if(variant==='candidate'){
  let source=text(path.join(destination,'native/particle_resident.hpp'));
  source=once(source,'EnginePose read_engine_pose(uint64_t id){','EnginePose read_engine_pose(uint64_t id,particle_pose_cache::Conversion<EnginePose>* cache=nullptr){');
  const start=source.indexOf(' alignas(8) std::array<float,12> transform{};'),end=source.indexOf('\n}\nstd::string engine_string',start);
  if(start<0||end<=start)throw Error('Pose reader boundary differs');
  const body=source.slice(start,end);
  const conversion=body.replace(' alignas(8) std::array<float,12> transform{};','').replace(' ptrcall(node_transform,object,nullptr,transform.data());',' ');
  if(conversion===body||!conversion.includes('basis_orthonormal'))throw Error('Pose conversion differs');
  source=source.slice(0,start)+' alignas(8) std::array<float,12> transform{};ptrcall(node_transform,object,nullptr,transform.data());\n const auto convert=[](const std::array<float,12>& transform){'+conversion+'};\n return cache?cache->read(id,transform,convert):convert(transform);'+source.slice(end);
  source=once(source,' uint64_t pose_id=0,source_id=0;',' uint64_t pose_id=0,source_id=0;bool cache_engine_pose=true;particle_pose_cache::Conversion<EnginePose> pose_cache,source_cache;\n EnginePose read_pose(bool source=false){return read_engine_pose(source?source_id:pose_id,cache_engine_pose?(source?&source_cache:&pose_cache):nullptr);}\n EngineVar pose_diagnostics(){auto out=EngineVar::dictionary();::set(out,"enabled",EngineVar::boolean(cache_engine_pose));::set(out,"hits",EngineVar::integer(pose_cache.hits+source_cache.hits));::set(out,"conversions",EngineVar::integer(pose_cache.conversions+source_cache.conversions));return out;}');
  source=once(source,'  state=Var(::get(config,"state"));','  cache_engine_pose=!::has(config,"cacheEnginePose")||::get(config,"cacheEnginePose").boolean();\n  state=Var(::get(config,"state"));');
  source=once(source,'const auto pose=read_engine_pose(pose_id),source=source_id==pose_id?pose:read_engine_pose(source_id);','const auto pose=read_pose(),source=source_id==pose_id?pose:read_pose(true);');
  source=once(source,'default:throw std::runtime_error("Unknown native owner operation");','case 8:out=owner.pose_diagnostics();break;default:throw std::runtime_error("Unknown native owner operation");');
  install('native/particle_resident.hpp',source,'Candidate: validate/read every live transform; reuse only exact unchanged finite conversion');
  let cpp=text(path.join(destination,'native/particle_kernel.cpp'));cpp=once(cpp,'namespace {','#include "experimental/particle_pose_cache.hpp"\n\nnamespace {');install('native/particle_kernel.cpp',cpp,'Candidate-only pure conversion-cache include');
  install(poseHeader,read(path.join(project,poseHeader)),'Pure conversion cache passed10166 checks');
  presentation=once(presentation,'pose=read_engine_pose(owner->pose_id);const auto source=owner->source_id==owner->pose_id?pose:read_engine_pose(owner->source_id);','pose=owner->read_pose();const auto source=owner->source_id==owner->pose_id?pose:owner->read_pose(true);');
 }
 install('native/particle_presentation.hpp',presentation,'Common diagnostic sums; candidate also selects exact-input pose conversion reuse');
 let group=text(path.join(destination,'systems/native_render/particle_stream_group.gd'));
 group=once(group,'\tProfile.finish("particle_frame_native_presentation_ms",phase)\n\tif last.has("error"): failure=str(last.error); close(); return','\tProfile.finish("particle_frame_native_presentation_ms",phase)\n\tif last.has("error"): failure=str(last.error); close(); return\n\tif Profile.enabled:\n\t\tfor name in last.get("phases",{}): Profile.record(str(name),float(last.phases[name]))');
 install('systems/native_render/particle_stream_group.gd',group,'Common: publish seven native subphase totals only with detailed profiling');
 install('tests/native_particle_pose_cache_engine_test.gd',read(path.join(project,'tests/native_particle_pose_cache_engine_test.gd')),'Dedicated cached-versus-uncached native scene proof');
 for(const pin of pins)if(hash(read(safe(destination,pin.relative)))!==pin.finalSha256)throw Error('Copy differs');
 const privateUserData=path.join(stage,variant+'-user-data');fs.mkdirSync(privateUserData);
 const receipt={...parent,run:label,variant,sourceProject:destination,privateUserData,sourcePins:pins,sourceBytes:pins.reduce((n,p)=>n+p.bytes,0),overrides,parentReceipt:{path:parentFile,sha256:hash(read(parentFile))},isolatedBuildFinalized:false,scope:'Private particle pose conversion/phase diagnostic experiment. No ordinary source/output changes; shared outputs must remain pinned.'};
 const file=path.join(stage,variant+'-sources.json');fs.writeFileSync(file,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});results.push({variant,file,pins:pins.length});
}
fs.writeFileSync(path.join(stage,'preparation.json'),JSON.stringify({success:true,label,results,builds:0,gpu:false,serverConnections:0},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,label,results,sharedNativeBuilds:0}));
