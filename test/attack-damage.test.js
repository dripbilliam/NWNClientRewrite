import test from 'node:test';
import assert from 'node:assert/strict';
import { addAttackDamage } from '../src/attack_damage.js';

test('attack components use highest flag and distinct empty/positive penalty floors', () => {
  const attack = { damage: Array(32).fill(-1) };
  addAttackDamage(attack, 3, 5);
  assert.equal(attack.damage[0], -1); assert.equal(attack.damage[1], 5);
  addAttackDamage(attack, 2, -9); assert.equal(attack.damage[1], 1);
  addAttackDamage(attack, 8, -9); assert.equal(attack.damage[3], 0);
  addAttackDamage(attack, 0x80000000, 3); assert.equal(attack.damage[31], 3);
  addAttackDamage(attack, 0, 2); assert.equal(attack.damage[0], 2);
});

test('attack damage preserves int32 arithmetic and signed-short storage', () => {
  const attack = { damage: Array(32).fill(-1) };
  addAttackDamage(attack, 1, 32768); assert.equal(attack.damage[0], -32768);
  addAttackDamage(attack, 1, 4); assert.equal(attack.damage[0], 4);
  addAttackDamage(attack, 1, 0x7fffffff); assert.equal(attack.damage[0], 1);
  assert.throws(() => addAttackDamage({ damage: [] }, 1, 2), /record is unavailable/);
});
