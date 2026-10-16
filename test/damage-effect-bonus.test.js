import test from 'node:test';
import assert from 'node:assert/strict';
import { parse2da } from '../src/area.js';
import { damageEffectBonus, damageEffectBonusAsync, selectDamageEffects, damageBonusEffectIntegers } from '../src/damage_effect_bonus.js';
import { itemDamageEffects } from '../src/damage_item_effects.js';
import { equipmentCombatEffects } from '../src/combat_modifiers.js';
import { damageRoll } from '../src/damage_roll.js';
import { ModuleSession } from '../src/module_session.js';
import { NativeRandom } from '../src/native_random.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

const table = (columns, rows) => parse2da(`2DA V2.0\n\n${columns}\n${rows}`);
const rules = () => ({
  iprp_damagecost: table('Rank NumDice Die', '0 0 0 0\n1 10 0 2\n2 30 0 9\n3 20 1 6\n4 30 0 4\n5 40 2 4\n6 50 0 7\n7 60 0 8\n8 70 0 5\n9 80 0 6'),
  damagetypes: table('Label', Array.from({ length: 13 }, (_, i) => `${i} Type`).join('\n')),
  baseitems: table('WeaponType WeaponWield CritHitMult NumDice DieToRoll AmmunitionType EquipableSlots',
    '0 1 0 3 1 8 2 16\n1 3 8 2 1 4 **** 32\n2 0 0 1 0 0 **** 2048'),
  itemCosts: new Map([[2, table('Value', '0 0\n1 1\n2 2\n3 3\n4 6')], [20, table('Value', '0 0\n1 -1\n2 -2')]])
});
const actor = () => ({ creatureData: { Race: 0, ClassList: [], FeatList: [], GoodEvil: 75, LawfulChaotic: 75 },
  position: [0, 0, 0], objectType: 5, effects: [], stats: { feats: [], equippedAbilities: { Str: 10 }, combat: {} } });
const effect = (cost, flags = 1, hand = 0, spellId = -1, type = 13, subject = [28, 0, 0]) =>
  ({ type, integers: [cost, flags, ...subject, hand], spellId });
const item = (base, slot, properties = []) => ({ id: slot, slot, data: { BaseItem: base, PropertiesList: properties } });
const attack = { weaponAttackType: 1, ranged: 0, attackType: 0, result: 1 };
function query(effects, options = {}, r = rules(), gear = []) {
  return damageEffectBonus(actor(), null, r, gear, new NativeRandom(1), { attack, effects, ...options });
}
function dice(values) {
  const trace = [];
  return { trace, dice(count, die) { trace.push([count, die]); assert.ok(values.length, 'Unexpected dice query'); return values.shift(); } };
}

test('damage bonus constructors validate active physical cost count and damage flags, retaining cost zero', () => {
  const r = rules();
  assert.deepEqual(damageBonusEffectIntegers(9, undefined, r), [9, 8, 28]);
  assert.deepEqual(damageBonusEffectIntegers(10, -1, r), [0, 8, 28]);
  assert.deepEqual(damageBonusEffectIntegers(-3, 0, r), [0, 0, 28]);
  assert.deepEqual(damageBonusEffectIntegers(2, 8191, r), [2, 8191, 28]);
  assert.deepEqual(damageBonusEffectIntegers(2, 8192, r), [2, 8, 28]);
  assert.throws(() => damageBonusEffectIntegers(1, 1, {}), /cost rules/);
});

test('generic sources group by spell AND exact flags; item creators and unsourced effects still stack', () => {
  const effects = [effect(1, 1, 0, 20), effect(2, 1, 0, 20), effect(1, 2, 0, 20),
    { ...effect(1), creatorId: 0x80000001 }, { ...effect(1), creatorId: 0x80000001 }, effect(1, 1, 0, 20, 14)];
  const result = query(effects);
  assert.equal(result.increase, 15); assert.equal(result.decrease, 2); assert.equal(result.total, 13);
  assert.deepEqual(result.selection.generic[0].map(s => s.cost), [2, 1, 1, 1]);
  assert.equal(query(Array.from({ length: 60 }, () => effect(1)), { limit: 1000 }).total, 100, 'Fifty generic slots per sign');
});

test('specific selection uses Rank, keeps first ties, and preserves highest-index/hand aliases', () => {
  const effects = [effect(3, 3, 1), effect(2, 2, 1), effect(4, 2, 3), effect(1, 4, 2), effect(1, 1, 7)];
  const selected = selectDamageEffects(effects, rules(), { hand: 6 });
  assert.equal(selected.specific[0][1], 2, 'Higher Rank beats cost ordering and ties preserve first');
  assert.equal(selected.specific[0][2], -1, 'Offhand is not the hand-6 alias');
  assert.equal(query(effects, { attack: { ...attack, weaponAttackType: 8 } }).total, 2, 'Hand 8 accepts hand 7');
  assert.equal(query([effect(1, 1, 2)], { attack: { ...attack, weaponAttackType: 0 }, offhand: true }).total, 2);
});

test('versus race/alignment and physical/energy split filter before selection', () => {
  const effects = [effect(1, 1, 0, -1, 13, [0, 2, 4]), effect(2, 1, 0, -1, 13, [1, 0, 0]),
    effect(1, 8), effect(1, 9)];
  assert.equal(query(effects, { versus: { race: 0, lawChaos: 2, goodEvil: 4 } }).total, 4, 'Mixed physical/energy flags stay in physical query');
  assert.equal(query(effects).total, 2, 'Unresolved target only admits unconditional entries');
});

test('dice run specific index/sign order then generic slot/sign order, rerolling each critical multiplier', () => {
  const random = dice([1, 2, 3, 4, 5, 6, 7, 8, 9]);
  const effects = [effect(3, 2, 0), effect(5, 1, 1, -1, 14), effect(3, 1, 1)];
  const result = damageEffectBonus(actor(), null, rules(), [item(0, 16)], random, { attack: { ...attack, result: 3 }, effects });
  assert.deepEqual(random.trace, [...Array(3).fill([1, 6]), ...Array(3).fill([2, 4]), ...Array(3).fill([1, 6])]);
  assert.deepEqual(result.entries.map(entry => entry.amount), [6, 15, 24]);
  assert.equal(result.total, 15);
});

test('caps apply separately AFTER every selected dice roll and retain signed native limits', () => {
  const random = dice([6, 4, 5, 3]);
  const result = damageEffectBonus(actor(), null, rules(), [], random,
    { attack, effects: [effect(3), effect(3), effect(3, 1, 0, -1, 14), effect(3, 1, 0, -1, 14)], limit: 8 });
  assert.equal(result.increase, 11); assert.equal(result.decrease, 7); assert.equal(result.total, 1);
  assert.equal(random.trace.length, 4);
  assert.equal(query([effect(1)], { limit: -2 }).total, 0);
});

test('maximized dice use full int32 products while ordinary RollDice narrows byte arguments', () => {
  const r = rules(); r.iprp_damagecost = table('Rank NumDice Die', '0 0 0 0\n1 1 257 258');
  const random = dice([2]);
  assert.equal(damageEffectBonus(actor(), null, r, [], random, { attack, effects: [effect(1)] }).total, 2);
  assert.deepEqual(random.trace, [[1, 2]]);
  assert.equal(query([effect(1)], { maximize: true, limit: 100000 }, r).total, 66306);
});

test('energy positives mitigate before AddDamage; legacy generic flags and ruleset fix are distinct', () => {
  const a = actor(), target = actor(), r = rules(), trace = [], records = [];
  const options = { attack, energy: true, effects: [effect(2, 8, 1), effect(1, 16)],
    immunity(n, flags) { trace.push(['immunity', n, flags]); return n - 1; },
    resistance(n, flags) { trace.push(['resistance', n, flags]); return n - 1; },
    addDamage(flags, n) { records.push([flags, n]); } };
  assert.equal(damageEffectBonus(a, target, r, [], new NativeRandom(1), options).total, 7);
  assert.deepEqual(trace, [['immunity', 9, 8], ['resistance', 8, 8], ['immunity', 2, 0x80000000], ['resistance', 1, 0x80000000]]);
  assert.deepEqual(records, [[8, 7], [16, 0]]);
  r.ruleset = table('Label Value', '0 FIX_EFFECTDAMAGEINCREASE_BYPASSING_DR_AND_DI 1'); trace.length = 0;
  damageEffectBonus(a, target, r, [], new NativeRandom(1), options);
  assert.deepEqual(trace.at(-1), ['resistance', 1, 16]);
});

test('generic energy penalties mutate attack data without reducing returned total, including maximize', () => {
  const records = [];
  const result = query([effect(1, 8, 1, -1, 14), effect(2, 8, 0, -1, 14)],
    { energy: true, maximize: true, addDamage: (...args) => records.push(args) });
  assert.equal(result.total, -2); assert.equal(result.decrease, 2);
  assert.deepEqual(records, [[8, -2], [8, -9]]);
  assert.equal(query([effect(1, 0, 0)], { energy: true }).total, 2, 'Zero flag takes energy filter but its component is not an energy index');
});

test('unavailable energy or trap context fails before consuming RNG', () => {
  const random = new NativeRandom(1);
  assert.throws(() => damageEffectBonus(actor(), actor(), rules(), [], random,
    { attack, energy: true, effects: [effect(3, 8)] }), /providers are unavailable/);
  assert.equal(random.draws, 0);
  assert.throws(() => damageEffectBonus(actor(), { objectType: 7 }, rules(), [], random, { attack }), /trap creator/);
  assert.equal(random.draws, 0);
});

test('async energy mitigation awaits each stage before publishing its attack component', async () => {
  const trace = [], random = new NativeRandom(1);
  const result = await damageEffectBonusAsync(actor(), actor(), rules(), [], random, {
    attack, energy: true, effects: [effect(1, 8)],
    async immunity(n) { trace.push('immunity'); await Promise.resolve(); return n; },
    async resistance(n) { trace.push('resistance'); await Promise.resolve(); return n - 1; },
    async addDamage(flags, n) { trace.push([flags, n]); }
  });
  assert.deepEqual(trace, ['immunity', 'resistance', [8, 1]]); assert.equal(result.total, 1);
});

test('ammunition is selected by active base-item ammo slot and merged by Rank, penalties by raw cost', () => {
  const r = rules(), gear = [item(0, 16), item(2, 2048, [{ PropertyName: 16, Subtype: 1, CostValue: 2 },
    { PropertyName: 21, CostValue: 4 }, { PropertyName: 17, Subtype: 4, Param1Value: 1, CostValue: 1 }])];
  const result = query([effect(3, 2, 1), effect(2, 2, 1, -1, 14)],
    { attack: { ...attack, ranged: 1 }, versus: { race: 0, lawChaos: 2, goodEvil: 4 } }, r, gear);
  assert.equal(result.total, 5); assert.equal(result.selection.specific[0][1], 2);
  assert.equal(result.selection.specific[1][1], 4, 'Raw higher ammo cost wins even though ranks tie');
  assert.equal(query([], { attack: { ...attack, ranged: 2 } }, r, gear).total, 0);
});

test('invalid combined ammunition slots discard bonuses and retain the native warning', () => {
  const r = rules();
  r.baseitems = table('WeaponType AmmunitionType EquipableSlots', '0 1 1 16\n1 0 0 3072');
  const result = query([], { attack: { ...attack, ranged: 1 } }, r,
    [item(0, 16), item(1, 3072, [{ PropertyName: 16, Subtype: 1, CostValue: 2 }])]);
  assert.equal(result.total, 0); assert.equal(result.selection.warnings[0].slot, 3072);
  assert.equal(result.selection.warnings[0].code, 'combat.inventory-slot-warning');
  const projection = itemDamageEffects(item(1, 16), { PropertyName: 6, CostValue: 1 }, r);
  assert.ok(projection.warnings.some(w => w.includes('no weapon type')));
});

test('item projection preserves conditional subjects, double-weapon hands, ammunition exclusion and +6 lookup', () => {
  const r = rules(), a = actor(), gear = item(1, 16);
  const projection = itemDamageEffects(gear, { PropertyName: 9, Subtype: 6, CostValue: 4 }, r);
  assert.deepEqual(projection.effects.map(e => e.integers), [[9, 4, 28, 3, 4, 2], [9, 4, 28, 3, 4, 1]]);
  assert.equal(projection.effects[0].creatorId, 16);
  assert.deepEqual(itemDamageEffects(item(20, 2048), { PropertyName: 16, CostValue: 1 }, r).effects, []);
  const decrease = equipmentCombatEffects([item(0, 16, [{ PropertyName: 10, CostValue: 2 }])], r,
    { root: a.creatureData, initialEffects: [{ type: 22, integers: [20, 28, 0, 0] }] });
  assert.deepEqual(decrease.effects.map(e => e.type), [14], 'Attack immunity does not block separate enhancement damage penalty');
  assert.deepEqual(itemDamageEffects(item(0, 16), { PropertyName: 21, CostValue: 2 }, r,
    { root: a.creatureData, effects: [{ type: 22, integers: [21, 28, 0, 0] }] }).effects, []);
});

test('GetDamageRoll uses equipped damage effects by default and main-hand effect critical profile for offhand', () => {
  const a = actor(), r = rules(), gear = [item(0, 16), item(1, 32, [{ PropertyName: 6, CostValue: 1 }])], random = dice([1, 1]);
  const result = damageRoll(a, null, r, gear, random, { attack: { ...attack, weaponAttackType: 2 },
    offhand: true, critical: true, difficulty: { playerToNpc: 0, npcToPlayer: 0, percentage: 100 }, damageFlags: () => 4,weaponAttackType:()=>2 });
  assert.equal(result.base, 2); assert.equal(result.criticalMultiplier, 2);
  assert.equal(result.effects, 6, 'Effect fixed +2 is multiplied by main-hand 3, not offhand 2');
  assert.equal(result.amount, 8);
});

test('live damage bonuses preserve handles, record dirty state, reject immunity, and expire strictly after due time', async () => {
  const s = new ModuleSession(null), r = rules(); s.characterRules = r;
  const a = s.register('creature', 'a', { ...actor(), stats: { feats:[],currentHP: 10, temporaryHP: 0, maxHP: 10 } });
  const b = s.register('door', 'b', { currentHP: 10 });
  const value = s.commands.EffectDamageIncrease([1, 1], { self: a.id });
  assert.equal(s.commands.GetEffectType([value]), 42);
  await s.commands.ApplyEffectToObject([1, value, a.id, 1]);
  assert.equal(a.effects[0].id, value.id); assert.equal(a.combatInformationDirty, 1);
  assert.equal(value.durationType, 0); a.combatInformationDirty = 0;
  s.scheduler.advance(1000); await s.scheduler.pump(); assert.deepEqual(a.effects.map(e=>e.type),[13,67]);
  s.scheduler.advance(1); await s.scheduler.pump(); assert.equal(a.effects.length, 0); assert.equal(a.combatInformationDirty, 1);
  const penalty = s.commands.EffectDamageDecrease([0, 1], { self: a.id });
  assert.equal(s.commands.GetEffectType([penalty]), 43);
  await s.commands.ApplyEffectToObject([2, penalty, b.id]); assert.deepEqual(b.effects, []);
  a.effects = [{ type: 22, integers: [21, 28, 0, 0] }];
  await s.commands.ApplyEffectToObject([2, penalty, a.id]); assert.equal(a.effects.length, 1);
  await s.commands.ApplyEffectToObject([2, { ...penalty, bypassImmunity: true }, a.id]);
  assert.equal(a.effects[0].id, penalty.id, 'Zero-cost penalty is retained; no positive-amount gate');
  assert.equal(s.commands.GetEffectCreator([a.effects[0]]), a.id);
  assert.equal(s.commands.GetMaster([OBJECT_INVALID]), OBJECT_INVALID);
});
