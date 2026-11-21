'use strict';
// Read-only source-pinned draw operation count. No engine/client launch.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),base='.cache/native-tracy/engine-msvc-a/source/servers/rendering/renderer_rd/forward_clustered/';
const pins={
 [base+'render_forward_clustered.cpp']:'fe8b102c6742d12f8a51a7312bfa8b72596277ee7d2f429fce5c97d6e03846dd',
 [base+'scene_shader_forward_clustered.cpp']:'d3cf861a3b184c42e9f7aa6bc331b9ef9267eab69701af8f8dd059de8b02a31a',
 'reports/nwn74-forward-census-d.performance.jsonl':'77884899f548d24b237611f08ebb639b25731fe007994ef88ce869babe0fd9c4'
};
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const source=Object.fromEntries(Object.entries(pins).map(([file,pin])=>{const bytes=fs.readFileSync(path.join(root,file));assert.equal(sha(bytes),pin,`Changed source: ${file}`);return [file,bytes.toString()]}));
const draw=source[base+'render_forward_clustered.cpp'],shader=source[base+'scene_shader_forward_clustered.cpp'];
const loop=draw.split('void RenderForwardClustered::_render_list_template(')[1].split('// Make the actual redraw request')[0];
assert(loop.includes('shader->get_vertex_input_mask(pipeline_key.version, pipeline_key.color_pass_flags, pipeline_key.ubershader)'));
assert(loop.includes('if (material_uniform_set != prev_material_uniform_set)'));
assert(loop.includes('if (xforms_uniform_set.is_valid() && prev_xforms_uniform_set != xforms_uniform_set)'));
assert(loop.includes('if (shader != prev_shader || pipeline_hash != prev_pipeline_hash)'));
assert(shader.includes('vertex_input_masks[shader_version].load(std::memory_order_relaxed)'));
assert(shader.includes('if (input_mask == 0)'));
const rows=source['reports/nwn74-forward-census-d.performance.jsonl'].trim().split(/\r?\n/).map(JSON.parse).filter(x=>x.frame_profile?.frames===240).slice(-3);assert.equal(rows.length,3);
const names=['rt_forward_draw_calls','rt_forward_vertex_lookups','rt_forward_vertex_binds','rt_forward_pipeline_hashes','rt_forward_pipeline_lookups','rt_forward_pipeline_reuses','rt_forward_material_binds','rt_forward_xform_binds','rt_forward_ubershader_fallbacks'];
const counts=rows.map(r=>Object.fromEntries(names.map(k=>[k,r.frame_profile.metrics[k].mean])));
assert(counts.every(c=>Math.abs(c.rt_forward_draw_calls-3054)<0.02&&c.rt_forward_vertex_lookups===c.rt_forward_draw_calls&&c.rt_forward_pipeline_hashes===c.rt_forward_draw_calls&&c.rt_forward_ubershader_fallbacks===0));
const receipt={issue:'NWN-74',scope:'Current Forward+ source and saved 3,054-draw count audit; no engine/client launch',pins,counts,conclusion:'Vertex input masks are requested once per drawn element in this no-fallback scene, but ShaderData already caches each shader-version mask in an atomic slot; warm draws do not repeat the expensive RenderingDevice shader mask query. Pipeline lookup/bind and transforms/material uniform binds are already guarded by previous state. The remaining 3,054 push-constant and draw commands encode varying base indices and required passes. No new substantial exact duplicate is proven; no private candidate justified.',productionEdited:false,fpsMeasured:false};
const out=path.join(root,'tools/nwn74/next-inner-operation-gate.json');assert(!fs.existsSync(out));fs.writeFileSync(out,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({sourcePinned:true,windows:counts.length,draws:counts.map(x=>x.rt_forward_draw_calls),vertexBinds:counts.map(x=>x.rt_forward_vertex_binds),pipelineReuses:counts.map(x=>x.rt_forward_pipeline_reuses),output:out}));
