import test from 'node:test';
import assert from 'node:assert/strict';
import { ABILITIES, characterStats } from '../src/character.js';
import { reconcileExperience, canLevelUp, updateMemorizedSlots } from '../src/character_progression.js';
import { ModuleSession } from '../src/module_session.js';
import { cloneGff } from '../src/gff.js';
import {parse2da} from '../src/area.js';

function fixture() {
  const rules = { racialtypes: { rows: new Map([[0, {}]]) }, gains: new Map(),
    skills: { rows: new Map([[0, {}], [1, {}]]) }, feat: { rows: new Map([[40, {}], [774, {}], [3, {}]]) },
    classes: { rows: new Map([[0, {}], [1, {}]]) }, spells: { rows: new Map() },
    exptable: { rows: new Map([[0, { XP: 0 }], [1, { XP: 1000 }], [2, { XP: 3000 }], [3, { XP: 6000 }]]) } };
  const root = { Race: 0, Gender: 0, ClassList: [{ Class: 0, ClassLevel: 2 }, { Class: 1, ClassLevel: 1 }],
    ...Object.fromEntries(ABILITIES.map(a => [a, 10])), Con: 12,
    LvlStatList: [
      { LvlStatClass: 0, LvlStatHitDie: 8, SkillPoints: 2, SkillList: [{ Rank: 2 }, { Rank: 0 }] },
      { LvlStatClass: 1, LvlStatHitDie: 4, SkillPoints: 7, SkillList: [{ Rank: 1 }, { Rank: 2 }], FeatList: [{ Feat: 40 }] },
      { LvlStatClass: 0, LvlStatHitDie: 6, SkillPoints: 3, SkillList: [{ Rank: 1 }, { Rank: 1 }], LvlStatAbility: 2, FeatList: [{ Feat: 774 }] }
    ], SkillList: [{ Rank: 4 }, { Rank: 3 }], SkillPoints: 3,
    FeatList: [{ Feat: 40 }, { Feat: 774 }], HitPoints: 18, CurrentHitPoints: 10, Experience: 3000, Gold: 5 };
  return { root, rules, stats: characterStats(root, rules) };
}

test('level loss deletes choices, reverses ability/feat/skill deltas and preserves imported data', () => {
  const { root, stats, rules } = fixture(), before = cloneGff(root);
  const down = reconcileExperience(root, stats, 0, rules);
  assert.equal(down.stats.level, 1); assert.deepEqual(down.stats.classes, [{ id: 0, level: 1 }]);
  assert.equal(down.root.Con, 10); assert.equal(down.root.SkillPoints, 2);
  assert.deepEqual(down.stats.skills, [2, 0]); assert.deepEqual(down.stats.feats, []);
  assert.equal(down.stats.maxHP, 8); assert.equal(down.stats.currentHP, 1);
  assert.equal(down.root.LvlStatList.length, 1); assert.deepEqual(root, before);
  const gain = reconcileExperience(down.root, down.stats, 3000, rules);
  assert.equal(gain.stats.level, 1); assert.equal(gain.stats.canLevelUp, true);
});

test('level-history great-ability changes use the active EPIC_GREAT_STAT_BONUS rule and reverse the same amount',()=>{
 const {root,stats,rules}=fixture();rules.ruleset=parse2da('2DA V2.0\n\nLabel Value\n0 EPIC_GREAT_STAT_BONUS 2');
 const down=reconcileExperience(root,stats,0,rules);assert.equal(down.root.Con,9);
 const prepared=cloneGff(down.root);prepared.LvlStatList=cloneGff(root.LvlStatList);const up=reconcileExperience(prepared,down.stats,3000,rules);assert.equal(up.root.Con,12);
});

test('preauthored history replays multiple levels with native HP delta and class-slot order', () => {
  const { root, stats, rules } = fixture();
  const down = reconcileExperience(root, stats, 0, rules);
  const prepared = cloneGff(down.root); prepared.LvlStatList = cloneGff(root.LvlStatList);
  const up = reconcileExperience(prepared, down.stats, 3000, rules);
  assert.deepEqual(up.stats.classes, stats.classes); assert.deepEqual(up.stats.skills, stats.skills);
  assert.equal(up.root.Con, 12); assert.equal(up.root.SkillPoints, 3);
  assert.equal(up.stats.currentHP, 1 + stats.maxHP - down.stats.maxHP);
  assert.equal(up.root.LvlStatList.length, 3); assert.deepEqual(up.changes, [1, 1]);
  const dead = reconcileExperience(prepared, { ...down.stats, currentHP: -10 }, 3000, rules);
  assert.equal(dead.stats.currentHP, -10);
});

test('zero-level non-final classes stay in place; configured minimum and XP boundary stop loss', () => {
  const { root, stats, rules } = fixture();
  root.ClassList = [{ Class: 1, ClassLevel: 1 }, { Class: 0, ClassLevel: 2 }];
  const down = reconcileExperience(root, stats, 1000, rules);
  assert.equal(down.stats.level, 2); assert.equal(down.root.LvlStatList.length, 2);
  const zero = reconcileExperience(root, stats, 0, rules);
  assert.deepEqual(zero.stats.classes, [{ id: 1, level: 0 }, { id: 0, level: 1 }]);
  const minimum = reconcileExperience(root, stats, 0, rules, { minimumLevel: 2 });
  assert.equal(minimum.stats.level, 2);
});

test('associate and PC/server limits gate replay; uint32 delta follows native signed subtraction', () => {
  const { stats, rules, root } = fixture();
  for (const associateType of [3, 5, 6, 7, 8]) assert.equal(canLevelUp({ ...stats, xp: 6000 }, rules, { associateType }), false);
  assert.equal(canLevelUp({ ...stats, xp: 6000 }, rules, { associateType: 1 }), true);
  assert.equal(canLevelUp({ ...stats, xp: 6000 }, rules, { maximumLevel: 3 }), false);
  const wrapped = reconcileExperience(root, { ...stats, xp: 0xfffffffe }, 3, rules);
  assert.equal(wrapped.delta, 5); assert.equal(wrapped.stats.level, 3);
});

test('level loss removes active records without deleting already-authored future records', () => {
  const { root, stats, rules } = fixture();
  const future = { LvlStatClass: 0, LvlStatHitDie: 2, SkillPoints: 9, SkillList: [{ Rank: 3 }, { Rank: 0 }] };
  root.LvlStatList.push(future);
  const down = reconcileExperience(root, stats, 0, rules);
  assert.equal(down.root.LvlStatList.length, 2); assert.deepEqual(down.root.LvlStatList[1], future);
  const up = reconcileExperience(down.root, down.stats, 1000, rules);
  assert.equal(up.stats.level, 2); assert.equal(up.stats.skillPoints, 9);
  assert.deepEqual(up.stats.skills, [5, 0]);
});

test('failed reconciliation is atomic and script/UI providers share live state under ID zero', () => {
  const { root, rules, stats } = fixture(), s = new ModuleSession({}); s.characterRules = rules;
  const pc = s.register('player', 'pc', { authored: root, creatureData: cloneGff(root), stats, isPC: true });
  assert.equal(pc.id, 0); const statsReference = pc.stats;
  pc.creatureData.LvlStatList[1].LvlStatClass = 99;
  assert.throws(() => s.setExperience(pc.id, 0), /history/);
  assert.equal(pc.stats.xp, 3000); assert.equal(pc.creatureData.LvlStatList.length, 3);
  pc.creatureData = cloneGff(root); s.setExperience(pc.id, 0);
  assert.equal(pc.stats, statsReference); assert.equal(s.commands.GetHasFeat([774, 0]), 0);
  assert.equal(s.commands.GetAbilityScore([0, 2, 1]), 10);
  assert.equal(s.commands.GetHitDice([0]), 1); assert.equal(s.commands.GetXP([0]), 0);
  assert.equal(root.Experience, 3000); assert.equal(root.Con, 12);
});

test('spell removal leaves empty slots and matches native metamagic XOR masks', () => {
  const { root, rules } = fixture();
  rules.classes.rows.set(0, { SpellTableColumn: 'Caster', SpellbookRestricted: 1 });
  rules.spells.rows.set(9, { Caster: 1 });
  root.ClassList[0].KnownList1 = [{ Spell: 9 }, { Spell: 12 }];
  root.ClassList[0].MemorizedList1 = [{ Spell: 9, Ready: 1, SpellMetaMagic: 0 }, { Spell: 12, Ready: 1 }];
  root.ClassList[0].MemorizedList2 = [{ Spell: 9, Ready: 1, SpellMetaMagic: 2 }];
  root.ClassList[0].MemorizedList3 = [{ Spell: 9, Ready: 1, SpellMetaMagic: 1 }];
  root.ClassList[0].MemorizedList5 = [{ Spell: 9, Ready: 1, SpellMetaMagic: 8 }];
  root.LvlStatList[2].KnownList1 = [{ Spell: 9 }];
  // Old class level 2 clears slot level 2 separately, as the native routine.
  const down = reconcileExperience(root, characterStats(root, rules), 1000, rules);
  const c = down.root.ClassList[0];
  assert.deepEqual(c.KnownList1, [{ Spell: 12 }]);
  assert.deepEqual(c.MemorizedList1, [null, { Spell: 12, Ready: 1 }]);
  assert.deepEqual(c.MemorizedList2, [null]); assert.deepEqual(c.MemorizedList3, [null]);
  assert.equal(c.MemorizedList5[0].SpellMetaMagic, 8, 'Native XOR loop does not visit the quicken mask');
});

test('spell slot counts follow custom class tables, primary ability, school and prestige progression', () => {
  const { root, rules } = fixture();
  root.Str = 16;
  root.ClassList = [{ Class: 127, ClassLevel: 1, School: 4 }, { Class: 1, ClassLevel: 3 }];
  rules.classes.rows.set(127, { SpellCaster: 1, MemorizesSpells: 1, SpellcastingAbil: 'STR', PickSchool: 1, Arcane: 1, SpellGainTable: 'custom_spells' });
  rules.classes.rows.set(1, { SpellCaster: 0, ArcSpellLvlMod: 2 });
  rules.classTables = new Map([['custom_spells', { rows: new Map([
    [0, { NumSpellLevels: 2, SpellLevel0: 1, SpellLevel1: 1 }], [2, { NumSpellLevels: 3, SpellLevel0: 4, SpellLevel1: 2, SpellLevel2: 0 }]
  ]) }]]);
  const c = root.ClassList[0]; c.MemorizedList0 = [{ Spell: 1 }, { Spell: 2 }, { Spell: 3 }, { Spell: 4 }, { Spell: 5 }];
  updateMemorizedSlots(root, rules);
  assert.deepEqual(c.MemorizedList0, [{ Spell: 1 }, { Spell: 2 }, { Spell: 3 }, { Spell: 4 }]);
  assert.deepEqual(c.MemorizedList1, [null, null, null, null]);
  assert.deepEqual(c.MemorizedList2, [null, null], 'Zero base slots still allow ability/school bonuses');
  assert.equal(c.MemorizedList3.length, 0, 'Missing spell-gain cells deny that spell level');
  const equipped = cloneGff(root); delete equipped.ClassList[0].bonusSpellSlots;
  equipped.Equip_ItemList = [{ PropertiesList: [
    { PropertyName: 13, Subtype: 127, CostValue: 3 }, { PropertyName: 13, Subtype: 127, CostValue: 3 },
    { PropertyName: 13, Subtype: 0, CostValue: 3 }, { PropertyName: 13, Subtype: 127, CostValue: 12 }
  ] }];
  updateMemorizedSlots(equipped, rules);
  assert.equal(equipped.ClassList[0].MemorizedList3.length, 2, 'Item bonus slots are additive, class-specific and allow otherwise unavailable spell levels');
  updateMemorizedSlots(equipped, rules); assert.equal(equipped.ClassList[0].MemorizedList3.length, 2, 'Providers are initialized once per class slot');
});
