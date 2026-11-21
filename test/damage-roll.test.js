import test from 'node:test';
import assert from 'node:assert/strict';
import { parse2da } from '../src/area.js';
import { damageRoll, damageRollAsync, damageDifficulty, sneakDamageDice, deathDamageDice } from '../src/damage_roll.js';
import { NativeRandom } from '../src/native_random.js';
import { createCombatRound, weaponAttackType } from '../src/combat_round.js';
import { currentAttackWeapon } from '../src/combat_weapon.js';

const table = (columns, rows) => parse2da(`2DA V2.0\n\n${columns}\n${rows}`);
const rules = {
  appearance: table('SIZECATEGORY', '0 3'), racialtypes: table('Label', '0 Human'),
  baseitems: table('NumDice DieToRoll CritHitMult EpicWeaponOverwhelmingCriticalFeat WeaponSize WeaponWield',
    '0 1 8 3 700 3 0\n1 1 4 2 701 3 0'),
  iprp_monstcost: table('NumDice Die', '0 0 0\n1 2 6\n2 0 0'),
  iprp_damagecost: table('NumDice Die', '0 0 0\n1 0 5\n2 2 6')
};
function actor(feats = [], strength = 10) {
  return { position: [0, 0, 0], creatureData: { IsPC: 0, Race: 0, Appearance_Type: 0, ClassList: [], GoodEvil: 50 },
    stats: { feats, level: 0, equippedAbilities: { Str: strength }, combat: { finalBreakdown: { armor: { monkAbilities: false } } } } };
}
const item = (base = 0, properties = [], slot = 16) => ({ id: 0x12345678, slot, data: { BaseItem: base, PropertiesList: properties } });
const attack = { weaponAttackType: 1, ranged: 0, attackType: 0 };
const difficulty = { playerToNpc: 0, npcToPlayer: 0, percentage: 100 };
const options = { attack, difficulty, effectBonus: () => 0, damageFlags: () => 1, weaponAttackType:()=>1 };

test('live damage roll awaits effect query and immediate resistance removal before reduction sees the changed state', async () => {
  const target = { id:77,objectType:9 }, trace=[], effects=[{id:'resistance'}], random=draws([6]);
  const result=await damageRollAsync(actor(),target,rules,[item()],random,{...options,
    effectBonus:async()=>{await Promise.resolve();trace.push('effect');return 2},damagePower:()=>1,
    immunity:async amount=>{trace.push('immunity');return amount},
    resistance:async amount=>{trace.push('resistance');await Promise.resolve();effects.splice(0);trace.push('removed');return amount-3},
    reduction:amount=>{assert.equal(effects.length,0);trace.push('reduction');return amount-2}
  });
  assert.equal(result.amount,3);assert.deepEqual(trace,['effect','immunity','resistance','removed','reduction']);
  assert.deepEqual(random.trace,[[1,8]]);
});
function draws(values) {
  const trace = [];
  return { trace, dice(count, sides) { trace.push([count, sides]); assert.ok(values.length, 'Unexpected dice query'); return values.shift(); },
    next() { assert.fail('Unexpected difficulty draw'); } };
}

test('critical weapon dice reroll per multiplier while sneak, death and random bonus roll once in native order', () => {
  const a = actor([221, 455], 14); a.combatMode = 10;
  const random = draws([2, 4, 6, 3, 5, 4]);
  const result = damageRoll(a, null, rules, [item()], random, { ...options, critical: true, sneak: true, death: true });
  assert.deepEqual(random.trace, [[1, 8], [1, 8], [1, 8], [1, 6], [1, 6], [1, 4]]);
  assert.equal(result.base, 12); assert.equal(result.bonus.total, 6);
  assert.equal(result.amount, 38, '12 base + 3 sneak + 5 death + (2 strength + 4 Dirty Fighting) * 3');
});

test('Overwhelming Critical rolls per multiplier normally but once for maximized weapon damage', () => {
  const normal = draws([2, 1, 4, 2, 6, 3]);
  const result = damageRoll(actor([700]), null, rules, [item()], normal, { ...options, critical: true });
  assert.equal(result.amount, 18);
  assert.deepEqual(normal.trace, [[1, 8], [1, 6], [1, 8], [1, 6], [1, 8], [1, 6]]);
  const maximum = draws([4, 6, 3]);
  assert.equal(damageRoll(actor([700]), null, rules, [item()], maximum, { ...options, critical: true, maximize: true }).amount, 21);
  assert.deepEqual(maximum.trace, [[1, 8], [1, 8], [1, 6]]);
});

test('unarmed critical ignores maximize and still uses difficulty weighting for each base roll', () => {
  const random = new NativeRandom(1);
  const result = damageRoll(actor([720]), null, rules, [], random, { ...options, critical: true, maximize: true,
    difficulty: { playerToNpc: 1, npcToPlayer: 0, percentage: 100 } });
  assert.equal(result.base, 17, 'Two weighted 1d3 maxima plus CRT 1d6 results of 6 and 5');
  assert.equal(random.draws, 4, 'Base dice are still consumed despite maximize; 100% weighting consumes no extra draw');
});

test('natural property availability is distinct from a valid zero-dice row', () => {
  const naturalAttack = { ...attack, weaponAttackType: 3 },naturalOptions={...options,attack:naturalAttack,weaponAttackType:()=>3};
  const absent = draws([]);
  assert.equal(damageRoll(actor(), null, rules, [item(0, [], 16384)], absent, naturalOptions).amount, 1);
  const present = draws([0]);
  assert.equal(damageRoll(actor(), null, rules, [item(0, [{ PropertyName: 77, Subtype: 1, CostValue: 2 }], 16384)], present,
    naturalOptions).amount, 1);
  assert.deepEqual(present.trace, [[0, 0]]);
  const populated = draws([7]);
  assert.equal(damageRoll(actor(), null, rules, [item(0, [{ PropertyName: 77, Subtype: 2, CostValue: 1 }], 16384)], populated,
    naturalOptions).amount, 7);
  assert.deepEqual(populated.trace, [[2, 6]]);
});

test('damage reselects natural weapons twice in native order instead of reusing the strike hand',()=>{
  for(const maximize of [false,true]){
    const a=actor();a.combatRound=createCombatRound();a.combatRound.onhandAttacks=1;
    const gear=[item(0,[{PropertyName:77,CostValue:1}],16384),item(1,[{PropertyName:77,CostValue:2}],32768)];
    const random=new NativeRandom(1),hand=()=>weaponAttackType(a.combatRound,gear,random);
    const result=damageRoll(a,null,rules,gear,random,{...options,attack:{...attack,weaponAttackType:4},maximize,weaponAttackType:hand});
    assert.equal(result.amount,maximize?12:11);assert.equal(random.draws,maximize?4:6);
    assert.equal(result.profile.dice,2);assert.equal(result.profile.sides,6);
  }
  const gear=[item()];
  assert.throws(()=>currentAttackWeapon(gear,rules,0),/selection query/);
  assert.equal(currentAttackWeapon(gear,rules,0,()=>1),gear[0]);
});

test('No Damage clears armed base dice after RNG consumption, then bonuses and Massive Critical still apply', () => {
  const random = draws([2, 4, 6]);
  const result = damageRoll(actor([], 14), null, rules, [item(0, [{ PropertyName: 47 }, { PropertyName: 74, Subtype: 2, CostValue: 1 }])], random,
    { ...options, critical: true });
  assert.equal(result.base, 0); assert.equal(result.massive, 5); assert.equal(result.amount, 11);
  assert.equal(random.trace.length, 3);
  const massive = draws([2, 4, 6, 9]);
  assert.equal(damageRoll(actor(), null, rules, [item(0, [{ PropertyName: 74, Subtype: 1, CostValue: 2 }])], massive,
    { ...options, critical: true }).amount, 21);
  assert.deepEqual(massive.trace.at(-1), [2, 6]);
});

test('mitigation queries run in native order with short narrowing and a final zero floor', () => {
  const target = { id: 77, objectType: 9 }, trace = [], random = draws([6]);
  const result = damageRoll(actor([], 6), target, rules, [item()], random, { ...options,
    effectBonus(context) { trace.push(['effects', context.criticalMultiplier]); return 10; },
    damageFlags() { trace.push(['flags']); return 3; },
    damagePower(context) { trace.push(['power', context.target.id]); return 2; },
    immunity(amount, flags, context) { trace.push(['immunity', amount, flags, context]); return 65535; },
    resistance(amount, flags, context) { trace.push(['resistance', amount, flags, context]); return -2; },
    reduction(amount, power, context) { trace.push(['reduction', amount, power, context]); return -3; }
  });
  assert.equal(result.beforeMitigation, 14); assert.equal(result.amount, 0);
  assert.deepEqual(trace.map(t => t[0]), ['effects', 'flags', 'power', 'immunity', 'resistance', 'reduction']);
  assert.equal(trace[4][1], -1); assert.equal(trace[5][1], -2);
  assert.deepEqual(trace[4][3], { simulation: false, combat: true, baseWeapon: true, ranged: 0 });
});

test('effect floor and signed short wrap are preserved rather than clamping pre-mitigation damage to unsigned', () => {
  assert.equal(damageRoll(actor([], 2), null, rules, [item()], draws([1]), { ...options, effectBonus: () => 7 }).amount, 7);
  assert.equal(damageRoll(actor(), null, rules, [item()], draws([32767]), { ...options, effectBonus: () => 2 }).amount, 2);
  assert.throws(() => damageRoll(actor(), { objectType: 5 }, rules, [item()], draws([]), options), /providers/);
  assert.throws(() => damageRoll(actor(), null, rules, [], draws([]), { ...options, attack: {} }), /providers/);
});

test('sneak ladders stack highest tiers and use pending feat state without summing lower tiers', () => {
  assert.equal(sneakDamageDice([842, 851, 221, 1041, 460, 1018]), 45);
  assert.equal(sneakDamageDice([221], [345, 1007]), 6);
  assert.equal(deathDamageDice([455, 1006, 1030]), 20);
  assert.equal(deathDamageDice([], [455]), 1);
});

test('difficulty selection distinguishes exact actor PC flag, possessed target and direction-specific option', () => {
  const a = actor(), target = { objectType: 5, isPC: true };
  assert.deepEqual(damageDifficulty(a, target, id => id * 10), { playerToNpc: 0, npcToPlayer: 1, percentage: 40 });
  a.creatureData.IsPC = 1; target.isPC = false;
  assert.deepEqual(damageDifficulty(a, target, id => id * 10), { playerToNpc: 1, npcToPlayer: 0, percentage: 30 });
  target.isPossessedFamiliar = true;
  assert.deepEqual(damageDifficulty(a, target, () => assert.fail()), difficulty);
  a.creatureData.IsPC = 2;
  assert.deepEqual(damageDifficulty(a, { objectType: 5 }, () => assert.fail()), difficulty);
});
