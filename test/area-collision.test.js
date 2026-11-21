import test from 'node:test';
import assert from 'node:assert/strict';
import { NativeAreaCollisionStore } from '../src/area_collision_store.js';
import { intersectAreaSegments, isCollisionObjectExcluded, noNonWalkPolysDetailed, noNonWalkPolysInDoors, queryDoorPolygons, handleTransparentDoor } from '../src/area_collision.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

function add(store, id, vertices) { return store.add(id, [0, 1, 0], [0, 0, 0], vertices, [[0, 1, 2]]); }
const query = (store, from = [0, 0], to = [4, 0], low = 0, high = 1, radius = 0, providers = {}, excluded = null, output = { id: 123 }) =>
  noNonWalkPolysDetailed(store, from, to, low, high, radius, OBJECT_INVALID, output, 1, excluded, 0, providers);
const wall = [[2, -2, 0], [2, 2, 0], [2, 2, 2]];
test('native area segment intersection keeps inclusive contacts and rejects collinear segments', () => {
  assert.deepEqual(intersectAreaSegments([0, 0], [4, 0], [2, -1], [2, 1]), [2, 0]);
  assert.deepEqual(intersectAreaSegments([2, -1], [2, 1], [0, 0], [4, 0]), [2, 0]);
  assert.deepEqual(intersectAreaSegments([0, 0], [2, 2], [2, 2], [4, 0]), [2, 2]);
  assert.equal(intersectAreaSegments([0, 0], [4, 0], [1, 0], [2, 0]), null);
  assert.equal(intersectAreaSegments([0, 0], [1, 0], [2, -1], [2, 1]), null);
});
test('static polygons block crossed walls and retain the supplied output ID', () => {
  const store = new NativeAreaCollisionStore(); add(store, 0x80000002, wall);
  const output = { id: 123 };
  assert.equal(query(store, [0, 0], [4, 0], 0, 1, 0, {}, null, output), 0);
  assert.equal(output.id, 123);
  assert.equal(query(store, [0, 3], [4, 3]), 1);
  assert.equal(query(store, [0, 0], [4, 0], 2.001, 3), 1);
  assert.equal(query(store, [0, 0], [4, 0], 2, 3), 0);
});
test('native static collision detects vertices and enclosing CCW triangles', () => {
  const store = new NativeAreaCollisionStore();
  add(store, 1, [[1, -.01, 0], [2, -.01, 0], [1, .01, 0]]);
  assert.equal(query(store, [0, 0], [4, 0], 0, 1, .1), 0);
  store.remove(0);
  add(store, 2, [[-10, -10, 0], [20, -10, 0], [0, 20, 0]]);
  assert.equal(query(store, [0, 0], [4, 0], 0, 1, .1), 0);
});
test('static swept collision checks all quadrants and clears geometry behind the start', () => {
  for (const [from, to] of [[[0, 0], [4, 4]], [[4, 4], [0, 0]], [[0, 4], [4, 0]], [[4, 0], [0, 4]]]) {
    const store = new NativeAreaCollisionStore(); add(store, 1, wall);
    assert.equal(query(store, from, to, 0, 1, .1), 0);
  }
  const store = new NativeAreaCollisionStore(); add(store, 1, [[-1, -1, 0], [-1, 1, 0], [-1, 1, 1]]);
  assert.equal(query(store), 1);
});
test('native detailed collision clamps radius through .65 and skips zero-length/reversed-height queries', () => {
  const store = new NativeAreaCollisionStore(); add(store, 1, [[2, .2, 0], [3, .2, 0], [2, .3, 0]]);
  assert.equal(query(store, [0, 0], [4, 0], 0, 1, .65), 1);
  assert.equal(query(store, [0, 0], [4, 0], 0, 1, .650001), 0);
  assert.equal(query(store, [2, .25], [2, .25]), 1);
  assert.equal(query(store, [0, 0], [4, 0], 1, 0, 1), 1);
});
test('exclusions are canonical objects and stop being queried after native remaining-count depletion', () => {
  const store = new NativeAreaCollisionStore(); add(store, 1, wall); add(store, 1, wall);
  const object = { id: 1 }, excluded = [object], calls = [];
  assert.equal(isCollisionObjectExcluded(1, excluded), 1);
  assert.equal(isCollisionObjectExcluded(2, excluded), 0);
  const providers = { isExcluded: (id, list) => { calls.push(id); return isCollisionObjectExcluded(id, list); } };
  assert.equal(query(store, undefined, undefined, undefined, undefined, undefined, providers, excluded), 0);
  assert.deepEqual(calls, [1]);
  object.id = 2;
  assert.equal(isCollisionObjectExcluded(1, excluded), 0);
  assert.throws(() => isCollisionObjectExcluded(1, [1]), /object is unavailable/);
});
test('removing static objects changes collision immediately without losing other canonical slots', () => {
  const store = new NativeAreaCollisionStore(); add(store, 1, wall); add(store, 2, [[2, 10, 0], [2, 11, 0], [2, 11, 1]]);
  assert.equal(query(store), 0); store.remove(0); assert.equal(query(store), 1);
  store.replace(1, 2, [0, 1, 0], [0, -10, 0], [[2, 10, 0], [2, 11, 0], [2, 11, 1]], [[0, 1, 2]]);
  assert.equal(query(store, [0, .5], [4, .5]), 0);
});
test('door collision retains ordered bounds, output ID and live exclusion/query dispatch', () => {
  const store = new NativeAreaCollisionStore();
  store.addDoorBounds(0x80000001, [2, -1, 0], [3, 1, 2]); store.addDoorBounds(2, [2, -1, 0], [3, 1, 2]);
  const calls = [], output = { id: 123 };
  const providers = { isExcluded: (id, excluded) => { calls.push(['exclude', id, excluded]); return 0; },
    doorPolygons: id => { calls.push(['door', id]); return id === 2 ? 0 : 1; } };
  assert.equal(query(store, undefined, undefined, undefined, undefined, .2, providers, null, output), 0);
  assert.equal(output.id, 2);
  assert.deepEqual(calls, [['exclude', 0x80000001, null], ['door', 0x80000001], ['exclude', 2, null], ['door', 2]]);
  assert.throws(() => query(store), /doorPolygons is unavailable/);
});
test('door polygon dispatch preserves native closed-door ignore rules', () => {
  const door = { id: 1, objectType: 10 }, calls = [], providers = { object: () => door, doorOpenState: () => 0,
    doorSurface: (...args) => { calls.push(args); return 0; } };
  const run = (ignoredId, flag) => queryDoorPolygons(1, [0, 0], [4, 0], 0, 1, .1, ignoredId, flag, providers);
  assert.equal(run(2, 0), 1); assert.equal(calls.length, 0);
  assert.equal(run(1, 0), 0); assert.equal(run(2, 1), 0); assert.equal(calls.length, 2);
  providers.object = () => null; assert.equal(run(2, 1), 0);
});
test('transparent doors consult active data, append real objects and retry with transparency flag0', () => {
  const store = new NativeAreaCollisionStore(); store.addDoorBounds(1, [2, -1, 0], [3, 1, 1]);
  const door = { id: 1, objectType: 10 }, output = { id: OBJECT_INVALID }, excluded = [], calls = [];
  const providers = { object: () => door, doorPolygons: () => 0,
    doorBlockSight: value => { assert.equal(value, door); calls.push('BlockSight'); return 0; } };
  providers.transparentDoor = (...args) => handleTransparentDoor(...args, providers);
  const run = () => noNonWalkPolysDetailed(store, [0, 0], [4, 0], 0, 1, .1, OBJECT_INVALID, output, 1, excluded, 1, providers);
  assert.equal(run(), 1); assert.deepEqual(excluded, [door]); assert.deepEqual(calls, ['BlockSight']);
  excluded.length = 0; providers.doorBlockSight = () => 1; assert.equal(run(), 0); assert.equal(excluded.length, 0);
  excluded.length = 0; providers.doorBlockSight = () => 0;
  const second = { id: 2, objectType: 10 }; store.addDoorBounds(2, [3, -1, 0], [4, 1, 1]);
  providers.object = id => id === 1 ? door : second;
  assert.equal(run(), 0); assert.equal(output.id, 2); assert.deepEqual(excluded, [door]);
});
test('direct door query preserves reversed-height OR bounds and exact transparency flag1', () => {
  const store = new NativeAreaCollisionStore(); store.addDoorBounds(1, [1, 0, .5], [2, 1, .6]);
  const output = { id: 0 }, providers = { doorPolygons: () => 0, transparentDoor: () => 9 };
  assert.equal(noNonWalkPolysInDoors(store, [0, .5], [4, .5], 1, 0, 0, 0, output, 1, null, 2, providers), 0);
  assert.equal(noNonWalkPolysInDoors(store, [0, .5], [4, .5], 1, 0, 0, 0, output, 1, null, 1, providers), 9);
});
