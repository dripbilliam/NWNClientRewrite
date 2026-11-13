'use strict';
// Source-only, fail-closed private derivative of the accepted 485 closure.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const manifest=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn64/baseline-source-pins.json'),'utf8'));
const label=process.argv[2]||'nwn64-preparation-a';
if(!/^[a-z0-9-]+$/.test(label))throw Error('Invalid private label');
const controlLabel=label+'-control';
const gap=path.join(root,'.cache/native-render-gap/particles');
const candidate=path.join(gap,label),control=path.join(gap,controlLabel);
for(const location of [candidate,control])if(fs.existsSync(location))throw Error('Retain previous capsule: '+location);
if(manifest.pins.length!==45)throw Error('Expected exact accepted 45-file source closure');
const files=new Map();
for(const pin of manifest.pins){
 const bytes=fs.readFileSync(path.join(manifest.project,pin.relative));
 if(hash(bytes)!==pin.sha256||bytes.length!==pin.bytes)throw Error('Accepted baseline changed: '+pin.relative);
 files.set(pin.relative,bytes);
}
const changes=[];
function edit(relative,transform){
 const original=files.get(relative);if(!original)throw Error('Unpinned source: '+relative);
 let source=original.toString('utf8').replace(/\r\n/g,'\n');
 const replace=(before,after)=>{
  if(source.split(before).length!==2)throw Error('Anchor must occur exactly once: '+relative+' '+before.slice(0,90));
  source=source.replace(before,after);
 };
 transform(replace);
 const after=Buffer.from(source.replace(/\n/g,'\r\n'));
 files.set(relative,after);changes.push({relative,beforeSha256:hash(original),afterSha256:hash(after)});
}
edit('native/particle_resident.hpp',replace=>{
 replace('using EngineVar=Var;','using EngineVar=Var;\n#include "particle_preparation_audit.hpp"');
 replace('auto callable=::get(*context->providers,name);','particle_preparation_audit::CallbackScope audit_callback;\n auto callable=::get(*context->providers,name);');
});
edit('native/particle_frame_sampler.hpp',replace=>{
 replace('struct Invocation {bool profile_seen=', 'struct Invocation {particle_preparation_audit::Frame preparation;bool profile_seen=');
 replace('struct Sample {uint64_t call=', 'struct Sample {particle_preparation_audit::Data preparation;bool preparation_enabled=false;uint64_t call=');
 replace('bool coarse_phases=false;uint64_t phase_clock_reads=', 'bool preparation_subphases=false;bool coarse_phases=false;uint64_t phase_clock_reads=');
 replace('const bool reset=::has(input,"reset")&&::get(input,"reset").boolean();',
  'const bool next_preparation=::has(input,"preparation_subphases")?::get(input,"preparation_subphases").boolean():preparation_subphases;\n  const bool reset=::has(input,"reset")&&::get(input,"reset").boolean();');
 replace('coarse_phases=next_coarse;enabled=next_enabled;', 'preparation_subphases=next_preparation;coarse_phases=next_coarse;enabled=next_enabled;');
 replace('::set(out,"coarse_phases",EngineVar::boolean(coarse_phases));', '::set(out,"preparation_subphases",EngineVar::boolean(preparation_subphases));::set(out,"coarse_phases",EngineVar::boolean(coarse_phases));');
 replace('sample.boundary));::method(rows,"append",{row});', 'sample.boundary));if(sample.preparation_enabled)::set(row,"preparation_audit",particle_preparation_audit::publish(sample.preparation));::method(rows,"append",{row});');
});
edit('native/particle_presentation.hpp',replace=>{
 replace('EngineVar patch;float explicit_radius=-1;', 'EngineVar patch;float explicit_radius=-1;bool preparation_boundary=false;');
 replace('owner->sample(controls.clip,controls.time);finish(controls_ms);',
  'particle_preparation_audit::count(particle_preparation_audit::SOURCES);\n  const auto sampled_before=owner->sampled_channels,constant_before=owner->constant_hits;\n  particle_preparation_audit::Span audit_channels(particle_preparation_audit::CHANNELS);owner->sample(controls.clip,controls.time);audit_channels.finish();\n  particle_preparation_audit::count(particle_preparation_audit::CHANNEL_SAMPLES,static_cast<uint64_t>(owner->sampled_channels-sampled_before));particle_preparation_audit::count(particle_preparation_audit::CONSTANT_HITS,static_cast<uint64_t>(owner->constant_hits-constant_before));finish(controls_ms);\n  particle_preparation_audit::Span audit_patch(particle_preparation_audit::PATCH);');
 replace('pose=owner->read_pose();const auto source=owner->source_id==owner->pose_id?pose:owner->read_pose(true);',
  'audit_patch.finish();\n  particle_preparation_audit::Span audit_pose(particle_preparation_audit::POSE);pose=owner->read_pose();audit_pose.finish();if(auto* audit=particle_preparation_audit::active())audit->pose(owner->pose_id,false);\n  EnginePose source;if(owner->source_id==owner->pose_id){source=pose;particle_preparation_audit::count(particle_preparation_audit::POSE_SOURCE_SAME);}else{particle_preparation_audit::Span audit_source(particle_preparation_audit::SOURCE_POSE);source=owner->read_pose(true);audit_source.finish();if(auto* audit=particle_preparation_audit::active())audit->pose(owner->source_id,true);}\n  particle_preparation_audit::Span audit_publish(particle_preparation_audit::SOURCE_PUBLISH);');
 replace('finish(pose_ms);\n  resident::Context ctx;', 'finish(pose_ms);audit_publish.finish();\n  particle_preparation_audit::Span audit_context(particle_preparation_audit::CONTEXT);resident::Context ctx;');
 replace('resident::ContextScope scope(ctx);\n  if(emitter.flags&4)', 'resident::ContextScope scope(ctx);audit_context.finish();\n  particle_preparation_audit::Span audit_admission(particle_preparation_audit::ADMISSION);if(emitter.flags&4)');
 replace('finish(admission_ms);\n  if(!culled&&controls.animate){', 'finish(admission_ms);audit_admission.finish();\n  if(culled)particle_preparation_audit::count(particle_preparation_audit::CULLED);if(!controls.animate)particle_preparation_audit::count(particle_preparation_audit::NOT_ANIMATING);\n  if(!culled&&controls.animate){\n   particle_preparation_audit::Span audit_simulation(particle_preparation_audit::SIMULATION);');
 replace('resident::compact_particle::Bridge bridge(owner->state,owner->compact_extras);\n   resident::compact_particle::animate',
  'if(auto* audit=particle_preparation_audit::active()){\n    auto& counts=audit->data.counts;counts[particle_preparation_audit::ACTIVE_BEFORE]+=owner->compact_pool.active.size();\n    if(!updated)++counts[particle_preparation_audit::FADED];if(emitter.chunk)++counts[particle_preparation_audit::CHUNK];if(emitter.flags&4)++counts[particle_preparation_audit::WIND];if(emitter.flags&16)++counts[particle_preparation_audit::BOUNCE];\n    ++counts[owner->kind==0?particle_preparation_audit::FOUNTAIN:owner->kind==1?particle_preparation_audit::EXPLOSION:particle_preparation_audit::SINGLE];\n    audit->safe=updated&&!emitter.chunk&&!(emitter.flags&(4U|16U));\n    const bool no_birth=(owner->kind==0&&emitter.birthRate<=0)||(owner->kind==1&&(emitter.birthRate==0||emitter.detonate108==0||emitter.blastLatch1c8>=1))||(owner->kind==2&&!owner->compact_pool.active.empty()&&(emitter.birthRate>=1||emitter.birthRate<=-1));\n    audit->no_birth=audit->safe&&no_birth;audit->groupable=audit->no_birth&&!controls.preparation_boundary&&owner->kind!=2;\n    if(audit->safe)++counts[particle_preparation_audit::SAFE_PREFIX];if(audit->no_birth)++counts[particle_preparation_audit::NO_BIRTH_PREFIX];\n    if(audit->groupable){++counts[particle_preparation_audit::GROUPABLE_NO_BIRTH];++audit->data.segment;audit->data.max_segment=std::max(audit->data.max_segment,audit->data.segment);}else audit->boundary();\n   }\n   resident::compact_particle::Bridge bridge(owner->state,owner->compact_extras);\n   resident::compact_particle::animate');
 replace('if(sampling_context){sampling_context->profile_seen=true;sampling_context->profile=profile;}', 'if(sampling_context){sampling_context->profile_seen=true;sampling_context->profile=profile;sampling_context->preparation.enabled=sampler.preparation_subphases&&!profile;}');
 replace('const auto eligibility_begin=profile?Clock::now():Clock::time_point{};', 'particle_preparation_audit::Span audit_eligibility(particle_preparation_audit::ELIGIBILITY);\n   const auto eligibility_begin=profile?Clock::now():Clock::time_point{};');
 replace('count();continue;}\n   if(profile)boundary_ms[0]', 'count();audit_eligibility.finish();continue;}\n   audit_eligibility.finish();if(profile)boundary_ms[0]');
 replace('if(!entry.owner){if(sampler.coarse_phases', 'if(!entry.owner){if(auto* audit=particle_preparation_audit::active())audit->boundary();if(sampler.coarse_phases');
 replace('::method(entry.fallback,"call",{EngineVar::number(delta)});', '{particle_preparation_audit::CallbackScope audit_callback;::method(entry.fallback,"call",{EngineVar::number(delta)});}');
 replace('const bool source_exists=fused?', 'particle_preparation_audit::Span audit_exists(particle_preparation_audit::SOURCE_EXISTS);const bool source_exists=fused?');
 replace('if(!source_exists)continue;', 'audit_exists.finish();if(!source_exists)continue;');
 replace('if(!entry.readiness.nil()){if(sampler.coarse_phases', 'const bool audit_had_readiness=!entry.readiness.nil();\n   if(!entry.readiness.nil()){particle_preparation_audit::Span audit_ready(particle_preparation_audit::READINESS);particle_preparation_audit::count(particle_preparation_audit::READY_CALLBACK);if(auto* audit=particle_preparation_audit::active())audit->boundary();if(sampler.coarse_phases');
 replace('if(!::method(entry.readiness,"call").boolean())continue;', 'const bool ready=[&](){particle_preparation_audit::CallbackScope audit_callback;return ::method(entry.readiness,"call").boolean();}();if(!ready)continue;');
 replace('const auto clock_begin=profile?Clock::now():Clock::time_point{};', 'next.preparation_boundary=audit_had_readiness||entry.clock_route==2||!entry.controls.patch.nil()||entry.controls.detonate;\n   if(!entry.controls.patch.nil()||entry.controls.detonate)particle_preparation_audit::count(particle_preparation_audit::PATCHED);\n   particle_preparation_audit::Span audit_clock(particle_preparation_audit::CLOCK);const auto clock_begin=profile?Clock::now():Clock::time_point{};');
 replace('if(actor_clock){if(sampler.coarse_phases', 'if(actor_clock){particle_preparation_audit::count(particle_preparation_audit::LIVE_CLOCK);if(auto* audit=particle_preparation_audit::active())audit->boundary();if(sampler.coarse_phases');
 replace('auto sampled=::method(entry.clock,"call");', 'auto sampled=[&](){particle_preparation_audit::CallbackScope audit_callback;return ::method(entry.clock,"call");}();');
 replace('if(profile)boundary_ms[2]+=', 'audit_clock.finish();if(profile)boundary_ms[2]+=');
 replace('FrameSampler::Invocation invocation;auto* previous=', 'FrameSampler::Invocation invocation;particle_preparation_audit::FrameScope preparation_scope(invocation.preparation);auto* previous=');
 replace('if(!sampler.enabled||!sampler.select(entries.size()))return frame(input);', 'if(!sampler.enabled||!sampler.select(entries.size())){particle_preparation_audit::Frame disabled;particle_preparation_audit::FrameScope preparation_scope(disabled);return frame(input);}');
 replace('sample.external=invocation.external;', 'sample.preparation_enabled=invocation.preparation.enabled;sample.preparation=invocation.preparation.data;sample.external=invocation.external;');
});
edit('native/particle_compact.hpp',replace=>{
 replace('Particle* spawn(Emitter& e,Pool& pool,float delta,float factor,Services& service){', 'Particle* spawn(Emitter& e,Pool& pool,float delta,float factor,Services& service){\n particle_preparation_audit::count(particle_preparation_audit::BIRTHS_CALLED);');
 replace('void fountain(Emitter& e,Pool& pool,float delta,Services& service){', 'void fountain(Emitter& e,Pool& pool,float delta,Services& service){\n particle_preparation_audit::Span audit_existing(particle_preparation_audit::EXISTING);');
 replace('standard(e,pool,delta,service);const auto rate_int=', 'standard(e,pool,delta,service);audit_existing.finish();particle_preparation_audit::Span audit_births(particle_preparation_audit::BIRTHS);const auto rate_int=');
 replace('void explosion(Emitter& e,Pool& pool,float delta,Services& service){', 'void explosion(Emitter& e,Pool& pool,float delta,Services& service){\n particle_preparation_audit::Span audit_existing(particle_preparation_audit::EXISTING);');
 replace('if(count!=0&&e.detonate108!=0&&1>e.blastLatch1c8)', 'audit_existing.finish();particle_preparation_audit::Span audit_births(particle_preparation_audit::BIRTHS);\n if(count!=0&&e.detonate108!=0&&1>e.blastLatch1c8)');
 replace('for(int64_t n=0;n<std::max(0,count);++n){const bool reuse=', 'for(int64_t n=0;n<std::max(0,count);++n){particle_preparation_audit::count(particle_preparation_audit::BIRTHS_CALLED);const bool reuse=');
 replace('void single(Emitter& e,Pool& pool,float delta,Services& service){', 'void single(Emitter& e,Pool& pool,float delta,Services& service){\n particle_preparation_audit::Span audit_existing(particle_preparation_audit::EXISTING);');
 replace('if(pool.active.empty()){auto part=create(e,pool,delta,service);pool.append(part);randomize(*part,e,service);return;}', 'if(pool.active.empty()){audit_existing.finish();particle_preparation_audit::Span audit_births(particle_preparation_audit::BIRTHS);particle_preparation_audit::count(particle_preparation_audit::BIRTHS_CALLED);auto part=create(e,pool,delta,service);pool.append(part);randomize(*part,e,service);return;}');
});
const auditRelative='native/particle_preparation_audit.hpp';
const auditHeader=fs.readFileSync(path.join(__dirname,'particle_preparation_audit.hpp'));
files.set(auditRelative,auditHeader);changes.push({relative:auditRelative,beforeSha256:null,afterSha256:hash(auditHeader)});
function saveCapsule(directory,inputFiles,scope){
 const project=path.join(directory,'kernel-project');fs.mkdirSync(project,{recursive:true});
 const pins=[];
 for(const [relative,bytes] of inputFiles){const target=path.join(project,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);pins.push({relative,bytes:bytes.length,sha256:hash(bytes)});}
 const proof={version:1,issue:'NWN-64/NWN-73',project,pins,scope,acceptedBinarySha256:'485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d'};
 fs.writeFileSync(path.join(directory,'kernel-source-pins.json'),JSON.stringify(proof,null,2)+'\n');return {directory,project,pinsSha256:hash(fs.readFileSync(path.join(directory,'kernel-source-pins.json'))),sourceFiles:pins.length};
}
const before=new Map(manifest.pins.map(pin=>[pin.relative,fs.readFileSync(path.join(manifest.project,pin.relative))]));
const controlProof=saveCapsule(control,before,'Exact accepted485 source control; no selected artifact mutation.');
const candidateProof=saveCapsule(candidate,files,'PRIVATE UNACCEPTED diagnostic-only derivative; opt-in source-preparation sparse subphases, profile=false/fused eligibility unchanged. No workers or optimization.');
const receipt={version:1,issue:'NWN-64/NWN-73',label,control:controlProof,candidate:candidateProof,changes,
 factorySha256:hash(fs.readFileSync(__filename)),baselineManifestSha256:hash(fs.readFileSync(path.join(root,'.cache/nwn64/baseline-source-pins.json'))),
 sharedSourceWrites:0,sharedBinaryWrites:0,engineStarts:0,compilations:0,defaultChanges:0};
fs.writeFileSync(path.join(candidate,'proposal.json'),JSON.stringify(receipt,null,2)+'\n');
process.stdout.write(JSON.stringify(receipt,null,2)+'\n');
