import test from 'node:test';
import assert from 'node:assert/strict';
import { creatureCurrentHitPoints, creatureLifeState, doCreatureDamage } from '../src/creature_damage.js';

const temp = (id, capacity) => ({ id: id.toString(16).padStart(16, '0'), type: 15, integers: [capacity] });
function fixture(baseHP, effects = [], options = {}) {
  const state = { baseHP, temporaryHP: effects.reduce((n, e) => n + e.integers[0], 0) }, trace = [];
  let active = effects;
  return { state, trace, active: () => active, providers: {
    getTemporaryEffects: () => active,
    removeEffectImmediate(id) {
      trace.push(['remove', id, state.baseHP, state.temporaryHP]);
      const effect = active.find(e => e.id === id);
      // The native removal handler subtracts the effect's remaining capacity.
      state.temporaryHP = Math.max(0, ((state.temporaryHP << 16) >> 16) - effect.integers[0]);
      active = active.filter(e => e.id !== id);
    },
    getDifficulty(id) { trace.push(['difficulty', id]); return options.difficulty ?? 0; },
    getLifeFlags() { trace.push(['flags']); return { isPC: options.isPC ?? 0, possessedFamiliar: options.possessedFamiliar ?? false, immortal: options.immortal ?? 0 }; }
  } };
}

test('native HP getters narrow the sum, while base-only selection tests equality to one', () => {
  const state = { baseHP: 32760, temporaryHP: 10 };
  assert.equal(creatureCurrentHitPoints(state), -32766);
  assert.equal(creatureCurrentHitPoints(state, 1), 32760);
  assert.equal(creatureCurrentHitPoints(state, 2), -32766);
  assert.throws(() => creatureCurrentHitPoints({ baseHP: 1 }), /state/);
});

test('temporary HP effects are consumed in order and removed before difficulty and base damage', () => {
  const f = fixture(20, [temp(1, 3), temp(2, 5), temp(3, 7)]);
  const result = doCreatureDamage(f.state, 6, f.providers);
  assert.deepEqual(f.active().map(e => [e.id, e.integers[0]]), [[temp(2, 0).id, 2], [temp(3, 0).id, 7]]);
  assert.deepEqual(result, { before: 35, after: 29, damageToBase: 0, absorbed: 6, baseHP: 20, temporaryHP: 9 });
  assert.deepEqual(f.trace, [['remove', temp(1, 0).id, 20, 15], ['difficulty', 5], ['flags']]);
});

test('depletion at exact capacity removes the effect immediately; only overflow damages base HP', () => {
  for (const [damage, expected] of [[8, 20], [11, 17]]) {
    const f = fixture(20, [temp(1, 3), temp(2, 5)]);
    doCreatureDamage(f.state, damage, f.providers);
    assert.equal(f.active().length, 0); assert.equal(f.state.baseHP, expected); assert.equal(f.state.temporaryHP, 0);
    assert.equal(f.trace.filter(t => t[0] === 'remove').length, 2);
  }
});

test('zero-capacity removal restarts the native scan and recounts prior surviving effects', () => {
  const f = fixture(20, [temp(1, 3), temp(2, 0), temp(3, 4)]);
  doCreatureDamage(f.state, 1, f.providers);
  assert.equal(f.state.temporaryHP, 8, 'Native accumulator recounts the first surviving capacity after restarting');
  assert.deepEqual(f.active().map(e => e.integers[0]), [2, 4]);
});

test('difficulty protects PCs and possessed familiars; immortal must equal one and applies to NPCs', () => {
  for (const [options, expected] of [
    [{ difficulty: 1, isPC: 1 }, 1], [{ difficulty: 1, possessedFamiliar: true }, 1],
    [{ difficulty: 1 }, -6], [{ immortal: 1 }, 1], [{ immortal: 2 }, -6], [{ difficulty: 2, isPC: 1 }, -6]
  ]) {
    const f = fixture(4, [], options); doCreatureDamage(f.state, 10, f.providers);
    assert.equal(f.state.baseHP, expected);
  }
  const dying = fixture(-4, [], { immortal: 1 }); doCreatureDamage(dying.state, 10, dying.providers);
  assert.equal(dying.state.baseHP, -4, 'Protection prevents further damage; it does not heal a dying creature');
});

test('stored HP remains int32 after damage but GetDead/GetIsPCDying use signed-short total HP', () => {
  const f = fixture(-32760); doCreatureDamage(f.state, 20, f.providers);
  assert.equal(f.state.baseHP, -32780); assert.equal(creatureCurrentHitPoints(f.state), 32756);
  assert.deepEqual(creatureLifeState({ baseHP: -9, temporaryHP: 0 }, 1), { dead: false, dying: true });
  assert.deepEqual(creatureLifeState({ baseHP: -10, temporaryHP: 0 }, 1), { dead: true, dying: false });
  assert.deepEqual(creatureLifeState({ baseHP: 0, temporaryHP: 1 }, 0), { dead: false, dying: false });
  assert.deepEqual(creatureLifeState({ baseHP: 0, temporaryHP: 0 }, 0), { dead: true, dying: false });
});
