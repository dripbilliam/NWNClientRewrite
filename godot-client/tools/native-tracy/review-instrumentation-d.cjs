// Independent small-file source review only. No compiler, runtime, or source edits.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const project = path.resolve(__dirname, '../..');
const at = relative => path.join(project, relative);
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const pin = file => { const bytes = fs.readFileSync(file); return { file, sha256: sha(bytes), bytes: bytes.length }; };
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const text = file => fs.readFileSync(file, 'utf8');
const checks = [];
function check(name, callback) { callback(); checks.push(name); }
const inputsFile = at('tools/native-tracy/accepted-engine-inputs.json');
const reconstructionFile = at('.cache/native-tracy/engine-msvc-a/reconstruction.json');
const manifestFile = at('.cache/native-tracy/instrumentation-source-d/manifest.json');
const inputs = read(inputsFile), reconstruction = read(reconstructionFile), manifest = read(manifestFile);
check('Exact source-D overlay manifest', () => assert.equal(pin(manifestFile).sha256, 'a7753445b3bf7fd257c20e6987aceee14b16311a93a70363cdf35ebe07096267'));
check('Reconstructed accepted-D input authority', () => { assert.equal(reconstruction.inputs.sha256, pin(inputsFile).sha256); assert.equal(inputs.overrides.length, 52); });
const resolved = inputs.overrides.map(row => {
 const file = path.join(reconstruction.source, row.relative), actual = pin(file);
 const origin = pin(row.sourceFile); assert.equal(origin.sha256, row.sha256, row.relative + ' origin');
 const overlay = manifest.outputs.find(output => output.relative === 'engine/' + row.relative);
 assert.equal(actual.sha256, overlay ? overlay.sha256 : row.sha256, row.relative);
 return { relative: row.relative, ...origin, reconstructedCurrentSha256: actual.sha256, hasExactOverlay: !!overlay };
});
checks.push('All52 authored origins match; private reconstruction is original or exact D overlay');
check('Correct manual-C light implementation retained', () => assert.equal(resolved.find(row => row.relative === 'modules/nwn_light_input_registry/light_input_registry.cpp').sha256, 'c3fba024fc4e0582b2c84bc35676f752aa3bc1aa4595b41a09b4e170c40d54d8'));
check('Correct manual-C light class layout retained', () => assert.equal(resolved.find(row => row.relative === 'modules/nwn_light_input_registry/light_input_registry.h').sha256, 'a0214be29f101ca7662eb35d76903e82b0fd30972cfada581e2d87659dc7babd'));
check('Overlay input paths are original or exact generated D output', () => { for (const row of manifest.inputs) { const overlay = row.absolute.startsWith(manifest.engine + path.sep) && manifest.outputs.find(output => output.relative === 'engine/' + row.relative); assert.equal(pin(row.absolute).sha256, overlay ? overlay.sha256 : row.sha256, row.absolute); } });
check('Overlay outputs close over pinned generated files', () => { for (const row of manifest.outputs) { const actual = pin(path.join(manifest.output, row.relative)); assert.equal(actual.sha256, row.sha256, row.relative); assert.equal(actual.bytes, row.bytes); } });
check('Frozen generator matches source-D factory hash', () => assert.equal(pin(path.join(manifest.output, 'factory/prepare-instrumentation.used.mjs')).sha256, manifest.factory.sha256));
const rendererInput = manifest.inputs.find(row => row.relative === 'servers/rendering/rendering_server_default.cpp');
let renderer = text(path.join(manifest.output, 'engine/servers/rendering/rendering_server_default.cpp'));
check('Source-D renderer begins with accepted c51c authored source', () => assert.equal(rendererInput.sha256, 'c51caa908bea822d4f9418f71c0353c4ccbe4472bd1cca7c1332e73b09eaa501'));
for (const addition of [
 '\n\tGodotProfileZone("NWNCapture/Render/draw_cpu");',
 '\n#if defined(GODOT_USE_TRACY)\n\ttracy::SetThreadName("NWN/RenderThread");\n#endif',
 '\n\tGodotProfileZone("NWNCapture/Render/sync_scope");'
]) { assert.equal(renderer.split(addition).length - 1, 1); renderer = renderer.replace(addition, ''); }
check('Renderer instrumentation reversal exactly restores accepted source bytes', () => assert.equal(sha(Buffer.from(renderer)), rendererInput.sha256));
let profilingHeader = text(path.join(manifest.output, 'engine/core/profiling/profiling.h'));
profilingHeader = profilingHeader.replace('new (&__godot_tracy_zone_##m_group_name) tracy::ScopedZone(&TracyConcat(__tracy_source_location, TracyLine), -1, true)', 'new (&__godot_tracy_zone_##m_group_name) tracy::ScopedZone(&TracyConcat(__tracy_source_location, TracyLine), true)');
const guardedStart = profilingHeader.indexOf('#ifdef TRACY_ON_DEMAND\n#define GodotProfileZoneScript(');
assert(guardedStart >= 0);
const guardedEnd = profilingHeader.indexOf('\n#endif', guardedStart) + '\n#endif'.length;
const guardedBlock = profilingHeader.slice(guardedStart, guardedEnd);
assert(guardedBlock.includes('\n#else\n'));
profilingHeader = profilingHeader.slice(0, guardedStart) + guardedBlock.split('\n#else\n')[1].slice(0, -'\n#endif'.length) + profilingHeader.slice(guardedEnd);
check('Profiling-header reverse diff exactly restores original archive input', () => assert.equal(sha(Buffer.from(profilingHeader)), manifest.inputs.find(row => row.relative === 'core/profiling/profiling.h').sha256));
let originalProfilingCpp = text(path.join(manifest.output, 'engine/core/profiling/profiling.cpp'));
originalProfilingCpp = originalProfilingCpp.replace('if (_data->hash == hash && _data->name == p_name) {', 'if (_data->hash == hash) {').replace('_data->hash = hash;\n\t_data->name = p_name;', '_data->name = p_name;').replace('extern "C" void nwn_tracy_link_anchor_v1() noexcept;\n\n', '').replace('\n\tnwn_tracy_link_anchor_v1();', '');
check('Profiling-implementation reverse diff restores original archive input', () => assert.equal(sha(Buffer.from(originalProfilingCpp)), manifest.inputs.find(row => row.relative === 'core/profiling/profiling.cpp').sha256));
let originalWorker = text(path.join(manifest.output, 'engine/core/object/worker_thread_pool.cpp'));
for (const addition of ['\n#include "core/profiling/profiling.h"', '\n\tGodotProfileZone("NWNCapture/Worker/task_scope");', '\n\tGodotProfileZone("NWNCapture/Worker/wait_task_scope");', '\n\tGodotProfileZone("NWNCapture/Worker/wait_group_scope");', '\n#if defined(GODOT_USE_TRACY)\n\ttracy::SetThreadName("NWN/WorkerThread");\n#endif']) { assert.equal(originalWorker.split(addition).length - 1, 1); originalWorker = originalWorker.replace(addition, ''); }
check('Worker reverse diff exactly restores original archive input', () => assert.equal(sha(Buffer.from(originalWorker)), manifest.inputs.find(row => row.relative === 'core/object/worker_thread_pool.cpp').sha256));
check('Light module is not overwritten by instrumentation outputs', () => assert(!manifest.outputs.some(row => row.relative.startsWith('engine/modules/nwn_light_input_registry/'))));
const nativeReceiptFile = at('.cache/native-render-gap/particles/combined-b/kernel-build/build-receipt.json');
const nativeReceipt = read(nativeReceiptFile);
const nativeFiles = nativeReceipt.sourcePins.map(row => { const file = at(row.relative); const actual = pin(file); assert.equal(actual.sha256, row.sha256, row.relative); return { relative: row.relative, ...actual }; });
checks.push('All accepted485 DLL source-receipt input hashes match current45 native inputs');
check('Actual485 DLL compiler policy is MSVC strict floating point', () => { assert(nativeReceipt.flags.includes('/O2')); assert(nativeReceipt.flags.includes('/fp:strict')); assert(nativeReceipt.flags.includes('/MD')); });
const profilingCpp = text(path.join(manifest.output, 'engine/core/profiling/profiling.cpp'));
const bridgeFile = path.join(manifest.output, 'engine/core/profiling/nwn_tracy_bridge.cpp');
const bridge = text(bridgeFile), api = text(path.join(manifest.output, 'particle/nwn_tracy_bridge_api.h'));
check('Live core-profiler TU strongly references bridge archive member', () => { assert(profilingCpp.includes('nwn_tracy_link_anchor_v1();')); assert(bridge.includes('extern "C" void nwn_tracy_link_anchor_v1() noexcept {}')); });
check('Bridge exports fixed primitive token ABI with engine-owned TLS', () => { assert(bridge.includes('NWN_TRACE_EXPORT uint64_t nwn_tracy_zone_begin_v1(uint32_t zone) noexcept')); assert(bridge.includes('thread_local Local local;')); assert(bridge.includes('constexpr uint32_t MAX_NESTING = 64;')); assert(api.includes('using NwnTracyBeginV1 = uint64_t (*)(uint32_t);')); assert(bridge.includes('local.slots[local.depth - 1].token != token')); });
const vendorFile = at('.cache/native-tracy/vendor/tracy-v0.13.0.source.json');
const vendor = read(vendorFile), scopedFile = path.join(vendor.source, 'public/client/TracyScoped.hpp'), scoped = text(scopedFile);
check('Exact upstream0.13 constructor permits inactive null source and keeps full connectionID', () => { assert.equal(vendor.commit, manifest.tracy.commit); assert(scoped.includes('ScopedZone( const SourceLocationData* srcloc, int32_t depth = -1, bool is_active = true )')); assert(scoped.includes('if( !m_active ) return;')); assert(scoped.includes('uint64_t m_connectionId = 0;')); assert(scoped.includes('if( GetProfiler().ConnectionId() != m_connectionId ) return;')); });
check('Only engine core SCsub adds a TracyClient translation unit', () => { const scsub = text(path.join(reconstruction.source, 'core/profiling/SCsub')); assert(scsub.includes('env.add_source_files(env.core_sources, "*.cpp")')); assert.equal((scsub.match(/env_tracy\.add_source_files/g) || []).length, 1); assert(!manifest.outputs.filter(row => row.relative.startsWith('particle/')).some(row => text(path.join(manifest.output, row.relative)).includes('#include <tracy/'))); });
const presentation = text(path.join(manifest.output, 'particle/particle_presentation.hpp'));
check('Presentation phases are whole-batch insertion points', () => { assert.equal((presentation.match(/nwn_trace::Phase /g) || []).length, 1); assert.equal((presentation.match(/nwn_phase\.next\(/g) || []).length, 5); assert(presentation.includes('case 65000:out=owner.tracy_info();break;')); });
const receipt = {
 version: 1, kind: 'independent-private-tracy-source-review', success: true, checkedUtc: new Date().toISOString(),
 scope: 'Small-file source/metadata checks and manual review only. No compiler, native runtime, capture, clone, archive extraction or product/source changes.',
 checks, references: { authoredInputs: pin(inputsFile), reconstruction: pin(reconstructionFile), overlay: pin(manifestFile), acceptedNativeReceipt: pin(nativeReceiptFile), vendor: pin(vendorFile), scopedZonePrimarySource: pin(scopedFile), reviewer: pin(__filename) },
 verifiedCounts: { authoredEngineOverrides: resolved.length, acceptedNativeInputs: nativeFiles.length, overlayInputs: manifest.inputs.length, overlayOutputs: manifest.outputs.length },
 sourceA: { rejectedForUse: true, reason: 'Old renderer27dd input loses accepted c51c patches, and old A did not include the later strong archive-link anchor/frozen generator.' },
 findings: [
  'Source-D reverse diff preserves exact accepted renderer; manual-C lights and all52 authored origins match. Reconstructed current files are either those exact origins or explicitly listed D outputs.',
  'Actual accepted485 DLL uses MSVC /O2 /fp:strict /MD. New engine MSVC/PDB is an explicit diagnostic compiler change relative to accepted10b, not byte-equivalent proof.',
  'Tracy storage, TLS, allocations and ScopedZone destructors stay in engine; only fixed-width IDs/token/counters cross the DLL ABI.',
  'RAII scopes retain gameplay local lifetime/order; sequential phases add no C++ blocks and no individual emitter/particle events.',
  'Tracy0.13 retains full64-bit connection lifetime and ignores stale-connection ends. A disconnect race can count an inactive constructed scope, so counters are not server-accepted event counts.'
 ],
 requiredBuildAndRuntimeGates: [
  'Build exactly source-D outputs over the accepted52 reconstruction, not any source-A/B/C engine outputs.',
  'Define TRACY_NO_SYSTEM_TRACING for the single engine client build; preserve on-demand/no-callstack/no-memory settings.',
  'Verify four named exports and matching Win64 ABI/snapshot72B; cold bind handshake/static_assert would strengthen drift detection.',
  'Prove real connected capture plus disconnect/reconnect and exception/reentry balance; require overflow/invalid_token0 and live_scopes0 at a quiescent boundary.',
  'No runtime/capture correctness or performance acceptance is established by this source review; GPU timing is not present.'
 ],
 installedSelectionChanged: false, compiled: false, executedNative: false
};
const out = at('.cache/native-tracy/instrumentation-review-d');
fs.mkdirSync(out, { recursive: true });
const file = path.join(out, 'receipt.json');
fs.writeFileSync(file, JSON.stringify(receipt, null, 2) + '\n', { flag: 'wx' });
console.log(JSON.stringify({ ...pin(file), checks: checks.length, verifiedCounts: receipt.verifiedCounts, compiled: false, executedNative: false }));
