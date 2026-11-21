// Emits selected private source overlays only. No clone, build, launch, or product write.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const argv = process.argv.slice(2);
const options = Object.fromEntries(argv.map(a => { const n=a.indexOf('='); if (!a.startsWith('--') || n < 3) throw Error('Use --name=value'); return [a.slice(2,n),a.slice(n+1)]; }));
for (const key of ['engine-src','particle-src','out']) if (!options[key]) throw Error(`Missing --${key}`);
const engine = fs.realpathSync(options['engine-src']);
const particle = fs.realpathSync(options['particle-src']);
const output = path.resolve(options.out);
const inside = (a,b) => { const r=path.relative(a,b); return r==='' || (!r.startsWith('..'+path.sep) && r!=='..' && !path.isAbsolute(r)); };
if (inside(engine,output) || inside(particle,output)) throw Error('Output must be outside source inputs');
if (fs.existsSync(output)) throw Error('Preserve prior output; choose a fresh --out');
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const inputs = [], outputs = [], transforms = [];
function read(base,relative) { const absolute=path.join(base,relative), bytes=fs.readFileSync(absolute); inputs.push({absolute,relative,sha256:sha(bytes),bytes:bytes.length}); return bytes.toString('utf8').replaceAll('\r\n','\n'); }
function one(text,needle,replacement,label) { const count=text.split(needle).length-1; if (count!==1) throw Error(`${label}: expected one exact anchor, got ${count}`); transforms.push(label); return text.replace(needle,replacement); }
function emit(relative,text) { const absolute=path.join(output,relative); fs.mkdirSync(path.dirname(absolute),{recursive:true}); fs.writeFileSync(absolute,text); outputs.push({relative,sha256:sha(Buffer.from(text)),bytes:Buffer.byteLength(text)}); }

let profiling = read(engine,'core/profiling/profiling.h');
profiling = one(profiling,
 'new (&__godot_tracy_zone_##m_group_name) tracy::ScopedZone(&TracyConcat(__tracy_source_location, TracyLine), true)',
 'new (&__godot_tracy_zone_##m_group_name) tracy::ScopedZone(&TracyConcat(__tracy_source_location, TracyLine), -1, true)',
 'Grouped zone: explicit no-callstack argument (true otherwise binds to depth=1)');
const originalScriptMacros = '#define GodotProfileZoneScript(m_ptr, m_file, m_function, m_name, m_line) \\\n\ttracy::ScopedZone __godot_tracy_script(tracy::intern_source_location(m_ptr, m_file, m_function, m_name, m_line, true))\n#define GodotProfileZoneScriptSystemCall(m_ptr, m_file, m_function, m_name, m_line) \\\n\ttracy::ScopedZone __godot_tracy_zone_system_call(tracy::intern_source_location(m_ptr, m_file, m_function, m_name, m_line, false))';
const guardedScriptMacros = '#ifdef TRACY_ON_DEMAND\n#define GodotProfileZoneScript(m_ptr, m_file, m_function, m_name, m_line) \\\n\tconst bool __godot_tracy_script_active = TracyIsConnected; \\\n\ttracy::ScopedZone __godot_tracy_script(__godot_tracy_script_active ? tracy::intern_source_location(m_ptr, m_file, m_function, m_name, m_line, true) : nullptr, -1, __godot_tracy_script_active)\n#define GodotProfileZoneScriptSystemCall(m_ptr, m_file, m_function, m_name, m_line) \\\n\tconst bool __godot_tracy_system_call_active = TracyIsConnected; \\\n\ttracy::ScopedZone __godot_tracy_zone_system_call(__godot_tracy_system_call_active ? tracy::intern_source_location(m_ptr, m_file, m_function, m_name, m_line, false) : nullptr, -1, __godot_tracy_system_call_active)\n#else\n' + originalScriptMacros + '\n#endif';
profiling = one(profiling,originalScriptMacros,guardedScriptMacros,'Guard disconnected script interning before any intern-table lock/allocation');
emit('engine/core/profiling/profiling.h',profiling);
let intern = read(engine,'core/profiling/profiling.cpp');
intern = one(intern,'if (_data->hash == hash) {','if (_data->hash == hash && _data->name == p_name) {','Interned StringName collision-safe equality');
intern = one(intern,'_data = TracyInternTable::string_allocator.alloc();\n\t_data->name = p_name;','_data = TracyInternTable::string_allocator.alloc();\n\t_data->hash = hash;\n\t_data->name = p_name;','Initialize omitted StringName intern hash');
intern = one(intern,'void godot_init_profiler() {\n\tMutexLock lock(tracy::TracyInternTable::mutex);','extern "C" void nwn_tracy_link_anchor_v1() noexcept;\n\nvoid godot_init_profiler() {\n\tnwn_tracy_link_anchor_v1();\n\tMutexLock lock(tracy::TracyInternTable::mutex);','Strong bridge link anchor from live core profiler object');
emit('engine/core/profiling/profiling.cpp',intern);

let worker = read(engine,'core/object/worker_thread_pool.cpp');
worker = one(worker,'#include "core/os/os.h"','#include "core/os/os.h"\n#include "core/profiling/profiling.h"','Worker profiling include');
worker = one(worker,'void WorkerThreadPool::_process_task(Task *p_task) {','void WorkerThreadPool::_process_task(Task *p_task) {\n\tGodotProfileZone("NWNCapture/Worker/task_scope");','Worker task scope (includes nested waits)');
worker = one(worker,'Error WorkerThreadPool::wait_for_task_completion(TaskID p_task_id) {','Error WorkerThreadPool::wait_for_task_completion(TaskID p_task_id) {\n\tGodotProfileZone("NWNCapture/Worker/wait_task_scope");','Worker wait-task inclusive scope');
worker = one(worker,'void WorkerThreadPool::wait_for_group_task_completion(GroupID p_group) {','void WorkerThreadPool::wait_for_group_task_completion(GroupID p_group) {\n\tGodotProfileZone("NWNCapture/Worker/wait_group_scope");','Worker wait-group inclusive scope');
worker = one(worker,'void WorkerThreadPool::_thread_function(void *p_user) {','void WorkerThreadPool::_thread_function(void *p_user) {\n#if defined(GODOT_USE_TRACY)\n\ttracy::SetThreadName("NWN/WorkerThread");\n#endif','Worker Tracy label once at thread start');
emit('engine/core/object/worker_thread_pool.cpp',worker);
let render = read(engine,'servers/rendering/rendering_server_default.cpp');
render = one(render,'void RenderingServerDefault::_draw(bool p_swap_buffers, double frame_step) {','void RenderingServerDefault::_draw(bool p_swap_buffers, double frame_step) {\n\tGodotProfileZone("NWNCapture/Render/draw_cpu");','Render full CPU draw scope');
render = one(render,'void RenderingServerDefault::_thread_loop() {','void RenderingServerDefault::_thread_loop() {\n#if defined(GODOT_USE_TRACY)\n\ttracy::SetThreadName("NWN/RenderThread");\n#endif','Render Tracy label once at thread-loop start');
render = one(render,'void RenderingServerDefault::sync() {','void RenderingServerDefault::sync() {\n\tGodotProfileZone("NWNCapture/Render/sync_scope");','Render main-thread sync inclusive scope');
emit('engine/servers/rendering/rendering_server_default.cpp',render);

for (const filename of ['nwn_tracy_bridge.cpp','nwn_tracy_bridge_api.h']) emit(`engine/core/profiling/${filename}`,read(here,filename));
for (const filename of ['nwn_tracy_bridge_api.h','nwn_tracy_dll_bind.hpp']) emit(`particle/${filename}`,read(here,filename));
let kernel = read(particle,'particle_kernel.cpp');
kernel = one(kernel,'#include "experimental/particle_pose_cache.hpp"','#include "nwn_tracy_dll_bind.hpp"\n#include "experimental/particle_pose_cache.hpp"','DLL private bridge include');
kernel = one(kernel,' library=lib;particle_scene_boundary::direct_address=address;',' if(!nwn_trace::bind_engine_once())return false;\n library=lib;particle_scene_boundary::direct_address=address;','Resolve exact engine exports before class registration; fail closed if absent');
emit('particle/particle_kernel.cpp',kernel);
let presentation = read(particle,'particle_presentation.hpp');
presentation = one(presentation,' EngineVar frame(const EngineVar& common){',' EngineVar frame(const EngineVar& common){\n  nwn_trace::Scope nwn_frame(NWN_TRACY_PARTICLE_FRAME);nwn_trace::Phase nwn_phase(NWN_TRACY_PARTICLE_SETUP);','Full particle frame/setup scopes');
presentation = one(presentation,'  for(auto* current:frame_entries){auto& entry=*current;const auto id=entry.id;','  nwn_phase.next(NWN_TRACY_PARTICLE_ADVANCE_BATCH);\n  for(auto* current:frame_entries){auto& entry=*current;const auto id=entry.id;','Advance batch scope; no per-emitter zones');
presentation = one(presentation,'  sparse_phase(1);','  nwn_phase.next(NWN_TRACY_PARTICLE_SORT_PACK);\n  sparse_phase(1);','Sort/pack preparation scope');
presentation = one(presentation,'  for(size_t n=0;n<drawing.size();++n){auto* entry=drawing[n];','  nwn_phase.next(NWN_TRACY_PARTICLE_GEOMETRY_BATCH);\n  for(size_t n=0;n<drawing.size();++n){auto* entry=drawing[n];','Geometry batch scope; no per-particle zones');
presentation = one(presentation,'  if(offset!=total)throw std::runtime_error("Native shared particle frame count mismatch");','  nwn_phase.next(NWN_TRACY_PARTICLE_PUBLICATION);\n  if(offset!=total)throw std::runtime_error("Native shared particle frame count mismatch");','Packet publication scope');
presentation = one(presentation,'  sparse_phase(2);','  nwn_phase.next(NWN_TRACY_PARTICLE_COUNTERS);\n  sparse_phase(2);','Counters/summary scope');
presentation = one(presentation,' EngineVar scene_frame()const{',' EngineVar scene_frame()const{\n  nwn_trace::Scope nwn_scene(NWN_TRACY_PARTICLE_SCENE_FRAME);','Scene-frame bridge publication scope');
presentation = one(presentation,' EngineVar refresh_visibility(){',' EngineVar refresh_visibility(){\n  nwn_trace::Scope nwn_visibility(NWN_TRACY_PARTICLE_REFRESH_VISIBILITY);','Particle visibility publication scope');
const coldMethod = ` EngineVar tracy_info()const{
  NwnTracySnapshotV1 values{};
  if(!nwn_trace::api.snapshot||!nwn_trace::api.snapshot(&values,sizeof(values)))throw std::runtime_error("Private Tracy bridge snapshot unavailable");
  auto out=EngineVar::dictionary();::set(out,"abi",EngineVar::integer(values.version));::set(out,"bytes",EngineVar::integer(values.bytes));
  ::set(out,"bound",EngineVar::boolean(nwn_trace::api.begin&&nwn_trace::api.end&&nwn_trace::api.connected&&nwn_trace::api.snapshot));
  ::set(out,"connected",EngineVar::boolean(nwn_trace::api.connected()!=0));
  ::set(out,"begin_requests",EngineVar::integer(static_cast<int64_t>(values.begin_requests)));::set(out,"begun",EngineVar::integer(static_cast<int64_t>(values.begun)));
  ::set(out,"end_requests",EngineVar::integer(static_cast<int64_t>(values.end_requests)));::set(out,"ended",EngineVar::integer(static_cast<int64_t>(values.ended)));
  ::set(out,"disconnected",EngineVar::integer(static_cast<int64_t>(values.disconnected)));::set(out,"overflow",EngineVar::integer(static_cast<int64_t>(values.overflow)));
  ::set(out,"invalid_token",EngineVar::integer(static_cast<int64_t>(values.invalid_token)));::set(out,"live_scopes",EngineVar::integer(static_cast<int64_t>(values.live_scopes)));return out;
 }
`;
presentation = one(presentation,' void configure_sampler(const EngineVar& input){',coldMethod+' void configure_sampler(const EngineVar& input){','Cold private bridge counters via dispatch65000; no text or per-frame snapshots');
presentation = one(presentation,'default:throw std::runtime_error("Unknown native particle presentation operation");','case 65000:out=owner.tracy_info();break;default:throw std::runtime_error("Unknown native particle presentation operation");','Cold operation65000; all existing operation cases unchanged');
emit('particle/particle_presentation.hpp',presentation);
for (const [filename,needle,insert,label] of [
 ['particle_stream_render.hpp',' void submit(){',' void submit(){\n  nwn_trace::Scope nwn_submit(NWN_TRACY_PARTICLE_RENDER_SUBMIT);','Native renderer submit scope'],
 ['model_pose_storage.hpp',' void publish(const Var& input){',' void publish(const Var& input){\n  nwn_trace::Scope nwn_model_pose(NWN_TRACY_MODEL_POSE_PUBLICATION);','Native pose publication scope'],
 ['light_history.hpp',' void step(const Var& input){',' void step(const Var& input){\n  nwn_trace::Scope nwn_light_history(NWN_TRACY_LIGHT_HISTORY_STEP);','Native light-history step scope']
]) {
 let text=read(particle,filename); text=one(text,needle,insert,label);
 if (filename==='particle_stream_render.hpp') text=one(text,' void draw(EngineVar device,const EngineVar& framebuffer,const EngineVar& matrix,int64_t samples){',' void draw(EngineVar device,const EngineVar& framebuffer,const EngineVar& matrix,int64_t samples){\n  nwn_trace::Scope nwn_draw(NWN_TRACY_PARTICLE_RENDER_DRAW);','Native renderer draw scope (CPU commands only)');
 emit(`particle/${filename}`,text);
}
const factoryBytes=fs.readFileSync(fileURLToPath(import.meta.url));
emit('factory/prepare-instrumentation.used.mjs',factoryBytes.toString('utf8'));
const manifest={schema:1,kind:'private-tracy-source-overlay',revision:'C',status:'SOURCE_ONLY_UNCOMPILED_UNEXECUTED',factory:{absolute:fileURLToPath(import.meta.url),sha256:sha(factoryBytes)},engine,particle,output,inputs,outputs,transforms,tracy:{version:'0.13.0',commit:'e6b9ea460993a6f093283055ef3c98025b19f909',singleClient:'engine-only',requiredDefines:['TRACY_NO_SYSTEM_TRACING'],coldOperation:65000,counterSemantics:'Individual relaxed atomic lifetime totals; snapshot is not a simultaneous cross-thread transaction. begun/ended count ScopedZone constructions/destructions, not server-accepted zone events.',scons:{profiler:'tracy',profiler_sample_callstack:false,profiler_track_memory:false,profiler_record_on_demand:true}},acceptance:false,sharedSourceWrites:0,notes:['No Tracy client or headers in the particle DLL; stable C ABI tokens point to engine-owned TLS slots.','Nested zones require same-thread LIFO; invalid/overflow counters must remain zero.','All capture timings are instrumented diagnostics, not normal FPS acceptance.','GPU zones are not integrated by this overlay; renderer zones measure CPU submission/waits.','Tracy client startup can allocate even disconnected; guarded script interning and bridge scopes add no disconnected per-call allocations.']};
fs.mkdirSync(output,{recursive:true});
fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
process.stdout.write(JSON.stringify({output,manifest:path.join(output,'manifest.json'),sha256:sha(fs.readFileSync(path.join(output,'manifest.json'))),inputs:inputs.length,outputs:outputs.length,transforms:transforms.length,compiled:false,executedNative:false})+'\n');
