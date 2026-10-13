import test from 'node:test';
import assert from 'node:assert/strict';
import { FactionReputationTable, effectivePVPSetting, subtractWorldTimes, personalReputationAdjustment,
  creatureReputation, objectReputation, aiStateReaction } from '../src/reputation.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

const creature = (id, factionId, pc = 0) => ({ id, objectType: 5, factionId, originalFactionId: factionId,
  masterId: OBJECT_INVALID, associateType: 0, reputationPCFlag: pc, personalReputationList: [], pvpReputationList: null,
  factionReputation: null, areaId: 100 });
function fixture() {
  const table = new FactionReputationTable(2, [
    { FactionID1: 0, FactionID2: 1, FactionRep: 0 }, { FactionID1: 0, FactionID2: 2, FactionRep: 90 },
    { FactionID1: 1, FactionID2: 2, FactionRep: 17 }, { FactionID1: 2, FactionID2: 1, FactionRep: 63 }]);
  const a = creature(0, 1), b = creature(0x80000001, 2), pc = creature(2, 3, 1), warnings = [];
  pc.factionReputation = table.defaultPC();
  const objects = new Map([[a.id, a], [b.id, b], [pc.id, pc]]), area = { id: 100, pvp: 0 };
  const providers = { table, object: id => objects.get(id) ?? null,
    creature: id => objects.get(id)?.objectType === 5 ? objects.get(id) : null,
    faction: object => object.factionId ?? null, area: object => object.areaId === area.id ? area : null,
    pvp: area => area.pvp, elapsed: entry => ({ milliseconds: entry.elapsed ?? 0 }), warning: message => warnings.push(message) };
  return { table, a, b, pc, objects, area, providers, warnings };
}

test('native FAC loading and lookup retain asymmetry, defaults, clamp, invalid IDs and NPC/PC swap', () => {
  const { table } = fixture();
  assert.equal(table.get(1, 2), 63); assert.equal(table.get(2, 1), 17);
  assert.equal(table.get(1, 1), 100); assert.equal(table.get(0, 1), 0); assert.equal(table.get(3, 2), 50);
  assert.equal(table.get(3, 1), 90, 'Native flat lookup permits a column to spill into the next row');
  assert.equal(table.get(3, 4), 50); assert.equal(table.get(-1, -1), 50);
  assert.deepEqual(table.defaultPC(), [0, 90]);
  const copy = table.defaultPC(); copy[0] = 11; assert.equal(table.defaultPC()[0], 0);
  const clamped = new FactionReputationTable(1, [{ FactionID1: 0, FactionID2: 1, FactionRep: -2 },
    { FactionID1: 1, FactionID2: 1, FactionRep: 201 }, { FactionID1: 1, FactionID2: 0, FactionRep: 4 }]);
  assert.equal(clamped.get(1, 0), 0); assert.equal(clamped.get(1, 1), 100);
});

test('native world-time subtraction preserves unsigned borrow and invalid-output status', () => {
  assert.deepEqual(subtractWorldTimes({ day: 10, time: 20 }, { day: 9, time: 99 }, 100), { status: 0, days: 0, milliseconds: 21 });
  assert.deepEqual(subtractWorldTimes({ day: 10, time: 20 }, { day: 10, time: 21 }, 100), { status: -2 });
  assert.deepEqual(subtractWorldTimes({ day: 1, time: 100 }, { day: 2, time: 0 }, 100), { status: 0, days: 0xfffffffe, milliseconds: 200 });
});

test('native effective PVP applies area inheritance and server override masks', () => {
  assert.deepEqual([0, 1, 2, 3].map(area => effectivePVPSetting(area, 0)), [0, 0, 0, 0]);
  assert.deepEqual([0, 1, 2, 3].map(area => effectivePVPSetting(area, 1)), [0, 1, 1, 1]);
  assert.deepEqual([0, 1, 2, 3].map(area => effectivePVPSetting(area, 2)), [0, 1, 2, 2]);
  assert.equal(effectivePVPSetting(259, 258), 2);
});

test('personal reputation sums backward, matches target/master, ignores own familiar and decays using fixed divisor', () => {
  const { a, b, providers } = fixture(), trace = [];
  b.masterId = 55;
  a.personalReputationList = [
    { objectId: b.id, amount: -40, decays: 1, duration: 360, elapsed: 90000 },
    { objectId: 55, amount: 20, decays: 0, duration: 0 },
    { objectId: b.id, amount: 180, decays: 1, duration: 360, elapsed: 270000 },
    { objectId: b.id, amount: 100, decays: 1, duration: 0, elapsed: 1 },
    { objectId: 123, amount: 999, decays: 1, duration: 0, elapsed: 99 }];
  providers.elapsed = entry => { trace.push(entry.amount); return { days: 20, milliseconds: entry.elapsed ?? 0 }; };
  assert.equal(personalReputationAdjustment(a, b.id, providers), -90);
  assert.deepEqual(trace, [100, 180, 20, -40]); assert.equal(a.personalReputationList.length, 4);
  b.masterId = a.id; b.associateType = 5; assert.equal(personalReputationAdjustment(a, b.id, providers), 0);
});

test('creature reputation preserves direct owner friendship and associate 7/8 independence', () => {
  const { a, b, pc, objects, providers } = fixture();
  b.masterId = a.id; assert.equal(creatureReputation(a, b.id, 2, 0, providers), 100);
  a.masterId = pc.id; b.masterId = OBJECT_INVALID;
  pc.factionReputation[1] = 12;
  assert.equal(creatureReputation(a, b.id, 2, 0, providers), 12);
  assert.equal(creatureReputation(a, b.id, 2, 1, providers), 17);
  for (const type of [7, 8]) { a.associateType = type; assert.equal(creatureReputation(a, b.id, 2, 0, providers), 17); }
  a.associateType = 1; objects.delete(pc.id); assert.equal(creatureReputation(a, b.id, 2, 0, providers), 17);
});

test('PC reputation uses its live faction vector; malformed source warns and returns adjusted 100', () => {
  const { pc, a, providers, warnings } = fixture();
  pc.factionReputation[0] = 45;
  pc.personalReputationList = [{ objectId: a.id, amount: -5, decays: 0, duration: 0 }];
  assert.equal(creatureReputation(pc, a.id, 1, 0, providers), 40);
  assert.equal(creatureReputation(pc, a.id, 0, 0, providers), 95); assert.equal(warnings.length, 1);
});

test('PC versus PC behavior distinguishes empty/missing/matching PVP records and same faction/no-PVP friendship', () => {
  const { pc, b, area, providers } = fixture(); b.reputationPCFlag = 1; b.factionId = 4;
  assert.equal(creatureReputation(pc, b.id, 4, 0, providers), 100);
  area.pvp = 2; assert.equal(creatureReputation(pc, b.id, 4, 0, providers), 50);
  pc.pvpReputationList = []; assert.equal(creatureReputation(pc, b.id, 4, 0, providers), 50);
  pc.pvpReputationList = [{ objectId: b.id, field8: 0 }]; assert.equal(creatureReputation(pc, b.id, 4, 0, providers), 0);
  pc.pvpReputationList[0].field8 = 1; assert.equal(creatureReputation(pc, b.id, 4, 0, providers), 50);
  b.factionId = pc.factionId; assert.equal(creatureReputation(pc, b.id, 4, 0, providers), 100);
});

test('object reputation delegates NPC-to-PC, traverses AOE creators, clamps once and returns neutral for DM/unsupported', () => {
  const { pc, a, b, objects, providers } = fixture();
  assert.deepEqual(objectReputation(a, b.id, 0, providers), { reputation: 17, sameFaction: 0 });
  assert.deepEqual(objectReputation(a, pc.id, 0, providers), { reputation: 0, sameFaction: 0 });
  pc.factionReputation[0] = 45; assert.equal(objectReputation(a, pc.id, 0, providers).reputation, 45);
  objects.set(11, { id: 11, objectType: 11, creatorId: a.id });
  assert.equal(objectReputation(b, 11, 0, providers).reputation, 63);
  assert.equal(objectReputation(objects.get(11), b.id, 0, providers).reputation, 17);
  objects.get(11).creatorId = 11; assert.equal(objectReputation(a, 11, 0, providers).reputation, 50);
  b.isDM = true; assert.equal(objectReputation(a, b.id, 0, providers).reputation, 50); b.isDM = false;
  assert.deepEqual(objectReputation(a, a.id, 0, providers), { reputation: 100, sameFaction: 1 });
});

test('AI reaction queries the target receiver and rejects DM/independent associates before reputation mutation', () => {
  const { pc, a, b, area, providers } = fixture();
  assert.equal(aiStateReaction(pc, a.id, providers), 2); assert.equal(aiStateReaction(pc, b.id, providers), 1);
  pc.factionReputation[1] = 89; assert.equal(aiStateReaction(pc, b.id, providers), 0);
  pc.factionReputation[1] = 100; area.pvp = 1; assert.equal(aiStateReaction(pc, b.id, providers), 0);
  area.pvp = 0; pc.associateType = 7; assert.equal(aiStateReaction(pc, a.id, providers), 0);
});

test('cyclic ownership and missing world-time output fail instead of claiming a successful query', () => {
  const { a, b, pc, providers } = fixture(); a.masterId = b.id; b.masterId = a.id;
  assert.throws(() => creatureReputation(a, pc.id, 3, 0, providers), /Cyclic/);
  a.masterId = OBJECT_INVALID; a.personalReputationList = [{ objectId: pc.id, amount: 4, decays: 1, duration: 30 }];
  providers.elapsed = () => ({ status: -2 }); assert.throws(() => personalReputationAdjustment(a, pc.id, providers), /unavailable/);
});
