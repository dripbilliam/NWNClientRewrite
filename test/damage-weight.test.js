import test from 'node:test';
import assert from 'node:assert/strict';
import { weightedDamageAmount } from '../src/damage_weight.js';
import { NativeRandom } from '../src/native_random.js';

test('native damage weighting preserves direction priority and no-draw branches', () => {
  const random = new NativeRandom(1);
  assert.equal(weightedDamageAmount(random, 3, 8, 0, 0, 150), 3);
  assert.equal(weightedDamageAmount(random, 3, 8, 1, 1, 0), 3);
  assert.equal(weightedDamageAmount(random, 3, 8, 1, 1, 100), 8);
  assert.equal(weightedDamageAmount(random, 3, 8, 0, 1, 100), 3);
  assert.equal(weightedDamageAmount(random, 3, 0, 1, 0, 50), 0);
  assert.equal(random.draws, 0);
});

test('player damage weighting adds a randomized fraction then caps to dice maximum', () => {
  const random = new NativeRandom(1); // CRT's first value is 41.
  assert.equal(weightedDamageAmount(random, 1, 10, 1, 0, 50), 10);
  assert.equal(random.draws, 1);
  assert.equal(weightedDamageAmount({ next: () => 0 }, 2, 10, 1, 0, 50), 7);
  assert.equal(weightedDamageAmount({ next: () => 0 }, 2, 10, 1, 0, 150), 10,
    'Signed remainder divisor is retained for percentages over 100');
});

test('NPC damage weighting floors reductions at one and draws only for percentages over 100', () => {
  const random = new NativeRandom(1);
  assert.equal(weightedDamageAmount(random, 8, 10, 0, 1, 50), 3);
  assert.equal(weightedDamageAmount(random, 2, 10, 0, 1, 50), 1);
  assert.equal(random.draws, 0);
  assert.equal(weightedDamageAmount(random, 8, 10, 0, 1, 150), 12);
  assert.equal(random.draws, 1);
  assert.equal(weightedDamageAmount({ next: () => 0 }, 8, 10, 0, 1, 150), 8);
});

test('damage weighting narrows products before signed division and final sums', () => {
  assert.equal(weightedDamageAmount({ next: () => 0 }, 0, 0x40000000, 0, 1, 50), 21474836,
    '0x40000000 * 50 wraps to INT_MIN before division, reversing the subtraction');
  assert.equal(weightedDamageAmount({ next: () => 1 }, 0x7fffffff, 100, 0, 1, 200), -0x80000000);
  assert.equal(weightedDamageAmount({ next: () => 0 }, 2, 5, 2, 2, 50), 2,
    'Native direction flags test equality to one rather than truthiness');
});

test('overflow prevents the player 100-percent short circuit and faults after the RNG draw', () => {
  const random = new NativeRandom(1);
  assert.throws(() => weightedDamageAmount(random, 1, 0x40000000, 1, 0, 100), /division fault/);
  assert.equal(random.draws, 1);
});
