import test from 'node:test';
import assert from 'node:assert/strict';
import { parseTalkTable, GameText } from '../src/talk_table.js';
import { GameUiState, journalRows, nativeControlKind } from '../src/game_ui_state.js';
import { GameObjectArray } from '../src/game_object_array.js';
import { buildUiModel, poseUiModel } from '../src/native_ui_assets.js';

function tlk(strings) {
  const chunks = strings.map(text => new TextEncoder().encode(text)), table = 20 + strings.length * 40;
  const bytes = new Uint8Array(table + chunks.reduce((n, c) => n + c.length, 0)), view = new DataView(bytes.buffer);
  bytes.set(new TextEncoder().encode('TLK V3.0')); view.setUint32(12, strings.length, true); view.setUint32(16, table, true);
  let cursor = 0;
  chunks.forEach((chunk, i) => { const p = 20 + i * 40; view.setUint32(p, 1, true); view.setUint32(p + 28, cursor, true); view.setUint32(p + 32, chunk.length, true); bytes.set(chunk, table + cursor); cursor += chunk.length; });
  return bytes;
}
test('TLK resolves indexed strings and checks every referenced range', () => {
  const bytes = tlk(['Journal', 'Inventory']), table = parseTalkTable(bytes);
  assert.equal(table.get(0), 'Journal'); assert.equal(table.get(1), 'Inventory'); assert.equal(table.get(2), undefined);
  assert.throws(() => parseTalkTable(bytes.subarray(0, 19)), /header/);
  new DataView(bytes.buffer).setUint32(20 + 28, 99999, true);
  assert.throws(() => parseTalkTable(bytes).get(0), /bounds/);
});
test('localized text respects language/gender, custom TLK and module strings', () => {
  const text = new GameText({ base: parseTalkTable(tlk(['Base'])), custom: parseTalkTable(tlk(['Custom'])) });
  assert.equal(text.resolve({ strRef: 0 }), 'Base'); assert.equal(text.strRef(0x01000000), 'Custom');
  assert.equal(text.resolve({ strRef: 0, entries: [{ languageId: 0, text: 'Embedded' }] }), 'Embedded');
  text.female = true;
  assert.equal(text.resolve({ entries: [{ languageId: 0, text: 'Male' }, { languageId: 1, text: 'Female' }] }), 'Female');
  assert.equal(text.resolve({ Obj_StrRef: 0xffffffff, AurString_Text: 'Literal' }), 'Literal');
});
test('journal UI projects actual tag/state and JRL End flags without mutating state', () => {
  const player = { journal: new Map([['first', 1], ['done', 4], ['unknown', 1]]) };
  const definitions = new Map([['first', { Name: 'First', Priority: 2, EntryList: [{ ID: 1, End: 0, Text: 'Started' }] }], ['done', { Name: 'Done', EntryList: [{ ID: 4, End: 1, Text: 'Finished' }] }]]);
  const text = new GameText();
  assert.deepEqual(journalRows(player, definitions, text).map(r => [r.tag, r.state, r.text]), [['first', 1, 'Started']]);
  assert.deepEqual(journalRows(player, definitions, text, { tab: 'completed' }).map(r => r.tag), ['done']);
  assert.equal(player.journal.size, 3);
});
test('UI stack and personal notes preserve state while panels change', () => {
  const state = new GameUiState(); state.notes.set(0, 'Note'); state.open('journal'); state.open('options');
  assert.equal(state.panel, 'options'); state.close(); assert.equal(state.panel, 'journal');
  state.toggle('journal'); assert.equal(state.panel, null); assert.equal(state.notes.get(0), 'Note');
  state.reset(); assert.equal(state.notes.size, 0);
});
test('native GUI widget types distinguish sliders, checkbox switches and provider lists', () => {
  assert.equal(nativeControlKind({ Obj_Type: 6, Obj_ResRef: 'ctl_ig_slider' }), 'slider');
  assert.equal(nativeControlKind({ Obj_Type: 2, Obj_ResRef: 'ctl_ig_slider' }), 'checkbox');
  assert.equal(nativeControlKind({ Obj_Type: 8, Obj_ResRef: 'ctl_cg_lstbx20' }), 'list');
  assert.equal(nativeControlKind({ Obj_Type: 8, Obj_ResRef: 'edit_jnl_348x408' }), 'text');
  assert.equal(nativeControlKind({ Obj_Type: 8, Obj_ResRef: 'ctl_cg_edit_s' }), 'edit');
});
test('quickbar retains uint32 references and rejects deleted objects', () => {
  const registry = new GameObjectArray(), actor = { areaId: 7 }, target = {};
  registry.addInternalObject(actor); registry.addInternalObject(target);
  const state = new GameUiState(); state.bind(1, 3, { action: 'door.use', targetId: target.id });
  assert.deepEqual(state.activate(1, 3, registry, actor.id), { action: 'door.use', targetId: target.id, actorId: 0, areaId: 7 });
  registry.delete(target.id); assert.equal(state.activate(1, 3, registry, actor.id), null);
  assert.throws(() => state.bind(3, 0, {}), /slot/);
});
test('native UI model keeps source XY coordinates, separate UV indices and hook transforms', () => {
  const model = { nodes: [{ name: 'root', parent: 'NULL', type: 'dummy', position: [1, -2, 0], orientation: [0, 0, 0, 1] }, { name: 'hook', parent: 'root', type: 'dummy', position: [.5, -.5, 0], orientation: [0, 0, 0, 1] }, { name: 'plane', parent: 'root', type: 'trimesh', position: [0, 0, 0], orientation: [0, 0, 0, 1], verts: [[0, 0, 0], [1, 0, 0], [0, -1, 0]], tverts: [[0, 0], [1, 0], [0, 1]], faces: [[0, 1, 2, 0, 2, 0, 1, 0]] }] };
  const ui = buildUiModel(model); assert.deepEqual(ui.hooks.get('hook'), [1.5, -2.5, 0]);
  assert.deepEqual(ui.bounds.min.toArray(), [1, -3, 0]); assert.deepEqual(ui.bounds.max.toArray(), [2, -2, 0]);
  const mesh = ui.root.getObjectByName('plane').children[0]; assert.deepEqual([...mesh.geometry.attributes.uv.array], [0, 1, 0, 0, 1, 0]);
});
test('UI up/down poses use native XY tracks and alpha without changing bindings', () => {
  const model = { nodes: [{ name: 'root', parent: 'NULL', type: 'dummy', position: [0, 0, 0], orientation: [0, 0, 0, 1] }, { name: 'plane', parent: 'root', type: 'trimesh', position: [1, 2, 0], orientation: [0, 0, 0, 1], verts: [[0, 0, 0], [1, 0, 0], [0, -1, 0]], tverts: [], faces: [[0, 1, 2, 0, 0, 0, 0, 0]] }], animations: [{ name: 'down', length: 0, tracks: [{ node: 'plane', property: 'position', frames: [{ time: 0, value: [3, -4, 0] }] }, { node: 'plane', property: 'alpha', frames: [{ time: 0, value: [0] }] }] }] };
  const ui = buildUiModel(model), plane = ui.root.getObjectByName('plane'); poseUiModel(ui, 'down'); assert.deepEqual(plane.position.toArray(), [3, -4, 0]); assert.equal(plane.children[0].visible, false);
  poseUiModel(ui, 'up'); assert.deepEqual(plane.position.toArray(), [1, 2, 0]); assert.equal(plane.children[0].visible, true);
});
