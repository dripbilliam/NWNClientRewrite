'use strict';
// Produce one private, source-pinned Forward+ Tracy overlay. Never edits engine source.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const source=path.join(root,'.cache/native-tracy/engine-msvc-a/source/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp');
const stage=path.join(root,'.cache/nwn74/inner-phase-tracy-a');
const output=path.join(stage,'render_forward_clustered.cpp');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
assert(!fs.existsSync(stage),'Preserve prior private overlay');
const before=fs.readFileSync(source,'utf8');
assert.equal(sha(Buffer.from(before)),'fe8b102c6742d12f8a51a7312bfa8b72596277ee7d2f429fce5c97d6e03846dd');
let after=before;
function once(anchor,replacement){assert.equal(after.split(anchor).length,2,'Expected one anchor: '+anchor.slice(0,70));after=after.replace(anchor,replacement);}
once('#include "modules/nwn_frame_probe/frame_probe.h"','#include "modules/nwn_frame_probe/frame_probe.h"\n#include "core/profiling/profiling.h"');
for(const [signature,label] of [
 ['void RenderForwardClustered::_render_list_template(RenderingDevice::DrawListID p_draw_list, RenderingDevice::FramebufferFormatID p_framebuffer_Format, RenderListParameters *p_params, uint32_t p_from_element, uint32_t p_to_element) {','NWN74:render_list_template'],
 ['void RenderForwardClustered::_render_list_with_draw_list(RenderListParameters *p_params, RID p_framebuffer, BitField<RD::DrawFlags> p_draw_flags, const Vector<Color> &p_clear_color_values, float p_clear_depth_value, uint32_t p_clear_stencil_value, const Rect2 &p_region) {','NWN74:draw_list_wrapper'],
 ['void RenderForwardClustered::_fill_instance_data(RenderListType p_render_list, int *p_render_info, uint32_t p_offset, int32_t p_max_elements, bool p_update_buffer) {','NWN74:fill_instance_data'],
 ['void RenderForwardClustered::_fill_render_list(RenderListType p_render_list, const RenderDataRD *p_render_data, PassMode p_pass_mode, bool p_using_sdfgi, bool p_using_opaque_gi, bool p_using_motion_pass, bool p_append) {','NWN74:fill_render_list'],
 ['void RenderForwardClustered::_pre_opaque_render(RenderDataRD *p_render_data, bool p_use_ssao, bool p_use_ssil, bool p_use_ssr, bool p_use_gi, const RID *p_normal_roughness_slices, RID p_voxel_gi_buffer) {','NWN74:pre_opaque'],
 ]) once(signature,signature+'\n\tGodotProfileZone("'+label+'");');
once('\trender_list[RENDER_LIST_OPAQUE].sort_by_key();\n\trender_list[RENDER_LIST_MOTION].sort_by_key();\n\trender_list[RENDER_LIST_ALPHA].sort_by_reverse_depth_and_priority();',
 '\t{\n\t\tGodotProfileZone("NWN74:sort_primary");\n\t\trender_list[RENDER_LIST_OPAQUE].sort_by_key();\n\t\trender_list[RENDER_LIST_MOTION].sort_by_key();\n\t\trender_list[RENDER_LIST_ALPHA].sort_by_reverse_depth_and_priority();\n\t}');
// All four secondary sort sites share a label, while their parent render pass
// keeps them attributable to the corresponding shadow/depth operation.
const secondary='\trender_list[RENDER_LIST_SECONDARY].sort_by_key();';
assert.equal(after.split(secondary).length-1,4);
after=after.split(secondary).join('\t{ GodotProfileZone("NWN74:sort_secondary"); render_list[RENDER_LIST_SECONDARY].sort_by_key(); }');
once('\trender_list[RENDER_LIST_SECONDARY].sort_by_key_range(render_list_from, render_list_size);',
 '\t{ GodotProfileZone("NWN74:sort_secondary_range"); render_list[RENDER_LIST_SECONDARY].sort_by_key_range(render_list_from, render_list_size); }');
fs.mkdirSync(stage,{recursive:true});fs.writeFileSync(output,after,{flag:'wx'});
assert.equal(sha(fs.readFileSync(source)),sha(Buffer.from(before)));
const receipt={issue:'NWN-74',private:true,diagnosticOnly:true,acceptedUnchanged:true,source,sourceSha256:sha(Buffer.from(before)),overlay:output,overlaySha256:sha(Buffer.from(after)),zones:['render_list_template','draw_list_wrapper','fill_instance_data','fill_render_list','pre_opaque','sort_primary','sort_secondary','sort_secondary_range'],frameAttribution:'Tracy timestamps and parent render zones; primary/secondary sorts retain parent pass context',scope:'One Forward+ translation unit. No rendering/state behavior change, accepted engine edit, or FPS measurement.'};
fs.writeFileSync(path.join(stage,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(receipt));
