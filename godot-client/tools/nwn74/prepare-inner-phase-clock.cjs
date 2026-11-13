'use strict';
// One-TU, opt-in render-frame phase timings when the private engine lacks Tracy.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const source=path.join(root,'.cache/native-tracy/engine-msvc-a/source/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp');
const stage=path.join(root,'.cache/nwn74/inner-phase-clock-a');
const output=path.join(stage,'render_forward_clustered.cpp');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
assert(!fs.existsSync(stage),'Preserve previous private clock stage');
const before=fs.readFileSync(source,'utf8');
assert.equal(sha(Buffer.from(before)),'fe8b102c6742d12f8a51a7312bfa8b72596277ee7d2f429fce5c97d6e03846dd');
let after=before;
function once(anchor,replacement){assert.equal(after.split(anchor).length,2,'Expected one anchor: '+anchor.slice(0,70));after=after.replace(anchor,replacement);}
once('#include "modules/nwn_frame_probe/frame_probe.h"','#include "modules/nwn_frame_probe/frame_probe.h"\n#include "core/os/os.h"');
const helper=`// NWN-74 private diagnostic only. Never linked into the accepted engine.
enum Nwn74InnerPhase { NWN74_SCENE, NWN74_SETUP_ENVIRONMENT, NWN74_FILL_RENDER_LIST,
    NWN74_FILL_INSTANCE_DATA, NWN74_SORT_PRIMARY, NWN74_SORT_SECONDARY,
    NWN74_RENDER_LIST_TEMPLATE, NWN74_DRAW_LIST_WRAPPER, NWN74_PRE_OPAQUE, NWN74_PHASE_COUNT };
static const char *const nwn74_phase_names[NWN74_PHASE_COUNT] = {
    "scene", "setup_environment", "fill_render_list", "fill_instance_data",
    "sort_primary", "sort_secondary", "render_list_template", "draw_list_wrapper", "pre_opaque" };
struct Nwn74InnerClock {
    bool enabled = OS::get_singleton() != nullptr && OS::get_singleton()->get_environment("NWN74_INNER_PHASES") == "1";
    uint64_t frame = UINT64_MAX, frames = 0;
    uint64_t total_us[NWN74_PHASE_COUNT] = {};
    uint64_t calls[NWN74_PHASE_COUNT] = {};
    void begin() {
        if (!enabled) return;
        const uint64_t current = RSG::rasterizer->get_frame_number();
        if (current == frame) return;
        if (frame != UINT64_MAX && ++frames == 120) {
            String row = "NWN74_INNER frame=" + itos(frame) + " frames=" + itos(frames);
            for (int i = 0; i < NWN74_PHASE_COUNT; ++i) {
                row += " " + String(nwn74_phase_names[i]) + "_us=" + itos(total_us[i]);
                row += " " + String(nwn74_phase_names[i]) + "_calls=" + itos(calls[i]);
                total_us[i] = calls[i] = 0;
            }
            print_line(row);
            frames = 0;
        }
        frame = current;
    }
};
static thread_local Nwn74InnerClock nwn74_inner_clock;
struct Nwn74InnerScope {
    Nwn74InnerPhase phase;
    uint64_t start = 0;
    explicit Nwn74InnerScope(Nwn74InnerPhase p) : phase(p) {
        if (nwn74_inner_clock.enabled) {
            nwn74_inner_clock.begin();
            start = OS::get_singleton()->get_ticks_usec();
        }
    }
    ~Nwn74InnerScope() {
        if (start != 0) {
            nwn74_inner_clock.total_us[phase] += OS::get_singleton()->get_ticks_usec() - start;
            nwn74_inner_clock.calls[phase]++;
        }
    }
};
`;
once('#define FADE_ALPHA_PASS_THRESHOLD 0.999\n','#define FADE_ALPHA_PASS_THRESHOLD 0.999\n\n'+helper);
for(const [signature,phase] of [
 ['void RenderForwardClustered::_render_list_template(RenderingDevice::DrawListID p_draw_list, RenderingDevice::FramebufferFormatID p_framebuffer_Format, RenderListParameters *p_params, uint32_t p_from_element, uint32_t p_to_element) {','NWN74_RENDER_LIST_TEMPLATE'],
 ['void RenderForwardClustered::_render_list_with_draw_list(RenderListParameters *p_params, RID p_framebuffer, BitField<RD::DrawFlags> p_draw_flags, const Vector<Color> &p_clear_color_values, float p_clear_depth_value, uint32_t p_clear_stencil_value, const Rect2 &p_region) {','NWN74_DRAW_LIST_WRAPPER'],
 ['uint32_t RenderForwardClustered::_setup_environment(const RenderDataRD *p_render_data, bool p_no_fog, const Size2i &p_screen_size, const Size2 &p_viewport_size, const Color &p_default_bg_color, bool p_opaque_render_buffers, bool p_apply_alpha_multiplier, bool p_pancake_shadows) {','NWN74_SETUP_ENVIRONMENT'],
 ['void RenderForwardClustered::_fill_instance_data(RenderListType p_render_list, int *p_render_info, uint32_t p_offset, int32_t p_max_elements, bool p_update_buffer) {','NWN74_FILL_INSTANCE_DATA'],
 ['void RenderForwardClustered::_fill_render_list(RenderListType p_render_list, const RenderDataRD *p_render_data, PassMode p_pass_mode, bool p_using_sdfgi, bool p_using_opaque_gi, bool p_using_motion_pass, bool p_append) {','NWN74_FILL_RENDER_LIST'],
 ['void RenderForwardClustered::_pre_opaque_render(RenderDataRD *p_render_data, bool p_use_ssao, bool p_use_ssil, bool p_use_ssr, bool p_use_gi, const RID *p_normal_roughness_slices, RID p_voxel_gi_buffer) {','NWN74_PRE_OPAQUE'],
 ['void RenderForwardClustered::_render_scene(RenderDataRD *p_render_data, const Color &p_default_bg_color) {','NWN74_SCENE'],
 ]) once(signature,signature+'\n\tNwn74InnerScope nwn74_clock_'+phase.toLowerCase()+'('+phase+');');
once('\trender_list[RENDER_LIST_OPAQUE].sort_by_key();\n\trender_list[RENDER_LIST_MOTION].sort_by_key();\n\trender_list[RENDER_LIST_ALPHA].sort_by_reverse_depth_and_priority();',
 '\t{ Nwn74InnerScope nwn74_clock_sort_primary(NWN74_SORT_PRIMARY);\n\t\trender_list[RENDER_LIST_OPAQUE].sort_by_key();\n\t\trender_list[RENDER_LIST_MOTION].sort_by_key();\n\t\trender_list[RENDER_LIST_ALPHA].sort_by_reverse_depth_and_priority();\n\t}');
const secondary='\trender_list[RENDER_LIST_SECONDARY].sort_by_key();';
assert.equal(after.split(secondary).length-1,4);
after=after.split(secondary).join('\t{ Nwn74InnerScope nwn74_clock_sort_secondary(NWN74_SORT_SECONDARY); render_list[RENDER_LIST_SECONDARY].sort_by_key(); }');
once('\trender_list[RENDER_LIST_SECONDARY].sort_by_key_range(render_list_from, render_list_size);',
 '\t{ Nwn74InnerScope nwn74_clock_sort_secondary(NWN74_SORT_SECONDARY); render_list[RENDER_LIST_SECONDARY].sort_by_key_range(render_list_from, render_list_size); }');
fs.mkdirSync(stage,{recursive:true});fs.writeFileSync(output,after,{flag:'wx'});
assert.equal(sha(fs.readFileSync(source)),sha(Buffer.from(before)));
const receipt={issue:'NWN-74',private:true,diagnosticOnly:true,source,sourceSha256:sha(Buffer.from(before)),overlay:output,overlaySha256:sha(Buffer.from(after)),gate:'NWN74_INNER_PHASES=1',periodFrames:120,phases:['scene','setup_environment','fill_render_list','fill_instance_data','sort_primary','sort_secondary','render_list_template','draw_list_wrapper','pre_opaque'],scope:'One Forward+ TU; wall microseconds grouped by RSG rasterizer frame. Inclusive nested spans must not be summed. No accepted change or FPS measurement.'};
fs.writeFileSync(path.join(stage,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(receipt));
