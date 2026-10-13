import test from 'node:test';
import assert from 'node:assert/strict';
import { parse2da } from '../src/area.js';
import { weaponDamageFlags, attackDamageFlags, weaponPower, calculateDamagePower } from '../src/damage_weapon.js';

const table = (columns, rows) => parse2da(`2DA V2.0\n\n${columns}\n${rows}`);
const rules = { baseitems: table('WeaponType RangedWeapon WeaponWield', '0 1 0 0\n1 2 0 0\n2 3 0 0\n3 4 0 0\n4 5 0 0\n5 0 0 0\n6 1 1 0\n7 1 0 8\n8 1 1 0') };
const item = (base, props = [], slot = 16) => ({ id: 44, slot, data: { BaseItem: base, PropertiesList: props } });
const a = (feats = [], monk = false) => ({ stats: { feats, combat: { finalBreakdown: { armor: { monkAbilities: monk } } } } });
const bonus = (amount, hand = 1, race = 28, law = 0, good = 0) => ({ type: 10, integers: [amount, hand, race, law, good] });

test('native base-item weapon types select physical flags and invalid type returns its warning before extra flags', () => {
  assert.deepEqual([0, 1, 2, 3, 4].map(base => weaponDamageFlags(item(base), rules).flags), [2, 1, 4, 6, 3]);
  assert.equal(weaponDamageFlags(null, rules).flags, 1);
  assert.equal(weaponDamageFlags(item(255), rules).flags, 0);
  const warning = weaponDamageFlags(item(5, [{ PropertyName: 33, Subtype: 0 }]), rules);
  assert.equal(warning.flags, 4); assert.equal(warning.warnings[0].itemId, 44);
});

test('extra melee/ranged flags use first appropriate property, permanent before temporary and subtype rather than CostValue', () => {
  assert.equal(weaponDamageFlags(item(0, [{ PropertyName: 34, Subtype: 0 }, { PropertyName: 33, Subtype: 0, CostValue: 2 }]), rules).flags, 3);
  assert.equal(weaponDamageFlags(item(6, [{ PropertyName: 33, Subtype: 0 }, { PropertyName: 34, Subtype: 2 }]), rules).flags, 6);
  assert.equal(weaponDamageFlags(item(0, [{ PropertyName: 33, Subtype: 8 }, { PropertyName: 33, Subtype: 0 }]), rules,
    [{ PropertyName: 33, Subtype: 2 }]).flags, 2, 'Unknown subtype on first property does not fall through');
  assert.equal(weaponDamageFlags(item(0), rules, [{ PropertyName: 33, Subtype: 0 }]).flags, 3);
});

test('current double-weapon hand wins over the left item and zero attack hand requires native selection', () => {
  assert.equal(attackDamageFlags([item(7), item(1, [], 32)], rules, { weaponAttackType: 2 }).flags, 2);
  assert.throws(() => attackDamageFlags([], rules, { weaponAttackType: 0 }), /selection/);
  assert.equal(attackDamageFlags([], rules, { weaponAttackType: 0 }, { resolvedHand: 1 }).flags, 1);
});

test('weapon power ignores generic attack bonuses and preserves distinct hand aliases, versus qualifiers and cap', () => {
  const effects = [bonus(20, 0), bonus(7, 1), bonus(9, 3), bonus(12, 4), bonus(8, 7), bonus(14, 1, 2, 2, 5)];
  const context = { race: 2, lawChaos: 2, goodEvil: 5 };
  assert.equal(weaponPower(effects, 1, false, context, 10), 10);
  assert.equal(weaponPower(effects, 1, false, null, 20), 7);
  assert.equal(weaponPower(effects, 6, false, null, 20), 9);
  assert.equal(weaponPower(effects, 8, false, null, 20), 8);
  assert.equal(weaponPower([bonus(5, 2)], 0, true, null, 20), 5);
  assert.equal(weaponPower([bonus(5, 2)], 0, false, null, 20), 0);
});

test('natural weapon power also uses reduction power regardless of condition or remaining budget', () => {
  const effects = [{ type: 12, integers: [0, 5, 0, 2] }];
  assert.equal(weaponPower(effects, 3, false, null, 20), 5);
  assert.equal(weaponPower(effects, 1, false, null, 20), 0);
  assert.equal(weaponPower([], 1, false, null, -2), 0);
  assert.equal(weaponPower([{ type: 22, integers: [1] }], 1, false, null, -2), -2);
});

test('CalculateDamagePower skips energy index above six before Ki/arrow adjustments, then narrows to byte', () => {
  assert.equal(calculateDamagePower(a(), [], rules, { ranged: 0 }, 6), 6);
  assert.equal(calculateDamagePower(a(), [], rules, { ranged: 0 }, 7), 8);
  assert.equal(calculateDamagePower(a(), [], rules, { ranged: 0 }, 255), 0);
  assert.equal(calculateDamagePower(a([698], true), [], rules, { ranged: 0 }, 0), 5);
  assert.equal(calculateDamagePower(a([698], true), [item(0)], rules, { ranged: 0 }, 0), 0);
  assert.equal(calculateDamagePower(a([449, 1059]), [item(8)], rules, { ranged: 1 }, 0), 20);
  assert.equal(calculateDamagePower(a([1059]), [item(8)], rules, { ranged: 2 }, 0), 0);
});

test('custom Ki selects the highest owned feat once; arrows find the first tier stronger than existing power', () => {
  const custom = { ...rules, ruleset: table('Label Value', '0 KI_STRIKE_LEVEL_5 1\n1 KI_STRIKE_LEVEL_1 10\n2 PRESTIGE_ENCHANT_ARROW_20_BONUS 1\n3 PRESTIGE_ENCHANT_ARROW_5_BONUS 12') };
  assert.equal(calculateDamagePower(a([698, 213], true), [], custom, { ranged: 0 }, 2), 2);
  assert.equal(calculateDamagePower(a([1059, 449]), [item(8)], custom, { ranged: 1 }, 2), 12);
});
