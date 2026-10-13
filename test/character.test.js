import assert from 'node:assert/strict';
import test from 'node:test';
import { ABILITIES, validateCharacter, characterStats, experienceAward, equipmentAbilityBonuses, importedObjectIds } from '../src/character.js';
import { ModuleSession } from '../src/module_session.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

function fixture() {
  const root = { IsPC: 1, Race: 0, Gender: 0, Appearance_Type: 0, Experience: 500, Gold: 17,
    ...Object.fromEntries(ABILITIES.map(a => [a, 10])), ClassList: [{ Class: 0, ClassLevel: 2 }],
    LvlStatList: [{ LvlStatHitDie: 8 }, { LvlStatHitDie: 4 }], HitPoints: 12, CurrentHitPoints: 9, FeatList: [], SkillList: [{ Rank: 3 }] };
  const rules = { racialtypes: { rows: new Map([[0, { Favored: '****', ConAdjust: '2' }]]) },
    classes: { rows: new Map([[0, { PreReqTable: '****', XPPenalty: '1' }], [1, { PreReqTable: '****', XPPenalty: '1' }], [2, { PreReqTable: 'prestige', XPPenalty: '0' }]]) },
    gains: new Map(), exptable: { rows: new Map([[2, { XP: '1000' }]]) } };
  return { root, rules };
}

test('PC hit points restore damage using level history and racial Constitution, not saved max snapshot', () => {
  const { root, rules } = fixture(); root.MaxHitPoints = 999;
  const s = characterStats(root, rules);
  assert.equal(s.baseAbilities.Con, 12); assert.equal(s.maxHP, 14); assert.equal(s.currentHP, 11);
  assert.equal(s.level, 2); assert.equal(s.nextXP, 1000); assert.deepEqual(s.skills, [3]);
  root.FeatList = [{ Feat: 40 }, { Feat: 754 }, { Feat: 755 }];
  assert.equal(characterStats(root, rules).maxHP, 56, 'Only highest epic toughness tier contributes');
});

test('each PC level contributes at least one HP before toughness even with negative Constitution', () => {
  const { root, rules } = fixture(); root.Con = 1; root.FeatList = [{ Feat: 40 }];
  assert.equal(characterStats(root, rules).maxHP, 7);
});

test('class stat gains sum levels and signed-byte class results before racial adjustments', () => {
  const { root, rules } = fixture(); rules.classes.rows.get(0).StatGainTable = 'gain';
  rules.gains.set('gain', { rows: new Map([[0, { CON: '2' }], [1, { CON: '4' }]]) });
  assert.equal(characterStats(root, rules).baseAbilities.Con, 18);
});

test('BIC validation rejects DM, incomplete history, duplicate classes and invalid HP without touching the registry', async () => {
  const { root } = fixture(); validateCharacter(root);
  assert.throws(() => validateCharacter({ ...root, IsDM: 1 }), /DM/);
  assert.throws(() => validateCharacter({ ...root, LvlStatList: [] }), /history/);
  assert.throws(() => validateCharacter({ ...root, ClassList: [root.ClassList[0], root.ClassList[0]] }), /class entry/);
  assert.throws(() => validateCharacter({ ...root, HitPoints: NaN }), /HitPoints/);
  const s = new ModuleSession(null); s.player = s.register('player', 'player', { journal: new Map() });
  await assert.rejects(s.loadCharacter(new Uint8Array(1)), /header/); assert.equal(s.registry.objects.size, 1); assert.equal(s.player.characterLoaded, undefined);
});

test('native favored class selection preserves first ties and excludes prerequisite classes', () => {
  const { rules } = fixture();
  const stats = { race: 0, classes: [{ id: 0, level: 10 }, { id: 1, level: 1 }, { id: 2, level: 20 }] };
  assert.equal(experienceAward(stats, 101, rules), 101, 'Highest ordinary class becomes favored; prestige exempt');
  rules.racialtypes.rows.get(0).Favored = '2';
  assert.equal(experienceAward(stats, 101, rules), 80, 'Uneven non-favored eligible class loses twenty percent with truncation');
  assert.equal(experienceAward(stats, 0, rules), 0); assert.equal(experienceAward(stats, -1, rules), 0);
});

test('script character and equipment accessors resolve canonical ID zero, owner IDs and native slot masks', () => {
  const { root, rules } = fixture(), s = new ModuleSession(null);
  const pc = s.register('player', 'player', { authored: root, stats: characterStats(root, rules), inventory: [], isPC: true });
  const item = s.register('item', 'sword', { ownerId: pc.id, equipmentSlot: 16 }); pc.inventory.push(item.id);
  assert.equal(pc.id, 0); assert.equal(s.commands.GetClassByPosition([1, 0]), 0);
  assert.equal(s.commands.GetClassByPosition([0, 0]), 255); assert.equal(s.commands.GetClassByPosition([1, OBJECT_INVALID]), 0);
  assert.equal(s.commands.GetLevelByClass([0, 0]), 2); assert.equal(s.commands.GetRacialType([OBJECT_INVALID]), 28);
  assert.equal(s.commands.GetItemInSlot([4, 0]), item.id); assert.equal(s.commands.GetItemInSlot([5, 0]), OBJECT_INVALID);
  assert.equal(s.commands.GetItemPossessor([item.id]), pc.id); assert.equal(s.commands.GetGold([0]), 17);
  assert.equal(s.commands.GetAbilityScore([0, 2, 1]), 12); assert.equal(s.commands.GetAbilityScore([0, 2, 0]), 12);
  s.registry.delete(item.id); assert.equal(s.commands.GetItemInSlot([4, 0]), OBJECT_INVALID);
  const imported = importedObjectIds(pc, { ObjectId: 12 }, [
    { id: 30, authored: { ObjectId: OBJECT_INVALID } },
    { id: 31, authored: { ObjectId: 0x80000006 } },
    { id: 32, authored: { ObjectId: 19 } }, { id: 33, authored: { ObjectId: 19 } }
  ]);
  assert.equal(imported.get(12), pc.id, 'Saved self reference resolves to the current PC');
  assert.equal(imported.get(0x80000006), 31, 'Foreign external ID maps to the new owned object, not to another registry namespace');
  assert.equal(imported.get(19), OBJECT_INVALID, 'Ambiguous saved identity cannot point to an arbitrary item');
  assert.equal(imported.has(OBJECT_INVALID), false, 'Serialized invalid references must never become valid objects');
});

test('native XP awards skip DM/associate/nonpositive values, wrap uint32, and update shared stats without altering input BIC', () => {
  const { root, rules } = fixture(), messages = [], s = new ModuleSession(null, { onMessage: m => messages.push(m) }); s.characterRules = rules;
  const pc = s.register('player', 'pc', { authored: root, stats: characterStats(root, rules) });
  s.commands.GiveXPToCreature([pc.id, 100]); assert.equal(s.commands.GetXP([pc.id]), 600); assert.equal(root.Experience, 500);
  pc.isDM = true; s.giveExperience(pc.id, 100); assert.equal(pc.stats.xp, 600);
  pc.isDM = false; pc.associateType = 1; s.giveExperience(pc.id, 100); assert.equal(pc.stats.xp, 600);
  pc.associateType = 0; pc.stats.xp = 0xfffffffe; s.giveExperience(pc.id, 5); assert.equal(pc.stats.xp, 3);
  assert.equal(messages.length, 2); assert.equal(messages[0].id, pc.id);
});

test('XP reaching the next level enables selection without inventing a level or class change', () => {
  const { root, rules } = fixture(), s = new ModuleSession(null); s.characterRules = rules;
  const pc = s.register('player', 'pc', { authored: root, stats: characterStats(root, rules) });
  s.giveExperience(pc.id, 600); assert.equal(pc.stats.canLevelUp, true); assert.equal(pc.stats.level, 2);
  assert.equal(pc.stats.classes[0].level, 2);
});

test('equipment ability effects use the strongest property per item and independent native increase/decrease limits', () => {
  const costs = { rows: new Map([[3, { Value: '3' }], [8, { Value: '8' }], [40, { Value: '40' }]]) };
  const rules = { abilityCosts: new Map([[1, costs], [21, costs]]) };
  const property = (type, value) => ({ PropertyName: type, Subtype: 2, CostValue: value });
  const items = [{ PropertiesList: [property(0, 3), property(0, 8)] }, { PropertiesList: [property(0, 8)] }];
  assert.equal(equipmentAbilityBonuses(items, rules).Con, 12);
  items.push({ PropertiesList: [property(27, 40)] }); assert.equal(equipmentAbilityBonuses(items, rules).Con, -18);
  assert.throws(() => equipmentAbilityBonuses([{ PropertiesList: [property(0, 99)] }], rules), /cost value/);
});
