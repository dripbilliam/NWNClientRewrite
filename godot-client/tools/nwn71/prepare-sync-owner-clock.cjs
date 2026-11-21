'use strict';
// Stages four private engine translation units; never edits accepted source.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const source=path.join(root,'.cache/nwn71/compositor-callback-a/source');
const accepted=path.join(root,'.cache/native-tracy/engine-msvc-a/source');
const stage=path.join(root,'.cache/nwn71/sync-owner-clock-a');
assert(!fs.existsSync(stage),'Preserve prior private stage');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const files={
 'servers/rendering/rendering_server_default.cpp':'7e65ea6124921dbe e01334f8b51af4be c8368cadae128109 cdf4da0afd92abf6'.replaceAll(' ',''),
 'servers/rendering/renderer_scene_cull.cpp':'394acdb359c22923 9c5b4f12b2e5d705 5a972bff1402646e ac33ef012bd4355d'.replaceAll(' ',''),
 'servers/rendering/renderer_rd/shader_rd.cpp':'4f0264598233380f 1f5809afb0b461c5 a81f6c4bb68dcc35 10675c8713d15de1'.replaceAll(' ',''),
 'drivers/vulkan/rendering_device_driver_vulkan.cpp':'7e97f993d3467254 c0766b9cf8c75333 98dd65c932c1794f 2cd85a99f6751d15'.replaceAll(' ',''),
};
function once(text,a,b){assert.equal(text.split(a).length,2,'Unique source anchor changed: '+a.slice(0,80));return text.replace(a,b);}
function patch(relative,transform){const before=fs.readFileSync(path.join(source,relative));assert.equal(sha(before),files[relative]);assert.equal(sha(fs.readFileSync(path.join(accepted,relative))),files[relative],'Accepted source differs '+relative);const after=Buffer.from(transform(before.toString('utf8')));assert.notEqual(sha(after),sha(before));for(const [name,bytes] of [['before',before],['after',after]]){const target=path.join(stage,name,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});}return {relative,beforeSha256:sha(before),afterSha256:sha(after)};}
const changes=[];
changes.push(patch('servers/rendering/rendering_server_default.cpp',text=>{
 const helper=`// NWN-71 private diagnostic: absolute monotonic clock for queue ownership.
struct Nwn71OwnerClock {
    const char *kind;
    uint64_t start = 0;
    uint64_t threshold;
    Nwn71OwnerClock(const char *p_kind, uint64_t p_threshold) : kind(p_kind), threshold(p_threshold) {
        static const bool enabled = OS::get_singleton() != nullptr && OS::get_singleton()->get_environment("NWN71_SYNC_OWNER_CLOCK") == "1";
        if (enabled) start = OS::get_singleton()->get_ticks_usec();
    }
    ~Nwn71OwnerClock() {
        if (!start) return;
        const uint64_t end = OS::get_singleton()->get_ticks_usec();
        if (end - start >= threshold) print_line("NWN71_CLOCK kind=" + String(kind) + " start_us=" + itos(start) + " end_us=" + itos(end) + " duration_us=" + itos(end - start));
    }
};
`;
 text=once(text,'/* EVENT QUEUING */\n\nvoid RenderingServerDefault::request_frame_drawn_callback',helper+'\n/* EVENT QUEUING */\n\nvoid RenderingServerDefault::request_frame_drawn_callback');
 text=once(text,'void RenderingServerDefault::_draw(bool p_swap_buffers, double frame_step) {','void RenderingServerDefault::_draw(bool p_swap_buffers, double frame_step) {\n\tNwn71OwnerClock nwn71_draw_clock("render_draw", 20000);');
 text=once(text,'\t\tWorkerThreadPool::get_singleton()->yield();\n\t\tcommand_queue.flush_all();',
 '\t\t{ Nwn71OwnerClock nwn71_yield_clock("render_yield", 20000); WorkerThreadPool::get_singleton()->yield(); }\n\t\t{ Nwn71OwnerClock nwn71_flush_clock("render_flush", 20000); command_queue.flush_all(); }');
 text=once(text,'void RenderingServerDefault::sync() {','void RenderingServerDefault::sync() {\n\tNwn71OwnerClock nwn71_sync_clock("main_sync", 20000);');
 return text;
}));
changes.push(patch('servers/rendering/renderer_scene_cull.cpp',text=>{
 const log=(kind,details)=>`\t\t\tconst uint64_t nwn71_${kind}_start = OS::get_singleton()->get_ticks_usec();\n\t\t\tWorkerThreadPool::get_singleton()->wait_for_group_task_completion(group_task);\n\t\t\tconst uint64_t nwn71_${kind}_end = OS::get_singleton()->get_ticks_usec();\n\t\t\tif (OS::get_singleton()->get_environment("NWN71_SYNC_OWNER_CLOCK") == "1" && nwn71_${kind}_end - nwn71_${kind}_start >= 2000) print_line("NWN71_WAIT producer=${kind} group=" + itos(group_task) + " ${details} start_us=" + itos(nwn71_${kind}_start) + " end_us=" + itos(nwn71_${kind}_end) + " duration_us=" + itos(nwn71_${kind}_end - nwn71_${kind}_start));`;
 const wait='\t\t\tWorkerThreadPool::get_singleton()->wait_for_group_task_completion(group_task);';
 function replaceSite(input,label,replacement){const from=input.indexOf(label);assert(from>=0);const at=input.indexOf(wait,from);assert(at>from&&at-from<700,'Wait not adjacent to '+label);return input.slice(0,at)+replacement+input.slice(at+wait.length);}
 text=replaceSite(text,'SNAME("VisibilityCullInstances")',log('visibility','count=" + itos(visibility_cull_data.cull_count) + "'));
 text=replaceSite(text,'SNAME("RenderCullInstances")',log('scene','count=" + itos(cull_to - cull_from) + "'));
 return text;
}));
changes.push(patch('servers/rendering/renderer_rd/shader_rd.cpp',text=>{
 text=once(text,'\tWorkerThreadPool::get_singleton()->wait_for_group_task_completion(group_task);\n\tp_version->group_compilation_tasks.write[p_group] = 0;',
 '\tconst uint64_t nwn71_shader_start = OS::get_singleton()->get_ticks_usec();\n\tWorkerThreadPool::get_singleton()->wait_for_group_task_completion(group_task);\n\tconst uint64_t nwn71_shader_end = OS::get_singleton()->get_ticks_usec();\n\tif (OS::get_singleton()->get_environment("NWN71_SYNC_OWNER_CLOCK") == "1" && nwn71_shader_end - nwn71_shader_start >= 2000) print_line("NWN71_WAIT producer=shader group=" + itos(group_task) + " variant_group=" + itos(p_group) + " shader=" + String(name) + " start_us=" + itos(nwn71_shader_start) + " end_us=" + itos(nwn71_shader_end) + " duration_us=" + itos(nwn71_shader_end - nwn71_shader_start));\n\tp_version->group_compilation_tasks.write[p_group] = 0;');
 return text;
}));
changes.push(patch('drivers/vulkan/rendering_device_driver_vulkan.cpp',text=>{
 text=once(text,'\t\tVkResult err = vkWaitForFences(vk_device, 1, &fence->vk_fence, VK_TRUE, UINT64_MAX);',
 '\t\tconst uint64_t nwn71_fence_start = OS::get_singleton()->get_ticks_usec();\n\t\tVkResult err = vkWaitForFences(vk_device, 1, &fence->vk_fence, VK_TRUE, UINT64_MAX);\n\t\tconst uint64_t nwn71_fence_end = OS::get_singleton()->get_ticks_usec();\n\t\tif (OS::get_singleton()->get_environment("NWN71_SYNC_OWNER_CLOCK") == "1" && nwn71_fence_end - nwn71_fence_start >= 1000) print_line("NWN71_DEVICE_WAIT kind=vkWaitForFences start_us=" + itos(nwn71_fence_start) + " end_us=" + itos(nwn71_fence_end) + " duration_us=" + itos(nwn71_fence_end - nwn71_fence_start));');
 return text;
}));
const receipt={issue:'NWN-71',private:true,diagnosticOnly:true,source,accepted,changes,gate:'NWN71_SYNC_OWNER_CLOCK=1',clocks:'OS monotonic microseconds, shared across main/render/worker calls',thresholdsUs:{main_sync:20000,render_draw:20000,render_flush:20000,render_yield:20000,group:2000,vulkan_fence:1000},scope:'Exact queue, cull, shader group wait and Vulkan fence call boundaries; no scheduling or accepted engine change. GPU/device coverage is limited to vkWaitForFences.'};
fs.writeFileSync(path.join(stage,'source-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(receipt));
