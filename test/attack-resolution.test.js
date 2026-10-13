import test from 'node:test';
import assert from 'node:assert/strict';
import { resolveAttackRoll, resolveConcealment, ATTACK_RESULT as R } from '../src/attack_roll.js';
import { NativeRandom } from '../src/native_random.js';
import { armorClassVersus } from '../src/combat_context.js';
import { attacksPerRound, criticalProfile, isFlatFooted } from '../src/combat_weapon.js';
import { effectImmunity } from '../src/effect_immunity.js';
import { attackModifierVersus, favoredEnemyBonus } from '../src/attack_modifier.js';
import { createCombatRound, initializeNumberOfAttacks, startCombatRound, endCombatRound, weaponAttackType } from '../src/combat_round.js';
import { parse2da } from '../src/area.js';

const table = (columns, body) => parse2da(`2DA V2.0\n\n${columns}\n${body}`);
const rules = { appearance: table('SIZECATEGORY', '42 3'), racialtypes: table('Label', '0 Human'), baseitems: table('CritThreat CritHitMult WeaponImprovedCriticalFeat WeaponOfChoiceFeat WeaponWield IsMonkWeapon WeaponType WeaponSize RangedWeapon WeaponFinesseMinimumCreatureSize', '99 2 3 60 900 1 1 1 3 0 2') };
const acEffect = (type, cat, amount, race = 28) => ({ type, integers: [cat, amount, race, 0, 0, 4103] });
function creature(feats = [], dex = 4) {
  return { id: 1, creatureData: { Race: 0, Appearance_Type: 0, ClassList: [{ Class: 0, ClassLevel: 1 }], SkillList: [] },
    stats: { feats, level: 16, equippedAbilities: { Str: 12, Dex: 18, Con: 10, Wis: 16, Int: 10, Cha: 14 }, combat: { baseAttackBonus: 18, baseAttackBonusWithoutEpic: 16, finalBreakdown: { armor: {
      natural: { authored: 2, classGains: [], dwarvenDefender: 0, armorSkin: 0, monkWisdom: 0, monkLevels: 0 },
      components: { dexterity: dex }, cache: { up: [25, 0, 0, 0, 3], down: [0, 0, 0, 0, 0] }, monkAbilities: false
    } } } }, itemCombatEffects: { effects: [] } };
}
const context = { flatFooted: false, visibility: { seen: true } };
const ac = (d, a, options = {}) => armorClassVersus(d, a, rules, [], { ...context, ...options });
function rolls(values) {
  const seen = [];
  return { seen, dice(count, sides) { seen.push([count, sides]); assert.ok(values.length); return values.shift(); } };
}
const options = { modifier: () => 5, armorClass: () => 15, criticalThreat: () => 19, resolveDefense: () => null };

test('natural attack outcomes and confirmation use different native predicates', () => {
  assert.equal(resolveAttackRoll(rolls([1]), { ...options, modifier: () => 100 }).result, R.MISS);
  assert.equal(resolveAttackRoll(rolls([20, 20]), { ...options, modifier: () => -10 }).result, R.HIT, 'Natural 20 hits; confirmation total 10 fails');
  const critical = resolveAttackRoll(rolls([19, 1]), { ...options, modifier: () => 14 });
  assert.equal(critical.result, R.CRITICAL, 'Confirmation natural 1 succeeds at AC 15');
  assert.equal(critical.confirmation, 1); assert.equal(critical.threatened, true);
  const immuneRandom = rolls([19, 20]);
  assert.equal(resolveAttackRoll(immuneRandom, { ...options, criticalImmune: true }).result, R.HIT);
  assert.equal(immuneRandom.seen.length, 2, 'Immunity is checked after confirmation draw');
});

test('actual attack modifier mutates separate round counters and uses the overall index for normal attacks', () => {
  const actor = creature(), round = createCombatRound(), attack = { weaponAttackType: 1, ranged: 0, attackType: 0 };
  const query = () => attackModifierVersus(actor, null, rules, [], { round, attack });
  assert.equal(query().total, 19);
  round.currentAttack = 2; assert.equal(query().total, 9);
  attack.weaponAttackType = 2; assert.equal(query().parts.iteration, 0); assert.equal(query().parts.iteration, -5);
  attack.weaponAttackType = 6; attack.attackType = 867; assert.equal(query().parts.iteration, 0);
  attack.attackType = 0; assert.equal(query().parts.iteration, -5, 'Special extra attack still advances the extra counter');
  attack.weaponAttackType = 1; attack.attackType = 65002; assert.equal(query().parts.iteration, 0);
});

test('ranged attack uses native five-metre point-blank threshold and target animation/perception modifiers', () => {
  const actor = creature([27, 584]), target = creature(); actor.position = [0, 0, 0]; target.position = [5, 0, 0];
  target.animationState = 4; target.creatureState = 6; target.blind = true;
  const round = createCombatRound(), attack = { weaponAttackType: 1, ranged: 1, attackType: 0 };
  const context = { round, attack, visibility: { seen: false }, attackerInvisible: true, flanking: true };
  const result = attackModifierVersus(actor, target, rules, [], context);
  assert.equal(result.total, 26, 'BAB18 + Dex4 + prowess1 + blind2 + invis2 - noSight4 - moving2 + stunned2 + flank2 + PBS1');
  assert.equal(result.parts.pointBlank, 1);
  target.position[0] = 5.01; assert.equal(attackModifierVersus(actor, target, rules, [], context).parts.pointBlank, 0);
  assert.throws(() => attackModifierVersus(actor, target, rules, [], { round, attack }), /perception/);
});

test('Favored Enemy uses native race defaults, stored acquisition class and explicit table overrides', () => {
  const actor = creature([273]), target = creature(); target.creatureData.Race = 12;
  assert.equal(favoredEnemyBonus(actor, target, rules), 4);
  actor.creatureData.IsPC = 1; actor.creatureData.LvlStatList = [{ LvlStatClass: 32, FeatList: [{ Feat: 273 }] }];
  actor.creatureData.ClassList = [{ Class: 32, ClassLevel: 12 }];
  assert.equal(favoredEnemyBonus(actor, target, rules), 4);
  const override = table('FavoredEnemyFeat', Array.from({ length: 13 }, (_, i) => `${i} ****`).join('\n'));
  assert.equal(favoredEnemyBonus(actor, target, { ...rules, racialtypes: override }), 0, 'Present column clears empty entries instead of using built-in defaults');
});

test('native round initialization schedules compressed animation groups and consumes NPC combat-step draws', () => {
  const actor = creature(); actor.isPC = true; actor.combatAnimationSpeed = 0;
  const round = createCombatRound(), random = new NativeRandom(1);
  assert.equal(round.attackGroup, 255); assert.equal(round.length, 0);
  startCombatRound(round, actor, 2, [], rules, random, { initialCombatStep: false });
  assert.equal(round.onhandAttacks, 4); assert.equal(round.length, 3000);
  assert.deepEqual(round.actions.map(a => [a.time, a.count, a.duration]), [[500, 2, 857], [1500, 1, 857], [2500, 1, 857]]);
  assert.equal(random.draws, 0);
  const order = [];
  endCombatRound(round, actor, rules, { processPending() { order.push('pending'); assert.equal(round.started, false); assert.equal(round.actions.length, 3); },
    isDead: () => false, roundEnd() { order.push('script'); assert.equal(round.actions.length, 0); } });
  assert.deepEqual(order, ['pending', 'script']); assert.equal(round.attacksOfOpportunity, 1);
  actor.isPC = false;
  startCombatRound(round, actor, 2, [], rules, random, { initialCombatStep: false });
  assert.equal(random.draws, 1); assert.equal(round.length,2500);
  assert.ok(round.actions.some(a => a.nativeActionType===4&&a.time===34&&a.duration===500));
});

test('number of attacks handles crossbows, haste, invalid modes and natural-weapon selection draws', () => {
  const actor = creature([411]); actor.combatMode = 6; actor.hasted = true;
  const r = { ...rules, baseitems: table('RangedWeapon WeaponType WeaponSize WeaponWield IsMonkWeapon', Array.from({ length: 8 }, (_, i) => `${i} 1 1 3 0 0`).join('\n')) };
  const round = createCombatRound(), items = [{ slot: 16, data: { BaseItem: 6 } }];
  assert.equal(initializeNumberOfAttacks(round, actor, items, r), 6); assert.equal(actor.combatMode, 0); assert.equal(round.offhandAttacks, 0);
  const natural = [{ slot: 16384 }, { slot: 32768 }, { slot: 65536 }], random = new NativeRandom(1);
  assert.equal(weaponAttackType(round, natural, random), 3); assert.equal(random.draws, 2);
  round.currentAttack = 4; round.offhandAttacks = 1; round.onhandAttacks = 4; round.additionalAttacks = 0;
  assert.equal(weaponAttackType(round, items, random), 2);
});

test('roll order, coup draw consumption and defense precedence match native control flow', () => {
  const order = [], random = { dice() { order.push('roll'); return 1; } };
  const result = resolveAttackRoll(random, { ...options, modifier() { order.push('modifier'); return 0; }, armorClass() { order.push('ac'); return 20; },
    resolveSneakAndDeath() { order.push('sneak'); }, coupDeGrace: true, resolveDefense() { assert.fail(); } });
  assert.deepEqual(order, ['roll', 'modifier', 'ac', 'sneak']); assert.equal(result.roll, 20); assert.equal(result.result, R.COUP_DE_GRACE);
  assert.equal(resolveAttackRoll(rolls([1]), { ...options, resolveDefense: () => ({ result: R.CONCEALED, missedBy: 1 }) }).result, R.CONCEALED);
  assert.throws(() => resolveAttackRoll(rolls([5]), { ...options, resolveDefense: null }), /unavailable/);
});

test('parry attempts precede miss decisions, consume a slot and queue riposte only at the threshold', () => {
  let ripostes = 0; const parry = { eligible: true, remaining: 2, rank: 10, onRiposte() { ripostes++; } };
  assert.equal(resolveAttackRoll(rolls([2, 7]), { ...options, parry }).result, R.PARRIED);
  assert.equal(ripostes, 1); assert.equal(parry.remaining, 1);
  resolveAttackRoll(rolls([20, 1]), { ...options, parry }); assert.equal(parry.remaining, 1, 'Natural 20 bypasses parry');
});

test('concealment is strict, equal chances choose miss chance and Blind Fight consumes a conditional reroll', () => {
  assert.equal(resolveConcealment(rolls([50]), { concealment: 50 }), null);
  assert.equal(resolveConcealment(rolls([49]), { concealment: 50 }).result, R.CONCEALED);
  assert.equal(resolveConcealment(rolls([49]), { concealment: 50, missChance: 50 }).result, R.MISS_CHANCE);
  const random = rolls([49, 50]);
  assert.equal(resolveConcealment(random, { concealment: 50, blindFight: true }), null);
  assert.deepEqual(random.seen, [[1, 100], [1, 100]]);
});

test('AC versus uses visibility, Dodge target state, negative Dexterity and Uncanny Dodge', () => {
  const target = creature([10]), attacker = creature(); attacker.id = 2;
  assert.equal(ac(target, attacker).total, 40);
  assert.equal(target.combatRound.dodgeTargetId, 2);
  attacker.id = 3; assert.equal(ac(target, attacker).parts.dodgeFeat, 0);
  assert.equal(ac(target, attacker, { flatFooted: true }).total, 15);
  const negative = creature([], -2);
  assert.equal(ac(negative, attacker, { flatFooted: true }).parts.dexterity, -2);
  assert.equal(ac(negative, attacker, { attackerInvisible: true }).parts.dexterity, 0, 'Invisible but not flat-footed drops negative Dex too');
  target.stats.feats.push(195); assert.equal(ac(target, attacker, { flatFooted: true }).parts.dexterity, 4);
  const blind = creature([408]);
  assert.equal(ac(blind, attacker, { visibility: { present: false, seen: false } }).parts.dexterity, 0);
  assert.equal(ac(blind, attacker, { visibility: { present: true, seen: false } }).parts.dexterity, 4);
  assert.equal(ac(blind, attacker, { visibility: { seen: false }, ranged: true }).parts.dexterity, 0);
  assert.throws(() => ac(target, attacker, { visibility: null }), /visibility/);
});

test('touch AC and contextual conditional penalties preserve target native quirks', () => {
  const target = creature(), attacker = creature();
  target.effects = [acEffect(48, 0, 30, 0), acEffect(49, 3, 5, 0), acEffect(49, 4, 20, 0)];
  let result = ac(target, attacker);
  assert.equal(result.parts.conditionalDodge, 30, 'Conditional Dodge is added after ordinary cap');
  assert.equal(result.parts.categoryEffects, -7, 'Shield penalty counts again as deflection; conditional deflection penalty is ignored');
  result = ac(target, attacker, { touch: true, flatFooted: true });
  assert.equal(result.total, 43, 'Conditional Dodge survives touch and flat-footed branches');
});

test('native weapon critical profile and attack count use physical rows and pre-epic BAB', () => {
  const c = creature([60, 885, 883, 900]), item = { slot: 16, data: { BaseItem: 0, PropertiesList: [{ PropertyName: 43 }] } };
  assert.deepEqual(criticalProfile(c, [item], rules), { threat: 13, multiplier: 4 });
  assert.equal(attacksPerRound(c, [item], rules), 4);
  c.stats.combat.finalBreakdown.armor.monkAbilities = true;
  assert.equal(attacksPerRound(c, [item], rules), 6);
  c.stats.combat.baseAttackBonusWithoutEpic = 0; assert.equal(attacksPerRound(c, [], rules), 1);
});

test('flat-footed native perception flags, animation and feat gates remain explicit', () => {
  const c = creature(); c.creatureState = 0; c.creatureAnimation = 9; c.perceptionUpdateFlags = 6;c.visionFlags=0;
  assert.equal(isFlatFooted(c), false);
  c.perceptionUpdateFlags = 0; assert.equal(isFlatFooted(c), true);
  c.combatMode = 11; assert.equal(isFlatFooted(c), false);
  c.visionFlags = 0x10; assert.equal(isFlatFooted(c), true);
  c.stats.feats.push(226); assert.equal(isFlatFooted(c), false);
  c.creatureState = 6; assert.equal(isFlatFooted(c), true);
});

test('immunity queries combine plot, built-in feats and target-conditioned live effects', () => {
  const root = { FeatList: [{ Feat: 894 }] }, conditional = { type: 22, integers: [20, 3, 2, 4] };
  assert.equal(effectImmunity(root, [], 12), true); assert.equal(effectImmunity(root, [], 6), true);
  assert.equal(effectImmunity(root, [], 12, null, { includeFeats: false }), false);
  assert.equal(effectImmunity(root, [conditional], 20), false);
  assert.equal(effectImmunity(root, [conditional], 20, { Race: 3, LawfulChaotic: 70, GoodEvil: 70 }), true);
  assert.equal(effectImmunity({ Plot: 1 }, [], 25, null, { includeFeats: false }), true);
});

test('script dice clamp before byte narrowing; Random zero consumes nothing and negative bounds negate results', () => {
  const random = new NativeRandom(1);
  assert.equal(random.random(0), 0); assert.equal(random.draws, 0);
  assert.equal(random.random(-10), -1);
  assert.equal(random.scriptDice(0, 20), 8);
  assert.equal(random.scriptDice(256, 20), 0); assert.equal(random.draws, 2);
});
