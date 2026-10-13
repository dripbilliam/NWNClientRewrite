import test from 'node:test';
import assert from 'node:assert/strict';
import { NativeIdList } from '../src/native_id_list.js';
import { inSubareas, intersectSubareas, handleSubareaChanges, updateSubareasOnMove, intersectSubareaPolygon } from '../src/subareas.js';

const makeList = values => { const list = new NativeIdList(); values.forEach(id => list.append(id)); return list; };
function fixture(old = []) {
  const objects = new Map([[1, { id: 1, objectType: 7 }], [2, { id: 2, objectType: 11 }], [3, { id: 3, objectType: 13 }]]);
  const events = [], queries = [], actor = { id: 0x80000001, nativeSubareaMembership: makeList(old), nativeFollowingAOEs: makeList([]) };
  const area = { nativeSubareas: makeList([1, 2, 3, 1]) };
  const p = { object: id => { queries.push(['object', id]); return objects.get(id); },
    area: () => area, inTrigger: () => 1, inAOE: () => 0, inEncounter: () => 1,
    lineTrigger: () => 1, lineAOE: () => 1, lineEncounter: () => 0,
    dm: () => 0, event: (...args) => events.push(args), entryEvent: () => 30,
    aoe: id => objects.get(id), moveAOE: (object, point) => queries.push(['moveAOE', object.id, point]) };
  return { objects, events, queries, actor, area, p };
}

test('native uint32 list append doubles capacity, SetSize grows exactly, empty releases storage and removal leaves tail', () => {
  const list = makeList([0xffffffff, 0x80000001]); assert.equal(list.capacity, 16);
  list.setSize(1); assert.equal(list.capacity, 16); assert.equal(list.ids[1], 0x80000001);
  list.setSize(20); assert.equal(list.capacity, 20); assert.equal(list.count, 20);
  list.ids.fill(1, 1); list.append(2); assert.equal(list.capacity, 40);
  list.setSize(0); assert.equal(list.capacity, 0); assert.equal(list.ids.length, 0);
  list.copyFrom(makeList([3, 4])); assert.equal(list.capacity, 2); assert.deepEqual([...list.view()], [3, 4]);
  list.remove(3); assert.equal(list.ids[1], 4); assert.deepEqual([...list.view()], [4]);
});

test('native subarea point query tests ordered types and skips membership duplicates before canonical lookup', async () => {
  const t = fixture(), output = makeList([1]);
  assert.equal(await inSubareas(t.area, [0, 0, 0], output, t.p), 1);
  assert.deepEqual([...output.view()], [1, 3]); assert.deepEqual(t.queries, [['object', 2], ['object', 3]]);
  const many = makeList(Array.from({ length: 17 }, (_, i) => i + 100));
  await inSubareas(t.area, [0, 0, 0], many, t.p); assert.deepEqual([...many.view()].slice(17), [1, 3]);
});

test('native line query performs object lookup before duplicate suppression and preserves encounter order', async () => {
  const t = fixture(), output = makeList([1]);
  assert.equal(await intersectSubareas(t.area, [0, 0, 0], [1, 0, 0], output, t.p), 1);
  assert.deepEqual([...output.view()], [1, 2]); assert.deepEqual(t.queries, [['object', 1], ['object', 2], ['object', 3], ['object', 1]]);
});

test('native subarea state changes emit exits before entries and retain missing-new-ID changed flag', async () => {
  const t = fixture([1, 2]);
  assert.equal(await handleSubareaChanges(t.actor, makeList([2, 3]), null, 0, t.p), 1);
  assert.deepEqual(t.events.map(e => [e[0], e[2]]), [[13, 1], [12, 3]]);
  assert.deepEqual(t.events[0][3], { scriptEvent: 13, objectIds: [t.actor.id] });
  assert.equal(await handleSubareaChanges(t.actor, makeList([1, 2, 99]), null, 0, t.p), 1);
  t.p.dm = () => 1; t.events.length = 0;
  assert.equal(await handleSubareaChanges(t.actor, makeList([3]), makeList([1]), 0, t.p), 0); assert.deepEqual(t.events, []);
});

test('native crossing branch emits outside enter/exit and inside exit/enter without setting changed return', async () => {
  const t = fixture([1]);
  assert.equal(await handleSubareaChanges(t.actor, makeList([1]), makeList([1, 2]), 1, t.p), 0);
  assert.deepEqual(t.events.map(e => [e[0], e[2]]), [[13, 1], [30, 1], [12, 2], [13, 2]]);
  assert.deepEqual([...t.actor.nativeSubareaMembership.view()], [1]);
});

test('native movement gathers endpoint/following AOEs/crossed list then conditionally copies membership with exact capacity', async () => {
  const t = fixture([2]); t.actor.nativeFollowingAOEs = makeList([2]);
  assert.equal(await updateSubareasOnMove(t.actor, [0, 0, 0], [1, 0, 0], 0, null, 0, t.p), 1);
  assert.deepEqual([...t.actor.nativeSubareaMembership.view()], [1, 3, 2]);
  assert.deepEqual(t.queries.find(q => q[0] === 'moveAOE'), ['moveAOE', 2, [1, 0, 0]]);
  assert.deepEqual(t.events.map(e => [e[0], e[2]]), [[12, 1], [12, 3], [13, 2], [12, 2]]);
  const empty = fixture([1]); empty.p.inTrigger = empty.p.inAOE = empty.p.inEncounter = () => 0;
  empty.p.lineTrigger = empty.p.lineAOE = () => 0;
  assert.equal(await updateSubareasOnMove(empty.actor, [0, 0, 0], [1, 0, 0], 1, null, 0, empty.p), 1);
  assert.equal(empty.actor.nativeSubareaMembership.capacity, 0);
});

test('native movement ignores purely crossed areas when old membership and endpoint-found result are both zero', async () => {
  const t = fixture(); t.p.inTrigger = t.p.inAOE = t.p.inEncounter = () => 0;
  assert.equal(await updateSubareasOnMove(t.actor, [0, 0, 0], [1, 0, 0], 0, null, 0, t.p), 0);
  assert.deepEqual(t.events, []); assert.equal(t.actor.nativeSubareaMembership.count, 0);
  t.p.area = () => null; const warnings = []; t.p.warning = text => warnings.push(text);
  assert.equal(await updateSubareasOnMove(t.actor, [], [], 0, null, 0, t.p), 0); assert.equal(warnings.length, 1);
});

test('native subarea polygon edge query ignores height, includes endpoint contacts, fails without area and rejects collinear edges', () => {
  const object = { geometry: [[0, 0], [2, 0], [2, 2], [0, 2]] };
  assert.equal(intersectSubareaPolygon(object, [-1, 50, -1], [3, -50, -1], true), 1);
  assert.equal(intersectSubareaPolygon(object, [.5, 50, -.5], [1.5, -50, -1.5], true), 0);
  assert.equal(intersectSubareaPolygon(object, [-1, 0, -1], [3, 0, -1], false), 0);
  assert.equal(intersectSubareaPolygon({ geometry: [[0, 0], [2, 0]] }, [.5, 0, 0], [1.5, 0, 0], true), 0);
});
