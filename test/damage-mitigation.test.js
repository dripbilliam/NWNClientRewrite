import test from 'node:test';
import assert from 'node:assert/strict';
import { parse2da } from '../src/area.js';
import { damageReduction, damageResistance, maximumDamageResistance } from '../src/damage_mitigation.js';

const table = rows => parse2da(`2DA V2.0\n\nLabel Value\n${rows}`);
const target = (feats = [], classes = []) => ({ id: 0x80000041, objectType: 5, stats: { feats }, creatureData: { ClassList: classes } });
const dr = (id, capacity, power, budget = 0, ranged = 0) => ({ id: id.toString(16).padStart(16, '0'), type: 12, integers: [capacity, power, budget, ranged] });
const resist = (id, flags, capacity, budget = 0, ranged = 0) => ({ id: id.toString(16).padStart(16, '0'), type: 2, integers: [flags, capacity, budget, ranged] });
const rules = {};

test('damage reduction selects the strongest applicable capacity before considering its remaining budget', () => {
  const effects = [dr(1, 5, 2), dr(2, 10, 2, 2)], original = structuredClone(effects);
  const result = damageReduction(target(), effects, rules, 12, 1);
  assert.equal(result.amount, 10); assert.equal(result.source, effects[1].id);
  assert.deepEqual(result.operations, [{ type: 'removeEffect', effectId: effects[1].id, immediate: true },
    { type: 'feedback', code: 67, targetId: 0x80000041, attackerId: undefined, route: 'direct', amount: 2, remaining: 0 }]);
  assert.deepEqual(effects, original, 'Query does not commit competing authoritative state');
});

test('reduction power is byte-sized and must be below threshold, ranged condition accepts nonzero ranged state', () => {
  const effects = [dr(1, 4, 2, 0, 1), dr(2, 20, 5, 0, 2)];
  assert.equal(damageReduction(target(), effects, rules, 9, 1).amount, 9);
  assert.equal(damageReduction(target(), effects, rules, 9, 257, { ranged: 2 }).amount, 5);
  assert.equal(damageReduction(target(), effects, rules, 9, 2, { ranged: 1 }).amount, 9);
});

test('innate reduction ties beat an effect without consuming its budget; a stronger low-budget effect can still win', () => {
  const a = target([334]), effects = [dr(1, 4, 3, 20)];
  assert.equal(damageReduction(a, effects, rules, 10, 0).source, 'innate');
  assert.equal(damageReduction(a, effects, rules, 10, 0).amount, 6);
  assert.equal(damageReduction(a, [dr(1, 10, 3, 1)], rules, 10, 0).amount, 9);
  assert.equal(damageReduction(a, effects, rules, 10, 3).amount, 6, 'Barbarian reduction has no weapon-power bypass');
});

test('native Barbarian and Dwarven progressions stack, Perfect Self replaces the subtotal, Epic DR adds highest tier', () => {
  const a = target([1067, 948, 216, 492, 494], [{ Class: 0, ClassLevel: 29 }, { Class: 36, ClassLevel: 14 }]);
  assert.equal(damageReduction(a, [], rules, 40, 0).amount, 11, 'Perfect Self replaces 7 + 9 with 20, then adds 9');
  assert.equal(damageReduction(a, [], rules, 40, 1).amount, 15, 'Power bypasses Perfect Self; 7 + 9 + 9 remains');
  const custom = { ruleset: table('0 BARBARIAN_DAMAGE_REDUCTION_LEVEL_4 8\n1 EPIC_DAMAGE_REDUCTION_9 2') };
  assert.equal(damageReduction(target([334, 494]), [], custom, 20, 0).amount, 10);
});

test('reduction simulation clips finite budget but skips both mutation and feedback', () => {
  const effect = dr(1, 10, 2, 3);
  assert.deepEqual(damageReduction(target(), [effect], rules, 8, 0, { simulation: 1 }),
    { amount: 5, source: effect.id, capacity: 3, operations: [] });
  const result = damageReduction(target(), [dr(2, 5, 2, 12)], rules, 3, 0, { combat: 1, attacker: { id: 0 } });
  assert.deepEqual(result.operations[0], { type: 'effectInteger', effectId: dr(2, 0, 0).id, index: 2, value: 9 });
  assert.equal(result.operations[1].route, 'attack'); assert.equal(result.operations[1].attackerId, 0);
});

test('energy feat resistance subtracts before effect resistance and honors native combined-flag branch priority', () => {
  const a = target([428, 553]), effects = [resist(1, 288, 3, 10)];
  const result = damageResistance(a, effects, rules, 20, 288);
  assert.equal(result.innate, 5, 'Cold branch wins over fire even if fire feat resistance is larger');
  assert.equal(result.amount, 12);
  assert.deepEqual(result.operations.map(op => op.type), ['feedback', 'effectInteger', 'feedback']);
  assert.deepEqual(result.operations.map(op => op.code).filter(Boolean), [63, 66]);
  assert.equal(result.operations[1].value, 7);
});

test('custom epic resistance walks descending tiers until the first value above ordinary resistance', () => {
  const custom = { ruleset: table('0 RESISTANCE_TO_ENERGY 20\n1 EPIC_ENERGY_RESISTANCE_AMOUNT_10 1\n2 EPIC_ENERGY_RESISTANCE_AMOUNT_9 30\n3 EPIC_ENERGY_RESISTANCE_AMOUNT_1 80') };
  const result = damageResistance(target([427, 542, 541, 533]), [], custom, 100, 16);
  assert.equal(result.innate, 30); assert.equal(result.amount, 70);
});

test('physical base-weapon resistance chooses the weakest physical flag, retaining first source on ties', () => {
  const effects = [resist(1, 1, 8, 30), resist(2, 2, 4, 10), resist(3, 4, 4, 20)];
  const result = damageResistance(target(), effects, rules, 12, 7, { baseWeapon: 1, ranged: 1 });
  assert.equal(result.amount, 8); assert.equal(result.source, effects[1].id);
  assert.equal(result.operations[0].value, 6);
  assert.equal(damageResistance(target(), effects, rules, 12, 7).amount, 4, 'Script damage does not use the base-weapon minimum');
  assert.equal(damageResistance(target(), [effects[0]], rules, 12, 3, { baseWeapon: 1 }).amount, 12,
    'Absent resistance to one of the physical flags supplies a zero minimum');
});

test('door and placeable hardness use unsigned byte and ties preserve innate hardness without budget depletion', () => {
  for (const objectType of [9, 10]) {
    const object = { id: 33, objectType, hardness: 261 }, effects = [resist(1, 1, 5, 10)];
    assert.deepEqual(maximumDamageResistance(object, effects, 1), { amount: 5, effect: null });
    const result = damageResistance(object, effects, rules, 9, 1);
    assert.equal(result.amount, 4); assert.equal(result.source, null); assert.equal(result.operations.length, 1);
    assert.equal(damageResistance(object, [], rules, 9, 16).amount, 9, 'Hardness does not resist acid');
    assert.equal(damageResistance(object, [], rules, 9, 4096).amount, 4);
  }
  assert.throws(() => damageResistance({ id: 33, objectType: 9 }, [], rules, 9, 1), /hardness/);
});

test('resistance simulation preserves native innate feedback while suppressing budget changes and effect feedback', () => {
  const result = damageResistance(target([427]), [resist(1, 16, 10, 2)], rules, 20, 16, { simulation: 1 });
  assert.equal(result.amount, 13); assert.equal(result.operations.length, 1);
  assert.equal(result.operations[0].code, 63); assert.equal(result.operations[0].amount, 5);
});

test('native negative budget quirks differ between resistance and reduction', () => {
  const reduction = damageReduction(target(), [dr(1, 5, 2, -3)], rules, 10, 0);
  assert.equal(reduction.amount, 13); assert.equal(reduction.operations[0].type, 'removeEffect');
  const resistance = damageResistance(target(), [resist(1, 16, 5, -3)], rules, 10, 16);
  assert.equal(resistance.amount, 5); assert.equal(resistance.operations.length, 1);
  assert.equal(resistance.operations[0].code, 66); assert.equal(resistance.operations[0].amount, -3);
});
