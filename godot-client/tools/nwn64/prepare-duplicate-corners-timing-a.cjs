'use strict';
// Stage identical profile=false shared-presenter fixtures for an exclusive
// coordinator timing lease. This script copies inputs; it starts no engine.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const read = file => fs.readFileSync(file);
const frozen = path.join(root, '.cache/nwn64/clock-runtime-accepted-g');
const baseManifestFile = path.join(frozen, 'manifest.json');
const baseManifestBytes = read(baseManifestFile);
assert.equal(sha(baseManifestBytes), 'f2ca8c77d2775a44dcede95034b593be3e9958dd8be982c2516f474fd2ff2f91');
const baseManifest = JSON.parse(baseManifestBytes);
const addedManifestFile = path.join(frozen, 'clock-manifest.json');
const addedManifestBytes = read(addedManifestFile);
assert.equal(sha(addedManifestBytes), 'b917642fcbe90fe1373f2cd185381eb0a2030bdb1b5f982f180452e1320f663f');
const addedManifest = JSON.parse(addedManifestBytes);
assert.equal(addedManifest.originalManifestSha256, sha(baseManifestBytes));
const sourceManifestFile = path.join(root, '.cache/nwn64/duplicate-corners-b/manifest.json');
assert.equal(sha(read(sourceManifestFile)), '87fefe888b88d448156d6222cbedc3b70277b99971e67feca8da1d51b802dafc');
const buildFile = path.join(root, '.cache/nwn64/duplicate-corners-b/kernel-build/build-receipt.json');
const buildBytes = read(buildFile), build = JSON.parse(buildBytes.toString().replace(/^\uFEFF/, ''));
assert.equal(sha(buildBytes), '97d0e753f56b0af1b4132feea3e6cb5e43e438b670f441e9db8d4b3ee70a691d');
assert(build.success && build.private && !build.accepted && !build.production);
assert.equal(build.sourceManifestSha256, sha(read(sourceManifestFile)));
assert(build.arguments.includes('/DNWN_PARTICLE_DUPLICATE_CORNERS=1'));
assert.equal(build.binarySha256, sha(read(build.binary)));
assert.equal(build.binarySha256, 'de08a762bd9b98a818ae095c73c1f155d745e2d471e69057d35fe53f47485d6b');
const accepted = read(path.join(root, '.cache/native-kernel/nwn-particle-kernel.dll'));
assert.equal(sha(accepted), '485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d');
const originalFixture = read(path.join(frozen, 'project/tests/nwn64_shared_clock_test.gd'));
assert.equal(sha(originalFixture), 'f067c88ac9c0e6ca79a75033a7da6f973b741f5dcb4c6958b2d7909c3fa9163c');
function replaceOnce(text, before, after) {
  assert.equal(text.split(before).length, 2, 'Fixture anchor changed');
  return text.replace(before, after);
}
let fixture = originalFixture.toString();
fixture = replaceOnce(fixture,
  'var wall: Array=[];var phases: Dictionary={};var phase_packets:=0;var last: Dictionary={}',
  'var wall: Array=[];var phases: Dictionary={};var phase_packets:=0;var last: Dictionary={};var measured_direct_vertices:=0;var positive_direct_frames:=0');
fixture = replaceOnce(fixture,
  '\t\tif benchmark and frame>=80:wall.append(Time.get_ticks_usec()-began)',
  '\t\tif benchmark and frame>=80:\n\t\t\twall.append(Time.get_ticks_usec()-began)\n\t\t\tvar direct_vertices:=int(last.get("vertices",-1))\n\t\t\tcheck(direct_vertices>=0 and direct_vertices%6==0 and int(last.get("scene_vertices",-1))==0,"Measured shared frame uses exact direct native-surface vertices")\n\t\t\tmeasured_direct_vertices+=direct_vertices\n\t\t\tpositive_direct_frames+=int(direct_vertices>0)');
fixture = replaceOnce(fixture,
  '\tcheck(phase_packets==(frames if diagnostic else 0),"Normal throughput has no diagnostic phase packets")',
  '\tcheck(phase_packets==(frames if diagnostic else 0),"Normal throughput has no diagnostic phase packets")\n\tcheck(not benchmark or positive_direct_frames>0,"Profile-off measured frames engage positive shared direct geometry")');
fixture = replaceOnce(fixture,
  '"component_call_us":quantiles(wall) if not wall.is_empty() else {},"separate_diagnostic_phase_us"',
  '"component_call_us":quantiles(wall) if not wall.is_empty() else {},"measured_direct_vertices":measured_direct_vertices,"positive_direct_frames":positive_direct_frames,"derived_duplicate_copy_calls":measured_direct_vertices/3,"copy_count_kind":"derived from 2 copies per 6 direct vertices; not instrumented","separate_diagnostic_phase_us"');
const fixtureBytes = Buffer.from(fixture);
const target = path.join(root, '.cache/nwn64/duplicate-corners-b/timing-pair-a');
assert(!fs.existsSync(target), 'Preserve prior timing pair');
const views = [];
for (const mode of ['control', 'candidate']) {
  const out = path.join(target, mode), project = path.join(out, 'project');
  fs.mkdirSync(project, { recursive: true });
  const pins = [];
  function put(relative, bytes) {
    assert(!path.isAbsolute(relative) && !relative.split(/[\\/]/).includes('..'));
    const file = path.join(project, relative);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, bytes, { flag: 'wx' });
    pins.push({ relative, bytes: bytes.length, sha256: sha(bytes) });
  }
  for (const row of [...baseManifest.files, ...addedManifest.added]) {
    const bytes = read(path.join(frozen, 'project', row.relative));
    assert.equal(bytes.length, row.bytes, row.relative);
    assert.equal(sha(bytes), row.sha256, row.relative);
    if (row.relative === '.cache/native-kernel/nwn-particle-kernel.dll') put(row.relative, mode === 'candidate' ? read(build.binary) : accepted);
    else if (row.relative === 'tests/nwn64_shared_clock_test.gd') put(row.relative, fixtureBytes);
    else put(row.relative, bytes);
  }
  const oracles = [];
  for (const row of baseManifest.oracles) {
    const relative = `backups/animations/${row.name}.json`, bytes = read(path.join(frozen, relative));
    assert.equal(sha(bytes), row.sha256, relative);
    const file = path.join(out, relative);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, bytes, { flag: 'wx' });
    oracles.push({ relative, bytes: bytes.length, sha256: sha(bytes) });
  }
  views.push({ mode, project, pins, oracles, nativeBinarySha256: mode === 'candidate' ? build.binarySha256 : sha(accepted), fixtureSha256: sha(fixtureBytes) });
}
const pair = { version: 1, issue: 'NWN-64', private: true, accepted: false, production: false, baseManifestSha256: sha(baseManifestBytes), addedManifestSha256: sha(addedManifestBytes), sourceManifestSha256: sha(read(sourceManifestFile)), buildReceiptSha256: sha(buildBytes), engineSha256: '753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b', views, scope: 'Matched 1750-source shared native presenter, profile=false, 960 culled, 350 canonical clocks, positive direct packet vertices. Derived copy engagement; component frame only, no renderer/FPS/live game.' };
const pairFile = path.join(target, 'pair.json');
fs.writeFileSync(pairFile, JSON.stringify(pair, null, 2) + '\n', { flag: 'wx' });
process.stdout.write(JSON.stringify({ pair: pairFile, sha256: sha(read(pairFile)), views: views.map(view => ({ mode: view.mode, files: view.pins.length, oracles: view.oracles.length, binary: view.nativeBinarySha256, fixture: view.fixtureSha256 })) }) + '\n');
