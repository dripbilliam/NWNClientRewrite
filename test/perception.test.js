import test from 'node:test';
import assert from 'node:assert/strict';
import { VisibilityList, requestVisibilityAllowsAttack, targetVisibilityAllowsAttack, reactionFromReputation } from '../src/perception.js';

test('native visibility list packs low five bits, preserves first duplicate and uses 16/doubling capacity', () => {
  const list = new VisibilityList(0);
  list.add(0x80000001, 3, 2, 7, 3); assert.equal(list.get(0x80000001), 29); assert.equal(list.capacity, 16);
  list.add(0x80000001, 0, 0, 0, 0); assert.equal(list.get(0x80000001), 29);
  for (let id = 0; id < 16; id++) list.add(id, 1, 1, 0, 0);
  assert.equal(list.capacity, 32); assert.equal(list.nodes.length, 17); assert.equal(list.node(17), null);
  list.set(0, 0xff); assert.equal(list.get(0), 255);
  assert.throws(() => list.get(undefined), /object ID/);
  assert.throws(() => list.add(NaN, 1, 1, 0, 0), /object ID/);
  assert.throws(() => list.remove(undefined), /object ID/);
  assert.throws(() => new VisibilityList(undefined), /object ID/);
});

test('clear visibility retains first self and raw flags; self removal warns but removes, shifting other nodes', () => {
  const warnings = [], list = new VisibilityList(0, message => warnings.push(message));
  list.set(4, 3).set(0, 0xb3).set(5, 1); list.clear();
  assert.deepEqual(list.nodes, [{ id: 0, flags: 0xb3 }]); assert.equal(list.capacity, 1);
  list.add(6, 0, 1, 0, 0); assert.equal(list.capacity, 2);
  list.remove(0); assert.deepEqual(list.nodes, [{ id: 6, flags: 2 }]); assert.equal(warnings.length, 1);
  list.clear(); assert.equal(list.capacity, 0); assert.equal(list.nodes.length, 0);
});

test('request and strike visibility gates differ for missing nodes and retained-but-unperceived targets', () => {
  const pc = { isPC: true }, npc = {}, familiar = { isPossessedFamiliar: true }, dm = { isPC: true, isDM: true };
  assert.equal(requestVisibilityAllowsAttack(null), true);
  for (const flags of [4, 5, 6, 7, 0x14]) assert.equal(requestVisibilityAllowsAttack(flags), false);
  for (const flags of [0, 3, 8, 12, 16, 17, 18, 19]) assert.equal(requestVisibilityAllowsAttack(flags), true);
  assert.equal(targetVisibilityAllowsAttack(pc, true, null), false); assert.equal(targetVisibilityAllowsAttack(familiar, true, null), false);
  assert.equal(targetVisibilityAllowsAttack(npc, true, null), true); assert.equal(targetVisibilityAllowsAttack(dm, true, null), true);
  assert.equal(targetVisibilityAllowsAttack(pc, false, null), true); assert.equal(targetVisibilityAllowsAttack(pc, true, 16), false);
  for (const flags of [3, 17, 18, 19]) assert.equal(targetVisibilityAllowsAttack(pc, true, flags), true);
});

test('native AI reaction thresholds and PVP masks use supplied reputation and same-faction output', () => {
  for (const [reputation, result] of [[-1, 2], [10, 2], [11, 0], [89, 0], [90, 1], [101, 1]]) {
    assert.equal(reactionFromReputation(reputation, 1, 0, true, true), result);
    assert.equal(reactionFromReputation(reputation, 0, 0, true, true), result);
  }
  assert.equal(reactionFromReputation(90, 0, 1, true, true), 0);
  assert.equal(reactionFromReputation(90, 1, 1, true, true), 1);
  assert.equal(reactionFromReputation(90, 1, 258, true, true), 0);
  assert.equal(reactionFromReputation(10, 1, 2, true, true), 2);
  assert.equal(reactionFromReputation(90, 0, 2, false, true), 1);
  assert.equal(reactionFromReputation(90, 0, undefined, true, false), 1);
  assert.throws(() => reactionFromReputation(undefined, 0, 0, true, true), /unavailable/);
});
