// Installed data stays in memory. These assertions cover general PC history
// mutation, not a module opening or manual character-creation validation.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import { openLocalModule } from './local-module.mjs';
import { parseCharacter, loadCharacterRules, characterStats, ABILITIES } from '../src/character.js';
import { cloneGff, getGffStructType } from '../src/gff.js';
import { reconcileExperience } from '../src/character_progression.js';

const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-progression.mjs <install> <module>');
const resolver = await openLocalModule(install, modulePath), rules = await loadCharacterRules(resolver);
const results = [];
for (const filename of (await fs.readdir(path.join(install, 'data/lcv'))).filter(f => /\.bic$/i.test(f))) {
  const root = parseCharacter(await fs.readFile(path.join(install, 'data/lcv', filename))), before = JSON.stringify(root), stats = characterStats(root, rules);
  if (stats.level <= 1) continue;
  const down = reconcileExperience(root, stats, 0, rules);
  assert.equal(down.stats.xp, 0); assert.equal(down.stats.level, 1); assert.equal(down.root.LvlStatList.length, 1);
  assert.equal(down.changes.length, stats.level - 1); assert.ok(down.stats.currentHP >= 1);
  for (const [i, s] of down.root.SkillList.entries()) {
    const sum = root.LvlStatList.slice(1, stats.level).reduce((n, h) => n + (h.SkillList?.[i]?.Rank ?? 0), 0);
    assert.equal(s.Rank, (root.SkillList[i].Rank - sum) & 255);
  }
  assert.equal(JSON.stringify(root), before, 'Imported source is immutable');
  for (let i = 0; i < (root.Equip_ItemList ?? []).length; i++) assert.equal(getGffStructType(down.root.Equip_ItemList[i]), getGffStructType(root.Equip_ItemList[i]));
  // Actual level loss erased history. XP alone leaves choices pending.
  const pending = reconcileExperience(down.root, down.stats, stats.xp, rules);
  assert.equal(pending.stats.level, 1); assert.equal(pending.stats.canLevelUp, true);
  // Separately simulate a file that was authored with future history. The
  // native replay branch is allowed to use those pre-existing choices.
  const prepared = cloneGff(down.root); prepared.LvlStatList = cloneGff(root.LvlStatList);
  const up = reconcileExperience(prepared, down.stats, stats.xp, rules);
  assert.equal(up.stats.level, stats.level); assert.deepEqual(up.stats.classes, stats.classes);
  for (const a of ABILITIES) assert.equal(up.root[a], root[a]);
  assert.deepEqual(up.stats.skills, stats.skills);
  assert.equal(up.stats.maxHP, stats.maxHP);
  assert.deepEqual(new Set(up.stats.feats), new Set(stats.feats));
  for (const c of root.ClassList) {
    const restored = up.root.ClassList.find(entry => entry.Class === c.Class);
    for (let l = 0; l < 10; l++) assert.deepEqual((restored[`KnownList${l}`] ?? []).map(s => s.Spell).sort((a, b) => a - b), (c[`KnownList${l}`] ?? []).map(s => s.Spell).sort((a, b) => a - b), `${filename} known spells level ${l}`);
  }
  results.push({ filename, from: stats.level, to: down.stats.level, maxHP: down.stats.maxHP, replay: up.stats.level });
}
console.log(JSON.stringify({ classTables: rules.classTables.size, characters: results, count: results.length }));
