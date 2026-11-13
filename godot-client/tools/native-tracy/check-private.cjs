'use strict';
// Bounded local parser and real native owner checks, without a server or assets.
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict'), crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
async function main() {
 const configFile = path.resolve(process.argv[2]), config = read(configFile);
 const stage = path.join(config.out, 'manifest.json'), out = path.join(config.out, 'native-checks-a');
 assert(!fs.existsSync(out), 'Keep prior native checks');
 require(path.join(config.source, 'verify.cjs')).verify(configFile);
 const runtime = require(path.join(config.view, 'tools/native-performance-runtime.cjs'));
 const options = runtime.decorateOptions(require(path.join(config.view, 'tools/native-client-flags.cjs')).resolvePerformanceOptions([], { env: {} }));
 const selection = await runtime.selectPerformanceRuntime(config.view, options.runtime);
 assert.equal(selection.executableSha256, config.engineSha256);
 assert.equal(options.renderCore.flags.length, 16);
 fs.mkdirSync(out);
 fs.copyFileSync(__filename, path.join(out, 'executor.cjs'), fs.constants.COPYFILE_EXCL);
 const fixture = path.join(config.project, '.cache/native-render-gap/scene/normal-integration-c/project/tests/native_normal_core_owner_fixture.gd');
 const testFile = path.join(config.view, 'tests/native_tracy_owner_fixture.gd');
 fs.copyFileSync(fixture, testFile, fs.constants.COPYFILE_EXCL);
 const expectedFile = path.join(out, 'expected.json');
 fs.writeFileSync(expectedFile, JSON.stringify({ requested: options.requested, lightInput: 'builtin', typed: true, thread: options.renderThread }), { flag: 'wx' });
 const specs = [
  { name: 'parse-live', args: ['--check-only', '--script', 'res://native_live_world.gd'] },
  { name: 'parse-session', args: ['--check-only', '--script', 'res://native_session_world.gd'] },
  { name: 'feature-contract', args: ['--script', 'res://tests/native_client_feature_report_test.gd'], report: true },
  { name: 'actual-owners', args: ['--script', 'res://tests/native_tracy_owner_fixture.gd'], report: true, extra: ['--expectation=' + expectedFile, ...options.nativeArguments] }
 ];
 const results = [];
 for (const spec of specs) {
  const directory = path.join(out, spec.name); fs.mkdirSync(directory);
  for (const name of ['appdata', 'localappdata']) fs.mkdirSync(path.join(directory, name));
  const report = path.join(directory, 'report.json');
  const args = ['--headless', '--path', config.view, ...options.engineArguments, '--log-file', path.join(directory, 'engine.log'), ...spec.args,
   ...(spec.report ? ['--', '--report=' + report, ...(spec.extra || [])] : [])];
  const result = spawnSync(config.engineLaunch, args, { windowsHide: true, encoding: 'utf8', timeout: 30000, maxBuffer: 16 * 1024 * 1024,
   env: { ...process.env, APPDATA: path.join(directory, 'appdata'), LOCALAPPDATA: path.join(directory, 'localappdata') } });
  fs.writeFileSync(path.join(directory, 'stdout.log'), result.stdout || '', { flag: 'wx' });
  fs.writeFileSync(path.join(directory, 'stderr.log'), result.stderr || '', { flag: 'wx' });
  const native = spec.report && fs.existsSync(report) ? read(report) : null;
  const errors = /SCRIPT ERROR|ERROR:|FATAL:|leaked|still in use|crash handler/i.test((result.stdout || '') + '\n' + (result.stderr || ''));
  const row = { name: spec.name, success: result.status === 0 && !result.error && !errors && (!spec.report || native?.success === true), exit: result.status,
   error: result.error?.message, errors, command: [config.engineLaunch, ...args], native };
  results.push(row); fs.writeFileSync(path.join(directory, 'receipt.json'), JSON.stringify(row, null, 2) + '\n', { flag: 'wx' });
  console.log(JSON.stringify({ name: row.name, success: row.success, exit: row.exit, errors: row.errors }));
  if (!row.success) break;
 }
 require(path.join(config.source, 'verify.cjs')).verify(configFile);
 const receipt = { version: 1, success: results.length === specs.length && results.every(row => row.success), createdUtc: new Date().toISOString(),
  stageManifestSha256: sha(stage), engineSha256: sha(config.engineLaunch), particleSha256: config.particleSha256, executorSha256: sha(__filename),
  fixture: { original: fixture, file: testFile, sha256: sha(testFile) }, flags: options.renderCore.flags, results,
  scope: 'Actual private client script compilation, capability contract and 32-lamp/settings/native-owner checks. No public login, gameplay, pixels, FPS or GPU timing acceptance.' };
 fs.writeFileSync(path.join(out, 'acceptance.json'), JSON.stringify(receipt, null, 2) + '\n', { flag: 'wx' });
 assert(receipt.success, 'Preserve rejected native checks');
}
main().catch(error => { console.error(error.stack); process.exitCode = 1; });
