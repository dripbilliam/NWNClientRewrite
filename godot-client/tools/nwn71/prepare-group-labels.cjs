'use strict';
// Emits private BEFORE/AFTER snapshots only. The coordinator applies/builds.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const arg=n=>process.argv.find(x=>x.startsWith('--'+n+'='))?.slice(n.length+3),label=arg('label');
if(!label||!/^[a-z0-9-]+$/.test(label))throw Error('Fresh --label required');
const source=path.resolve(root,arg('source')??'.cache/native-tracy/engine-msvc-a/source'),output=path.join(root,'.cache/nwn71/group-labels-'+label);
if(fs.existsSync(output))throw Error('Preserve existing snapshots');
const changes=[];
function patch(file,operation){const bytes=fs.readFileSync(path.join(source,file)),before=bytes.toString().replace(/\r\n/g,'\n'),after=operation(before);assert.notEqual(before,after);for(const [stage,text]of[['before',before],['after',after]]){const dest=path.join(output,stage,file);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,text,{flag:'wx'});}changes.push({file,originalBytesSha256:sha(bytes),beforeSha256:sha(Buffer.from(before)),afterSha256:sha(Buffer.from(after))});}
function replace(text,from,to){assert.equal(text.split(from).length,2,'Exact unique source seam changed: '+from.slice(0,100));return text.replace(from,to);}
patch('core/object/worker_thread_pool.cpp',text=>{
 text=replace(text,'\tGodotProfileZone("NWNCapture/Worker/task_scope");',`#if defined(GODOT_USE_TRACY)
	ZoneNamedN(nwn71_worker_task, "NWNCapture/Worker/task_scope", true);
	TaskID nwn71_task_id = INVALID_TASK_ID;
	GroupID nwn71_group_id = INVALID_TASK_ID;
	String nwn71_description;
#else
	GodotProfileZone("NWNCapture/Worker/task_scope");
#endif`);
 const capture=`#if defined(GODOT_USE_TRACY)
		// Copy immutable labels while the existing task mutex owns the record.
		// No task/group pointer is retained by the profiler after this scope.
		if (TracyIsConnected) {
			nwn71_task_id = p_task->self;
			nwn71_group_id = p_task->group ? p_task->group->self : INVALID_TASK_ID;
			nwn71_description = p_task->description;
		}
#endif
`;
 text=replace(text,'\t\tif (p_task->pending_notify_yield_over) {\n\t\t\tcurr_thread.yield_is_over = true;\n\t\t}\n\t\ttask_mutex.unlock();','\t\tif (p_task->pending_notify_yield_over) {\n\t\t\tcurr_thread.yield_is_over = true;\n\t\t}\n'+capture+'\t\ttask_mutex.unlock();');
 text=replace(text,'\t}\n#endif\n\n#ifdef THREADS_ENABLED\n\tbool low_priority = p_task->low_priority;',`	}
#elif defined(GODOT_USE_TRACY)
	// A non-threaded build has no concurrent task record owner.
	nwn71_task_id = p_task->self;
	nwn71_group_id = p_task->group ? p_task->group->self : INVALID_TASK_ID;
	nwn71_description = p_task->description;
#endif
#if defined(GODOT_USE_TRACY)
	if (TracyIsConnected) {
		// The official CSV exporter exports ZoneText, not ZoneValue.
		const CharString nwn71_label = nwn71_description.replace("\\t", " ").replace("\\r", " ").replace("\\n", " ").utf8();
		ZoneTextVF(nwn71_worker_task, "pool=%p;group=%lld;task=%lld;description=%s", (void *)this, (long long)nwn71_group_id, (long long)nwn71_task_id, nwn71_label.get_data());
	}
#endif

#ifdef THREADS_ENABLED
	bool low_priority = p_task->low_priority;`);
 text=replace(text,'\tGodotProfileZone("NWNCapture/Worker/wait_group_scope");',`#if defined(GODOT_USE_TRACY)
	ZoneNamedN(nwn71_worker_group_wait, "NWNCapture/Worker/wait_group_scope", true);
	if (TracyIsConnected) {
		// Both values are method inputs; never dereference the waited group.
		ZoneTextVF(nwn71_worker_group_wait, "pool=%p;group=%lld", (void *)this, (long long)p_group);
	}
#else
	GodotProfileZone("NWNCapture/Worker/wait_group_scope");
#endif`);
 return text;
});
patch('servers/rendering/renderer_rd/shader_rd.cpp',text=>{
 text=replace(text,'#include "core/os/os.h"','#include "core/os/os.h"\n#include "core/profiling/profiling.h"');
 text=replace(text,'void ShaderRD::_compile_variant(uint32_t p_variant, CompileData p_data) {',`void ShaderRD::_compile_variant(uint32_t p_variant, CompileData p_data) {
#if defined(GODOT_USE_TRACY)
	ZoneNamedN(nwn71_shader_variant, "NWN71/Shader/compile_variant", true);
	if (TracyIsConnected) {
		const CharString nwn71_shader_name = name.utf8();
		ZoneTextVF(nwn71_shader_variant, "shader=%s;variant_group=%d;variant_in_group=%u", nwn71_shader_name.get_data(), p_data.group, p_variant);
	}
#endif`);
 text=replace(text,'\tWorkerThreadPool::get_singleton()->wait_for_group_task_completion(group_task);',`	{
#if defined(GODOT_USE_TRACY)
		ZoneNamedN(nwn71_shader_group_wait, "NWN71/Shader/compile_group_wait", true);
		if (TracyIsConnected) {
			const CharString nwn71_shader_name = name.utf8();
			ZoneTextVF(nwn71_shader_group_wait, "pool=%p;group=%lld;shader=%s;variant_group=%d", (void *)WorkerThreadPool::get_singleton(), (long long)group_task, nwn71_shader_name.get_data(), p_group);
		}
#endif
		WorkerThreadPool::get_singleton()->wait_for_group_task_completion(group_task);
	}`);
 return text;
});
const receipt={schema:'nwn71-private-task-labels-v1',source:path.relative(root,source).replaceAll('\\','/'),changes,engineEdits:0,compiled:false,schedulingChanges:0,normalBuildAddedWork:0,scope:'Private diagnostic snapshots only. GODOT_USE_TRACY labels correlate worker wait/producer by exact pool+group, and shader child scopes identify compile family. Text conversion only while profiler connected; instrumented timing is not normal-engine timing.'};
fs.writeFileSync(path.join(output,'source-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output:path.relative(root,output).replaceAll('\\','/'),changes}));
