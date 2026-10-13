import test from 'node:test';
import assert from 'node:assert/strict';
import { parse2da } from '../src/area.js';
import { desiredAttackRange, maximumAttackRange, withinMaximumAttackRange } from '../src/combat_range.js';

const rules = {
  appearance: parse2da('2DA V2.0\n\nPREFATCKDIST weaponscale HITDIST\n91 1.25 1.5 0.75\n92 2 **** ****'),
  baseitems: parse2da('2DA V2.0\n\nPrefAttackDist AmmunitionType RangedWeapon\n99 2.5 0 1\n98 10 2 0')
};
const actor = (appearance = 0, modelType = 'P') => ({ modelType, objectType: 5, creatureData: { Appearance_Type: appearance } });
const weapon = base => [{ slot: 16, data: { BaseItem: base } }];

test('reach reads physical active rows, weapon scaling and target hit distance, with creature overrides', () => {
  const a = actor(), target = actor(1);
  assert.equal(desiredAttackRange(a, target, rules, []).distance, 1.75);
  assert.equal(desiredAttackRange(a, target, rules, weapon(0)).distance, 4.25);
  a.modelType = 'S'; assert.equal(desiredAttackRange(a, target, rules, weapon(0)).distance, 3);
  a.modelType = 'F'; assert.equal(desiredAttackRange(a, target, rules, weapon(0)).distance, 4.25);
  assert.equal(desiredAttackRange(a, target, rules, weapon(0), true).distance, 1.75);
  assert.equal(desiredAttackRange(a, null, rules, weapon(69)).distance, 1.25);
  assert.equal(desiredAttackRange(actor(1), null, rules, weapon(0)).distance, 2.5, 'Missing weapon scale uses native one');
});

test('maximum reach uses ammunition type instead of ranged flag and keeps native 40/20 constants', () => {
  const a = actor(), target = actor(0);
  assert.equal(maximumAttackRange(a, target, rules, weapon(0)).distance, 6);
  assert.equal(maximumAttackRange(a, target, rules, weapon(1)).distance, 40);
  assert.equal(maximumAttackRange(a, target, rules, weapon(1), { shortRanged: true }).distance, 20);
  assert.equal(maximumAttackRange(a, target, rules, weapon(1), { forceCreatureRange: true }).distance, 40);
});

test('maximum geometric range includes native float slack and vertical distance, and rejects other areas', () => {
  const a = { position: [0, 0, 0], areaId: 5 }, target = { position: [2, 0, 0], areaId: 5 };
  assert.equal(withinMaximumAttackRange(a, target, 2), true);
  target.position = [0, 2.009, 0]; assert.equal(withinMaximumAttackRange(a, target, 2), true);
  target.position[1] = 2.011; assert.equal(withinMaximumAttackRange(a, target, 2), false);
  target.areaId = 6; target.position = [0, 0, 0]; assert.equal(withinMaximumAttackRange(a, target, 2), false);
});

test('unknown preferred reach fails explicitly; nonpositive native values warn rather than inventing reach', () => {
  const a = actor();
  assert.throws(() => desiredAttackRange(a, null, { ...rules, appearance: parse2da('2DA V2.0\n\nPREFATCKDIST\n0 ****') }, []), /unavailable/);
  delete a.modelType; assert.throws(() => desiredAttackRange(a, null, rules, weapon(0)), /MODELTYPE/);
  const result = desiredAttackRange(actor(), null, { ...rules, appearance: parse2da('2DA V2.0\n\nPREFATCKDIST\n0 0') }, []);
  assert.equal(result.distance, 0); assert.equal(result.warnings.length, 1);
});
