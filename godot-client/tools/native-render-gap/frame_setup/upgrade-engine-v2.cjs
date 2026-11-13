'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const project=path.resolve(__dirname,'../../..'),stage=path.join(project,'.cache/native-render-gap/engine'),file=path.join(stage,'manifest.json'),prior=JSON.parse(fs.readFileSync(file)),source=prior.source;
const sha=x=>crypto.createHash('sha256').update(x).digest('hex');
const plans=new Map(),patches=new Map(prior.patches.map(p=>[p.relative,p]));
function read(relative){return plans.get(relative)?.after??fs.readFileSync(path.join(source,relative),'utf8');}
function edit(relative,transform){
 const before=read(relative),after=transform(before);if(before===after)throw Error('No change '+relative);
 if(!plans.has(relative))plans.set(relative,{before,after});else plans.get(relative).after=after;
}
function once(s,a,b){if(s.split(a).length!==2)throw Error('Nonunique source anchor '+a.slice(0,120));return s.replace(a,b);}
for(const p of prior.patches)if(sha(fs.readFileSync(path.join(source,p.relative)))!==p.afterSha256)throw Error('Current private source drift');
for(const p of prior.modules)if(sha(fs.readFileSync(path.join(source,p.relative)))!==p.sha256)throw Error('Current module drift');
const pair=require('../original/bounds-repair/pair-guard.cjs').transform(read('servers/rendering/renderer_scene_cull.h'),read('servers/rendering/renderer_scene_cull.cpp'));
edit('servers/rendering/renderer_scene_cull.h',()=>pair.header);
edit('servers/rendering/renderer_scene_cull.cpp',()=>pair.source);
const keys=['QUEUE_BONES_NOTIFICATION','QUEUE_SKELETON_DATA_NOTIFICATION','QUEUE_AABB_NOTIFICATION','TRANSFORM_CALLS','TRANSFORM_EQUAL','CUSTOM_AABB_CALLS','CUSTOM_AABB_EQUAL','DIRTY_MESH_SKELETON','DIRTY_MESH_CUSTOM_AABB','DIRTY_BOUNDS_EQUAL','DIRTY_BOUNDS_CHANGED','PAIR_REPAIR_US','PAIR_REPAIRS','PAIR_BONE_ONLY_EQUAL_BOUNDS','PAIR_SKIPPED','BONE_GUARD_SKIPPED','SKELETON_UPLOADS_CHANGED','SKELETON_UPLOADS_UNCHANGED','VIEWPORT_DRAW_US'];
edit('modules/nwn_frame_probe/frame_probe.h',s=>{
 s=once(s,' COUNT\n',' '+keys.join(', ')+',\n COUNT\n');
 s=once(s,'void finish();','void finish();\nvoid instance_sample(uint64_t node, uint64_t instance, uint64_t skeleton, uint64_t flags);');
 return once(s,' static Dictionary completed_frame();',' static Dictionary completed_frame();\n static Dictionary dirty_instance_sample();');
});
edit('modules/nwn_frame_probe/frame_probe.cpp',s=>{
 s=once(s,'std::atomic<uint64_t> pending[NwnFrameMetrics::COUNT]{};','std::atomic<uint64_t> pending[NwnFrameMetrics::COUNT]{};\nconstexpr int SAMPLE_LIMIT=512;\nstd::atomic<uint64_t> published_samples[SAMPLE_LIMIT][4]{};\nstd::atomic<uint64_t> published_sample_count{0}, published_sample_total{0};\nthread_local uint64_t samples[SAMPLE_LIMIT][4]{};\nthread_local uint64_t sample_total=0;');
 s=once(s,' "bone_calls", "bone_equal", "bone_changed", "skeleton_uploads", "skeleton_upload_bytes"',' "bone_calls", "bone_equal", "bone_changed", "skeleton_uploads", "skeleton_upload_bytes",\n '+keys.map(k=>'"'+k.toLowerCase()+'"').join(', '));
 s=once(s,' frame_started = OS::get_singleton()->get_ticks_usec();',' sample_total=0;\n frame_started = OS::get_singleton()->get_ticks_usec();');
 s=once(s,'void finish() {','void instance_sample(uint64_t node,uint64_t instance,uint64_t skeleton,uint64_t flags) {\n if(!recording) return;\n if(sample_total<SAMPLE_LIMIT) { samples[sample_total][0]=node; samples[sample_total][1]=instance; samples[sample_total][2]=skeleton; samples[sample_total][3]=flags; }\n ++sample_total;\n}\nvoid finish() {');
 s=once(s,' frame_id.fetch_add(1);',' const uint64_t count=MIN(sample_total,uint64_t(SAMPLE_LIMIT));\n for(uint64_t i=0;i<count;++i) for(int j=0;j<4;++j) published_samples[i][j].store(samples[i][j]);\n published_sample_count.store(count); published_sample_total.store(sample_total);\n frame_id.fetch_add(1);');
 s=once(s,'void NwnFrameProbe::_bind_methods() {',
 'Dictionary NwnFrameProbe::dirty_instance_sample() {\n Dictionary out; out["available"]=false;\n for(int attempt=0;attempt<5;++attempt) {\n  const uint64_t before=generation.load(); if(before&1) continue;\n  const uint64_t count=published_sample_count.load(),total=published_sample_total.load(),id=frame_id.load();\n  uint64_t copy[SAMPLE_LIMIT][4];\n  for(uint64_t i=0;i<count;++i)for(int j=0;j<4;++j)copy[i][j]=published_samples[i][j].load();\n  if(before!=generation.load()||id==0)continue;\n  Array rows;\n  for(uint64_t i=0;i<count;++i) { Dictionary row; row["node_id"]=int64_t(copy[i][0]);row["instance_rid"]=int64_t(copy[i][1]);row["skeleton_rid"]=int64_t(copy[i][2]);row["flags"]=int64_t(copy[i][3]);rows.push_back(row); }\n  out["available"]=true;out["frame_id"]=int64_t(id);out["total"]=int64_t(total);out["dropped"]=int64_t(total-count);out["rows"]=rows;out["scope"]="Completed rendering frame; bounded instance drain identities, no Node reads. Flags: AABB1/dependencies2/custom4/skeleton8/bone-only16; base_type in bits16+.";return out;\n } return out;\n}\nvoid NwnFrameProbe::_bind_methods() {');
 return once(s,' ClassDB::bind_static_method("NwnFrameProbe", D_METHOD("completed_frame"), &NwnFrameProbe::completed_frame);',' ClassDB::bind_static_method("NwnFrameProbe", D_METHOD("completed_frame"), &NwnFrameProbe::completed_frame);\n ClassDB::bind_static_method("NwnFrameProbe", D_METHOD("dirty_instance_sample"), &NwnFrameProbe::dirty_instance_sample);');
});
edit('servers/rendering/renderer_scene_cull.h',s=>{
 s='#include "modules/nwn_frame_probe/frame_probe.h"\n'+s;
 s=once(s,'\t\t\tInstance *instance = (Instance *)tracker->userdata;\n\t\t\tswitch (p_notification) {','\t\t\tInstance *instance = (Instance *)tracker->userdata;\n\t\t\tif(p_notification==Dependency::DEPENDENCY_CHANGED_SKELETON_BONES) NwnFrameMetrics::add(NwnFrameMetrics::QUEUE_BONES_NOTIFICATION);\n\t\t\tif(p_notification==Dependency::DEPENDENCY_CHANGED_SKELETON_DATA) NwnFrameMetrics::add(NwnFrameMetrics::QUEUE_SKELETON_DATA_NOTIFICATION);\n\t\t\tif(p_notification==Dependency::DEPENDENCY_CHANGED_AABB) NwnFrameMetrics::add(NwnFrameMetrics::QUEUE_AABB_NOTIFICATION);\n\t\t\tswitch (p_notification) {');return s;
});
edit('servers/rendering/renderer_scene_cull.cpp',s=>{
 s=once(s,'\tNwnFrameMetrics::add(NwnFrameMetrics::setup() ? NwnFrameMetrics::DIRTY_INSTANCES_SETUP : NwnFrameMetrics::DIRTY_INSTANCES_LATE);','\tNwnFrameMetrics::instance_sample(uint64_t(p_instance->object_id),p_instance->self.get_id(),p_instance->skeleton.get_id(),(p_instance->update_aabb?1:0)|(p_instance->update_dependencies?2:0)|(p_instance->custom_aabb?4:0)|(p_instance->skeleton.is_valid()?8:0)|(skeleton_pair_only?16:0)|(uint64_t(p_instance->base_type)<<16));\n\tif(p_instance->base_type==RSE::INSTANCE_MESH && p_instance->skeleton.is_valid()) NwnFrameMetrics::add(NwnFrameMetrics::DIRTY_MESH_SKELETON);\n\tif(p_instance->base_type==RSE::INSTANCE_MESH && p_instance->custom_aabb) NwnFrameMetrics::add(NwnFrameMetrics::DIRTY_MESH_CUSTOM_AABB);\n\tNwnFrameMetrics::add(NwnFrameMetrics::setup() ? NwnFrameMetrics::DIRTY_INSTANCES_SETUP : NwnFrameMetrics::DIRTY_INSTANCES_LATE);');
 s=once(s,'\tp_instance->aabb = new_aabb;','\tNwnFrameMetrics::add(p_instance->aabb==new_aabb ? NwnFrameMetrics::DIRTY_BOUNDS_EQUAL : NwnFrameMetrics::DIRTY_BOUNDS_CHANGED);\n\tp_instance->aabb = new_aabb;');
 s=once(s,'\t\tp_instance->prev_transformed_aabb = p_instance->transformed_aabb;\n\t\treturn;\n\t}\n\n\t//move instance and repair','\t\tNwnFrameMetrics::add(NwnFrameMetrics::PAIR_SKIPPED);\n\t\tp_instance->prev_transformed_aabb = p_instance->transformed_aabb;\n\t\treturn;\n\t}\n\n\t//move instance and repair');
 s=once(s,'\t//move instance and repair\n\tpair_pass++;','\tif(p_skeleton_pair_only && p_instance->transformed_aabb==p_instance->prev_transformed_aabb) NwnFrameMetrics::add(NwnFrameMetrics::PAIR_BONE_ONLY_EQUAL_BOUNDS);\n\t//move instance and repair\n\tpair_pass++;');
 s=once(s,'\tpair.pair();','\tNwnFrameMetrics::add(NwnFrameMetrics::PAIR_REPAIRS);\n\t{ NwnFrameMetrics::Scope probe(NwnFrameMetrics::PAIR_REPAIR_US); pair.pair(); }');
 s=once(s,'void RendererSceneCull::instance_set_transform(RID p_instance, const Transform3D &p_transform) {','void RendererSceneCull::instance_set_transform(RID p_instance, const Transform3D &p_transform) {\n\tNwnFrameMetrics::add(NwnFrameMetrics::TRANSFORM_CALLS);');
 s=once(s,'\tif (instance->transform == p_transform) {','\tif (instance->transform == p_transform) {\n\t\tNwnFrameMetrics::add(NwnFrameMetrics::TRANSFORM_EQUAL);');
 s=once(s,'void RendererSceneCull::instance_set_custom_aabb(RID p_instance, AABB p_aabb) {','void RendererSceneCull::instance_set_custom_aabb(RID p_instance, AABB p_aabb) {\n\tNwnFrameMetrics::add(NwnFrameMetrics::CUSTOM_AABB_CALLS);');
 s=once(s,'\tif (p_aabb != AABB()) {','\tif(instance->custom_aabb && *instance->custom_aabb==p_aabb) NwnFrameMetrics::add(NwnFrameMetrics::CUSTOM_AABB_EQUAL);\n\tif (p_aabb != AABB()) {');
 return s;
});
edit('servers/rendering/rendering_server_default.cpp',s=>once(s,'\tRSG::viewport->draw_viewports(p_swap_buffers);','\t{ NwnFrameMetrics::Scope probe(NwnFrameMetrics::VIEWPORT_DRAW_US); RSG::viewport->draw_viewports(p_swap_buffers); }'));
edit('servers/rendering/renderer_rd/storage_rd/mesh_storage.h',s=>once(s,'\tstruct Skeleton {\n','\tstruct Skeleton {\n\t\tuint64_t nwn_probe_changes = 0;\n'));
edit('servers/rendering/renderer_rd/storage_rd/mesh_storage.cpp',s=>{
 s=once(s,'\tif(NwnFrameMetrics::collecting()) {','\tstatic const bool nwn_upload_guard_exact=OS::get_singleton()->get_cmdline_user_args().find("--skeleton-upload-guard=exact")!=nullptr;\n\tif(NwnFrameMetrics::collecting() || (nwn_upload_guard_exact && !skeleton->dirty)) {');
 s=once(s,'\t NwnFrameMetrics::add(NwnFrameMetrics::BONE_CALLS);\n\t NwnFrameMetrics::add(memcmp(dataptr,words,sizeof(words))==0 ? NwnFrameMetrics::BONE_EQUAL : NwnFrameMetrics::BONE_CHANGED);',
 '\t const bool same=memcmp(dataptr,words,sizeof(words))==0;\n\t if(NwnFrameMetrics::collecting()) {\n\t  NwnFrameMetrics::add(NwnFrameMetrics::BONE_CALLS);\n\t  NwnFrameMetrics::add(same ? NwnFrameMetrics::BONE_EQUAL : NwnFrameMetrics::BONE_CHANGED);\n\t  if(!same) ++skeleton->nwn_probe_changes;\n\t }\n\t if(nwn_upload_guard_exact && !skeleton->dirty && same) { NwnFrameMetrics::add(NwnFrameMetrics::BONE_GUARD_SKIPPED); return; }');
 s=once(s,'\t\tNwnFrameMetrics::add(NwnFrameMetrics::SKELETON_UPLOADS);','\t\tNwnFrameMetrics::add(NwnFrameMetrics::SKELETON_UPLOADS);\n\t\tNwnFrameMetrics::add(skeleton->nwn_probe_changes ? NwnFrameMetrics::SKELETON_UPLOADS_CHANGED : NwnFrameMetrics::SKELETON_UPLOADS_UNCHANGED);\n\t\tskeleton->nwn_probe_changes=0;');
 return s;
});
const upgrade=path.join(stage,'upgrade-v2');if(fs.existsSync(upgrade))throw Error('Existing upgrade receipt retained');
// All anchors and previous hashes are checked before the first engine write.
fs.mkdirSync(upgrade,{recursive:true});fs.copyFileSync(file,path.join(upgrade,'previous-manifest.json'));
for(const [relative,p]of plans){const saved=path.join(upgrade,'before',relative);fs.mkdirSync(path.dirname(saved),{recursive:true});fs.writeFileSync(saved,p.before);fs.writeFileSync(path.join(source,relative),p.after);if(!relative.startsWith('modules/'))patches.set(relative,{relative,beforeSha256:patches.get(relative)?.beforeSha256??sha(p.before),afterSha256:sha(p.after)});}
const modules=[];
for(const name of ['nwn_frame_probe','nwn_particle_snapshot'])for(const f of fs.readdirSync(path.join(source,'modules',name))){const p=path.join(source,'modules',name,f);if(fs.statSync(p).isFile())modules.push({relative:path.relative(source,p),sha256:sha(fs.readFileSync(p))});}
const result={...prior,createdAt:new Date().toISOString(),revision:2,previousManifest:{file:path.join(upgrade,'previous-manifest.json'),sha256:sha(fs.readFileSync(path.join(upgrade,'previous-manifest.json')))},patches:[...patches.values()],modules,featuresDefaultOff:['RT metrics','skeleton-upload-guard','skeleton-pair-guard'],upgradeScope:'Bounded dirty-instance identities, exact reason/pair/resource attribution and independent default-off backend guards. Original app and baseline engine remain unchanged.'};
fs.writeFileSync(file,JSON.stringify(result,null,2)+'\n');fs.writeFileSync(path.join(upgrade,'receipt.json'),JSON.stringify({success:true,changes:[...plans].map(([relative,p])=>({relative,before:sha(p.before),after:sha(p.after)})),manifestSha256:sha(fs.readFileSync(file))},null,2)+'\n');console.log(JSON.stringify({success:true,source,changes:plans.size}));
