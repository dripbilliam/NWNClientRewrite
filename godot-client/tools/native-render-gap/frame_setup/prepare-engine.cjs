const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const project = path.resolve(__dirname, '../../..');
const baseline = path.join(project, '.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/source');
const stage = path.join(project, '.cache/native-render-gap/engine');
const source = path.join(stage, 'source');
const sha = data => crypto.createHash('sha256').update(data).digest('hex');
fs.mkdirSync(stage, {recursive:true});
if (fs.existsSync(source)) throw new Error('Do not overwrite an existing engine fork');
fs.cpSync(baseline, source, {recursive:true, preserveTimestamps:true, filter: p => !['.git','__pycache__'].includes(path.basename(p))});
const patches=[];
function edit(relative, transform) {
 const file=path.join(source,relative), before=fs.readFileSync(file,'utf8');
 const after=transform(before);
 if(before===after) throw new Error('Unchanged patch '+relative);
 fs.writeFileSync(file,after);
 patches.push({relative,beforeSha256:sha(before),afterSha256:sha(after)});
}
function once(text, old, replacement) {
 if(text.split(old).length!==2) throw new Error('Expected exact one occurrence: '+old.slice(0,120));
 return text.replace(old,replacement);
}
const include='#include "modules/nwn_frame_probe/frame_probe.h"\n';
edit('servers/rendering/rendering_server_default.cpp', s=>{
 s=include+s;
 s=once(s,'\tuint64_t time_usec = OS::get_singleton()->get_ticks_usec();','\tNwnFrameMetrics::begin();\n\tuint64_t time_usec = OS::get_singleton()->get_ticks_usec();');
 s=once(s,'\tRSG::scene->update(); //update scenes stuff before updating instances','\t{ NwnFrameMetrics::Scope probe(NwnFrameMetrics::SCENE_US); RSG::scene->update(); } // exact original boundary');
 s=once(s,'\tRSG::canvas->update();','\t{ NwnFrameMetrics::Scope probe(NwnFrameMetrics::CANVAS_US); RSG::canvas->update(); }');
 s=once(s,'\tframe_setup_time = double(OS::get_singleton()->get_ticks_usec() - time_usec) / 1000.0;','\tframe_setup_time = double(OS::get_singleton()->get_ticks_usec() - time_usec) / 1000.0;\n\tNwnFrameMetrics::end_setup();');
 s=once(s,'\tRSG::utilities->update_memory_info();','\tRSG::utilities->update_memory_info();\n\tNwnFrameMetrics::finish();');
 return s;
});
edit('servers/rendering/renderer_scene_cull.cpp',s=>{
 s=include+s;
 s=once(s,'void RendererSceneCull::_instance_queue_update(Instance *p_instance, bool p_update_aabb, bool p_update_dependencies) const {',
 '$&'.replace('$&','void RendererSceneCull::_instance_queue_update(Instance *p_instance, bool p_update_aabb, bool p_update_dependencies) const {')+'\n\tNwnFrameMetrics::add(NwnFrameMetrics::QUEUE_REQUESTS);');
 s=once(s,'\tif (p_instance->update_item.in_list()) {\n\t\treturn;\n\t}\n\n\t_instance_update_list.add(&p_instance->update_item);',
 '\tif (p_instance->update_item.in_list()) {\n\t\tNwnFrameMetrics::add(NwnFrameMetrics::QUEUE_COALESCED);\n\t\treturn;\n\t}\n\n\tNwnFrameMetrics::add(NwnFrameMetrics::QUEUE_ADDED);\n\t_instance_update_list.add(&p_instance->update_item);');
 s=once(s,'void RendererSceneCull::_update_dirty_instance(Instance *p_instance) const {',
 'void RendererSceneCull::_update_dirty_instance(Instance *p_instance) const {\n\tNwnFrameMetrics::add(NwnFrameMetrics::setup() ? NwnFrameMetrics::DIRTY_INSTANCES_SETUP : NwnFrameMetrics::DIRTY_INSTANCES_LATE);\n\tif(p_instance->update_aabb) NwnFrameMetrics::add(NwnFrameMetrics::DIRTY_AABB);\n\tif(p_instance->update_dependencies) NwnFrameMetrics::add(NwnFrameMetrics::DIRTY_DEPENDENCIES);\n\tNwnFrameMetrics::add(p_instance->base_type == RSE::INSTANCE_MESH ? NwnFrameMetrics::DIRTY_MESH : p_instance->base_type == RSE::INSTANCE_LIGHT ? NwnFrameMetrics::DIRTY_LIGHT : NwnFrameMetrics::DIRTY_OTHER);');
 s=once(s,'void RendererSceneCull::update_dirty_instances() const {\n\twhile (_instance_update_list.first()) {\n\t\t_update_dirty_instance(_instance_update_list.first()->self());\n\t}\n\n\t// Update dirty resources after dirty instances as instance updates may affect resources.\n\tRSG::utilities->update_dirty_resources();\n}',
 'void RendererSceneCull::update_dirty_instances() const {\n\t{ NwnFrameMetrics::Scope probe(NwnFrameMetrics::setup() ? NwnFrameMetrics::DIRTY_DRAIN_SETUP_US : NwnFrameMetrics::DIRTY_DRAIN_LATE_US);\n\twhile (_instance_update_list.first()) {\n\t\t_update_dirty_instance(_instance_update_list.first()->self());\n\t} }\n\n\t// Update dirty resources after dirty instances as instance updates may affect resources.\n\t{ NwnFrameMetrics::Scope probe(NwnFrameMetrics::setup() ? NwnFrameMetrics::RESOURCES_SETUP_US : NwnFrameMetrics::RESOURCES_LATE_US); RSG::utilities->update_dirty_resources(); }\n\tif(NwnFrameMetrics::active() && _instance_update_list.first()) NwnFrameMetrics::add(NwnFrameMetrics::PENDING_AFTER_RESOURCES);\n}');
 for(const [old,key] of [
 ['s->indexers[Scenario::INDEXER_GEOMETRY].optimize_incremental(indexer_update_iterations);','BVH_GEOMETRY_US'],
 ['s->indexers[Scenario::INDEXER_VOLUMES].optimize_incremental(indexer_update_iterations);','BVH_VOLUMES_US'],
 ['scene_render->update();','SCENE_RENDER_UPDATE_US'],['render_particle_colliders();','PARTICLE_COLLIDERS_US']]) {
  // scene_render/update and colliders are unique statements in this source.
  s=once(s,'\t'+old,'\t{ NwnFrameMetrics::Scope probe(NwnFrameMetrics::'+key+'); '+old+' }');
 }
 return s;
});
edit('servers/rendering/renderer_rd/storage_rd/utilities.cpp',s=>{
 s=include+s;
 for(const [call,key] of [
 ['MaterialStorage::get_singleton()->_update_global_shader_uniforms();','UNIFORMS_US'],
 ['MaterialStorage::get_singleton()->_update_queued_materials();','MATERIALS_US'],
 ['MeshStorage::get_singleton()->_update_dirty_multimeshes();','MULTIMESHES_US'],
 ['MeshStorage::get_singleton()->_update_dirty_skeletons();','SKELETONS_US'],
 ['TextureStorage::get_singleton()->update_decal_atlas();','DECAL_ATLAS_US'],
 ['TextureStorage::get_singleton()->update_area_light_atlas();','LIGHT_ATLAS_US']])
 s=once(s,'\t'+call,'\t{ NwnFrameMetrics::Scope probe(NwnFrameMetrics::'+key+'); '+call+' }');
 return s;
});
edit('servers/rendering/renderer_rd/storage_rd/light_storage.cpp',s=>{
 s=include+s;
 s=once(s,'\tif (light->param[p_param] == p_value) {\n\t\treturn;',
 '\tif(p_param == RSE::LIGHT_PARAM_RANGE) NwnFrameMetrics::add(NwnFrameMetrics::RANGE_CALLS);\n\tif (light->param[p_param] == p_value) {\n\t\tif(p_param == RSE::LIGHT_PARAM_RANGE) NwnFrameMetrics::add(NwnFrameMetrics::RANGE_EQUAL);\n\t\treturn;');
 s=once(s,'\n\tswitch (p_param) {','\n\tif(p_param == RSE::LIGHT_PARAM_RANGE) NwnFrameMetrics::add(NwnFrameMetrics::RANGE_CHANGED);\n\tswitch (p_param) {');
 s=once(s,'\tlight->shadow = p_enabled;','\tNwnFrameMetrics::add(NwnFrameMetrics::SHADOW_CALLS);\n\tif(light->shadow == p_enabled) NwnFrameMetrics::add(NwnFrameMetrics::SHADOW_EQUAL);\n\tlight->shadow = p_enabled;');
 return s;
});
edit('servers/rendering/renderer_rd/storage_rd/mesh_storage.cpp',s=>{
 s=include+s;
 s=once(s,'\tfloat *dataptr = skeleton->data.ptr() + p_bone * 12;\n\n\tdataptr[0] = p_transform.basis.rows[0][0];',
 '\tfloat *dataptr = skeleton->data.ptr() + p_bone * 12;\n\tif(NwnFrameMetrics::collecting()) {\n\t const float words[12]={p_transform.basis.rows[0][0],p_transform.basis.rows[0][1],p_transform.basis.rows[0][2],p_transform.origin.x,p_transform.basis.rows[1][0],p_transform.basis.rows[1][1],p_transform.basis.rows[1][2],p_transform.origin.y,p_transform.basis.rows[2][0],p_transform.basis.rows[2][1],p_transform.basis.rows[2][2],p_transform.origin.z};\n\t NwnFrameMetrics::add(NwnFrameMetrics::BONE_CALLS);\n\t NwnFrameMetrics::add(memcmp(dataptr,words,sizeof(words))==0 ? NwnFrameMetrics::BONE_EQUAL : NwnFrameMetrics::BONE_CHANGED);\n\t}\n\n\tdataptr[0] = p_transform.basis.rows[0][0];');
 s=once(s,'\t\tSkeleton *skeleton = skeleton_dirty_list;','\t\tSkeleton *skeleton = skeleton_dirty_list;\n\t\tNwnFrameMetrics::add(NwnFrameMetrics::SKELETON_UPLOADS);\n\t\tNwnFrameMetrics::add(NwnFrameMetrics::SKELETON_UPLOAD_BYTES,skeleton->data.size()*sizeof(float));');
 return s;
});
fs.cpSync(path.join(__dirname,'module'),path.join(source,'modules/nwn_frame_probe'),{recursive:true});
fs.cpSync(path.join(__dirname,'../particles/engine-module'),path.join(source,'modules/nwn_particle_snapshot'),{recursive:true});
edit('modules/nwn_particle_snapshot/register_types.cpp',s=>{
 s='#include "scene_boundary.h"\n#include "rig_skin_publisher.h"\n'+s;
 return once(s,'  GDREGISTER_CLASS(NwnParticleSceneSnapshot);','  GDREGISTER_CLASS(NwnParticleSceneSnapshot);\n  GDREGISTER_CLASS(NwnParticleSceneBoundary);\n  GDREGISTER_CLASS(NwnRigSkinPublisher);');
});
const modules=[];
for(const name of ['nwn_frame_probe','nwn_particle_snapshot']) for(const f of fs.readdirSync(path.join(source,'modules',name))) {
 const p=path.join(source,'modules',name,f); if(fs.statSync(p).isFile()) modules.push({relative:path.relative(source,p),sha256:sha(fs.readFileSync(p))});
}
const receipt={createdAt:new Date().toISOString(),baseline,source,patches,modules,defaultProbeEnabled:false,private:true,mainSourceChanged:false};
fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify(receipt,null,2));
