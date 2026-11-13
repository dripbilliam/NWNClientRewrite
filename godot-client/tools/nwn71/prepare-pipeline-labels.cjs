'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),arg=n=>process.argv.find(x=>x.startsWith('--'+n+'='))?.slice(n.length+3),label=arg('label'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
if(!label||!/^[a-z0-9-]+$/.test(label))throw Error('Fresh --label required');
const source=path.join(root,'.cache/native-tracy/engine-msvc-a/source'),base=path.join(root,'.cache/nwn71/group-labels-a'),output=path.join(root,'.cache/nwn71/pipeline-labels-'+label);if(fs.existsSync(output))throw Error('Preserve prior labels');
const changes=[];
function one(text,before,after){assert.equal(text.split(before).length,2,'Unique seam changed: '+before.slice(0,100));return text.replace(before,after);}
function write(file,edit,previous){const live=fs.readFileSync(path.join(source,file)),input=previous?fs.readFileSync(path.join(previous,file)):live,before=live.toString().replace(/\r\n/g,'\n'),after=edit(input.toString().replace(/\r\n/g,'\n'));for(const [name,bytes] of [['before',live],['after',Buffer.from(after)]]){const target=path.join(output,name,file);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});}changes.push({file,beforeSha256:sha(live),afterSha256:sha(Buffer.from(after)),priorLabelBase:previous?{file:path.join(previous,file),sha256:sha(input)}:null});}
write('core/object/worker_thread_pool.cpp',text=>one(text,'\tGodotProfileZone("NWNCapture/Worker/wait_task_scope");',`#if defined(GODOT_USE_TRACY)
	ZoneNamedN(nwn71_worker_task_wait, "NWNCapture/Worker/wait_task_scope", true);
	if (TracyIsConnected) {
		// Method input only. No dereference before lookup or after task free.
		ZoneTextVF(nwn71_worker_task_wait, "pool=%p;task=%lld", (void *)this, (long long)p_task_id);
	}
#else
	GodotProfileZone("NWNCapture/Worker/wait_task_scope");
#endif`),path.join(base,'after'));
write('servers/rendering/renderer_rd/shader_rd.cpp',text=>text,path.join(base,'after'));
write('servers/rendering/rendering_device.cpp',text=>{
 text=one(text,'\tRenderPipeline pipeline;\n\tpipeline.driver_id = driver->render_pipeline_create(',`	RenderPipeline pipeline;
#if defined(GODOT_USE_TRACY)
	{
		ZoneNamedN(nwn71_rd_pipeline_driver, "NWN71/Pipeline/rd_driver_create", true);
		if (TracyIsConnected) {
			ZoneTextVF(nwn71_rd_pipeline_driver, "shader_rid=%llu", (unsigned long long)p_shader.get_id());
		}
#endif
	pipeline.driver_id = driver->render_pipeline_create(`);
 text=one(text,'\t\t\tp_specialization_constants);\n\n\t// Don\'t print error when it\'s expected.',`			p_specialization_constants);
#if defined(GODOT_USE_TRACY)
	}
#endif

	// Don't print error when it's expected.`);
 text=one(text,'void RenderingDevice::update_pipeline_cache(bool p_closing) {\n\t_THREAD_SAFE_METHOD_',`void RenderingDevice::update_pipeline_cache(bool p_closing) {
#if defined(GODOT_USE_TRACY)
	GodotProfileZoneGroupedFirst(nwn71_rd_cache, "NWN71/Pipeline/cache_lock_wait");
#endif
	_THREAD_SAFE_METHOD_
#if defined(GODOT_USE_TRACY)
	GodotProfileZoneGrouped(nwn71_rd_cache, "NWN71/Pipeline/cache_locked");
#endif`);
 text=one(text,'\t\tsize_t new_pipelines_cache_size = driver->pipeline_cache_query_size();',`#if defined(GODOT_USE_TRACY)
		GodotProfileZoneGroupedFirst(nwn71_cache_query, "NWN71/Pipeline/cache_query_size");
#endif
		size_t new_pipelines_cache_size = driver->pipeline_cache_query_size();
#if defined(GODOT_USE_TRACY)
		GodotProfileZoneGrouped(nwn71_cache_query, "NWN71/Pipeline/cache_query_result");
#endif`);
 text=one(text,'\tself->_thread_safe_.lock();\n\tVector<uint8_t> cache_blob = self->driver->pipeline_cache_serialize();\n\tself->_thread_safe_.unlock();',`#if defined(GODOT_USE_TRACY)
	GodotProfileZoneGroupedFirst(nwn71_cache_save, "NWN71/Pipeline/cache_save_lock_wait");
#endif
	self->_thread_safe_.lock();
#if defined(GODOT_USE_TRACY)
	GodotProfileZoneGrouped(nwn71_cache_save, "NWN71/Pipeline/cache_serialize_locked");
#endif
	Vector<uint8_t> cache_blob = self->driver->pipeline_cache_serialize();
	self->_thread_safe_.unlock();
#if defined(GODOT_USE_TRACY)
	GodotProfileZoneGrouped(nwn71_cache_save, "NWN71/Pipeline/cache_after_unlock");
#endif`);
 return text;
});
write('drivers/vulkan/rendering_device_driver_vulkan.cpp',text=>{
 text=one(text,'#include "rendering_device_driver_vulkan.h"','#include "rendering_device_driver_vulkan.h"\n#include "core/profiling/profiling.h"');
 const call='vkCreateGraphicsPipelines(vk_device, pipelines_cache.vk_cache, 1, &pipeline_create_info, VKC::get_allocation_callbacks(VK_OBJECT_TYPE_PIPELINE), &vk_pipeline)';
 return one(text,'\tVkResult err = '+call+';',`#if defined(GODOT_USE_TRACY)
	VkResult err;
	{
		ZoneNamedN(nwn71_vk_pipeline_create, "NWN71/Pipeline/vkCreateGraphicsPipelines", true);
		err = ${call};
	}
#else
	VkResult err = ${call};
#endif`);
});
const receipt={schema:'nwn71-private-pipeline-labels-v1',source,changes,engineEdits:0,compiled:false,schedulingChanges:0,normalBuildAddedWork:0,scope:'Source-only extension of proven pool/group/task labels. Exact individual wait taskID plus nested RD driver/Vulkan-create/cache-lock/query scopes. No mutex or scheduling change; no driver-internal serialization claim.'};fs.writeFileSync(path.join(output,'source-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output:path.relative(root,output).replaceAll('\\','/'),changes}));
