'use strict';
// Bounded historical CSV/source analysis only. Never opens the large trace.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const project = path.resolve(__dirname, '../..'), at = relative => path.join(project, relative), sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const pin = file => { const data = fs.readFileSync(file); return { file, sha256: sha(data), bytes: data.length }; };
function parse(line) {
 const suffix = [];
 for (let i = 0; i < 4; i++) { const index = line.lastIndexOf(','); assert(index >= 0); suffix.unshift(line.slice(index + 1)); line = line.slice(0, index); }
 assert(/^\d+$/.test(suffix[1]) && /^\d+$/.test(suffix[2]) && /^\d+$/.test(suffix[3]));
 return { name: line, file: suffix[0], line: Number(suffix[1]), selfNs: suffix[2], calls: Number(suffix[3]), selfSeconds: Number(suffix[2]) / 1e9, meanWallUs: Number(suffix[2]) / Number(suffix[3]) / 1e3 };
}
assert.equal(parse('method<int, float>,res://file.gd,14,10000,2').name, 'method<int, float>');
const csvFile = at('.cache/native-tracy/arelith-review-a/whole-self.csv'), csv = fs.readFileSync(csvFile, 'utf8').replace(/^\uFEFF/, '').trimEnd().split(/\r?\n/);
assert.equal(csv.shift(), 'name,src_file,src_line,total_ns,counts'); const rows = csv.map(parse); assert.equal(rows.length, 14848);
const byCost = (a, b) => BigInt(a.selfNs) === BigInt(b.selfNs) ? 0 : BigInt(a.selfNs) > BigInt(b.selfNs) ? -1 : 1;
const capturedRoot = at('.cache/native-tracy/live/manual-source-d/project'), sourcePins = [], sources = {};
for (const name of ['prepared_cache.gd', 'prepared_write_queue.gd', 'preparation_store.gd', 'source_bytes_cache.gd', 'asset_service.gd', 'prework_store.gd', 'resource_catalog.gd', 'palette_texture.gd', 'resource_index_backend.gd']) {
 const file = path.join(capturedRoot, 'systems/native_data', name), actual = pin(file), normal = pin(at('systems/native_data/' + name));
 sourcePins.push({ ...actual, normalCurrentSha256: normal.sha256, sameAsCurrentNormal: actual.sha256 === normal.sha256 }); sources[name] = fs.readFileSync(file, 'utf8').split(/\r?\n/);
}
function anchor(name, needle) { const lines = sources[name], index = lines.findIndex(line => line.includes(needle)); assert(index >= 0, name + ':' + needle); return { file: path.join(capturedRoot, 'systems/native_data', name), line: index + 1, needle }; }
function row(name, suffix, line) { const value = rows.find(row => row.name === name && row.file.endsWith(suffix) && (line === undefined || row.line === line)); assert(value, name + ':' + suffix); return value; }
const mkdir = row('make_dir_recursive_absolute', 'prepared_cache.gd'), fingerprints = row('open', 'prepared_cache.gd', 32), renames = row('rename_absolute', 'prepared_cache.gd'), idle = row('wait', 'prepared_write_queue.gd');
assert.equal(mkdir.calls, row('configure', 'prepared_cache.gd').calls);
const result = {
 version: 1, kind: 'independent-arelith-tracy-cache-source-analysis', success: true, analyzedUtc: new Date().toISOString(), csv: pin(csvFile), rows: rows.length, parsedFromRightmostCommas: 4, parserCommaNameCasePassed: true,
 trace: { file: at('.cache/native-tracy/arelith-review-a/session.tracy'), bytes: fs.statSync(at('.cache/native-tracy/arelith-review-a/session.tracy')).size, contentRead: false, hashComputed: false },
 scope: 'Actual GUI-exported whole-capture SELF table and exact recorded private-stageD cache source. Statistics aggregate instrumented wall spans across threads, include waiting, and have no event-time/thread dimension. No FPS, critical-main-thread stall, isolated CPU cost or causal speedup claim.',
 topOverall: [...rows].sort(byCost).slice(0, 20), cacheRows: rows.filter(row => /(?:prepared_cache|prepared_write_queue|preparation_store|source_bytes_cache)\.gd$/.test(row.file)).sort(byCost).slice(0, 35), sourcePins,
 findings: [
  { priority: 1, title: 'Directory initialization repeated per resource and writer packet', measured: mkdir,
   anchors: [anchor('prepared_cache.gd', 'func configure('), anchor('prepared_cache.gd', 'DirAccess.make_dir_recursive_absolute(resolved)'), anchor('asset_service.gd', 'var cache:=Cache.new(); var enabled:='), anchor('asset_service.gd', 'var cache_ok :='), anchor('prepared_write_queue.gd', 'var cache:=Cache.new()')],
   explanation: 'Every configure does recursive directory creation/check even for a read-only hit. Prework.configure also delegates to this cache. Asset workers create/configure fresh per decode/rig; prepared writer creates/configures per packet. Raw writer already retains raw_caches per directory.',
   candidate: 'Separate normalized root validation/read lookup from directory creation. Initialize each directory once per actual service/catalog lifetime; writer may retain its own cache per directory. Retry directory creation after a missing-directory write failure. Do not share mutable failure/last_save Cache instances between workers.',
   obligations: 'Preserve allowed-root policy, changed root/epoch, external deletion, permissions/failure fallback and unique temporary publication. Directory readiness never proves payload validity.' },
  { priority: 2, title: 'Same initial resource bytes hashed at multiple stages of one worker job', measuredAggregateOnly: row('update', 'prepared_cache.gd', 23),
   anchors: [anchor('asset_service.gd', 'Cache.digest(bytes),preparation_policy'), anchor('asset_service.gd', 'Cache.digest(bytes),job.options'), anchor('asset_service.gd', 'var began:=Time.get_ticks_usec(); var source_sha:=Cache.digest(bytes)'), anchor('asset_service.gd', 'var source_sha := known_sha')],
   explanation: 'Eligible jobs hash the same initial PackedByteArray for prework lookup, full-bundle memory lookup and decoder lookup. decode_uncached already has a known_sha parameter. The68312 digest-update events also include different dependency, palette, key and checksum inputs; this aggregate is not all duplicate work.',
   candidate: 'Calculate one SHA256 for the job-owned exact byte value and pass it through internal prework/memory/decode calls. Keep separate hashes for distinct resources/derived data and persisted payload verification. Do not invent a global identity/pointer hash cache.' },
  { priority: 3, title: 'Memory cache hits deep-copy full prepared bundles; save computes work before no-op decisions', measuredLoad: row('load_data', 'preparation_store.gd', 54), measuredSave: row('save_data', 'preparation_store.gd', 59),
   anchors: [anchor('preparation_store.gd', 'return value.duplicate(true)'), anchor('asset_service.gd', 'job.memory_store.load_data(memory_key'), anchor('preparation_store.gd', 'var began:=Time.get_ticks_usec(); var cost:='), anchor('preparation_store.gd', 'var copy: Dictionary=value if retain_immutable'), anchor('preparation_store.gd', 'if epoch!=expected:'), anchor('preparation_store.gd', 'if not entries.has(identity):')],
   explanation: 'Full-bundle hits occur in AssetService._work and return a recursive private copy. Save accounts and may copy before discovering an obsolete epoch or an existing identity; eviction also scans request bindings. Native retained-cost work appears separately under resource_index_backend.class_call_static, so do not attribute all save-self time to accounting.',
   candidate: 'Add a cheap mutex-protected stale/existing-identity check and recheck at commit, preserving accounting semantics explicitly. Larger architecture: immutable canonical bundle plus small per-consumer mutable model/rig state, retaining private default for unsupported consumers.',
   obligations: 'Do not return shared mutable graphs. Preserve epochs, private nested mutation/alias behavior, coalesced waiter wakeups, exact FIFO budget/entry eviction and worker-side detached destruction. Phase data is needed before blaming copies versus eviction/destruction.' },
  { priority: 4, title: 'Repeated file fingerprints around content-addressed publication', measuredFingerprintOpen: fingerprints, measuredRename: renames, ratioFingerprintOpenToRename: fingerprints.calls / renames.calls,
   anchors: [anchor('prepared_cache.gd', 'if known_publication(path,fingerprint(path)'), anchor('prepared_cache.gd', 'var stamp:=fingerprint(path)'), anchor('prepared_cache.gd', 'if fingerprint(path)!=stamp:'), anchor('prepared_cache.gd', 'var published_stamp:=fingerprint(path)'), anchor('prepared_cache.gd', 'return valid and fingerprint(path)==stamp')],
   explanation: 'A fresh successful publication traverses roughly4 fingerprint open probes: save preflight, publish initial, pre-rename race check and post-rename proof. Observed20794 opens/5145 renames≈4.04 is consistent with this structure, not a temporal match proof. Existing proofs deliberately rehash the payload against same-length corruption.',
   candidate: 'Check whether a validated in-process proof exists before requesting the preflight fingerprint; absent proof cannot make that early-return succeed. Keep final race/identity validation. Consider already-open handle reuse only after preserving close/share/rename and concurrent mutation semantics.',
   obligations: 'Preserve unique temporary names, checksum/decoder/source/revision identity, flush/error handling, same-length corruption detection, path gate/competing publication and safe failed-write fallback. Do not replace temp+validated publication with in-place writes or a metadata-only validity cache.' }
 ],
 threadAndTimingQualification: {
  idleWait: { ...idle, role: 'Prepared writer Semaphore.wait, mostly no-work blocking. Not130seconds of CPU or a main freeze.' },
  sourceProvenWorkerRoutes: [anchor('asset_service.gd', 'WorkerThreadPool.add_task(_work.bind(job)'), anchor('prepared_write_queue.gd', 'thread.start(drain,Thread.PRIORITY_LOW)')],
  mixedOrUnproven: 'Generic disk cache helpers and store.save_data have multiple callers; whole-self alone cannot assign all calls to main versus workers. Worker I/O/copy time can delay readiness and compete for resources but is not automatically frame-critical.',
  parentGUIObservation: 'Parent observed27 threads for make_dir row; that thread count is not encoded in this CSV and was not independently reconstructed here.',
  criticalPathNext: 'Use the selected gameplay range and actual main-thread event ancestry for synchronous cache callers/waits before estimating a frame-time benefit. Whole-capture counts include startup, preparation, transitions, menus and shutdown.'
 },
 stage: { project: capturedRoot, parentReportedSourceIdentityPrefix: '22ea4402', normalSource: 'ea3469f0b87fa346acd28c0ffe97bba646601ed567e80d5f8eee03068989ebda', allReviewedCacheSourcesMatchCurrentNormal: sourcePins.every(row => row.sameAsCurrentNormal) },
 noImplementation: true, nativeStarts: 0, compilerStarts: 0, GUIActions: 0, profileStarts: 0, reviewer: pin(__filename)
};
const out = at('.cache/native-tracy/arelith-cache-audit-a'); fs.mkdirSync(out, { recursive: true }); const file = path.join(out, 'receipt.json'); fs.writeFileSync(file, JSON.stringify(result, null, 2) + '\n', { flag: 'wx' }); console.log(JSON.stringify({ file, sha256: pin(file).sha256, csvRows: rows.length, reviewedCacheSources: sourcePins.length, allSourcesMatch: result.stage.allReviewedCacheSourcesMatchCurrentNormal, nativeStarts: 0 }));
