import test from 'node:test';
import assert from 'node:assert/strict';
import { field as f, record as r, writeGff, writeMod, OracleScript } from '../scripts/native-oracle-data.mjs';
import { parseGff, getGffStructType } from '../src/gff.js';
import { parseNcs, parseScriptApi } from '../src/ncs.js';
import { NwScriptVm } from '../src/nwscript_vm.js';

test('owned fixture GFF preserves nested list offsets, equipment structure IDs and signed fields', () => {
  const bytes = writeGff('UTC ', r({ Tag: f(10, 'own'), Name: f(12, 'Owned'), Signed: f(3, -20), Position: f(8, 1.5), Empty: f(15, []),
    Equipment: f(15, [r({ Inner: f(15, [r({ Rank: f(0, 2) }, 7)]), Ref: f(11, 'own_item') }, 16), r({ Rank: f(0, 3) }, 32)]) }));
  const parsed = parseGff(bytes, 'UTC ').root;
  assert.equal(parsed.Tag, 'own'); assert.equal(parsed.Signed, -20); assert.equal(parsed.Position, 1.5);
  assert.equal(parsed.Name.entries[0].text, 'Owned'); assert.deepEqual(parsed.Empty, []);
  assert.equal(getGffStructType(parsed.Equipment[0]), 16); assert.equal(getGffStructType(parsed.Equipment[1]), 32);
  assert.equal(parsed.Equipment[0].Inner[0].Rank, 2); assert.equal(parsed.Equipment[0].Ref, 'own_item');
});
test('owned archive resource offsets match their independently decoded resource payloads', () => {
  const a = writeGff('IFO ', r({ Tag: f(10, 'module') })), b = writeGff('ARE ', r({ Width: f(3, 1) }));
  const bytes = writeMod([['module', 2014, a], ['oc_arena', 2012, b]]);
  assert.equal(bytes.subarray(0, 8).toString(), 'MOD V1.0');
  const keys = bytes.readUInt32LE(24), table = bytes.readUInt32LE(28);
  assert.equal(bytes.readUInt32LE(16), 2); assert.equal(bytes.readUInt16LE(keys + 20), 2014);
  const payload = index => bytes.subarray(bytes.readUInt32LE(table + index * 8), bytes.readUInt32LE(table + index * 8) + bytes.readUInt32LE(table + index * 8 + 4));
  assert.equal(parseGff(payload(0)).root.Tag, 'module'); assert.equal(parseGff(payload(1)).root.Width, 1);
});
test('owned oracle scripts execute nested native-order calls, string operations and both branches', async () => {
  const api = parseScriptApi('void PrintString(string text); string GetTag(object o); string IntToString(int n);');
  const call = (name, ...args) => ({ call: name, args });
  const code = new OracleScript(api);
  code.ifThen({ equalString: [call('GetTag', { self: true }), 'oc_a'] },
    () => code.statement(call('PrintString', { concat: ['A ', call('IntToString', { add: [1,2] })] })),
    () => code.statement(call('PrintString', 'B')));
  code.ifThen({ ge: [3,3] }, () => code.statement(call('PrintString', 'DONE')));
  const program = parseNcs(code.finish(), 'owned'), printed = [];
  const vm = new NwScriptVm({ api, command: name => (args, frame) => {
    if (name === 'PrintString') printed.push(args[0]);
    if (name === 'GetTag') { assert.equal(args[0], frame.self); return frame.self === 1 ? 'oc_a' : 'oc_b'; }
    if (name === 'IntToString') return String(args[0]);
  }});
  assert.deepEqual((await vm.run(program, 1)).stack, []); assert.deepEqual(printed, ['A 3','DONE']);
  printed.length = 0; assert.deepEqual((await vm.run(program, 2)).stack, []); assert.deepEqual(printed, ['B','DONE']);
});
