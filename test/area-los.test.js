import test from 'node:test';
import assert from 'node:assert/strict';
import { clearAreaLOS } from '../src/area_los.js';
import { clipAreaTileLOS } from '../src/tile_los.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

function fixture(overrides = {}) {
  const calls = [], area = { width: 3, height: 2 }, output = [99, 99, 99], hit = { id: 123 };
  const p = {
    tile: (_area, x, y) => { calls.push(['tile', x, y]); return { x, y, orientation: 0, mesh: {} }; },
    clipTile: clipAreaTileLOS,
    clearTile: (_tile, mask, from, to) => { calls.push(['clear', mask, from, to]); return 1; },
    object: id => { calls.push(['object', id]); return null; },
    detailed: (_area, ...args) => { calls.push(['detailed', ...args]); return 1; },
    door: () => null, ...overrides,
  };
  const run = (from = [2, 5, 1], to = [28, 5, 2], source = 4, target = 5, transparent = 0) => clearAreaLOS(area, from, to, output, hit, source, target, transparent, p);
  return { calls, area, output, hit, p, run };
}

test('area LOS traverses actual tiles, re-resolves after clipping, propagates native direction mask and full height range', async () => {
  const t = fixture(); assert.equal(await t.run(), 1);
  assert.deepEqual(t.calls.filter(c => c[0] === 'tile'), [['tile', 0, 0], ['tile', 0, 0], ['tile', 1, 0], ['tile', 1, 0], ['tile', 2, 0], ['tile', 2, 0]]);
  assert.deepEqual(t.calls.filter(c => c[0] === 'clear').map(c => c[1]), [21, 21, 21]);
  assert.deepEqual(t.output, [0, 0, 0]); assert.equal(t.hit.id, OBJECT_INVALID);
  const detailed = t.calls.at(-1);
  assert.deepEqual(detailed.slice(1, 8), [[2, 5], [28, 5], 1, 2, 0, OBJECT_INVALID, t.hit]);
  assert.deepEqual(detailed.slice(8), [1, null, 0]);
});

test('area LOS has distinct reverse/equal-axis masks and signed cvtt multiplication tile index', async () => {
  const t = fixture(); assert.equal(await t.run([28, 5, 2], [2, 5, 1]), 1);
  assert.ok(t.calls.filter(c => c[0] === 'clear').every(c => c[1] === 56));
  const inside = fixture(); assert.equal(await inside.run([-.1, 5, 1], [1, 5, 1]), 1);
  assert.equal(inside.calls[0][1], 0); // cvtt(-.1*.1) truncates toward0.
  assert.equal(inside.calls.find(c => c[0] === 'clear')[1], 49);
});

test('area LOS excludes only canonical door/placeable source and target in lookup order, preserving duplicates', async () => {
  const door = { id: 4, objectType: 10 }, t = fixture({ object: id => id === 4 ? door : { id, objectType: 5 } });
  assert.equal(await t.run([2, 5, 1], [3, 5, 1], 4, 4), 1);
  assert.deepEqual(t.calls.at(-1)[9], [door, door]);
  const placeable = { id: 5, objectType: 9 };
  t.p.object = id => id === 5 ? placeable : { id, objectType: 5 };
  assert.equal(await t.run([2, 5, 1], [3, 5, 1], 4, 5), 1);
  assert.deepEqual(t.calls.at(-1)[9], [placeable]);
});

test('tile blocker shortens detailed XY ray while retaining original height range and returns0 after clear object query', async () => {
  const t = fixture({ clearTile: (_tile, _mask, _from, _to, point) => { point.splice(0, 3, 6, 5, 1.5); return 0; } });
  assert.equal(await t.run(), 0); assert.deepEqual(t.output, [6, 5, 1.5]);
  assert.deepEqual(t.calls.at(-1).slice(1, 5), [[2, 5], [6, 5], 1, 2]);
  assert.equal(t.calls.filter(c => c[0] === 'tile').length, 2);
});

test('clip failure still checks objects to zero output; outside/missing tiles return immediately without object lookups', async () => {
  const fail = fixture({ clipTile: () => ({ status: 0 }) });
  assert.equal(await fail.run(), 0); assert.deepEqual(fail.calls.at(-1)[2], [0, 0]);
  const outside = fixture(); assert.equal(await outside.run([-11, 5, 1]), 0); assert.deepEqual(outside.calls, []);
  const missing = fixture({ tile: () => null, object: () => { throw new Error('Unexpected object lookup'); } });
  assert.equal(await missing.run(), 0);
});

test('static blocker retains invalid hit ID/zero point while door blocker computes door crossing plus native .3 offset', async () => {
  const t = fixture({ detailed: (_area, _from, _to, _low, _high, _radius, _ignored, hit) => { hit.id = 0xaabbccdd; return 0; },
    door: () => ({ nativePosition: [5, 5, 0], nativeOrientation: [1, 0, 0] }) });
  assert.equal(await t.run([2, 5, 0], [8, 5, 0]), 0);
  assert.deepEqual(t.output, [Math.fround(5 - Math.fround(.3)), 5, 1]);
  assert.equal(t.hit.id, 0xaabbccdd);
  t.p.detailed = () => 0;
  assert.equal(await t.run([2, 5, 0], [8, 5, 0]), 0); assert.deepEqual(t.output, [0, 0, 0]);
  assert.equal(t.hit.id, OBJECT_INVALID);
});

test('LOS preserves tile hit when blocking door center line misses; stalled traversal and lost second tile fail explicitly', async () => {
  const t = fixture({ clearTile: (_tile, _mask, _from, _to, point) => { point.splice(0, 3, 6, 5, 1); return 0; },
    detailed: (_area, _from, _to, _low, _high, _radius, _ignored, hit) => { hit.id = 10; return 0; },
    door: () => ({ nativePosition: [5, 8, 0], nativeOrientation: [1, 0, 0] }) });
  assert.equal(await t.run(), 0); assert.deepEqual(t.output, [6, 5, 1]);
  const stuck = fixture({ clipTile: () => ({ status: 1, entry: [2, 5, 1], exit: [3, 5, 1] }) });
  await assert.rejects(stuck.run(), /no progress/);
  let gets = 0;
  const lost = fixture({ tile: () => ++gets === 1 ? { x: 0, y: 0, orientation: 0, mesh: {} } : null });
  await assert.rejects(lost.run(), /disappeared/);
});
