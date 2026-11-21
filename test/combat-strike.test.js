import test from 'node:test';
import assert from 'node:assert/strict';
import { createCombatRound } from '../src/combat_round.js';
import { clearAllAttacks, copyAttackData } from '../src/combat_attack_data.js';
import { resolveMeleeGroup, resolveRangedGroup, signalMeleeDamage, signalRangedDamage, attackResultDoesDamage } from '../src/combat_strike.js';
import { ScriptScheduler } from '../src/script_scheduler.js';

function actor() { return { id: 0x80000000, combatMode: 3, combatRound: createCombatRound() }; }
function hooks(trace) {
  const current = a => a.combatRound.currentAttack;
  return { weaponAttackType(a) { trace.push(['weapon', current(a)]); return 1; },
    situational(a) { trace.push(['situation', current(a)]); }, cachedSpecial(a) { trace.push(['special', current(a)]); },
    attackRoll(a, t, record) { trace.push(['roll', current(a)]); record.result = current(a) === 0 ? 1 : 4; },
    damage(a) { trace.push(['damage', current(a)]); }, postDamage(a) { trace.push(['post', current(a)]); },
    animations(a, i, n, t, d, record) { trace.push(['animate', i, n, d]); record.animationDuration = d; record.attackDuration = d; },
    specialAttack() { trace.push(['resolveSpecial']); }, signal(a, t, count) { trace.push(['signal', current(a), count]); } };
}
test('melee resolves each pool slot in native order, advances only after animation, and signals once', async () => {
  const a = actor(), t = { id: 0 }, trace = [], pool = a.combatRound.attacks;
  await resolveMeleeGroup(a, t, 2, 857, hooks(trace));
  assert.deepEqual(trace, [['weapon', 0], ['situation', 0], ['special', 0], ['roll', 0], ['damage', 0], ['post', 0], ['animate', 0, 2, 857],
    ['weapon', 1], ['situation', 1], ['special', 1], ['roll', 1], ['animate', 1, 2, 857], ['signal', 2, 2]]);
  assert.equal(a.combatRound.attacks, pool); assert.deepEqual(pool.slice(0, 2).map(d => [d.group, d.targetId, d.combatMode, d.weaponAttackType]), [[0, 0, 3, 1], [0, 0, 3, 1]]);
  assert.deepEqual(Array.from({ length: 12 }, (_, i) => i).filter(attackResultDoesDamage), [1, 3, 5, 6, 7, 10]);
});
test('special and coup-de-grace branches bypass the corresponding generic hooks; absent providers preserve the pool', async () => {
  const a = actor(), trace = [], providers = hooks(trace), data = a.combatRound.attacks[0];
  const missing = { ...providers }; delete missing.postDamage;
  await assert.rejects(resolveMeleeGroup(a, { id: 1 }, 1, 10, missing), /postDamage/);
  assert.equal(data.group, 255); assert.equal(a.combatRound.attackGroup, 255); assert.deepEqual(trace, []);
  providers.situational = (a, t, record) => { record.coupDeGrace = 1; record.attackType = 9; };
  await resolveMeleeGroup(a, { id: 1 }, 1, 10, providers);
  assert.deepEqual(trace, [['weapon', 0], ['resolveSpecial'], ['signal', 1, 1]]);
});
test('ranged group uses ammunition count, marks ranged, does not copy mode, and routes misses separately', async () => {
  const a = actor(), trace = [], providers = hooks(trace);
  providers.setAnimation = () => assert.fail(); providers.ammunition = (a, requested) => { assert.equal(requested, 3); return 2; };
  providers.miss = a => trace.push(['miss', a.combatRound.currentAttack]);
  providers.animations = (a, t, d) => trace.push(['rangedAnimate', a.combatRound.currentAttack, d]);
  await resolveRangedGroup(a, { id: 7 }, 3, 857, providers);
  assert.equal(a.combatRound.currentAttack, 2); assert.equal(a.combatRound.attacks[0].ranged, 1); assert.equal(a.combatRound.attacks[0].combatMode, 0);
  assert.ok(trace.some(x => x[0] === 'miss' && x[1] === 1)); assert.deepEqual(trace.at(-1), ['signal', 2, 2]);
  a.combatRound.paused = true; a.combatRound.pauseTimer = 900;
  await resolveRangedGroup(a, null, 1, 10, { setAnimation: (a, state) => { trace.push(['resume', state]); } });
  assert.equal(a.combatRound.paused, false); assert.equal(a.combatRound.pauseTimer, 900, 'SetPauseTimer(0) adds zero to positive timer');
  assert.deepEqual(trace.at(-1), ['resume', 1]);
});
test('native attack copy excludes padding and attached lists, preserves scalar/string snapshot across pool reuse', () => {
  const a = actor(), source = a.combatRound.attacks[0]; source.targetId = 0; source.damage[12] = 37;
  source.strings[1] = 'debug'; source.lists[0].push({ id: 1 }); source.raw.setUint8(0x15, 0x66);
  const copy = copyAttackData(source); clearAllAttacks(a.combatRound);
  assert.equal(copy.targetId, 0); assert.equal(copy.damage[12], 37); assert.equal(copy.strings[1], 'debug');
  assert.equal(copy.lists[0].length, 0); assert.equal(copy.raw.getUint8(0x15), 0); assert.notEqual(copy.damage, source.damage);
});
test('melee signaling retains native delayed event ordering and payload ownership after source records reset', async () => {
  const a = actor(), r = a.combatRound, events = []; r.currentAttack = 2;
  const one = r.attacks[0], two = r.attacks[1];
  one.result = 1; one.animationDuration = 857; one.attackDuration = 857; one.damage[12] = 8; one.targetId = 0;
  one.lists[3].push({ type: 2, integers: [1] }, { type: 2, integers: [2] }); one.lists[0].push({ effect: 'target' });
  one.lists[1].push({ effect: 'actor' }); one.lists[2].push({ effect: 'other', id: 9 });
  two.result = 4; two.animationDuration = 857; two.attackDuration = 857; two.targetId = 0;
  two.lists[3].push({ type: 2, integers: [234] }, { type: 3, integers: [234] });
  await signalMeleeDamage(a, { id: 0 }, 2, { enqueue: (...e) => events.push(e), createDamageEffect: (id, integers) => ({ creatorId: id, integers }),
    hasFeat: () => false, attackWeapon: () => null, effectTarget: e => e.id, messageType: e => e.type, messageInteger: (e, i) => e.integers[i] });
  assert.deepEqual(events.map(e => [e[0], e[1], e[2], e[3]]), [[15, a.id, 0, 0], [20, a.id, a.id, 0],
    [22, a.id, 0, 428], [22, a.id, 0, 428], [5, a.id, 0, 428], [5, a.id, 0, 428], [19, a.id, a.id, 428], [19, 9, 9, 428],
    [15, a.id, 0, 428], [20, a.id, a.id, 428], [22, a.id, 0, 856]]);
  assert.deepEqual(events[2][4].integers, [2]); const effect = events[4][4]; assert.equal(effect.integers[12], 8);
  assert.deepEqual(effect.integers.slice(32), [1, 428, 0, 0, 1, 0, 0]);
  const firstCopy = events[0][4]; clearAllAttacks(r); assert.equal(firstCopy.damage[12], 8); assert.equal(effect.integers[12], 8);
});
test('signal missing message interpretation fails before events; AoO feat and opportunist suppression are distinct', async () => {
  const a = actor(), record = a.combatRound.attacks[0], events = []; a.combatRound.currentAttack = 1;
  record.result = 4; record.lists[3].push({}); const providers = { enqueue: (...e) => events.push(e), createDamageEffect() {}, hasFeat: () => true, attackWeapon: () => null };
  await assert.rejects(signalMeleeDamage(a, { id: 1 }, 1, providers), /messageType/); assert.equal(events.length, 0);
  record.lists[3].length = 0; record.attackType = 9; await signalMeleeDamage(a, { id: 1 }, 1, providers);
  assert.deepEqual(events.map(e => e[0]), [15, 20]);
  events.length = 0; record.attackType = 65002; providers.hasFeat = () => false;
  await signalMeleeDamage(a, { id: 1 }, 1, providers); assert.deepEqual(events.map(e => e[0]), [15]);
});
test('combat millisecond scheduling avoids float conversion, preserves native positive-delay LIFO and waits for due time', async () => {
  const events = [], scheduler = new ScriptScheduler({ validTarget: () => true, dispatch: ({ event }) => events.push(event) });
  scheduler.localTimer.setMinutesPerHour(255); // native BYTE rate; large delay fits this world's day.
  scheduler.enqueueMilliseconds(0, 'impact', 16777217); scheduler.enqueueMilliseconds(0, 'effect', 16777217);
  scheduler.advance(16777216); await scheduler.pump(); assert.deepEqual(events, []);
  scheduler.advance(1); await scheduler.pump(); assert.deepEqual(events, ['effect', 'impact']);
});
test('ranged signaling separates launch/ammunition/impact delays, retains all miss feedback, and sets native effect flags', async () => {
  const a = actor(), r = a.combatRound, trace = []; a.isPC = true; r.currentAttack = 2;
  const one = r.attacks[0], two = r.attacks[1];
  one.animationDuration = 857; one.reactionDelay = 50; one.result = 4; one.lists[3].push({ type: 3, integers: [7] });
  two.animationDuration = 800; two.reactionDelay = 300; two.result = 1; two.damage[12] = 8;
  await signalRangedDamage(a, { id: 0 }, 2, { enqueue: (...args) => trace.push(['event', ...args]), difficulty: () => 1,
    safeProjectile: (a, delay, index) => trace.push(['projectile', delay, index]), ammunition: (a, delay) => trace.push(['ammo', delay]),
    createDamageEffect: (id, integers) => ({ creatorId: id, integers }) });
  assert.deepEqual(trace.filter(e => e[0] !== 'event'), [['projectile', 428, 0], ['ammo', 429], ['projectile', 828, 1], ['ammo', 829]]);
  const events = trace.filter(e => e[0] === 'event');
  assert.deepEqual(events.map(e => [e[1], e[4]]), [[15, 0], [22, 478], [15, 428], [5, 906]]);
  assert.deepEqual(events.at(-1)[5].integers.slice(32), [0, 400, 0, 0, 1, 1, 0]);
  // Native next impact delay uses the PREVIOUS record's travel/duration,
  // even when this record has a different travel value.
  assert.equal(events.at(-1)[4], 906);
});
