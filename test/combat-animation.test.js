import test from 'node:test';
import assert from 'node:assert/strict';
import { CombatAnimationRandom, resolveMeleeAnimations } from '../src/combat_animation.js';
import { createCombatRound } from '../src/combat_round.js';
import { createAttackData } from '../src/combat_attack_data.js';
import { checkActionLength } from '../src/combat_timing.js';

const fixture = () => ({ actor: { id: 0 }, target: { id: 1, objectType: 5, animationState: 0, creatureState: 0, combatRound: createCombatRound() }, data: createAttackData() });
test('isolated animation RNG helper follows the MSVC sequence and requires explicit seed', () => {
  assert.throws(() => new CombatAnimationRandom(), /seed/);
  const random = new CombatAnimationRandom(1); assert.deepEqual(Array.from({ length: 5 }, () => random.next()), [41, 18467, 6334, 26500, 19169]);
  assert.equal(random.draws, 5);
});
test('melee group reactions pause defender half for earlier attacks and full for last, using full length eligibility', async () => {
  const { actor, target, data } = fixture(), round = target.combatRound;
  round.started = true; round.length = 4000; round.timer = 10; round.actions.push({ time: 2000 }); data.result = 1;
  await resolveMeleeAnimations(actor, 0, 2, target, 857, data);
  assert.equal(data.animationDuration, 857); assert.equal(data.reactionAnimation, 14); assert.equal(data.reactionDelay, 428); assert.equal(data.attackDuration, 857);
  assert.equal(round.pausedBy, 0); assert.equal(round.pauseTimer, 428); assert.equal(round.length, 3572);
  await resolveMeleeAnimations(actor, 1, 2, target, 857, data); assert.equal(round.pauseTimer, 1285); assert.equal(round.length, 2715);
  round.pausedBy = 42; data.attackDuration = 0; data.reactionDelay = 0;
  await resolveMeleeAnimations(actor, 0, 1, target, 857, data); assert.equal(data.reactionAnimation, 1); assert.equal(data.attackDuration, 0); assert.equal(round.pauseTimer, 1285);
});
test('busy target animations suppress reaction and its RNG, while placeables retain duration without defender round writes', async () => {
  const { actor, target, data } = fixture(); data.result = 4; target.animationState = 15;
  await resolveMeleeAnimations(actor, 0, 1, target, 857, data); assert.equal(data.reactionAnimation, 1); assert.equal(target.combatRound.paused, false);
  target.objectType = 9; target.animationState = 0; data.result = 1;
  await resolveMeleeAnimations(actor, 0, 1, target, 857, data); assert.equal(data.reactionAnimation, 14); assert.equal(data.attackDuration, 0); assert.equal(data.reactionDelay, 0);
});
test('miss animation consumes the supplied stream before conditional lock/ranged queries and preserves reaction outcomes', async () => {
  const { actor, target, data } = fixture(), trace = []; data.result = 4;
  const providers = { animationRandom: { next: () => { trace.push('random'); return 2; } }, getLock: () => { trace.push('lock'); return 0; },
    rangedEquipped: () => { trace.push('ranged'); return 0; } };
  await resolveMeleeAnimations(actor, 0, 1, target, 857, data, providers); assert.deepEqual(trace, ['random', 'lock', 'ranged']); assert.equal(data.reactionAnimation, 12);
  trace.length = 0; providers.animationRandom.next = () => { trace.push('random'); return 1; };
  await resolveMeleeAnimations(actor, 0, 1, target, 857, data, providers); assert.deepEqual(trace, ['random']); assert.equal(data.reactionAnimation, 11);
  target.creatureState = 8; await resolveMeleeAnimations(actor, 0, 1, target, 857, data, providers); assert.equal(data.reactionAnimation, 1);
});
test('missing miss-animation dependencies preserve record; action length uses exact-one and int32 overflow gates', async () => {
  const { actor, target, data } = fixture(); data.result = 4;
  await assert.rejects(resolveMeleeAnimations(actor, 0, 1, target, 857, data), /providers/); assert.equal(data.animationDuration, 0);
  const r = target.combatRound; r.paused = 2; r.started = 2; r.pausedBy = 42; assert.equal(checkActionLength(r, 0, 999999), true);
  r.started = true; r.length = 0x7fffffff; r.overlap = 0; r.timer = 0; assert.equal(checkActionLength(r, 0, 1), false);
  r.length = 0; r.timer = 0; assert.equal(checkActionLength(r, 0, 1000), true); assert.equal(checkActionLength(r, 0, 1001), false);
});
