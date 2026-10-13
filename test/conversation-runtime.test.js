import assert from 'node:assert/strict';
import { FactionReputationTable } from '../src/reputation.js';
import test from 'node:test';
import { ModuleSession } from '../src/module_session.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';
import { nearestObjects, nativeDistanceSquared, creatureCriteria } from '../src/nearest_objects.js';
import { inTrigger, triggerGeometry } from '../src/trigger_geometry.js';
import { creatureSpacing, creatureTalkRange, horizontalInRange, placeableUsePoint, placeableUseRange } from '../src/interaction_range.js';
import { parsePlaceableActionPoints } from '../src/walkmesh.js';

function fixture() {
  const calls = [], messages = [], session = new ModuleSession({}, { onMessage: m => messages.push(m) });
  const owner = session.register('creature', 'npc', { tag: 'NPC', position: [0, 0, 0], authored: { CurrentHitPoints: 10, Race: 1, ClassList: [{ Class: 10 }] } });
  const area = session.register('area', 'area', { objects: [owner.id], scripts: {} });
  owner.areaId = area.id;
  const player = session.register('player', 'pc', { isPC: true, position: [1, 0, 0], areaId: area.id, journal: new Map(), stats: { currentHP: 10 } });
  area.objects.push(player.id); session.player = player; session.currentArea = area;
  session.program = async name => name;
  session.vm = { run: async (name, self) => { calls.push({ name, self, speaker: session.commands.GetPCSpeaker([], { self }) }); return { stack: [{ type: 3, value: name === 'false' ? 0 : 1 }] }; } };
  return { session, owner, player, area, calls, messages };
}

const link = (Index, Active = '') => ({ Index, Active });
function dialogue() {
  return {
    StartingList: [link(2, 'false'), link(0, 'true')], EndConversation: 'ended', EndConverAbort: 'aborted',
    EntryList: [
      { Text: 'First', Quest: 'QuestTag', QuestEntry: 20, Script: 'entry', RepliesList: [link(0, 'false'), link(1, 'true'), link(1)] },
      { Text: 'Second', RepliesList: [] }, { Text: 'Unavailable', RepliesList: [] }
    ], ReplyList: [{ Text: 'Hidden' }, { Text: 'Reply', Script: 'reply', EntriesList: [link(2, 'false'), link(1, 'true')] }]
  };
}

test('DLG conditions and actions run as the canonical owner, in authored order; replies retain link ordinals', async () => {
  const { session, owner, player, calls } = fixture();
  session.conversation.resources.set('dialogue', dialogue());
  assert.equal(owner.id, 0, 'ID zero is a valid dialogue owner');
  assert.equal(await session.conversation.start(owner, player, 'dialogue'), true);
  assert.deepEqual(calls.map(c => c.name), ['false', 'true', 'entry', 'false', 'true']);
  assert.ok(calls.every(c => c.self === 0 && c.speaker === player.id));
  assert.deepEqual(session.conversation.state.replies.map(r => [r.ordinal, r.index]), [[1, 1], [2, 1]]);
  assert.equal(player.journal.get('QuestTag'), 20);
  const version = session.conversation.version;
  assert.equal(await session.conversation.choose(0, version), false);
  assert.equal(await session.conversation.choose(1, version - 1), false);
  assert.equal(await session.conversation.choose(1, version), true);
  assert.deepEqual(calls.slice(-3).map(c => c.name), ['reply', 'false', 'true']);
  assert.equal(session.conversation.state.entryIndex, 1);
  assert.equal(session.conversation.state.complete, true);
  assert.equal(await session.conversation.choose(1, version), false, 'A stale duplicate cannot rerun its script');
  await session.conversation.finish();
  assert.deepEqual(calls.at(-1), { name: 'ended', self: 0, speaker: player.id });
  assert.equal(session.commands.GetPCSpeaker([], { self: owner.id }), OBJECT_INVALID);
  assert.equal(player.dialogOwnerId, OBJECT_INVALID);
});

test('a pending reply rejects concurrent clicks and clears ownership even when the abort script fails', async () => {
  const { session, owner, player } = fixture();
  session.conversation.resources.set('dialogue', dialogue());
  await session.conversation.start(owner, player, 'dialogue');
  const run = session.vm.run; let unblock;
  session.vm.run = async (name, self) => { if (name === 'reply') await new Promise(r => { unblock = r; }); return run(name, self); };
  const version = session.conversation.version, pending = session.conversation.choose(1, version);
  await Promise.resolve(); await Promise.resolve();
  assert.equal(await session.conversation.choose(1, version), false);
  unblock(); await pending;
  session.vm.run = async () => { throw new Error('Unsupported end action'); };
  await assert.rejects(session.conversation.finish(true), /Unsupported end action/);
  assert.equal(session.conversation.state, null); assert.equal(owner.conversation, null);
  assert.equal(player.dialogOwnerId, OBJECT_INVALID);
});

test('unsupported conditions fail visibly without inventing a branch; journal state only advances', async () => {
  const { session, owner, player } = fixture();
  player.locals.setInt('NW_JOURNAL_ENTRYQuestTag', 30);
  session.conversation.resources.set('dialogue', dialogue());
  await session.conversation.start(owner, player, 'dialogue');
  assert.equal(player.journal.get('QuestTag'), 30);
  await session.conversation.finish(true);
  session.vm.run = async () => ({ stack: [] });
  await assert.rejects(session.conversation.start(owner, player, 'dialogue'), /did not return an integer/);
  assert.match(session.conversation.state.error, /integer/); assert.deepEqual(session.conversation.state.replies, []);
});

test('nearest queries use 3D float32 distance, X-list encounter ties and canonical IDs, excluding owned items', () => {
  const { session, owner, player, area } = fixture();
  owner.position = [0, 0, 0]; player.position = [1, 20, 0];
  const a = session.register('creature', 'a', { areaId: area.id, position: [-1, 0, 0] });
  const b = session.register('creature', 'b', { areaId: area.id, position: [1, 0, 0] });
  const item = session.register('item', 'owned', { areaId: area.id, ownerId: player.id, position: [0, 0, 0] });
  area.objects.push(a.id, b.id, item.id);
  const any = () => true;
  assert.equal(nearestObjects(session, owner, 0, any, owner.id), b.id, '+X is visited before -X');
  assert.equal(nearestObjects(session, owner, 2, any, owner.id), a.id);
  assert.equal(nearestObjects(session, owner, 3, any, owner.id), player.id, 'Height participates in nearest ordering');
  assert.equal(nearestObjects(session, owner, 4, any, owner.id), OBJECT_INVALID);
  assert.equal(nearestObjects(session, owner, 1, any), owner.id, 'Location queries can return the object at that location');
  assert.equal(nativeDistanceSquared([16777217, 0, 0], [16777216, 0, 0]), 0, 'Inputs narrow to float32 before subtracting');
});

test('nearest-creature filters AND criteria and exclude DM/dead/dying by default; faction and perception thresholds are exact', () => {
  const { session, owner, player } = fixture();
  session.factionTable = new FactionReputationTable(1, [{ FactionID1: 0, FactionID2: 1, FactionRep: 90 }]);
  owner.factionId = 1; player.factionId = 2; player.factionReputation = session.factionTable.defaultPC();
  assert.equal(creatureCriteria(session, player, [[0, 1], [2, 10], [1, 0]])(owner), true);
  assert.equal(creatureCriteria(session, player, [[0, 1], [2, 9]])(owner), false);
  assert.equal(creatureCriteria(session, player, [[3, 0]])(owner), true);
  player.factionReputation[0] = 89;
  assert.equal(creatureCriteria(session, player, [[3, 2]])(owner), true);
  owner.isDM = true; assert.equal(creatureCriteria(session, player, [[0, 28]])(owner), false); owner.isDM = false;
  owner.authored.CurrentHitPoints = 0;
  assert.equal(creatureCriteria(session, player, [[0, 28]])(owner), false);
  assert.equal(creatureCriteria(session, player, [[4, 0]])(owner), true);
  player.stats.currentHP = -9;
  assert.equal(session.isDead(player), false); assert.equal(session.isDying(player), true);
  player.stats.currentHP = -10; assert.equal(session.isDead(player), true); assert.equal(session.isDying(player), false);
  owner.authored.CurrentHitPoints = 10; player.perception = new Map([[owner.id, 3]]);
  assert.equal(creatureCriteria(session, player, [[7, 0]])(owner), true);
  assert.equal(creatureCriteria(session, player, [[7, 1]])(owner), false);
  owner.effects = [{ spellId: 1 }]; assert.equal(creatureCriteria(session, player, [[5, 1]])(owner), true);
  assert.equal(creatureCriteria(session, player, [[6, 1]])(owner), false);
  owner.authored.EffectList = [{}]; assert.throws(() => creatureCriteria(session, player, [[5, 1]])(owner), /effect import/);
});

test('cutscene mode saves plot on first enable, preserves raw mode and only affects PC/familiar objects', () => {
  const { session, owner, player } = fixture();
  player.plot = false; session.setCutscene(player.id, 1, 1); session.setCutscene(player.id, 1, 0);
  assert.equal(player.plot, true); assert.equal(player.cutscene.leftClicks, false);
  session.setCutscene(player.id, 2, 1);
  assert.equal(player.plot, false); assert.equal(player.cutscene.enabled, false); assert.equal(player.cutscene.rawMode, 2);
  session.setCutscene(owner.id, 1, 0); assert.equal(owner.cutscene, undefined);
  player.plot = true; session.setCutscene(player.id, 1); session.setCutscene(player.id, 0); assert.equal(player.plot, true);
});

test('nearest-creature preserves target quirks: first-value race wildcard and search-wide dead selection', () => {
  const { session, owner, player } = fixture();
  assert.equal(creatureCriteria(session, player, [[1, 0], [0, 28]])(owner), false, 'ALL in a later criterion does not invoke the native wildcard');
  const predicate = creatureCriteria(session, player, [[4, 1], [4, 0]]);
  assert.equal(predicate(owner), false);
  owner.authored.CurrentHitPoints = 0;
  assert.equal(predicate(owner), true, 'The native dead-selection flag survives the rejected candidate');
});

test('trigger geometry adds source XY without rotating and ignores elevation; concave polygons retain their notch', () => {
  const geometry = triggerGeometry({ XPosition: 10, YPosition: 20, XOrientation: 0, YOrientation: -1, Geometry: [[0, 0], [4, 0], [4, 1], [1, 1], [1, 4], [0, 4]].map(([PointX, PointY]) => ({ PointX, PointY })) });
  const trigger = { geometry };
  assert.deepEqual(geometry[1], [14, 20]);
  assert.equal(inTrigger(trigger, [10.5, 1000, -22]), true);
  assert.equal(inTrigger(trigger, [12, -1000, -20.5]), true);
  assert.equal(inTrigger(trigger, [12, 0, -22]), false);
  assert.equal(inTrigger(trigger, [9, 0, -22]), false);
});

test('movement emits trigger enter/exit once per crossing, supports overlaps/reentry and drops deleted targets', async () => {
  const { session, area, player, calls } = fixture();
  const geometry = [[0, 0], [4, 0], [4, 4], [0, 4]];
  const a = session.register('trigger', 'triggerA', { areaId: area.id, geometry, scripts: { enter: 'enterA', exit: 'exitA' } });
  const b = session.register('trigger', 'triggerB', { areaId: area.id, geometry, scripts: { enter: 'enterB', exit: 'exitB' } });
  area.objects.push(a.id, b.id); player.position = [2, 99, -2];
  session.updateTriggers(player); session.updateTriggers(player); await session.scheduler.pump();
  assert.deepEqual(calls.map(c => c.name), ['enterA', 'enterB']);
  assert.equal(a.eventObjects.entering, player.id);
  player.position = [5, 0, -2]; session.updateTriggers(player); await session.scheduler.pump();
  assert.deepEqual(calls.slice(-2).map(c => c.name), ['exitA', 'exitB']); assert.equal(a.eventObjects.exiting, player.id);
  player.position = [2, 0, -2]; session.updateTriggers(player); session.unregister(b.id); await session.scheduler.pump();
  assert.equal(calls.at(-1).name, 'enterA');
});

test('NPC talk range uses both appearance CREPERSPACE fields, combat allowance and float32 boundary checks', () => {
  const appearances = { rows: new Map([[1, { PERSPACE: '0.3', CREPERSPACE: '0.5' }], [2, { CREPERSPACE: '1' }]]) };
  const actor = { authored: { Appearance_Type: 1 } }, target = { authored: { Appearance_Type: 2 }, combatTargetId: OBJECT_INVALID };
  assert.deepEqual(creatureSpacing(actor, appearances), { personal: Math.fround(0.3), creature: 0.5 });
  const range = creatureTalkRange(actor, target, appearances);
  assert.equal(range, Math.fround(Math.fround(1.5 + Math.fround(0.3)) + Math.fround(1 + Math.fround(0.1))));
  assert.equal(horizontalInRange([0, 0, 0], [range, 200, 0], range), true);
  assert.equal(horizontalInRange([0, 0, 0], [range + 0.001, 0, 0], range), false);
  target.combatTargetId = 0; assert.ok(creatureTalkRange(actor, target, appearances) > range);
});

test('PWK use points preserve their authored indices, transform to world space and choose point two on distance ties', () => {
  const points = parsePlaceableActionPoints('node dummy OBJ_pwk_use02\n position 0 -1 0\nendnode\nnode dummy OBJ_pwk_dp_use_01\n position 0 1 0\nendnode', { position: [10, 20, 2], angle: Math.PI / 2 });
  assert.deepEqual(points, [[9, 2, -20], [11, 2, -20]]);
  const actor = { position: [10, 2, -20] }, target = { position: [10, 2, -20], actionPoints: points };
  assert.equal(placeableUsePoint(actor, target), points[1]);
  target.actionPoints = [null, points[1]]; assert.equal(placeableUsePoint(actor, target), target.position, 'A missing first point falls back to the object origin');
  assert.equal(placeableUseRange(actor), Math.fround(Math.fround(Math.fround(.6) + Math.fround(.5)) + Math.fround(.1)));
});

test('perception and attempt-target APIs read canonical runtime fields and reject noncreature observers', () => {
  const { session, owner, player } = fixture();
  owner.perception = new Map([[player.id, 2]]);
  assert.equal(session.commands.GetObjectSeen([player.id, owner.id]), 0);
  assert.equal(session.commands.GetObjectHeard([player.id, owner.id]), 1);
  assert.equal(session.commands.GetObjectSeen([owner.id, OBJECT_INVALID]), 0);
  owner.attemptedAttackTargetId = 0; owner.attemptedSpellTargetId = player.id;
  assert.equal(session.commands.GetAttemptedAttackTarget([], { self: owner.id }), 0);
  assert.equal(session.commands.GetAttemptedSpellTarget([], { self: owner.id }), player.id);
  assert.equal(session.commands.GetCurrentAction([owner.id]), 65535);
  owner.currentActionId = 7; assert.equal(session.commands.GetCurrentAction([owner.id]), 7);
});

test('named dialogue speakers use the closest tag within ten metres, cache the chosen ID and release participant ownership', async () => {
  const { session, owner, player, area } = fixture();
  const first = session.register('creature', 'speakerA', { tag: 'Speaker', areaId: area.id, position: [2, 0, 0], authored: { CurrentHitPoints: 10 } });
  const second = session.register('creature', 'speakerB', { tag: 'Speaker', areaId: area.id, position: [5, 0, 0], authored: { CurrentHitPoints: 10 } });
  area.objects.push(first.id, second.id);
  const resource = dialogue(); resource.EntryList[0].Speaker = 'Speaker';
  session.conversation.resources.set('dialogue', resource);
  await session.conversation.start(owner, player, 'dialogue');
  assert.equal(session.conversation.state.speakerId, first.id); assert.equal(first.dialogOwnerId, owner.id);
  first.position[0] = 11;
  assert.equal(session.conversation.speaker(resource.EntryList[0]), null, 'Do not silently substitute another object after caching');
  await session.conversation.finish(); assert.equal(first.dialogOwnerId, OBJECT_INVALID);
});

test('the test startup bypass only omits initial entry; subsequent area events still run', async () => {
  const { session, owner, player, area, calls } = fixture();
  session.runStartupScripts = false;
  session.areas.set('first', area); area.scripts.enter = 'initialEnter';
  const next = session.register('area', 'next', { objects: [], scripts: { enter: 'nextEnter' } }); session.areas.set('next', next);
  session.currentArea = null;
  await session.enterArea('first', [0, 0, 0]); await session.scheduler.pump();
  assert.equal(calls.length, 0);
  await session.enterArea('next', [0, 0, 0]); await session.scheduler.pump();
  assert.equal(calls.at(-1).name, 'nextEnter'); assert.equal(player.areaId, next.id); assert.equal(owner.areaId, area.id);
});
