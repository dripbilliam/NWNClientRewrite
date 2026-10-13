import test from 'node:test';
import assert from 'node:assert/strict';
import { NativeAreaCollisionStore } from '../src/area_collision_store.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

const triangle = [[0, 0, 0], [1, 0, 1], [0, 1, 2]];
const add = (store, id, vertices = triangle, faces = [[0, 1, 2]]) => store.add(id, [0, 1, 0], [0, 0, 0], vertices, faces);
test('collision storage retains full canonical IDs and native transform/bounds', () => {
  const store = new NativeAreaCollisionStore();
  const slot = store.add(0x80000002, [1, 0, 999], [10, 20, 30], triangle, [[0, 1, 2]]);
  assert.equal(slot, 0); assert.equal(store.objectIds[slot], 0x80000002);
  assert.deepEqual(Array.from(store.vertices.subarray(0, 9)), [10, 20, 30, 10, 19, 31, 11, 20, 32]);
  assert.deepEqual(store.getBounds(slot), [[10, 19, 30], [11, 20, 32]]);
  assert.equal(store.objectCapacity, 16); assert.equal(store.vertexCapacity, 16); assert.equal(store.indexCapacity, 48);
});
test('native vertex capacity grows against previous capacity, and slots grow on equality', () => {
  const store = new NativeAreaCollisionStore();
  add(store, 1, Array.from({ length: 15 }, () => [0, 0, 0]), []);
  add(store, 2, [[0, 0, 0]], []);
  assert.equal(store.vertexCapacity, 32);
  const ids = store.objectIds;
  for (let i = 2; i < 15; i++) add(store, i + 1, [], []);
  assert.equal(store.objectCapacity, 16); assert.equal(store.objectIds, ids);
  add(store, 16, [], []);
  assert.equal(store.objectCapacity, 32); assert.equal(store.objectCount, 16);
  const faces = new NativeAreaCollisionStore();
  add(faces, 1, triangle, Array.from({ length: 16 }, () => [0, 1, 2]));
  assert.equal(faces.indexCapacity, 96);
});
test('removal compacts global geometry, rebases indices and retains slot holes', () => {
  const store = new NativeAreaCollisionStore();
  add(store, 1); add(store, 2); add(store, 3);
  store.remove(1);
  assert.equal(store.objectCount, 3); assert.equal(store.vertexCount, 6); assert.equal(store.faceCount, 2);
  assert.deepEqual(Array.from(store.indices.subarray(0, 6)), [0, 1, 2, 3, 4, 5]);
  assert.equal(store.objectIds[1], OBJECT_INVALID);
  assert.deepEqual(Array.from(store.vertexStarts.subarray(0, 3)), [0, 0, 3]);
  assert.deepEqual(Array.from(store.faceStarts.subarray(0, 3)), [0, 0, 1]);
  assert.deepEqual(store.getBounds(1), [[1000000, 1000000, 1000000], [-1000000, -1000000, -1000000]]);
  assert.equal(add(store, 4), 1);
  assert.equal(store.vertexStarts[1], 6); assert.equal(store.faceStarts[1], 2);
  store.remove(2); store.remove(0);
  assert.equal(add(store, 5), 2); assert.equal(add(store, 6), 0);
});
test('duplicate IDs are allowed and replacement requires matching ID and geometry sizes', () => {
  const store = new NativeAreaCollisionStore(); add(store, 1); add(store, 1);
  const before = Array.from(store.vertices);
  store.replace(0, 2, [0, 1, 0], [5, 5, 5], triangle, [[0, 1, 2]]);
  store.replace(0, 1, [0, 1, 0], [5, 5, 5], [], []);
  assert.deepEqual(Array.from(store.vertices), before);
  store.replace(1, 1, [0, 1, 0], [5, 5, 5], triangle, [[2, 1, 0]]);
  assert.deepEqual(store.getBounds(1), [[5, 5, 5], [6, 6, 7]]);
  assert.deepEqual(Array.from(store.indices.subarray(3, 6)), [5, 4, 3]);
  assert.equal(store.vertexCount, 6); assert.equal(store.objectCount, 2);
});
test('empty geometry retains native inverted bounds and invalid-memory operations fail explicitly', () => {
  const store = new NativeAreaCollisionStore(); add(store, 1, [], []);
  assert.deepEqual(store.getBounds(0), [[1000000, 1000000, 1000000], [-1000000, -1000000, -1000000]]);
  store.remove(-1); store.remove(100); store.replace(-1); store.replace(100);
  assert.throws(() => store.remove(-2), /invalid memory/);
  assert.throws(() => store.getBounds(1), /invalid memory/);
  assert.throws(() => add(store, 2, triangle, [[0, 1, 3]]), /invalid/);
  assert.equal(store.objectCount, 1);
});
test('door bounds preserve insertion order, grow 8 then 16 and delete only first duplicate', () => {
  const store = new NativeAreaCollisionStore();
  for (let i = 0; i < 9; i++) assert.equal(store.addDoorBounds(i % 2, [i, 0, 0], [i + 1, 1, 1]), 0);
  assert.equal(store.doorCapacity, 16); assert.equal(store.doorCount, 9);
  assert.equal(store.removeDoorBounds(0), 1);
  assert.deepEqual(Array.from(store.doorIds.subarray(0, 8)), [1, 0, 1, 0, 1, 0, 1, 0]);
  assert.deepEqual(Array.from(store.doorBounds.subarray(0, 6)), [1, 0, 0, 2, 1, 1]);
  assert.equal(store.removeDoorBounds(999), 0); assert.equal(store.doorCount, 8);
});
