'use strict';
// Creates one private Forward+ source candidate; never writes accepted engine source.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const before=path.join(root,'.cache/native-tracy/engine-msvc-a/source/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp');
const output=path.join(root,'.cache/nwn74/pipeline-key-skip-a');
assert(!fs.existsSync(output),'Preserve previous private source');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const source=fs.readFileSync(before,'utf8');
assert.equal(sha(Buffer.from(source)),'fe8b102c6742d12f8a51a7312bfa8b72596277ee7d2f429fce5c97d6e03846dd');
function one(text,needle,replacement){assert.equal(text.split(needle).length,2,'Expected exactly one source anchor');return text.replace(needle,replacement)}
let candidate=source;
candidate=one(candidate,'\tSceneShaderForwardClustered::ShaderData::PipelineKey pipeline_key;\n\tuint32_t pipeline_hash = 0;',
 '\tSceneShaderForwardClustered::ShaderData::PipelineKey pipeline_key;\n\tSceneShaderForwardClustered::ShaderData::PipelineKey prev_pipeline_key;\n\tbool prev_pipeline_key_valid = false;\n\tuint32_t pipeline_hash = 0;');
candidate=one(candidate,'\t\t\tpipeline_hash = pipeline_key.hash();',
 `\t\t\t// The last successfully bound pipeline already has this hash. Compare
\t\t\t// the exact hash inputs before repeating eleven Murmur hash steps.
\t\t\tconst bool same_pipeline_key = prev_pipeline_key_valid && shader == prev_shader &&
\t\t\t\t\tpipeline_key.vertex_format_id == prev_pipeline_key.vertex_format_id &&
\t\t\t\t\tpipeline_key.framebuffer_format_id == prev_pipeline_key.framebuffer_format_id &&
\t\t\t\t\tpipeline_key.cull_mode == prev_pipeline_key.cull_mode &&
\t\t\t\t\tpipeline_key.primitive_type == prev_pipeline_key.primitive_type &&
\t\t\t\t\tpipeline_key.version == prev_pipeline_key.version &&
\t\t\t\t\tpipeline_key.color_pass_flags == prev_pipeline_key.color_pass_flags &&
\t\t\t\t\tpipeline_key.shader_specialization.packed_0 == prev_pipeline_key.shader_specialization.packed_0 &&
\t\t\t\t\tpipeline_key.shader_specialization.packed_1 == prev_pipeline_key.shader_specialization.packed_1 &&
\t\t\t\t\tpipeline_key.shader_specialization.packed_2 == prev_pipeline_key.shader_specialization.packed_2 &&
\t\t\t\t\tpipeline_key.wireframe == prev_pipeline_key.wireframe &&
\t\t\t\t\tpipeline_key.ubershader == prev_pipeline_key.ubershader;
\t\t\tpipeline_hash = same_pipeline_key ? prev_pipeline_hash : pipeline_key.hash();`);
candidate=one(candidate,'\t\t\t\t\tprev_shader = shader;\n\t\t\t\t\tprev_pipeline_hash = pipeline_hash;',
 '\t\t\t\t\tprev_shader = shader;\n\t\t\t\t\tprev_pipeline_hash = pipeline_hash;\n\t\t\t\t\tprev_pipeline_key = pipeline_key;\n\t\t\t\t\tprev_pipeline_key_valid = true;');
fs.mkdirSync(output,{recursive:true});
const after=path.join(output,'render_forward_clustered.cpp');
fs.writeFileSync(after,candidate,{flag:'wx'});
assert.equal(sha(fs.readFileSync(before)),sha(Buffer.from(source)),'Accepted source changed during private generation');
const receipt={issue:'NWN-74',private:true,accepted:false,source:before,sourceSha256:sha(Buffer.from(source)),candidate:after,candidateSha256:sha(Buffer.from(candidate)),changedTranslationUnits:['servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp'],scope:'Private exact pipeline-key hash reuse. No accepted source, executable, client or renderer default change. Source-only candidate; no build or FPS claim.'};
fs.writeFileSync(path.join(output,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(receipt));
