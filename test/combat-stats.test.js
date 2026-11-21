import assert from 'node:assert/strict';
import test from 'node:test';
import { parse2da } from '../src/area.js';
import { abilityModifier, baseCombatStats, preEpicClassLevels, rulesetInt, rulesetHash, rulesetDuplicates } from '../src/combat_stats.js';
import { characterStats } from '../src/character.js';
import { ModuleSession } from '../src/module_session.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';
import { RuntimeDiagnostics } from '../src/runtime_diagnostics.js';
import { NwScriptVm } from '../src/nwscript_vm.js';

const table = (columns, lines, defaults = '') => parse2da(`2DA V2.0\n${defaults}\n\n${columns}\n${lines}`);
function rules() {
  return {
    classes: table('AttackBonusTable SavingThrowTable', '99 high good\nlabel low poor'),
    classTables: new Map([
      ['high', table('BAB', '8 1\n1 2\n100 3')],
      ['low', table('bab', '8 0\n1 1\n100 1')],
      ['good', table('FortSave RefSave WillSave', '50 2 0 0\n50 3 0 0\nfoo 3 1 1')],
      ['poor', table('FortSave RefSave WillSave', 'foo 0 0 2\nbar 0 0 3\nbaz 1 1 3')]
    ]),
    epicattacks: table('BAB', '20 1\n21 1\n22 2'),
    epicsaves: table('FortSave RefSave WillSave', '21 0 0 0\n22 1 1 1\n23 1 1 1'),
    ruleset: table('Label Value', '0 **** ****')
  };
}
const root = (classes = [{ Class: 0, ClassLevel: 3 }]) => ({ ClassList: classes,
  LvlStatList: classes.flatMap(c => Array.from({ length: c.ClassLevel }, () => ({ LvlStatClass: c.Class }))), FeatList: [] });
const calculate = (r, tables = rules(), options = {}) => baseCombatStats(r, tables, { charismaModifier: 0, ...options });

test('native combat reads physical 2DA rows, including repeated/non-numeric labels and case-insensitive columns', () => {
  const result = calculate(root());
  assert.equal(result.baseAttackBonus, 3);
  assert.deepEqual(result.baseSaves, { fortitude: 3, reflex: 1, will: 1 });
  assert.equal(calculate(root([{ Class: 1, ClassLevel: 2 }])).baseAttackBonus, 1);
  const duplicateColumns = rules(); duplicateColumns.classTables.set('high', table('BAB BAB', '0 7 99'));
  assert.equal(calculate(root([{ Class: 0, ClassLevel: 1 }]), duplicateColumns).baseAttackBonus, 7, 'Native column lookup takes the first match');
});

test('pre-epic attribution uses every history epic flag, then class-slot order when count differs from live level', () => {
  const r = root([{ Class: 0, ClassLevel: 15 }, { Class: 1, ClassLevel: 10 }]);
  r.LvlStatList = Array.from({ length: 25 }, (_, i) => ({ LvlStatClass: i < 10 ? 0 : 1, EpicLevel: i === 2 || i >= 20 ? 1 : 0 }));
  assert.deepEqual(preEpicClassLevels(r), [9, 10], 'Native does not just slice the first twenty records');
  r.LvlStatList.push({ LvlStatClass: 1 });
  assert.deepEqual(preEpicClassLevels(r), [15, 5], 'Stored future history activates the fallback');
  r.ClassList.reverse();
  assert.deepEqual(preEpicClassLevels(r), [10, 10], 'Class-slot order must survive');
  assert.deepEqual(preEpicClassLevels({ ClassList: [{ Class: 0, ClassLevel: 1 }], LvlStatList: [{}] }), [1], 'CNWLevelStats constructor defaults both class and epic flag to zero');
});

test('epic attack is separate from class attack; runtime override supersedes both modes, serialized snapshot does not', () => {
  const r = root([{ Class: 0, ClassLevel: 23 }]);
  r.LvlStatList.forEach(h => { h.EpicLevel = 1; }); r.LvlStatList[0].EpicLevel = 0;
  r.BaseAttackBonus = 200;
  const result = calculate(r);
  assert.equal(result.baseAttackBonusWithoutEpic, 1); assert.equal(result.baseAttackBonus, 3);
  assert.deepEqual(result.baseSaves, { fortitude: 3, reflex: 1, will: 1 });
  const overridden = calculate(r, rules(), { overrideBaseAttackBonus: 255 });
  assert.equal(overridden.baseAttackBonusWithoutEpic, 255); assert.equal(overridden.baseAttackBonus, 255);
});

test('class loader zeroes failed BAB cells but save and epic loaders retain out-of-range DEFAULT output', () => {
  const tables = rules(), r = root();
  tables.classTables.set('high', table('BAB', '0 0xff\n1 ****', 'DEFAULT: 257'));
  tables.classTables.set('good', table('FortSave WillSave', '0 260 -2\n1 **** ****', 'DEFAULT: 257'));
  assert.equal(calculate(r, tables).baseAttackBonus, 0);
  assert.deepEqual(calculate(r, tables).baseSaves, { fortitude: 1, reflex: 1, will: 1 });
  r.ClassList[0].ClassLevel = 1; r.LvlStatList.length = 1;
  const first = calculate(r, tables);
  assert.equal(first.baseAttackBonus, 255); assert.deepEqual(first.baseSaves, { fortitude: 4, reflex: 1, will: -2 });
  r.ClassList[0].ClassLevel = 2; r.LvlStatList.push({ LvlStatClass: 0 });
  assert.deepEqual(calculate(r, tables).baseSaves, { fortitude: 0, reflex: 1, will: 0 }, 'Explicit empty cells return zero rather than DEFAULT');
});

test('class/epic getters bound unsigned-byte levels to 1..60 and saves wrap as signed bytes', () => {
  const tables = rules(), sixty = table('BAB FortSave RefSave WillSave', Array.from({ length: 60 }, (_, i) => `${i} 250 130 255 129`).join('\n'));
  for (const key of ['high', 'low', 'good', 'poor']) tables.classTables.set(key, sixty);
  const r = root([{ Class: 0, ClassLevel: 3 }, { Class: 1, ClassLevel: 3 }]);
  assert.equal(calculate(r, tables).baseAttackBonus, 500, 'Class BAB sums in int, not char');
  assert.deepEqual(calculate(r, tables).baseSaves, { fortitude: 4, reflex: -2, will: 2 });
  r.ClassList = [{ Class: 0, ClassLevel: 60 }]; r.LvlStatList = Array.from({ length: 60 }, () => ({ LvlStatClass: 0, EpicLevel: 0 }));
  tables.epicattacks = table('BAB', '0 0'); tables.epicsaves = table('FortSave RefSave WillSave', '0 0 0 0');
  assert.equal(calculate(r, tables).baseAttackBonus, 250);
  r.ClassList[0].ClassLevel = 61; r.LvlStatList.push({ LvlStatClass: 0 });
  assert.equal(calculate(r, tables).baseAttackBonus, 0); assert.deepEqual(calculate(r, tables).baseSaves, { fortitude: 0, reflex: 0, will: 0 });
});

test('save feat IDs follow native branches, include pending feats once, and Divine Grace ignores negative Charisma', () => {
  const r = root();
  r.FeatList = [217, 14, 24, 22, 248, 388, 386, 380, 583, 585, 695].map(Feat => ({ Feat }));
  assert.deepEqual(calculate(r, rules(), { charismaModifier: 3, pendingFeats: [14, 248] }).baseSaves,
    { fortitude: 14, reflex: 12, will: 13 });
  assert.deepEqual(calculate(r, rules(), { charismaModifier: -1 }).baseSaves,
    { fortitude: 11, reflex: 9, will: 10 });
  r.FeatList = [];
  assert.deepEqual(calculate(r, rules(), { pendingFeats: [14, 24, 22] }).baseSaves,
    { fortitude: 5, reflex: 3, will: 3 });
});

test('ruleset constants use case-sensitive labels, last nonempty duplicate, native atoi and signed-byte results', () => {
  const tables = rules();
  tables.ruleset = table('Label Value', '0 GREAT_FORTITUDE_SAVE_BONUS 9\n1 GREAT_FORTITUDE_SAVE_BONUS 130junk\n2 GREAT_FORTITUDE_SAVE_BONUS ****\n3 great_fortitude_save_bonus 8\n4 LUCKY_SAVE_BONUS 0x20');
  const r = root(); r.FeatList = [{ Feat: 14 }, { Feat: 248 }];
  assert.equal(rulesetInt(tables, 'MISSING', 7), 7);
  assert.equal(rulesetHash('C'), 0xaf63fe4c86022652n, 'Observed folded first-char seed in CalcStatModifier');
  assert.equal(rulesetHash('L'), 0xaf64014c86022b6bn, 'Observed Lucky/Lightning first-char seed');
  assert.deepEqual(rulesetDuplicates(tables), ['GREAT_FORTITUDE_SAVE_BONUS']);
  assert.equal(calculate(r, tables).baseSaves.fortitude, -123);
  assert.equal(calculate(r, tables).baseSaves.reflex, 1, 'Ruleset uses atoi rather than hexadecimal cell conversion');
});

test('CalcStatModifier preserves native even-neutral correction, odd-neutral truncation and rule faults', () => {
  assert.deepEqual([3, 9, 10, 11, 255].map(score => abilityModifier(score, {})), [-4, -1, 0, 0, 122]);
  const r = { ruleset: table('Label Value', '0 CHARGEN_ABILITY_NEUTRAL_VALUE 11\n1 CHARGEN_ABILITY_MODIFIER_INCREMENT 3') };
  assert.equal(abilityModifier(9, r), 0, 'Native odd-neutral branch truncates toward zero');
  assert.equal(abilityModifier(17, r), 2);
  r.ruleset = table('Label Value', '0 CHARGEN_ABILITY_MODIFIER_INCREMENT 0');
  assert.throws(() => abilityModifier(14, r), /division fault/);
});

test('unloaded/corrupt combat providers fail explicitly; canonical invalid/noncreature IDs return native zero', () => {
  assert.throws(() => calculate(root(), {}), /not loaded/);
  const tables = rules(); tables.classTables.delete('high');
  assert.throws(() => calculate(root(), tables), /unavailable/);
  assert.throws(() => calculate(root(), rules(), { charismaModifier: NaN }), /Charisma/);
  const s = new ModuleSession(null), pc = s.register('player', 'pc', { stats: { combat: calculate(root()) } });
  assert.equal(s.commands.GetBaseAttackBonus([pc.id]), 3);
  assert.equal(s.commands.GetBaseAttackBonus([OBJECT_INVALID]), 0);
  assert.equal(s.commands.GetBaseAttackBonus([s.register('door', 'door', {}).id]), 0);
  pc.stats.combat = null;
  assert.throws(() => s.commands.GetBaseAttackBonus([pc.id]), /not been loaded/);
});

test('live character providers ignore BIC combat snapshots and recompute from current classes and feats', () => {
  const r = root(); Object.assign(r, { Str: 10, Dex: 10, Con: 10, Int: 10, Wis: 10, Cha: 16, Race: 0, Experience: 0,
    HitPoints: 24, CurrentHitPoints: 24, BaseAttackBonus: 200, FortSaveThrow: 99 });
  r.LvlStatList.forEach(h => { h.LvlStatHitDie = 8; }); r.FeatList = [{ Feat: 217 }];
  const tables = rules(); tables.classes = table('AttackBonusTable SavingThrowTable', '0 high good\n1 low poor');
  tables.racialtypes = { rows: new Map([[0, {}]]) }; tables.gains = new Map(); tables.exptable = { rows: new Map() };
  const before = JSON.stringify(r);
  const s = characterStats(r, tables);
  assert.equal(s.combat.baseAttackBonus, 3); assert.equal(s.combat.baseSaves.fortitude, 6);
  assert.equal(JSON.stringify(r), before);
  r.ClassList[0].ClassLevel = 1; r.LvlStatList.length = 1; r.FeatList = [];
  assert.equal(characterStats(r, tables).combat.baseAttackBonus, 1);
  assert.equal(characterStats(r, tables).combat.baseSaves.fortitude, 2);
});

test('a script querying unavailable creature combat stats records the engine call and canonical target', async () => {
  const s = new ModuleSession(null), npc = s.register('creature', 'custom:npc:0', {}), log = new RuntimeDiagnostics();
  const vm = new NwScriptVm({ api: [{ name: 'GetBaseAttackBonus', args: [{ name: 'oCreature', type: 'object' }], returns: 'int' }],
    command: name => s.commands[name], diagnostics: log });
  const program = { name: 'combat_query', instructions: new Map([
    [13, { pc: 13, op: 4, type: 6, value: npc.id, next: 19 }],
    [19, { pc: 19, op: 5, command: 0, argc: 1, next: 24 }], [24, { pc: 24, op: 0x20 }]
  ]) };
  await assert.rejects(vm.run(program, npc.id), /not been loaded/);
  assert.equal(log.records.length, 1); assert.equal(log.records[0].code, 'engine.unimplemented');
  assert.equal(log.records[0].context.engineCall, 'GetBaseAttackBonus');
  assert.deepEqual(log.records[0].context.objectArguments, [{ index: 0, name: 'oCreature', objectId: npc.id }]);
});
