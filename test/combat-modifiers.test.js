import assert from 'node:assert/strict';
import test from 'node:test';
import { parse2da } from '../src/area.js';
import { armorClass, armorEffectCache, attackBonuses, attackEffectBonus, cappedDexterityModifier, equipmentCombatEffects, finalCombatStats, itemArmorClass, savingThrowEffectBonus } from '../src/combat_modifiers.js';
import { characterStats } from '../src/character.js';
import { ModuleSession } from '../src/module_session.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

const table = (columns, lines, defaults = '') => parse2da(`2DA V2.0\n${defaults}\n\n${columns}\n${lines}`);
function rules() {
  const zero = table('BAB FortSave RefSave WillSave', Array.from({ length: 60 }, (_, i) => `${i} 0 0 0 0`).join('\n'));
  return { ruleset: table('Label Value', '0 **** ****'),
    classes: table('AttackBonusTable SavingThrowTable StatGainTable', Array.from({ length: 41 }, (_, i) => `${i} zero zero ****`).join('\n')),
    classTables: new Map([['zero', zero]]), gains: new Map(), epicattacks: zero, epicsaves: zero,
    racialtypes: table('StrAdjust', '0 0'), exptable: table('XP', '0 0\n1 1000'),
    baseitems: { rows: new Map([[0, { ModelType: '0', WeaponType: '1', WeaponSize: '3', WeaponWield: '1', WeaponFinesseMinimumCreatureSize: '1', WeaponFocusFeat: '100', EpicWeaponFocusFeat: '630' }],
      [16, { ModelType: '3', AC_Enchant: '2' }], [14, { ModelType: '0', BaseAC: '2', AC_Enchant: '3' }],
      [19, { ModelType: '0', AC_Enchant: '0' }], [52, { ModelType: '0', AC_Enchant: '4' }]]) },
    armor: table('dexbonus', '0 100\n1 8\n2 6\n3 4\n4 4\n5 2\n6 1\n7 1\n8 1'),
    parts_chest: table('ACBonus', '0 0\n1 8\n2 1.5\n3 -1.5'), appearance: table('SIZECATEGORY', '0 3'),
    itemCosts: new Map([[1, table('Value', '0 0\n1 1\n2 2\n3 3')], [2, table('Value', '0 0\n1 1\n2 2\n3 3\n4 4')], [20, table('Value', '0 0\n1 -1\n2 -2')]]) };
}
function root(classes = [{ Class: 0, ClassLevel: 1 }], feats = []) {
  return { ClassList: classes, FeatList: feats.map(Feat => ({ Feat })), SkillList: [], NaturalAC: 0,
    Str: 12, Dex: 18, Con: 10, Int: 10, Wis: 16, Cha: 8, Race: 0, Appearance_Type: 0, Experience: 0,
    HitPoints: 8, CurrentHitPoints: 8, LvlStatList: classes.flatMap(c => Array.from({ length: c.ClassLevel }, () => ({ LvlStatClass: c.Class, LvlStatHitDie: 8 }))) };
}
const mods = { Str: 1, Dex: 4, Con: 0, Int: 0, Wis: 3, Cha: -1 };
const base = { baseAttackBonus: 6, baseSaves: { fortitude: 2, reflex: 3, will: 4 } };
const item = (baseId, slot = 16, PropertiesList = [], extra = {}) => ({ id: slot + 100, slot, data: { BaseItem: baseId, PropertiesList, ...extra } });
const ac = (category, amount, type = 48) => ({ type, integers: [category, amount, 28, 0, 0, 4103] });
const save = (amount, spellId = -1, which = 0, type = 26) => ({ type, spellId, integers: [amount, which, 0, 28, 0, 0] });
const attack = (amount, hand = 0, type = 10, spellId = -1) => ({ type, spellId, integers: [amount, hand, 28, 0, 0] });

test('armor floats round ties upward and Dexterity caps test int positivity before signed-byte narrowing', () => {
  const r = rules();
  assert.equal(itemArmorClass(item(16, 2, [], { ArmorPart_Torso: 2 }), r), 2);
  assert.equal(itemArmorClass(item(16, 2, [], { ArmorPart_Torso: 3 }), r), -1);
  const chest = item(16, 2, [], { ArmorPart_Torso: 1 });
  assert.equal(cappedDexterityModifier(4, chest, r), 1);
  assert.equal(cappedDexterityModifier(-2, chest, r), -2);
  r.armor = table('DEXBONUS', '0 0', 'DEFAULT: 128');
  assert.equal(cappedDexterityModifier(4, chest, r), -128);
  r.armor = table('DEXBONUS', '0 0', 'DEFAULT: 0');
  assert.equal(cappedDexterityModifier(4, chest, r), 4, 'Zero means uncapped in the native function');
});

test('GetAC combines native byte components, strongest category bonuses and capped stacking Dodge', () => {
  const r = rules(), c = root(); c.NaturalAC = 2; c.SkillList[21] = { Rank: 14 };
  const gear = [item(16, 2, [], { ArmorPart_Torso: 1 }), item(14, 32)];
  const effects = [ac(2, 3), ac(2, 2), ac(3, 3), ac(4, 3), ac(1, 4), ac(0, 15), ac(0, 10)];
  const result = armorClass(c, r, mods, gear, effects);
  assert.deepEqual(result.components, { armor: 11, shield: 5, deflection: 3, natural: 6, dodge: 20, tumble: 2, dexterity: 1 });
  assert.equal(result.total, 58);
  assert.equal(armorClass(c, r, mods, gear, [ac(2, 120)]).components.armor, -128, 'Native narrows each category sum before adding to the short AC total');
  assert.equal(armorClass(c, r, mods, [], [ac(0, 2, 49)]).components.dodge, -2, 'Dodge has an upper cap, not a floor');
});

test('monk, Shou, defender and class table natural AC respect native equipment gates', () => {
  const r = rules(), c = root([{ Class: 5, ClassLevel: 10 }, { Class: 39, ClassLevel: 6 }, { Class: 34, ClassLevel: 2 }], [260, 490]);
  r.classes.orderedRows[34].StatGainTable = 'natural';
  r.classTables.set('natural', table('NaturalAC', '0 2\n1 0'));
  const bare = armorClass(c, r, mods, [], []);
  assert.equal(bare.monkAbilities, true); assert.equal(bare.components.natural, 11);
  assert.equal(armorClass(c, r, mods, [item(14, 32)], []).components.natural, 6);
  const light = item(16, 2, [], { ArmorPart_Torso: 2 });
  assert.equal(armorClass(c, r, mods, [light], []).monkAbilities, false);
  c.ClassList.push({ Class: 40, ClassLevel: 1 });
  assert.equal(armorClass(c, r, mods, [light], []).monkAbilities, true);
});

test('live natural-armor queries share transition/equipment flags and retain monk, feat and canonical base data',()=>{
 const r=rules(),c=root([{Class:5,ClassLevel:10},{Class:39,ClassLevel:6},{Class:34,ClassLevel:2}],[260,490]);c.NaturalAC=5;
 r.classes.orderedRows[34].StatGainTable='natural';r.classTables.set('natural',table('NaturalAC','0 2\n1 0'));
 const actor={creatureData:c,nativeField9f4:0,nativeField97c:0,nativeNaturalACD51:9},before=armorClass(c,r,mods,[],[],{actor});
 assert.equal(before.natural.authored,5);assert.equal(before.natural.classGains.reduce((n,v)=>n+v,0),2);
 for(const gate of ['nativeField9f4','nativeField97c']){actor[gate]=1;const during=armorClass(c,r,mods,[],[],{actor});assert.equal(during.natural.authored,9);assert.deepEqual(during.natural.classGains,[]);
  for(const key of ['monkWisdom','monkLevels','dwarvenDefender','armorSkin'])assert.equal(during.natural[key],before.natural[key]);assert.equal(during.components.natural-before.components.natural,2);assert.equal(c.NaturalAC,5);actor[gate]=0;
 }
 assert.deepEqual(armorClass(c,r,mods,[],[],{actor}),before);
});

test('script AC excludes size and opponent bonuses; conditional effects do not enter its cache', () => {
  const r = rules(), c = root(); r.appearance.orderedRows[0].SIZECATEGORY = '2';
  const conditional = ac(4, 10); conditional.integers[2] = 3;
  assert.equal(finalCombatStats(c, r, { Str: 10, Dex: 10, Con: 10, Int: 10, Wis: 10, Cha: 10 }, base, { effects: [conditional] }).armorClass, 10);
  assert.equal(armorEffectCache([ac(4, 130), ac(4, 2)]).up[4], 2, 'Initial native cache compares the prior signed byte against the new integer amount');
});

test('saving throw effects keep maxima per spell/item, stack unsourced effects and cap signs independently', () => {
  const c = root([{ Class: 32, ClassLevel: 10 }], [904]);
  const effects = [save(4, 9), save(2, 9), save(3), save(3), save(10, 10), save(8, 11), save(7, 9, 0, 27)];
  const result = savingThrowEffectBonus(c, effects, [], 1);
  assert.deepEqual(result, { increase: 20, decrease: 7, sacredDefense: 5, total: 18 });
  assert.equal(savingThrowEffectBonus(c, Array.from({ length: 55 }, () => save(1)), [], 1, { limit: 100 }).increase, 50);
  effects.push({ ...save(15, 9), creatorId: 200 }, { ...save(2, 8), creatorId: 200 });
  assert.equal(savingThrowEffectBonus(root(), effects, [{ id: 200 }], 1, { limit: 100 }).increase, 43);
});

test('final saves add Luck of Heroes, signed Dark Blessing and authored bonus fields, ignoring snapshots', () => {
  const r = rules(), c = root(undefined, [382, 473]);
  Object.assign(c, { fortbonus: 130, refbonus: -2, willbonus: 3, FortSaveThrow: 99 });
  const result = finalCombatStats(c, r, { Str: 12, Dex: 18, Con: 10, Int: 10, Wis: 16, Cha: 8 }, base);
  assert.deepEqual(result.saves, { fortitude: -124, reflex: 5, will: 10 });
  assert.equal(result.finalBreakdown.saves.fortitude.darkBlessing, -1);
});

test('save-specific item subtype order is Fortitude, Will, Reflex; cost tables are native handler choices', () => {
  const r = rules();
  r.itemCosts.set(20, table('Value', '0 0\n1 1\n2 2'));
  const gear = [item(52, 256, [{ PropertyName: 41, Subtype: 2, CostValue: 3, CostTable: 255 }, { PropertyName: 50, Subtype: 3, CostValue: 2 }])];
  const effects = equipmentCombatEffects(gear, r).effects;
  assert.equal(savingThrowEffectBonus(root(), effects, gear, 3).total, 3);
  assert.equal(savingThrowEffectBonus(root(), effects, gear, 2).total, 2, 'Common handler chooses the effect sign from the cost value');
  assert.equal(savingThrowEffectBonus(root(), effects, gear, 1).total, 0);
});

test('general save items read the native SavingThrowType column, with native fallback mapping', () => {
  const r = rules(), gear = [item(52, 256, [{ PropertyName: 40, Subtype: 0, CostValue: 2 }, { PropertyName: 40, Subtype: 5, CostValue: 3 }])];
  let effects = equipmentCombatEffects(gear, r).effects;
  assert.equal(savingThrowEffectBonus(root(), effects, gear, 1).total, 2);
  assert.equal(savingThrowEffectBonus(root(), effects, gear, 1, { saveType: 3 }).total, 3, 'Same item retains the stronger qualifying property');
  r.iprp_saveelement = table('SavingThrowType', '0 7\n1 ****');
  effects = equipmentCombatEffects(gear, r).effects;
  assert.equal(savingThrowEffectBonus(root(), effects, gear, 1).total, 0);
  assert.equal(savingThrowEffectBonus(root(), effects, gear, 1, { saveType: 7 }).total, 2);
});

test('equipped Haste contributes Dodge once and records its unimplemented movement/round consequences', () => {
  const r = rules(), gear = [item(19, 512, [{ PropertyName: 35 }]), item(19, 4, [{ PropertyName: 35 }])];
  const result = equipmentCombatEffects(gear, r);
  assert.equal(result.effects.length, 1); assert.equal(result.effects[0].integers[1], 4);
  assert.equal(result.unsupported.length, 2);
  assert.equal(armorClass(root(), r, mods, gear, result.effects).total, 18);
});

test('negative item effects reject missing immunity applicability instead of publishing approximate saves/attacks', () => {
  const r = rules();
  assert.throws(() => equipmentCombatEffects([item(52, 128, [{ PropertyName: 50, Subtype: 1, CostValue: 2 }])], r), /immunity provider/);
  assert.throws(() => equipmentCombatEffects([item(0, 16, [{ PropertyName: 10, CostValue: 2 }])], r), /immunity provider/);
});

test('invalid-slot attack penalties continue as generic effects while attack bonuses are discarded', () => {
  const r = rules(), gear = [item(19, 512, [{ PropertyName: 10, CostValue: 2 }, { PropertyName: 56, CostValue: 2 }])];
  const result = equipmentCombatEffects(gear, r, { root: root() });
  assert.deepEqual(result.effects.filter(e => e.type === 11).map(e => [e.type, ...e.integers]), [[11, 2, 0, 28, 0, 0]]);
  assert.ok(result.effects.some(e => e.type === 14 && e.integers[5] === 0), 'Separate damage penalty also retains a generic hand');
  assert.ok(result.unsupported.some(e => /generic attack effect applied/.test(e.reason)));
  assert.ok(result.unsupported.some(e => /discarded/.test(e.reason)));
});

test('attack effects distinguish generic source stacking, strongest weapon bonus and touch suppression', () => {
  const effects = [attack(5, 0, 10, 9), attack(2, 0, 10, 9), attack(3), attack(4, 1), attack(2, 1), attack(2, 1, 11)];
  assert.equal(attackEffectBonus(effects, [], 1).total, 10);
  assert.equal(attackEffectBonus(effects, [], 2).total, 8);
  assert.equal(attackEffectBonus(effects, [], 1, { touch: true }).total, 6);
  assert.equal(attackEffectBonus([attack(4, 3)], [], 6).total, 4);
  assert.equal(attackEffectBonus([{ ...attack(3), creatorId: 200 }, { ...attack(2), creatorId: 200 }], [{ id: 200 }], 1).total, 5,
    'Generic attack effects group by spell, even when their creator is an item');
});

test('melee and ranged providers preserve finesse, focus, Epic Prowess and touch branches', () => {
  const r = rules(), c = root(undefined, [42, 100, 630, 584]);
  assert.deepEqual(attackBonuses(c, r, mods, [], [], base, { size: 3 }), { melee: 14, offhand: 14, ranged: 13 });
  assert.deepEqual(attackBonuses(c, r, mods, [], [], base, { size: 3, touch: true }), { melee: 11, offhand: 11, ranged: 10 });
  const weapon = item(0);
  assert.equal(attackBonuses(c, r, mods, [weapon], [], base, { size: 0 }).melee, 11, 'Finesse needs the minimum creature size');
  r.baseitems.rows.get(0).RangedWeapon = '1';
  assert.equal(attackBonuses(c, r, mods, [weapon], [], base, { size: 3 }).melee, 0);
});

test('dual-wield penalties follow weapon size, double weapons and native feat/ruleset constants', () => {
  const r = rules(), c = root(undefined, [42, 100, 630, 584, 1, 41]);
  const right = item(0), left = item(0, 32); left.data.BaseItem = 1;
  r.baseitems.rows.set(1, { ...r.baseitems.rows.get(0), WeaponSize: '2' });
  const result = attackBonuses(c, r, mods, [right, left], [], base, { size: 3 });
  assert.equal(result.melee, 12); assert.equal(result.offhand, 12);
  r.baseitems.rows.get(0).WeaponWield = '8';
  const double = attackBonuses(c, r, mods, [right], [], base, { size: 3 });
  assert.equal(double.melee, 12); assert.equal(double.offhand, 12);
});

test('ranged Zen Archery, highest Enchant Arrow tier, Good Aim and halfling sling branches', () => {
  const r = rules(), c = root(undefined, [412, 449, 1045, 250]); c.Race = 3;
  r.baseitems.rows.set(61, { ModelType: '0', RangedWeapon: '1', WeaponWield: '11' });
  const result = attackBonuses(c, r, { ...mods, Wis: 5 }, [item(61)], [], base, { size: 2 });
  assert.equal(result.ranged, 19, '6 BAB + 5 Wis + 6 arrow + 1 Good Aim + 1 sling');
  assert.equal(attackBonuses(c, r, { ...mods, Wis: 5 }, [item(61)], [], base, { size: 2, touch: true }).ranged, 10);
});

function sessionFixture() {
  const r = rules(), c = root(), s = new ModuleSession(null); s.characterRules = r;
  const pc = s.register('player', 'pc', { isPC: true, authored: c, creatureData: c, stats: characterStats(c, r), inventory: [] });
  return { r, c, s, pc };
}

test('canonical script getters return the native invalid and noncreature values, and reject unavailable stats', () => {
  const { s, pc } = sessionFixture();
  assert.equal(s.commands.GetAC([pc.id]), 14);
  assert.equal(s.commands.GetAC([OBJECT_INVALID]), -1);
  const door = s.register('door', 'd', { authored: { Fort: 255, Ref: 3, Will: 4 } });
  assert.equal(s.commands.GetAC([door.id]), 0); assert.equal(s.commands.GetFortitudeSavingThrow([door.id]), 255);
  assert.equal(s.commands.GetReflexSavingThrow([door.id]), 3); assert.equal(s.commands.GetWillSavingThrow([OBJECT_INVALID]), 0);
  pc.stats.combat.saves = null;
  assert.throws(() => s.commands.GetWillSavingThrow([pc.id]), /not been loaded/);
});

test('temporary stat boosts preserve canonical identity, enumerate and remove with native deferred timing', async () => {
  const { s, pc } = sessionFixture(), shared = pc.stats, frame = { self: pc.id };
  const effect = s.commands.EffectSavingThrowIncrease([0, 3], frame);
  await s.commands.ApplyEffectToObject([1, effect, pc.id, 0.1]);
  assert.equal(s.commands.GetFortitudeSavingThrow([pc.id]), 3);
  assert.equal(s.commands.GetEffectType([effect]), 50);
  assert.equal(s.commands.GetFirstEffect([pc.id]).id, effect.id);
  s.commands.RemoveEffect([pc.id, s.commands.GetFirstEffect([pc.id])], frame);
  assert.equal(s.commands.GetFortitudeSavingThrow([pc.id]), 3, 'Hidden until scheduler deletion, still affects stats');
  await s.scheduler.pump();
  assert.equal(s.commands.GetFortitudeSavingThrow([pc.id]), 0);
  const attackEffect = s.commands.EffectAttackIncrease([2], frame);
  await s.commands.ApplyEffectToObject([1, attackEffect, pc.id, 0.1]);
  assert.ok(pc.nativeEffectIcons778.records.some(e=>e.iconId===29));
  assert.equal(pc.stats.combat.attackBonuses.melee, 3);
  s.scheduler.time = 100; await s.effects.update(); assert.equal(pc.stats.combat.attackBonuses.melee, 3);
  s.scheduler.time = 101; await s.effects.update(); assert.equal(pc.stats.combat.attackBonuses.melee, 1);
  assert.equal(pc.stats, shared); assert.equal(s.registry.get(pc.id), pc);
  assert.deepEqual(pc.nativeEffectIcons778.records,[]);
});

test('AC removal restores the next strongest bonus and subtracts stacking Dodge without losing equipment', async () => {
  const { s, pc } = sessionFixture(), frame = { self: pc.id };
  const low = s.commands.EffectACIncrease([2, 4], frame), high = s.commands.EffectACIncrease([5, 4], frame);
  for (const effect of [low, high]) await s.commands.ApplyEffectToObject([2, effect, pc.id]);
  assert.equal(s.commands.GetAC([pc.id]), 19);
  s.effects.remove(pc.id, high.id); assert.equal(s.commands.GetAC([pc.id]), 16);
  const dodge = s.commands.EffectACIncrease([4], frame); await s.commands.ApplyEffectToObject([2, dodge, pc.id]);
  assert.equal(s.commands.GetAC([pc.id]), 20);
  s.effects.remove(pc.id, dodge.id); assert.equal(s.commands.GetAC([pc.id]), 16);
  s.effects.remove(pc.id, low.id); assert.equal(s.commands.GetAC([pc.id]), 14);
});

test('decrease effects respect immunity on application; gaining immunity preserves existing penalties', async () => {
  const { s, pc } = sessionFixture(), frame = { self: pc.id };
  await s.commands.ApplyEffectToObject([2, s.commands.EffectACIncrease([0], frame), pc.id]);
  assert.equal(pc.effects?.length ?? 0, 0);
  const penalty = s.commands.EffectACDecrease([2], frame);
  await s.effects.apply(2, penalty, pc.id);
  assert.equal(s.commands.GetAC([pc.id]), 12);
  await s.effects.apply(2, s.commands.EffectImmunity([23], frame), pc.id);
  await s.effects.apply(2, s.commands.EffectACDecrease([3], frame), pc.id);
  assert.equal(s.commands.GetAC([pc.id]), 12);
  s.effects.remove(pc.id, penalty.id);
  assert.equal(s.commands.GetAC([pc.id]), 14);
  const atk = s.commands.EffectAttackDecrease([2], frame), sav = s.commands.EffectSavingThrowDecrease([0, 3], frame);
  await s.effects.apply(2, atk, pc.id); await s.effects.apply(2, sav, pc.id);
  assert.equal(pc.stats.combat.attackBonuses.melee, -1);
  assert.equal(s.commands.GetFortitudeSavingThrow([pc.id]), -3);
  pc.plot = true;
  await s.effects.apply(2, s.commands.EffectAttackDecrease([4], frame), pc.id);
  assert.equal(pc.stats.combat.attackBonuses.melee, -1);
  const parsed = s.commands.EffectAttackIncrease([2, 8], frame);
  assert.equal(parsed.integers[1], 0, 'Native invalid attack modifier falls back to misc');
  assert.equal(s.commands.EffectSavingThrowIncrease([-1, 2], frame).integers[1], 0);
});
