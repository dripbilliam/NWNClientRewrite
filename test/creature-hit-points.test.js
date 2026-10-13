import assert from 'node:assert/strict';
import test from 'node:test';
import { creatureMaxHitPoints, restoredCreatureHitPoints } from '../src/creature_hit_points.js';
import { NativeRandom } from '../src/native_random.js';
import { parse2da } from '../src/area.js';

const rules = { ruleset: parse2da('2DA V2.0\n\nLabel Value\n0 FEAT_TOUGHNESS_HP_BONUS 2\n1 FEAT_EPIC_TOUGHNESS_HP_BONUS_2 45\n2 FEAT_DEATHLESS_VIGOR_HP_BONUS 4\n3 FEAT_EPIC_DEATHLESS_VIGOR_HP_BONUS 7') };
const npc = { IsPC: 0, ClassList: [{ Class: 4, ClassLevel: 3 }], HitPoints: 12, CurrentHitPoints: 9, FeatList: [] };

test('NPC HP restores aggregate base and CON while preserving damage instead of requiring PC history', () => {
  const hp = creatureMaxHitPoints(npc, 2, rules);
  assert.equal(hp, 18); assert.equal(restoredCreatureHitPoints(npc, hp, 2), 15);
  const low = creatureMaxHitPoints(npc, -5, rules);
  assert.equal(low, 3); assert.equal(restoredCreatureHitPoints(npc, low, -5), 0);
  assert.equal(restoredCreatureHitPoints({ ...npc, CurrentHitPoints: 20 }, low, -5), 3, 'Native low-CON floor discards overfull saved HP');
});

test('HP feat rules apply through active ruleset and keep PC and NPC Deathless Vigor branches distinct', () => {
  const root = { ...npc, ClassList: [{ Class: 34, ClassLevel: 15 }], FeatList: [{ Feat: 40 }, { Feat: 754 }, { Feat: 755 }, { Feat: 891 }] };
  assert.equal(creatureMaxHitPoints(root, 0, rules), 15 + 30 + 45 + 60 + 7);
  assert.equal(creatureMaxHitPoints(root, 0, rules, { includeFeatBonuses: false }), 15 + 45 + 60 + 7);
  const pc = { ...root, IsPC: 1, LvlStatList: Array.from({ length: 15 }, () => ({ LvlStatHitDie: 4 })) };
  assert.equal(creatureMaxHitPoints(pc, 0, rules), 60 + 30 + 45 + 24 + 7);
  assert.equal(creatureMaxHitPoints(pc, 0, rules, { includeFeatBonuses: false }), 60 + 45 + 7);
  assert.equal(creatureMaxHitPoints(pc, 0, rules, { possessedFamiliar: true }), creatureMaxHitPoints(root, 0, rules));
});

test('native HP calculations retain signed-short wrapping and ignore MaxHitPoints snapshots', () => {
  assert.equal(creatureMaxHitPoints({ ...npc, MaxHitPoints: 9999 }, 2, rules), 18);
  assert.equal(creatureMaxHitPoints({ ...npc, HitPoints: 32767, ClassList: [{ Class: 4, ClassLevel: 1 }] }, 1, rules), -32768);
  assert.equal(restoredCreatureHitPoints({ ...npc, IsPC: 1, HitPoints: 32767, CurrentHitPoints: 32766 }, -32768, 1), 32767);
});

test('native CRT dice stream has known draws, byte arguments and no draws for zero count/sides', () => {
  const random = new NativeRandom(1);
  assert.deepEqual(Array.from({ length: 5 }, () => random.next()), [41, 18467, 6334, 26500, 19169]);
  random.seed(1); assert.equal(random.dice(2, 20), 2 + 8); assert.equal(random.draws, 2);
  assert.equal(random.dice(0, 20), 0); assert.equal(random.dice(3, 0), 0); assert.equal(random.draws, 2);
  random.seed(1); assert.equal(random.dice(257, 276), 2); assert.equal(random.draws, 1);
  assert.throws(() => random.seed(-1), /seed/); assert.throws(() => random.seed(1.5), /seed/);
});
