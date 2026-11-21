import test from 'node:test';
import assert from 'node:assert/strict';
import { parse2da } from '../src/area.js';
import { damageBonus, specialAttackDamageBonus } from '../src/damage_bonus.js';
import { unarmedDamageProfile } from '../src/unarmed_damage.js';
import { damageEffectIntegers, damageImmunityByFlags, damageAfterImmunity } from '../src/damage_effect.js';

const table = (columns, rows) => parse2da(`2DA V2.0\n\n${columns}\n${rows}`);
const rules = {
  appearance: table('SIZECATEGORY', '0 3\n1 2'), racialtypes: table('Label', '0 Human'),
  baseitems: table('WeaponSize WeaponWield WeaponSpecializationFeat EpicWeaponSpecializationFeat',
    '0 3 0 141 671\n1 4 0 141 671\n2 3 11 141 671')
};
function actor({ str = 16, feats = [], classes = [], small = false, monk = false, goodEvil = 50 } = {}) {
  return { position: [0, 0, 0], creatureData: { Race: 0, IsPC: 0, Appearance_Type: small ? 1 : 0, GoodEvil: goodEvil, ClassList: classes },
    stats: { feats, level: classes.reduce((n, c) => n + c.ClassLevel, 0), equippedAbilities: { Str: str }, combat: { finalBreakdown: { armor: { monkAbilities: monk } } } } };
}
const item = (base = 0, properties = [], slot = 16) => ({ id: 42, slot, data: { BaseItem: base, PropertiesList: properties } });
const attack = { weaponAttackType: 1, ranged: 0, attackType: 0 };
const noDraw = { dice() { assert.fail('Unexpected damage bonus RNG draw'); } };
const bonus = (a, items, options = {}) => damageBonus(a, null, rules, items, noDraw, { attack, ...options });

test('damage strength distinguishes ordinary, two-handed, double, offhand and negative modifiers', () => {
  assert.equal(bonus(actor(), [item()]).parts.strength, 3);
  assert.equal(bonus(actor(), [item(1)]).parts.strength, 4);
  assert.equal(bonus(actor({ str: 8 }), [item(1)]).parts.strength, -1);
  assert.equal(bonus(actor(), [item()], { offhand: true }).parts.strength, 1);
  assert.equal(bonus(actor({ str: 8 }), [item()], { offhand: true }).parts.strength, -1);
  const custom = { ...rules, ruleset: table('Label Value', '0 TWO_HANDED_WEAPON_STRENGTH_MODIFIER 2.25') };
  assert.equal(damageBonus(actor(), null, custom, [item(1)], noDraw, { attack }).parts.strength, 6);
});

test('ranged damage carries thrown strength and Mighty can override a negative crossbow modifier', () => {
  const ranged = { ...attack, ranged: 1 };
  assert.equal(bonus(actor(), [item()], { attack: ranged }).parts.strength, 0);
  assert.equal(bonus(actor({ str: 8 }), [item()], { attack: ranged }).parts.strength, -1);
  assert.equal(bonus(actor(), [item(2)], { attack: ranged }).parts.strength, 3);
  const crossbow = item(6); // Missing base-rule row defaults; native base ID excludes negative strength.
  assert.equal(bonus(actor({ str: 8 }), [crossbow], { attack: ranged }).parts.strength, 0);
  crossbow.data.PropertiesList.push({ PropertyName: 45, Subtype: 0, CostValue: 2 });
  assert.equal(bonus(actor({ str: 8 }), [crossbow], { attack: ranged }).parts.strength, -1);
});

test('damage bonuses consume Bane dice before Dirty Fighting and map specialization through physical item rows', () => {
  const a = actor({ feats: [261, 855, 141, 671], classes: [{ Class: 7, ClassLevel: 10 }] });
  a.combatMode = 10;
  const calls = [], random = { dice(count, sides) { calls.push([count, sides]); return calls.length === 1 ? 7 : 3; } };
  const result = damageBonus(a, actor(), rules, [item()], random, { attack });
  assert.deepEqual(calls, [[2, 6], [1, 4]]);
  assert.deepEqual(result.parts, { strength: 3, pointBlank: 0, arrows: 0, favoredEnemy: 3, bane: 7, mode: 0, dirtyFighting: 3, specialization: 2, epicSpecialization: 4, special: 0 });
  assert.equal(result.total, 22);
  assert.equal(bonus(actor({ feats: [138, 668] }), []).total, 9);
});

test('damage Point Blank Shot uses inclusive native 3D five-meter range', () => {
  const a = actor({ feats: [27] }), target = actor(); target.position = [3, 4, 0];
  const options = { attack: { ...attack, ranged: 1 } };
  assert.equal(damageBonus(a, target, rules, [item()], noDraw, options).parts.pointBlank, 1);
  target.position[2] = 0.01;
  assert.equal(damageBonus(a, target, rules, [item()], noDraw, options).parts.pointBlank, 0);
});

test('smite damage uses appropriate class levels, alignment boundaries and highest Great Smiting tier', () => {
  const a = actor({ feats: [824, 833], classes: [{ Class: 6, ClassLevel: 8 }, { Class: 32, ClassLevel: 2 }, { Class: 31, ClassLevel: 7 }] });
  assert.equal(specialAttackDamageBonus(a, actor({ goodEvil: 30 }), rules, 301), 110);
  assert.equal(specialAttackDamageBonus(a, actor({ goodEvil: 31 }), rules, 301), 0);
  assert.equal(specialAttackDamageBonus(a, actor({ goodEvil: 70 }), rules, 472), 77);
  assert.equal(specialAttackDamageBonus(a, actor({ goodEvil: 69 }), rules, 472), 0);
  assert.equal(specialAttackDamageBonus(actor(), null, rules, 39), -4);
  assert.equal(specialAttackDamageBonus(actor({ classes: [{ Class: 5, ClassLevel: 0 }] }), null, rules, 39), 0,
    'Stunning Fist checks presence of Monk class, not a positive level');
});

test('native Monk unarmed tiers preserve separate small dice and die progressions', () => {
  assert.deepEqual(unarmedDamageProfile(actor(), rules), { dice: 1, sides: 3 });
  assert.deepEqual(unarmedDamageProfile(actor({ small: true }), rules), { dice: 1, sides: 2 });
  for (const [level, normal, small] of [[1, 6, 4], [4, 8, 6], [8, 10, 8], [12, 12, 10], [16, 20, 6]]) {
    const options = { classes: [{ Class: 5, ClassLevel: level }], monk: true };
    assert.deepEqual(unarmedDamageProfile(actor(options), rules), { dice: 1, sides: normal });
    assert.deepEqual(unarmedDamageProfile(actor({ ...options, small: true }), rules), { dice: level < 16 ? 1 : 2, sides: small });
  }
});

test('Shou third tier forces its die below combined Monk tier four while small dice remain one', () => {
  const options = { classes: [{ Class: 5, ClassLevel: 7 }, { Class: 40, ClassLevel: 5 }], monk: true };
  assert.deepEqual(unarmedDamageProfile(actor(options), rules), { dice: 2, sides: 6 });
  assert.deepEqual(unarmedDamageProfile(actor({ ...options, small: true }), rules), { dice: 1, sides: 10 });
  options.classes[0].ClassLevel = 11;
  assert.deepEqual(unarmedDamageProfile(actor(options), rules), { dice: 1, sides: 20 });
  assert.deepEqual(unarmedDamageProfile(actor({ ...options, small: true }), rules), { dice: 2, sides: 6 });
  const custom = { ...rules, ruleset: table('Label Value', '0 MONK_DAMAGE_TIER_ONE_THRESHHOLD 2\n1 MONK_DAMAGE_TIER_ONE_DAMAGE_DIE 257') };
  assert.deepEqual(unarmedDamageProfile(actor({ classes: [{ Class: 5, ClassLevel: 2 }], monk: true }), custom), { dice: 1, sides: 1 });
});

test('damage constructor normalizes amount, flag range and power without splitting combined flags', () => {
  const values = damageEffectIntegers(12, 3, 22, 13);
  assert.equal(values.length, 39); assert.equal(values[0], -1); assert.equal(values[1], 12);
  assert.equal(values[2], -1); assert.deepEqual(values.slice(32), [0, 1000, 3, 22, 0, 0, 0]);
  assert.equal(damageEffectIntegers(-1, 1, 0, 13)[0], 1);
  assert.equal(damageEffectIntegers(10001, 1, 0, 13)[0], 1);
  assert.equal(damageEffectIntegers(10000, 0, -1, 13)[0], 10000);
  assert.equal(damageEffectIntegers(0, 8192, 23, 13)[0], 0);
  assert.equal(damageEffectIntegers(5, 8192, 0, 14)[13], 5);
  assert.equal(damageEffectIntegers(5, -1, 0, 32)[0], 5);
  assert.throws(() => damageEffectIntegers(1), /rules/);
});

test('damage immunity selects weakest flagged cache entry including zero/vulnerability and the native fire feat shortcut', () => {
  const cache = Array(32).fill(0); cache[0] = 50; cache[1] = 100;
  assert.equal(damageImmunityByFlags(3, cache), 50);
  assert.equal(damageImmunityByFlags(7, cache), 0);
  cache[1] = 231; assert.equal(damageImmunityByFlags(3, cache), -25);
  assert.equal(damageImmunityByFlags(0, cache), 0);
  assert.equal(damageImmunityByFlags(257, cache, [964]), 100);
  assert.throws(() => damageImmunityByFlags(1), /cache/);
  assert.equal(damageAfterImmunity(3, 1), 2);
  assert.equal(damageAfterImmunity(0, 50), -1, 'DoDamageImmunity itself does not clamp');
  assert.equal(damageAfterImmunity(9, -50), 13);
  assert.equal(damageAfterImmunity(9, 100), 0);
});
