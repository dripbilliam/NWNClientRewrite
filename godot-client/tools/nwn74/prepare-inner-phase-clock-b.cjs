'use strict';
// Add sampled per-draw phases to the successful private frame-clock overlay.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),source=path.join(root,'.cache/nwn74/inner-phase-clock-a/render_forward_clustered.cpp');
const stage=path.join(root,'.cache/nwn74/inner-phase-clock-b'),output=path.join(stage,'render_forward_clustered.cpp');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
assert(!fs.existsSync(stage));const before=fs.readFileSync(source,'utf8');
assert.equal(sha(Buffer.from(before)),'1e403149df32010d86a60aef350ca1255787a443648a983e9eee952433c97fca');
let after=before;function one(a,b){assert.equal(after.split(a).length,2,'Anchor differs: '+a.slice(0,70));after=after.replace(a,b);}
one('NWN74_RENDER_LIST_TEMPLATE, NWN74_DRAW_LIST_WRAPPER, NWN74_PRE_OPAQUE, NWN74_PHASE_COUNT',
 'NWN74_RENDER_LIST_TEMPLATE, NWN74_DRAW_LIST_WRAPPER, NWN74_PRE_OPAQUE,\n    NWN74_INPUT_MASK, NWN74_VERTEX_ARRAY, NWN74_PIPELINE, NWN74_BINDING, NWN74_PUSH, NWN74_DRAW, NWN74_PHASE_COUNT');
one('"sort_primary", "sort_secondary", "render_list_template", "draw_list_wrapper", "pre_opaque" };',
 '"sort_primary", "sort_secondary", "render_list_template", "draw_list_wrapper", "pre_opaque",\n    "input_mask", "vertex_array", "pipeline", "binding", "push", "draw" };');
one('uint64_t frame = UINT64_MAX, frames = 0;','uint64_t frame = UINT64_MAX, frames = 0, submitted_draws = 0;');
one('String row = "NWN74_INNER frame=" + itos(frame) + " frames=" + itos(frames);',
 'String row = "NWN74_INNER frame=" + itos(frame) + " frames=" + itos(frames) + " submitted_draws=" + itos(submitted_draws);\n            submitted_draws = 0;');
one('explicit Nwn74InnerScope(Nwn74InnerPhase p) : phase(p) {\n        if (nwn74_inner_clock.enabled) {',
 'explicit Nwn74InnerScope(Nwn74InnerPhase p, bool sampled = true) : phase(p) {\n        if (sampled && nwn74_inner_clock.enabled) {');
one('\t\tpush_constant.base_index = i + p_params->element_offset;',
 '\t\tconst bool nwn74_sample = (i & 7u) == 0u;\n\t\tpush_constant.base_index = i + p_params->element_offset;');
one('\t\t\tuint64_t input_mask = shader->get_vertex_input_mask(pipeline_key.version, pipeline_key.color_pass_flags, pipeline_key.ubershader);',
 '\t\t\tuint64_t input_mask;\n\t\t\t{ Nwn74InnerScope nwn74_clock_input_mask(NWN74_INPUT_MASK, nwn74_sample);\n\t\t\t\tinput_mask = shader->get_vertex_input_mask(pipeline_key.version, pipeline_key.color_pass_flags, pipeline_key.ubershader);\n\t\t\t}');
one('\t\t\tif (surf->owner->mesh_instance.is_valid()) {\n\t\t\t\tmesh_storage->mesh_instance_surface_get_vertex_arrays_and_format',
 '\t\t\t{ Nwn74InnerScope nwn74_clock_vertex_array(NWN74_VERTEX_ARRAY, nwn74_sample);\n\t\t\tif (surf->owner->mesh_instance.is_valid()) {\n\t\t\t\tmesh_storage->mesh_instance_surface_get_vertex_arrays_and_format');
one('\t\t\t\tmesh_storage->mesh_surface_get_vertex_arrays_and_format(mesh_surface, input_mask, pipeline_motion_vectors, emulate_point_size, vertex_array_rd, vertex_format);\n\t\t\t}\n\n\t\t\tpipeline_key.vertex_format_id',
 '\t\t\t\tmesh_storage->mesh_surface_get_vertex_arrays_and_format(mesh_surface, input_mask, pipeline_motion_vectors, emulate_point_size, vertex_array_rd, vertex_format);\n\t\t\t}\n\t\t\t}\n\n\t\t\tpipeline_key.vertex_format_id');
one('\t\t\tpipeline_hash = pipeline_key.hash();',
 '\t\t\t{ Nwn74InnerScope nwn74_clock_pipeline(NWN74_PIPELINE, nwn74_sample);\n\t\t\tpipeline_hash = pipeline_key.hash();');
one('\t\t\t} else {\n\t\t\t\t// The same pipeline is bound already.\n\t\t\t\tpipeline_valid = true;\n\t\t\t\tbreak;\n\t\t\t}\n\t\t}\n\n\t\tif (pipeline_valid)',
 '\t\t\t} else {\n\t\t\t\t// The same pipeline is bound already.\n\t\t\t\tpipeline_valid = true;\n\t\t\t\tbreak;\n\t\t\t}\n\t\t\t}\n\t\t}\n\n\t\tif (pipeline_valid)');
one('\t\tif (pipeline_valid) {\n\t\t\tif (!emulate_point_size)',
 '\t\tif (pipeline_valid) {\n\t\t\tconst uint64_t nwn74_binding_start = nwn74_sample ? OS::get_singleton()->get_ticks_usec() : 0;\n\t\t\tif (!emulate_point_size)');
one('\t\t\tif (surf->owner->base_flags & INSTANCE_DATA_FLAG_PARTICLES) {',
 '\t\t\tif (nwn74_binding_start) {\n\t\t\t\tnwn74_inner_clock.total_us[NWN74_BINDING] += OS::get_singleton()->get_ticks_usec() - nwn74_binding_start;\n\t\t\t\tnwn74_inner_clock.calls[NWN74_BINDING]++;\n\t\t\t}\n\t\t\tif (surf->owner->base_flags & INSTANCE_DATA_FLAG_PARTICLES) {');
one('\t\t\tRD::get_singleton()->draw_list_set_push_constant(draw_list, &push_constant, push_constant_size);',
 '\t\t\t{ Nwn74InnerScope nwn74_clock_push(NWN74_PUSH, nwn74_sample);\n\t\t\t\tRD::get_singleton()->draw_list_set_push_constant(draw_list, &push_constant, push_constant_size);\n\t\t\t}');
one('\t\t\tif (emulate_point_size) {\n\t\t\t\tif (indirect)',
 '\t\t\tif (nwn74_inner_clock.enabled) nwn74_inner_clock.submitted_draws++;\n\t\t\t{ Nwn74InnerScope nwn74_clock_draw(NWN74_DRAW, nwn74_sample);\n\t\t\tif (emulate_point_size) {\n\t\t\t\tif (indirect)');
one('\t\t\t\tRD::get_singleton()->draw_list_draw(draw_list, index_array_rd.is_valid(), instance_count);\n\t\t\t}\n\t\t}\n\n\t\ti += element_info.repeat - 1;',
 '\t\t\t\tRD::get_singleton()->draw_list_draw(draw_list, index_array_rd.is_valid(), instance_count);\n\t\t\t}\n\t\t\t}\n\t\t}\n\n\t\ti += element_info.repeat - 1;');
fs.mkdirSync(stage,{recursive:true});fs.writeFileSync(output,after,{flag:'wx'});
const receipt={issue:'NWN-74',private:true,source,sourceSha256:sha(Buffer.from(before)),overlay:output,overlaySha256:sha(Buffer.from(after)),gate:'NWN74_INNER_PHASES=1',sampleIndexMask:7,periodFrames:120,scope:'Same frame-phase clock as A plus sampled per-draw operation scopes. Exact draw code and order unchanged; no accepted engine edit.'};
fs.writeFileSync(path.join(stage,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(receipt));
