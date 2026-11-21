import test from 'node:test';
import assert from 'node:assert/strict';
import { NativeAreaSpatialArray, setObjectPosition } from '../src/area_spatial.js';
import { areaObjectsByX, areaSpatialIds, firstAreaSpatialIndex } from '../src/nearest_objects.js';
import { ModuleSession } from '../src/module_session.js';

function fixture() {
  const registry = new Map(), warnings = [], array = new NativeAreaSpatialArray(registry, message => warnings.push(message));
  const add = (id, x) => { const object = { id, position: [x, 0, 0] }; registry.set(id, object); array.insert(id); return object; };
  return { registry, warnings, array, add };
}

test('native spatial array inserts full uint32 IDs at equal-X front and retains native capacity/unused tail', () => {
  const t = fixture(); t.add(0xffffffff, 4); t.add(0x80000001, 4); t.add(5, 2);
  assert.deepEqual([...t.array.view()], [5, 0x80000001, 0xffffffff]);
  assert.equal(t.array.capacity, 16); t.array.remove(0x80000001);
  assert.deepEqual([...t.array.view()], [5, 0xffffffff]); assert.equal(t.array.ids[2], 0xffffffff);
  assert.equal(t.array.capacity, 16); t.array.remove(999); assert.equal(t.array.count, 2);
  for (let id = 100; id < 115; id++) t.add(id, id);
  assert.equal(t.array.count, 17); assert.equal(t.array.capacity, 32);
  t.array.insert(5); assert.equal(t.array.count, 17);
  assert.equal(t.array.insert(42), 0); assert.throws(() => t.array.insert(-1), /invalid/);
});

test('native first-X query implements last-index boundary and binary lookup order, and reports stale IDs', () => {
  const t = fixture(); assert.equal(t.array.firstByX(0), null);
  for (let id = 1; id <= 4; id++) t.add(id, id);
  for (const [x, index] of [[0, 0], [1, 0], [2, 1], [2.5, 2], [4, 3], [5, null]]) assert.equal(t.array.firstByX(x), index);
  const visits = [], get = t.registry.get.bind(t.registry);
  t.registry.get = id => { visits.push(id); return get(id); };
  assert.equal(t.array.firstByX(4), 3); assert.deepEqual(visits, [2, 3, 4]);
  t.registry.delete(2); assert.equal(t.array.firstByX(0), null); assert.equal(t.warnings.length, 1);
});

test('native position ordering swaps neighbors only across strict X comparisons, retaining moved equal-X order', () => {
  const t = fixture(), a = t.add(1, 1), b = t.add(2, 2), c = t.add(3, 3), d = t.add(4, 4);
  a.position[0] = 3; assert.equal(t.array.update(a), 1);
  assert.deepEqual([...t.array.view()], [2, 1, 3, 4]);
  d.position[0] = 2; t.array.update(d); assert.deepEqual([...t.array.view()], [2, 4, 1, 3]);
  b.position[0] = 6; t.array.update(b); assert.deepEqual([...t.array.view()], [4, 1, 3, 2]);
  c.position[0] = -1; t.array.update(c); assert.deepEqual([...t.array.view()], [3, 4, 1, 2]);
  assert.throws(() => t.array.update({ id: 999, position: [0, 0, 0] }), /absent/);
});

test('native array update stops at an unresolved neighbor and does not globally re-sort', () => {
  const t = fixture(), a = t.add(1, 1); t.add(2, 2); t.add(3, 3);
  t.registry.delete(2); a.position[0] = 5;
  assert.equal(t.array.update(a), 1); assert.deepEqual([...t.array.view()], [1, 2, 3]);
});

test('native SetPosition has exact flag1 bypass, same-value early return and get-area-before-write ordering', () => {
  const object = { id: 1, position: [1, 0, 3] }, alias = object.position, calls = [];
  const area = {};
  const p = { area: actor => { calls.push(['area', [...actor.position]]); return area; },
    update: (value, actor) => { assert.equal(value, area); calls.push(['update', [...actor.position]]); } };
  setObjectPosition(object, [1, -0, 3], 0, p); assert.deepEqual(calls, []); assert.equal(Object.is(object.position[1], -0), false);
  setObjectPosition(object, [4, 5, 6], 0, p); assert.equal(object.position, alias);
  assert.deepEqual(calls, [['area', [1, 0, 3]], ['update', [4, 5, 6]]]); assert.deepEqual(object.nativePosition, [4, -6, 5]);
  calls.length = 0; setObjectPosition(object, [7, 8, 9], 1, {}); assert.deepEqual(calls, []);
  setObjectPosition(object, [1, 2, 3], 2, p); assert.equal(calls.length, 2);
  assert.throws(() => setObjectPosition(object, [NaN, 0, 0], 0, p), /arguments/);
});

test('canonical combat/nearest spatial providers consume retained array and live native search', () => {
  const t = fixture(), a = t.add(1, 1); t.add(2, 2); t.add(3, 3);
  const area = { nativeSpatial: t.array, objects: [999] }, session = { registry: t.registry };
  a.position[0] = 3; t.array.update(a);
  assert.deepEqual(areaObjectsByX(session, area).map(o => o.id), [2, 1, 3]);
  assert.deepEqual([...areaSpatialIds(session, area)], [2, 1, 3]); assert.equal(firstAreaSpatialIndex(session, area, 3), 1);
});

test('live session SetPosition preserves canonical shared vector and persists unavailable spatial updates', () => {
  const s = new ModuleSession({}), area = s.register('area', 'area', { objects: [] }), actor = s.register('player', 'player', { areaId: area.id, position: [1, 0, 0] });
  area.nativeSpatial = new NativeAreaSpatialArray(s.registry); area.nativeSpatial.insert(actor.id);
  s.setPosition(actor, [3, 0, -5], 0); assert.deepEqual(actor.position, [3, 0, -5]); assert.equal(area.nativeSpatial.firstByX(3), 0);
  area.nativeSpatial.remove(actor.id);
  assert.throws(() => s.setPosition(actor, [4, 0, -5], 0), /absent/); assert.ok(s.diagnostics.some(message => message.includes('absent')));
});
