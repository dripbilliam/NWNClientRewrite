// Bounded owner for the NEW original-instruction oracle. No engine/build/server.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const workspace = path.dirname(project);
const label = process.argv[2];
if (!/^[a-z0-9-]{3,80}$/.test(label ?? '')) throw Error('Supply a fresh oracle evidence label');
const directory = path.join(project, '.cache/native-clock-real-oracle', label);
if (fs.existsSync(directory)) throw Error('Existing oracle evidence retained');
const binary = path.resolve(workspace, '../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe');
const expectedBinary = '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
const fileHash = p => hash(fs.readFileSync(p));
if (fileHash(binary) !== expectedBinary) throw Error('Original binary SHA256 differs');
// Resolved read-only from HKCU PythonCore/3.11/InstallPath during authoring.
// Spawn the installed interpreter itself, never the py.exe launcher/process tree.
const pythonInterpreter = 'C:\\Program Files\\WindowsApps\\PythonSoftwareFoundation.Python.3.11_3.11.2544.0_x64__qbz5n2kfra8p0\\python3.11.exe';
const pythonSha256 = 'ea21d2833698f5bf74e44b7125855336a7bc1291be6983532109b016f9859257';
if (fileHash(pythonInterpreter) !== pythonSha256) throw Error('Pinned existing Python interpreter differs');
const relatives = [
  'godot-client/tools/native-clock-real-oracle.py',
  'godot-client/tools/test-native-clock-real-oracle.mjs',
  'godot-client/NATIVE-REMOTE-CLIENT-CLOCK-LIFECYCLE.md',
  'godot-client/reports/native-remote-client-clock-lifecycle-v1.json',
  'scripts/inspect-native-intratile-coordinator.py',
  'scripts/inspect-native-client-pause.py',
];
const inputs = relatives.map(name => ({path: name, sha256: fileHash(path.join(workspace, name))}));
const outputNames = [
  '.cache/native-window/nwn-window-modes.exe', '.cache/native-window/build-manifest.json',
  '.cache/native-kernel/nwn-particle-kernel.dll', '.cache/native-kernel/build-manifest.json',
  '.cache/native-resource-index/nwn-resource-index.dll', '.cache/native-resource-index/build-manifest.json',
];
const nativeOutputs = outputNames.map(name => ({path: name, sha256: fileHash(path.join(project, name))}));
fs.mkdirSync(path.join(directory, 'inputs'), {recursive: true});
for (const row of inputs) {
  const target = path.join(directory, 'inputs', row.path);
  fs.mkdirSync(path.dirname(target), {recursive: true});
  fs.copyFileSync(path.join(workspace, row.path), target);
  if (fileHash(target) !== row.sha256) throw Error('Oracle input changed during copy');
}
const resultFile = path.join(directory, 'result.json');
const args = ['-B', path.join(workspace, 'godot-client/tools/native-clock-real-oracle.py'), '--output', resultFile];
const command = {file: pythonInterpreter, sha256: pythonSha256, args, directInterpreter: true,
  windowsHide: true, wallMilliseconds: 35000, combinedOutputBytes: 1024 * 1024};
fs.writeFileSync(path.join(directory, 'command.json'), JSON.stringify(command, null, 2) + '\n');
const outcome = await new Promise(resolve => {
  const child = spawn(pythonInterpreter, args, {
    windowsHide: true, cwd: workspace, stdio: ['ignore', 'pipe', 'pipe'],
    env: {...process.env, PYTHONDONTWRITEBYTECODE: '1', NATIVE_CLOCK_REAL_ORACLE_BOUNDED: '35s-512KiB-v1'},
  });
  let stdout = '', stderr = '', failure = null, consumed = 0;
  let spawned = false, exitObserved = false, closeObserved = false;
  let killRequested = false, killAccepted = null;
  const stop = reason => {
    failure ??= reason;
    if (!exitObserved && !killRequested) {
      killRequested = true;
      // ChildProcess.kill holds only this directly spawned interpreter handle.
      // No PID/name matching, launcher descendant, or taskkill is involved.
      killAccepted = child.kill();
      if (!killAccepted) failure += '; direct owned interpreter termination was not accepted';
    }
  };
  const consume = (kind, data) => {
    consumed += data.length;
    if (consumed > command.combinedOutputBytes) { stop('Oracle stdout/stderr exceeded1MiB'); return; }
    if (kind === 'stdout') stdout += data.toString(); else stderr += data.toString();
  };
  child.stdout.on('data', data => consume('stdout', data));
  child.stderr.on('data', data => consume('stderr', data));
  child.once('spawn', () => { spawned = true; });
  child.once('exit', () => { exitObserved = true; });
  child.once('error', error => { failure ??= error.message; });
  const deadline = setTimeout(() => stop('Oracle exceeded35s'), command.wallMilliseconds);
  child.once('close', (code, signal) => {
    closeObserved = true;
    clearTimeout(deadline);
    resolve({code, signal, failure, stdout, stderr, ownedProcessId: child.pid ?? null,
      spawned, exitObserved, closeObserved, killRequested, killAccepted});
  });
});
fs.writeFileSync(path.join(directory, 'stdout.log'), outcome.stdout);
fs.writeFileSync(path.join(directory, 'stderr.log'), outcome.stderr);
let result = null, reportError = null, resultSha256 = null;
try {
  if (!fs.existsSync(resultFile)) throw Error('No oracle result');
  if (fs.statSync(resultFile).size > 512 * 1024) throw Error('Oracle result exceeds512KiB');
  const bytes = fs.readFileSync(resultFile);
  resultSha256 = hash(bytes);
  result = JSON.parse(bytes);
} catch (error) { reportError = error.message; }
const changedInputs = inputs.filter(r => fileHash(path.join(workspace, r.path)) !== r.sha256).map(r => r.path);
const changedCopies = inputs.filter(r => fileHash(path.join(directory, 'inputs', r.path)) !== r.sha256).map(r => r.path);
const changedOutputs = nativeOutputs.filter(r => fileHash(path.join(project, r.path)) !== r.sha256).map(r => r.path);
const binaryUnchanged = fileHash(binary) === expectedBinary;
const interpreterUnchanged = fileHash(pythonInterpreter) === pythonSha256;
const ownedChildClosed = outcome.spawned && outcome.exitObserved && outcome.closeObserved;
const dependencyGuardsValid = Array.isArray(result?.guards?.changedDependencies) && !result.guards.changedDependencies.length;
const completeMatrix = result?.configurations?.length === 11 && result?.rows?.length === 117;
const definedRows = result?.rows?.filter(r => r.defined === true).length ?? 0;
const undefinedRows = result?.rows?.filter(r => r.defined === false && r.result === null && r.diagnosticOnly === true).length ?? 0;
const proof = {
  success: outcome.code === 0 && !outcome.failure && !reportError && result?.success === true && completeMatrix &&
    definedRows === 113 && undefinedRows === 4 && !changedInputs.length && !changedCopies.length && !changedOutputs.length &&
    binaryUnchanged && interpreterUnchanged && ownedChildClosed && dependencyGuardsValid,
  method: 'original-instructions-unicorn', configurations: result?.configurations?.length ?? 0,
  rows: result?.rows?.length ?? 0, definedRows, undefinedRows, completeMatrix,
  resultSha256, inputs, changedInputs, changedCopies, nativeOutputs, changedOutputs,
  binarySha256: expectedBinary, binaryUnchanged, exitCode: outcome.code, signal: outcome.signal,
  error: outcome.failure ?? result?.error ?? null, reportError, ownedProcessId: outcome.ownedProcessId,
  interpreter: {path: pythonInterpreter, sha256: pythonSha256, unchanged: interpreterUnchanged},
  ownedChildClosed, childLifecycle: {directInterpreter: true, spawned: outcome.spawned,
    exitObserved: outcome.exitObserved, closeObserved: outcome.closeObserved,
    killRequested: outcome.killRequested, killAccepted: outcome.killAccepted},
  dependencyGuardsValid, changedDependencies: result?.guards?.changedDependencies ?? null,
  command, serverConnections: 0, keyReads: 0, profileReads: 0, gpu: false, userProcessActions: 0, nativeBuilds: 0,
  scope: 'Original 16dd60 configuration prefix and16e110 under controlled WinAPI/CPU state. No live WinAPI or threaded-cache equivalence; QPC-failure rows unavailable.',
};
fs.writeFileSync(path.join(directory, 'proof.json'), JSON.stringify(proof, null, 2) + '\n');
console.log(JSON.stringify({...proof, inputs: inputs.length, nativeOutputs: nativeOutputs.length, directory}));
process.exitCode = proof.success ? 0 : 1;
