import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createRequire } from 'node:module';
import { RuntimeDiagnostics, runtimeDiagnostics } from '../src/runtime_diagnostics.js';
import { NwScriptVm } from '../src/nwscript_vm.js';
import { ModuleSession } from '../src/module_session.js';
import { ResourceResolver, RESOURCE_TYPE } from '../src/resource_archive.js';
import { loadAreaWalkmesh } from '../src/area.js';
import { GameText } from '../src/talk_table.js';
const { createRuntimeLog } = createRequire(import.meta.url)('../electron/runtime_log.cjs');
const program = { name: 'diagnostic_fixture', instructions: new Map([[13, { pc: 13, op: 5, command: 0, argc: 0, next: 18 }], [18, { pc: 18, op: 0x20 }]]) };
const spec = { name: 'CopyObject', args: [], returns: 'void' };

test('unsupported and partially implemented engine calls retain exact script/self/command context without consuming actions', async () => {
  const log = new RuntimeDiagnostics();
  const vm = new NwScriptVm({ api: [{ ...spec, args: [{ type: 'action' }] }], command: () => null, diagnostics: log, diagnosticContext: () => ({ module: 'custom.mod', area: 'test_area' }) });
  const actionProgram = { ...program, instructions: new Map(program.instructions) }; actionProgram.instructions.set(13, { ...program.instructions.get(13), argc: 1 });
  await assert.rejects(vm.run(actionProgram, 0x80000000), /CopyObject is not implemented/);
  assert.equal(log.records.length, 1);
  assert.deepEqual(Object.fromEntries(['module', 'area', 'script', 'pc', 'engineCall', 'engineId', 'objectId'].map(k => [k, log.records[0].context[k]])),
    { module: 'custom.mod', area: 'test_area', script: program.name, pc: 13, engineCall: 'CopyObject', engineId: 0, objectId: 0x80000000 });
  vm.api = [spec]; vm.command = () => () => { throw new Error('Saved active effect import is not implemented'); };
  await assert.rejects(vm.run(program, 0), /Saved active effect/);
  assert.equal(log.records[1].code, 'engine.unimplemented'); assert.equal(log.records[1].context.objectId, 0);
  vm.command = () => () => {}; vm.limitations = { CopyObject: 'Presentation pending' };
  await vm.run(program, 0); assert.equal(log.records[2].code, 'engine.partial');
  vm.api = [{ ...spec, args: [{ name: 'target', type: 'object' }] }]; vm.command = () => null;
  const objectProgram = { ...program, instructions: new Map([[13, { op: 4, type: 6, value: 0, next: 19 }], [19, { op: 5, pc: 19, command: 0, argc: 1, next: 24 }]]) };
  await assert.rejects(vm.run(objectProgram, 0x80000000), /not implemented/);
  assert.deepEqual(log.records[3].context.objectArguments, [{ index: 0, name: 'target', objectId: 0x80000000 }]);
});

test('scheduler and session reporting do not double-record VM failures; separate executions remain separate occurrences', async () => {
  const start = runtimeDiagnostics.records.length;
  const session = new ModuleSession({ moduleName: 'generic.mod' });
  const actor = session.register('creature', 'a:creature:0', { tag: 'npc' });
  session.vm = new NwScriptVm({ api: [spec], command: () => null, diagnosticContext: id => session.diagnosticContext(id) });
  for (let n = 0; n < 2; n++) session.scheduler.enqueue(actor.id, { type: 'situation', situation: { program, pc: 13, stack: [], bp: 0 } });
  await session.scheduler.pump();
  const records = runtimeDiagnostics.records.slice(start);
  assert.equal(records.length, 2); assert.ok(records.every(r => r.code === 'engine.unimplemented' && r.context.sourceKey === 'a:creature:0'));
  for (let n = 0; n < 80; n++) session.report(new Error(`load omission ${n}`));
  assert.equal(session.diagnostics.length, 64); assert.equal(runtimeDiagnostics.records.length - start, 82);
});

test('resource fallback probes and cached read failures are recorded on every attempt without interfering with successful resolution', async () => {
  const start = runtimeDiagnostics.records.length;
  const resolver = new ResourceResolver({ entries: new Map([['texture:2033', new Uint8Array([1, 2])]]) }, { resources: new Map(), bifNames: [] }, []);
  await assert.rejects(resolver.getResource('texture', RESOURCE_TYPE.TGA), /not found/);
  assert.deepEqual(new Uint8Array(await resolver.getResource('texture', RESOURCE_TYPE.DDS)), new Uint8Array([1, 2]));
  const error = new Error('File read failed');
  const rejected = Promise.reject(error); rejected.catch(() => {});
  resolver.key.resources.set('mesh:2002', { bifIndex: 0, resourceIndex: 0 }); resolver.key.bifNames = ['broken.bif']; resolver.bifCache.set('broken.bif', rejected);
  for (let n = 0; n < 2; n++) await assert.rejects(resolver.getResource('mesh', RESOURCE_TYPE.MDL), /File read failed/);
  const records = runtimeDiagnostics.records.slice(start);
  assert.equal(records.length, 3); assert.equal(records[0].code, 'resource.lookup-failed'); assert.equal(records[0].severity, 'info');
  assert.ok(records.slice(1).every(r => r.code === 'resource.read-failed' && r.severity === 'error' && r.context.bifName === 'broken.bif'));
  assert.equal(records[0].context.resRef, 'texture'); assert.match(records[0].context.outcome, /may recover/);
});

test('a swallowed walkmesh parser/load failure records the omitted tile and area', async () => {
  const start = runtimeDiagnostics.records.length;
  const result = await loadAreaWalkmesh({ resRef: 'generic_area', width: 1, tileHeight: 5, tiles: [{ model: 'broken_tile', height: 0 }] }, {
    getResource: async name => { if (name === 'surfacemat') return new TextEncoder().encode('2DA V2.0\n\n Walk\n0 1\n').buffer; throw new Error('Malformed walkmesh payload'); }
  });
  assert.equal(result.missing.length, 1); assert.equal(result.triangles.length, 0);
  const record = runtimeDiagnostics.records[start]; assert.equal(record.code, 'scene.walkmesh-unavailable');
  assert.equal(record.context.area, 'generic_area'); assert.equal(record.context.tileIndex, 0); assert.equal(record.context.model, 'broken_tile');
});

test('unavailable talk-table references record once per table while retaining localized fallback text', () => {
  const start = runtimeDiagnostics.records.length, text = new GameText();
  for (let i = 0; i < 5; i++) assert.equal(text.resolve({ strRef: 123, entries: [{ languageId: 6, text: 'Localized fallback' }] }), 'Localized fallback');
  text.strRef(0xffffffff);
  const records = runtimeDiagnostics.records.slice(start); assert.equal(records.length, 1); assert.equal(records[0].context.strRef, 123);
  assert.equal(text.resolve({ strRef: 124, entries: [{ languageId: 0, text: 'Preferred local text' }] }), 'Preferred local text');
  assert.equal(runtimeDiagnostics.records.length - start, 1);
});

test('journal persists early records, concurrent batches and metadata snapshots without truncating the full history', async () => {
  const log = new RuntimeDiagnostics({ session: 'test' }), batches = [], context = { objectId: 0, nested: { tag: 'original' } };
  log.record('early', 'Before persistence attached', context); context.nested.tag = 'changed';
  await log.attach(async records => { await new Promise(resolve => setTimeout(resolve, 1)); batches.push(...records); }, 'test sink');
  for (let i = 0; i < 500; i++) log.record('missing', `Missing ${i}`);
  await Promise.all([log.flush(), log.flush()]);
  assert.equal(batches.length, 501); assert.equal(log.records.length, 501); assert.equal(log.pending.length, 0);
  assert.equal(batches[0].context.nested.tag, 'original'); assert.deepEqual(batches.map(r => r.sequence), Array.from({ length: 501 }, (_, i) => i + 1));
  assert.equal(log.jsonl().trim().split('\n').length, 501);
});

test('failed persistence retains the complete queue and exposes the failure for export and retry', async () => {
  let failing = true; const written = [], log = new RuntimeDiagnostics({ sink: async batch => { if (failing) throw new Error('Disk full'); written.push(...batch); } });
  log.record('engine.unimplemented', 'CopyObject'); await assert.rejects(log.flush(), /Disk full/);
  assert.equal(log.storageError, 'Disk full'); assert.equal(log.pending.length, 2); assert.match(log.jsonl(), /diagnostic.save-failed/);
  failing = false; await log.flush(); assert.equal(log.storageError, null); assert.equal(written.length, 2); assert.equal(log.pending.length, 0);
});

test('diagnostic metadata safely represents circular objects, bigint handles and binary byte counts', () => {
  const log = new RuntimeDiagnostics(), context = { handle: 123n, asset: new Uint8Array([1, 2]) }; context.cycle = context;
  log.record('test', 'safe', context);
  assert.equal(log.records[0].context.handle, '123'); assert.deepEqual(log.records[0].context.asset, { binaryBytes: 2 }); assert.match(log.jsonl(), /circular/);
});

test('native writer creates separate durable JSONL files, deduplicates acknowledgements and rejects arbitrary payloads', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'nwn-diagnostic-test-'));
  try {
    const log = new RuntimeDiagnostics({ session: 'test' }); log.record('engine.unimplemented', 'CopyObject', { objectId: 0 });
    const writer = createRuntimeLog(directory), other = createRuntimeLog(directory);
    assert.notEqual(writer.path, other.path);
    writer.append(log.records); writer.append(log.records);
    assert.deepEqual(fs.readFileSync(writer.path, 'utf8').trim().split('\n').map(JSON.parse), log.records);
    assert.throws(() => writer.append([{ path: '../escape', message: 'invalid' }]), /Invalid diagnostic/);
  } finally { assert.ok(path.resolve(directory).startsWith(path.resolve(os.tmpdir()) + path.sep)); fs.rmSync(directory, { recursive: true }); }
});
