import assert from 'node:assert/strict';
import test from 'node:test';
import { GameObjectArray, OBJECT_INVALID } from '../src/game_object_array.js';
import { parseNcs, parseScriptApi } from '../src/ncs.js';
import { NwScriptVm, ScriptError } from '../src/nwscript_vm.js';
import { ScriptScheduler } from '../src/script_scheduler.js';
import { ModuleSession } from '../src/module_session.js';
import { ScriptVariableTable } from '../src/script_variables.js';

function program(rows) {
  const code = []; const labels = new Map(), fixes = [];
  const u16 = n => code.push((n >>> 8) & 255, n & 255);
  const i32 = n => code.push((n >>> 24) & 255, (n >>> 16) & 255, (n >>> 8) & 255, n & 255);
  for (const row of rows) {
    if (typeof row === 'string') { labels.set(row, 13 + code.length); continue; }
    const [op, type = 0, value, size] = row, pc = 13 + code.length;
    code.push(op, type);
    if (op === 4 && type === 5) { const bytes = new TextEncoder().encode(value); u16(bytes.length); code.push(...bytes); }
    else if (op === 4 && type === 4) { const b = new ArrayBuffer(4); new DataView(b).setFloat32(0, value); code.push(...new Uint8Array(b)); }
    else if ([4, 0x1b, 0x23, 0x24, 0x28, 0x29].includes(op)) i32(value);
    else if ([0x1d, 0x1e, 0x1f, 0x25].includes(op)) { fixes.push({ index: code.length, pc, label: value }); i32(0); }
    else if ([1, 3, 0x26, 0x27].includes(op)) { i32(value); u16(size); }
    else if (op === 5) { u16(value); code.push(size); }
    else if (op === 0x2c) { i32(value); i32(size); }
    else if (op === 0x21) { u16(value); u16(size); u16(row[4]); }
  }
  const bytes = new Uint8Array(13 + code.length), view = new DataView(bytes.buffer);
  bytes.set(new TextEncoder().encode('NCS V1.0')); bytes[8] = 0x42; view.setUint32(9, bytes.length); bytes.set(code, 13);
  for (const fix of fixes) view.setInt32(13 + fix.index, labels.get(fix.label) - fix.pc);
  return parseNcs(bytes, 'fixture');
}
const api = parseScriptApi('void AssignCommand(object subject, action command); void SetLocalInt(object obj, string name, int value); void DelayCommand(float seconds, action command);');

test('native object table keeps namespaces, hash collisions, ID zero and exact external IDs', () => {
  const table = new GameObjectArray({ cacheBits: 2 });
  const first = {}, collision = {}, external = {};
  assert.equal(table.addInternalObject(first).id, 0);
  assert.equal(table.addObjectAtPos(4, collision).status, 0);
  assert.equal(table.addExternalObject(0, external).status, 1, 'Native checks the supplied namespace before tagging an external ID');
  assert.equal(table.addExternalObject(0x80000000, external).id, 0x80000000);
  assert.equal(table.get(0), first); assert.equal(table.get(4), collision); assert.equal(table.get(0x80000000), external);
  assert.equal(table.addExternalObject(0, {}).status, 1);
  assert.equal(table.addInternalObject(first).status, 1);
  assert.equal(table.get(OBJECT_INVALID), undefined); assert.equal(table.get('0'), undefined);
  assert.equal(table.delete(0).object, first); assert.equal(table.get(4), collision); assert.equal(table.get(0x80000000), external);
  assert.equal(table.addInternalObject({}).id, 5, 'Deleted IDs must not be recycled');
  assert.equal(table.getGameObject(123).status, 1);
  table.clean(0); assert.equal(table.get(4), collision);
});

test('character-object allocation is independent of creature type and preserves exhaustion guards', () => {
  const table = new GameObjectArray();
  assert.equal(table.addInternalObject({}, { characterObject: true }).id, 0x7fffffff);
  assert.equal(table.addInternalObject({}, { characterObject: true }).id, 0x7ffffffe);
  assert.equal(table.addInternalObject({ kind: 'creature' }).id, 0);
  table.nextObjectId[0] = 0x7effffff; table.nextCharacterId[0] = 0x7f000001;
  assert.equal(table.addInternalObject({}).status, 1);
  assert.equal(table.addInternalObject({}, { characterObject: true }).status, 1);
  assert.equal(table.addObjectAtPos(OBJECT_INVALID, {}).status, 1);
  assert.equal(table.addObjectAtPos(0x01000000, {}).status, 1, 'Preserve native mask classification');
  assert.equal(table.addInternalObject(null).status, 4);
});

test('NCS header, truncation and branches into operands are rejected', () => {
  assert.throws(() => parseNcs(new Uint8Array(13)), /header/);
  const branch = new Uint8Array(21); branch.set(new TextEncoder().encode('NCS V1.0')); branch[8] = 0x42;
  new DataView(branch.buffer).setUint32(9, branch.length); branch.set([0x1d, 0, 0, 0, 0, 2, 0x20, 0], 13);
  assert.throws(() => parseNcs(branch), /non-instruction/);
  const b = new Uint8Array(15); b.set(new TextEncoder().encode('NCS V1.0')); b[8] = 0x42; new DataView(b.buffer).setUint32(9, b.length); b.set([4, 3], 13);
  assert.throws(() => parseNcs(b), /truncated/);
});

test('integer overflow, native negative shifts and float32 arithmetic differ from JavaScript defaults', async () => {
  const vm = new NwScriptVm({ api: [], command: () => null });
  const run = async (a, b, op, type = 0x20) => (await vm.run(program([[4, type === 0x21 ? 4 : 3, a], [4, type === 0x21 ? 4 : 3, b], [op, type], [0x20]]))).stack[0].value;
  assert.equal(await run(0x7fffffff, 1, 0x14), -2147483648);
  assert.equal(await run(0x7fffffff, 0x7fffffff, 0x16), 1);
  assert.equal(await run(-3, 1, 0x12), -1);
  assert.equal(await run(-3, 1, 0x13), -2);
  assert.equal(await run(16777216, 1, 0x14, 0x21), 16777216);
  await assert.rejects(run(1, 0, 0x17), /Division by zero/);
  await assert.rejects(run(-2147483648, -1, 0x17), /overflow/);
});

test('OBJECT_SELF is resolved at execution, other object constants and RSADD are invalid', async () => {
  const vm = new NwScriptVm({ api: [], command: () => null });
  const result = await vm.run(program([[4, 6, 0], [4, 6, 1], [4, 6, 123], [2, 6], [0x20]]), 0x80000001);
  assert.deepEqual(result.stack.map(c => c.value), [0x80000001, OBJECT_INVALID, OBJECT_INVALID, OBJECT_INVALID]);
});

test('vectors occupy three float cells and native/script coordinates are separate from rendering', async () => {
  const vm = new NwScriptVm({ api: [], command: () => null });
  const result = await vm.run(program([[4,4,1],[4,4,2],[4,4,3],[4,4,4],[4,4,5],[4,4,6],[0x14,0x3a],[4,4,2],[0x16,0x3b],[0x20]]));
  assert.deepEqual(result.stack, [10,14,18].map(value => ({type:4,value})));
  const session = new ModuleSession(null), actor = session.register('player','player',{position:[2,1,-3],bearing:0,areaId:7});
  assert.deepEqual(session.commands.GetPosition([actor.id]),[2,3,1]);
  assert.deepEqual(session.commands.GetLocation([actor.id]),{areaId:7,position:[2,3,1],orientation:90});
});

test('native SAVEBP excludes its saved-BP cell and global copies do not address that cell', async () => {
  const vm = new NwScriptVm({ api: [], command: () => null });
  const result = await vm.run(program([[4, 3, 41], [0x2a], [0x27, 1, -4, 4], [4, 3, 1], [0x14, 0x20], [0x26, 1, -4, 4], [0x1b, 0, -4], [0x2b], [0x20]]));
  assert.equal(result.bp, 0); assert.deepEqual(result.stack, [{ type: 3, value: 42 }]);
});

test('subroutine returns and DESTRUCT preserve the selected interior cells', async () => {
  const vm = new NwScriptVm({ api: [], command: () => null });
  const result = await vm.run(program([[0x1e, 0, 'sub'], [0x20], 'sub', [4, 3, 10], [4, 3, 20], [4, 3, 30], [0x21, 1, 12, 4, 4], [0x20]]));
  assert.deepEqual(result.stack, [{ type: 3, value: 20 }]);
});

test('STORE_STATE captures AFTER normal argument pops, copies locals and changes self at dispatch', async () => {
  const captured = [], observed = [];
  const vm = new NwScriptVm({ api, command: name => ({
    AssignCommand: ([subject, situation]) => captured.push({ subject, situation }),
    SetLocalInt: args => observed.push(args)
  })[name] });
  // The compiler's closure follows STORE_STATE + JMP, not an action stack cell.
  const p = program([[4, 3, 7], [0x2c, 16, 0, 4], [0x1d, 0, 'after'],
    'closure', [3, 1, -4, 4], [4, 5, 'value'], [4, 6, 0], [5, 0, 1, 3], [0x20],
    'after', [4, 6, 0], [5, 0, 0, 2], [0x24, 3, -4], [0x1b, 0, -4], [0x20]]);
  await vm.run(p, 10);
  assert.equal(observed.length, 0); assert.equal(captured[0].subject, 10);
  assert.equal(captured[0].situation.stack[0].value, 7);
  await vm.run(p, 99, { situation: captured[0].situation });
  assert.deepEqual(observed, [[99, 'value', 7]]);
});

test('unsupported engine calls fail with script/PC and do not report fabricated success', async () => {
  const vm = new NwScriptVm({ api, command: () => null });
  await assert.rejects(vm.run(program([[4, 6, 0], [5, 0, 0, 2], [0x20]])), error => error instanceof ScriptError && error.script === 'fixture' && error.pc === 19 && /AssignCommand/.test(error.message));
});

test('malformed stack types, runaway scripts and recursive subroutines are bounded', async () => {
  const vm = new NwScriptVm({ api: [], command: () => null, instructionLimit: 500 });
  await assert.rejects(vm.run(program([[4, 5, 'x'], [0x22, 3], [0x20]])), /type mismatch/);
  await assert.rejects(vm.run(program(['loop', [0x1d, 0, 'loop']])), /budget/);
  await assert.rejects(vm.run(program(['recurse', [0x1e, 0, 'recurse'], [0x20]])), /return stack/);
});

test('scheduler defers zero-delay events, preserves timestamp ties and drops deleted targets', async () => {
  const log = [], valid = new Set([0, 1]);
  const scheduler = new ScriptScheduler({ validTarget: id => valid.has(id), dispatch: e => { log.push(e.event); if(e.event==='first') scheduler.enqueue(0, 'nested'); } });
  scheduler.enqueue(0, 'later', 0.01); scheduler.enqueue(0, 'first'); scheduler.enqueue(0, 'second'); scheduler.enqueue(1, 'deleted');
  valid.delete(1); assert.deepEqual(log, []);
  await scheduler.pump(); assert.deepEqual(log, ['first', 'second', 'nested']);
  scheduler.advance(9); await scheduler.pump(); assert.equal(log.length, 3);
  scheduler.advance(1); await scheduler.pump(); assert.equal(log.at(-1), 'later');
});

test('module IDs survive area membership changes and local variables retain type and case', async () => {
  const session = new ModuleSession(null), a = session.register('area', 'a', { scripts: {} }), b = session.register('area', 'b', { scripts: {} });
  session.module = session.register('module', 'module', {}); session.ifo = {}; session.started = true;
  session.player = session.register('player', 'player', { position: [0,0,0], journal: new Map() });
  const id = session.player.id;
  session.commands.SetLocalInt([id, 'Flag', 3]); session.commands.SetLocalString([id, 'Flag', 'text']);
  session.areas.set('a', a); session.areas.set('b', b);
  await session.enterArea('a', [1,0,1]); await session.enterArea('b', [2,0,2]); await session.enterArea('a', [3,0,3]);
  assert.equal(session.registry.get(id), session.player); assert.equal(session.player.id, id);
  assert.equal(session.local(id, 'Flag', 'int'), 3); assert.equal(session.local(id, 'Flag', 'string'), 'text'); assert.equal(session.local(id, 'flag', 'int'), 0);
  assert.equal(session.player.areaId, a.id);
});

test('native module tag lookup is case-sensitive and transition preference is waypoint then door', () => {
  const s = new ModuleSession(null);
  const door = s.register('door', 'door', { tag: 'Destination', linkedTo: 'Destination', linkedToFlags: 1 });
  const waypoint = s.register('waypoint', 'waypoint', { tag: 'Destination' });
  assert.equal(s.byTag('destination').length, 0);
  assert.equal(s.transitionTarget(door), waypoint);
  const newer = s.register('waypoint', 'newer', { tag: 'Destination' });
  assert.equal(s.transitionTarget(door), waypoint, 'Resolved transition target stays cached');
  s.registry.delete(waypoint.id); assert.equal(s.transitionTarget(door), newer);
  s.registry.delete(newer.id); assert.equal(s.transitionTarget(door), door);
});

test('native local variable names share typed fields and default values delete only their field', () => {
  const t = new ScriptVariableTable();
  t.setInt('Flag', 2); t.setString('Flag', 'value'); t.setObject('Flag', 0);
  assert.equal(t.entries.size, 1); assert.equal(t.getObject('Flag'), 0);
  t.setInt('Flag', 0); assert.equal(t.getInt('Flag'), 0); assert.equal(t.getString('Flag'), 'value');
  t.deleteIndex('Flag', 'string'); assert.equal(t.entries.size, 1);
  t.setObject('Flag', OBJECT_INVALID); assert.equal(t.entries.size, 0);
  assert.equal(t.getInt('flag'), 0); assert.equal(t.getObject('missing'), OBJECT_INVALID);
});
