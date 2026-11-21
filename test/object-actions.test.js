import test from 'node:test';
import assert from 'node:assert/strict';
import { ObjectActionList, createObjectActionState, addObjectAction, actionParameter, setActionParameter,
  computeAIState, computeAIStateOnAction, clearObjectActions, manageObjectActions, runObjectActions } from '../src/object_actions.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

const actor = () => ({ objectType: 5, commandable: 1, objectActionState: createObjectActionState(), animationState: 9, currentActionId: 7 });
const floatBits = value => { const raw = new DataView(new ArrayBuffer(4)); raw.setFloat32(0, value, true); return raw.getInt32(0, true); };

test('native object list retains identity/order when removed and reinserted, including middle links', () => {
  const list = new ObjectActionList(), a = {}, b = {}, c = {};
  list.insert(a); const middle = list.insert(b); list.insert(c);
  assert.equal(list.remove(middle), b); assert.deepEqual([...list], [a, c]);
  assert.equal(list.head.next.previous, list.head); assert.equal(list.tail.previous.next, list.tail);
  assert.equal(list.shift(), a); list.insert(a, true); assert.deepEqual([...list], [a, c]);
  list.shift(); list.shift(); assert.equal(list.count, 0); assert.equal(list.head, null); assert.equal(list.tail, null);
});

test('native action group allocation, reuse and ushort wrap preserve front ordering', () => {
  const state = createObjectActionState();
  const first = addObjectAction(state, 12), reused = addObjectAction(state, 17, 65534, [], true);
  assert.equal(first.groupId, 0); assert.equal(reused.groupId, 0); assert.equal(state.nextGroup, 1);
  const explicit = addObjectAction(state, 19, 45); assert.equal(explicit.groupId, 45); assert.equal(state.lastGroup, 0);
  state.nextGroup = 65534;
  assert.equal(addObjectAction(state, 5).groupId, 65534); assert.equal(state.nextGroup, 0);
  assert.equal(addObjectAction(state, 1).groupId, 0); assert.equal(state.nextGroup, 1);
  assert.equal(state.list.head.action, reused); assert.equal(state.list.count, 5);
});

test('action parameters preserve raw float/object bits, copy string bytes, own situations and stop at type zero', () => {
  const state = createObjectActionState(), bytes = Uint8Array.of(0x61, 0, 0xff), situation = { pc: 23 };
  const node = addObjectAction(state, 12, 65535, [{ type: 3, value: 0x80000001 }, { type: 2, value: floatBits(-0) },
    { type: 4, value: bytes }, { type: 5, value: situation }, { type: 6, value: 257 }, { type: 0 }, { type: 1, value: 5 }]);
  bytes[0] = 0;
  assert.equal(node.parameterCount, 5); assert.equal(node.parameterData[0], -2147483647);
  assert.equal(actionParameter(node, 0), 0x80000001); assert.ok(Object.is(actionParameter(node, 1), -0));
  assert.deepEqual(actionParameter(node, 2), Uint8Array.of(0x61, 0, 0xff)); assert.equal(actionParameter(node, 3), situation);
  assert.equal(actionParameter(node, 4), 1); assert.equal(node.parameterTypes[6], 0); assert.equal(node.nativeField9c, 1);
  setActionParameter(node, 12, 3, 9); assert.equal(node.parameterCount, 13); assert.equal(node.parameterTypes.length, 12);
});

test('AI summary scans queued records before executing action; first priority wins without changing gameplay animation/action', () => {
  const a = actor(), s = a.objectActionState;
  addObjectAction(s, 1); addObjectAction(s, 12, 65535, [{ type: 3, value: 0 }]);
  s.executingId = 12; s.executingTargetId = 42; computeAIState(a);
  assert.equal(a.creatureAnimation, 2); assert.equal(a.currentAITargetId, 0);
  addObjectAction(s, 7); addObjectAction(s, 15); s.executingId = 8;
  computeAIState(a); assert.equal(a.creatureAnimation, 10); assert.equal(a.currentAITargetId, OBJECT_INVALID);
  assert.equal(a.animationState, 9); assert.equal(a.currentActionId, 7);
  for (const [id, expected] of [[8, 12], [11, 13], [15, 14], [46, 14], [20, 15], [21, 16], [25, 17], [26, 18],
    [27, 19], [28, 20], [29, 21], [34, 22], [35, 23], [38, 24], [39, 25], [40, 26], [41, 27],
    [42, 28], [54, 29], [56, 30], [57, 31], [59, 32]]) {
    a.creatureAnimation = 0; computeAIStateOnAction(a, id); assert.equal(a.creatureAnimation, expected);
  }
  a.creatureAnimation = 0; computeAIStateOnAction(a, 51); assert.equal(a.creatureAnimation, 1);
  computeAIStateOnAction(a, 50); assert.equal(a.creatureAnimation, 2); assert.equal(a.currentAITargetId, OBJECT_INVALID);
  a.creatureAnimation = 0; computeAIStateOnAction(a, 65535); assert.equal(a.creatureAnimation, 0);
});

test('clear actions respects commandable==1, cancellation refusal, changing head identity and situation disposal', async () => {
  const a = actor(), s = a.objectActionState, trace = [], situation = {};
  const first = addObjectAction(s, 7, 1, [{ type: 5, value: situation }]);
  const refused = addObjectAction(s, 12, 2), last = addObjectAction(s, 5, 3);
  const providers = { clearAction: (actor, node, head) => { trace.push([node.actionId, head]); return node === refused ? 0 : 1; },
    resetPath: () => trace.push('path'), deleteSituation: value => { assert.equal(value, situation); trace.push('delete'); } };
  a.commandable = 2; await clearObjectActions(a, providers); assert.equal(s.list.count, 3); assert.deepEqual(trace, []);
  a.commandable = true; await clearObjectActions(a, providers);
  assert.deepEqual([...s.list], [refused]); assert.deepEqual(trace, [[7, true], 'delete', [12, true], [5, false], 'path']);
  assert.equal(first.parameterData[0], 0); assert.equal(last.parameterCount, 0);
});

test('action manager uses actual client lookup and native request masks, preserving queued priority actions for movement', async () => {
  const a = actor(), trace = [];
  const providers = { hasClient: () => false, clearActions: () => trace.push('clear') };
  await manageObjectActions(a, 4, providers); assert.deepEqual(trace, []);
  providers.hasClient = () => true;
  for (const request of [1, 2, 3, 4, 5, 8, 9]) await manageObjectActions(a, request, providers);
  assert.equal(trace.length, 4); // 1,2,4,8
  addObjectAction(a.objectActionState, 15);
  await manageObjectActions(a, 1, providers); assert.equal(trace.length, 4);
  await manageObjectActions(a, 8, providers); assert.equal(trace.length, 5);
});

function lifecycle(trace, dispatch, elapsed = 0n) {
  return { dispatch, microseconds: () => elapsed, completed: (a, node) => trace.push(['completed', node.actionId]),
    lastAction: (a, id) => trace.push(['last', id]), overflow: () => trace.push('overflow') };
}

test('RunActions exposes executing attack target/node, restores sentinel, and puts pending record before inserted actions', async () => {
  const a = actor(), s = a.objectActionState, trace = [];
  const node = addObjectAction(s, 12, 65535, [{ type: 3, value: 0x80000001 }]);
  const providers = lifecycle(trace, async (a, current) => {
    assert.equal(current, node); assert.equal(s.executingId, 12); assert.equal(s.executingNode, node);
    assert.equal(s.executingTargetId, 0x80000001); computeAIState(a); assert.equal(a.currentAITargetId, 0x80000001);
    addObjectAction(s, 19, node.groupId, [], true); return 1;
  });
  await runObjectActions(a, 3, 100, 0n, providers);
  assert.equal(s.list.head.action, node); assert.equal(s.list.count, 2); assert.equal(s.executingId, 65535);
  assert.equal(s.executingTargetId, OBJECT_INVALID); assert.equal(s.executingNode, null);
  assert.equal(s.startDay, 3); assert.equal(s.startTime, 100); assert.equal(s.lastRunDay, 3); assert.equal(s.lastRunTime, 100);
  assert.deepEqual(trace, [['last', 12], 'overflow']);
});

test('RunActions completes consecutive actions at 1000 microseconds but stops strictly after budget or movement actions', async () => {
  for (const [firstId, elapsed, remaining] of [[19, 1000n, 0], [19, 1001n, 1], [1, 0n, 1], [5, 0n, 1], [48, 0n, 1], [51, 0n, 1]]) {
    const a = actor(), trace = [], s = a.objectActionState; addObjectAction(s, firstId); addObjectAction(s, 19);
    await runObjectActions(a, 3, 100, 0n, lifecycle(trace, () => 2, elapsed));
    assert.equal(s.list.count, remaining); assert.equal(s.startDay, 0); assert.equal(s.startTime, 0);
  }
  const a = actor(), s = a.objectActionState, trace = [];
  addObjectAction(s, 12); a.attackActionTargetId = 10; a.nativeAttackTarget724 = 20; a.attackTargetId = 30;
  await runObjectActions(a, 0, 0, 0n, lifecycle(trace, () => 3));
  assert.equal(a.attackActionTargetId, OBJECT_INVALID); assert.equal(a.nativeAttackTarget724, OBJECT_INVALID);
  assert.equal(a.attackTargetId, 30);
});

test('unsupported action preflight retains exact queued record and execution failures restore it without fake completion', async () => {
  const a = actor(), s = a.objectActionState, trace = [], node = addObjectAction(s, 12);
  const providers = lifecycle(trace, () => { throw new Error('Strike provider unavailable'); });
  providers.preflight = () => { throw new Error('Perception provider unavailable'); };
  await assert.rejects(runObjectActions(a, 3, 100, 0n, providers), /Perception/);
  assert.equal(s.list.head.action, node); assert.equal(s.startTime, 0); assert.deepEqual(trace, []);
  delete providers.preflight;
  await assert.rejects(runObjectActions(a, 3, 100, 0n, providers), /Strike/);
  assert.equal(s.list.head.action, node); assert.equal(s.executingId, 65535); assert.equal(s.executingTargetId, OBJECT_INVALID);
  assert.equal(s.running, false); assert.deepEqual(trace, [['last', 12]]);
  // AddActionNodeParameter writes its count before rejecting index 12.
  // Preserve the record and report the unsupported malformed count rather
  // than reading outside the native allocation or silently clamping it.
  setActionParameter(node, 12, 3, 9);
  providers.dispatch = () => assert.fail('Malformed action must not run');
  await assert.rejects(runObjectActions(a, 3, 100, 0n, providers), /parameter count/);
  assert.equal(s.list.head.action, node); assert.equal(s.running, false);
});
