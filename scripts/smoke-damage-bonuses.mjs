// Installed-resource integration only; no attack is scheduled and no native
// oracle is claimed. Read original assets in memory without copying them.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import { openLocalModule } from './local-module.mjs';
import { ModuleSession } from '../src/module_session.js';
import { intEntry } from '../src/combat_stats.js';

const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-damage-bonuses.mjs <install> <module>');
const resolver = await openLocalModule(install, modulePath);
const results = [], diagnostics = [];
for (const filename of (await fs.readdir(path.join(install, 'data/lcv'))).filter(f => /\.bic$/i.test(f))) {
  // Each character belongs to a fresh world. Replacing an active PC is not a
  // supported lifecycle and must not be added merely to satisfy this probe.
  const s = await new ModuleSession(resolver, { runStartupScripts: false }).initialize([]);
  await s.loadCharacter(await fs.readFile(path.join(install, 'data/lcv', filename)), filename);
  const pc = s.player, identity = pc.stats, root = JSON.stringify(pc.authored), hp = s.hitPoints(pc.id, false);
  const attack = { weaponAttackType: 1, ranged: 0, result: 1, damage: Array(32).fill(-1) };
  const before = await s.damage.effectBonus(pc, null, attack, { maximize: true });
  const value = s.commands.EffectDamageIncrease([1, 1], { self: pc.id });
  s.commands.ApplyEffectToObject([2, value, pc.id]);
  const after = await s.damage.effectBonus(pc, null, attack, { maximize: true });
  const r = s.characterRules.iprp_damagecost, dice = intEntry(r, 1, 'NumDice').value, die = intEntry(r, 1, 'Die').value;
  assert.equal(after.increase - before.increase, dice ? Math.imul(dice, die) : die);
  s.commands.RemoveEffect([pc.id, value], { self: pc.id }); await s.scheduler.pump();
  assert.equal((await s.damage.effectBonus(pc, null, attack, { maximize: true })).total, before.total);
  // Exercise the same live adapter's native attack-component update. Querying
  // energy bonuses can mutate the current attack record even in maximize mode
  // when a penalty is present; this probe uses an ordinary positive query.
  const energy = s.commands.EffectDamageIncrease([1, 8], { self: pc.id });
  s.commands.ApplyEffectToObject([2, energy, pc.id]);
  await s.damage.effectBonus(pc, null, attack, { energy: true });
  assert.ok(attack.damage[3] > 0);
  s.commands.RemoveEffect([pc.id, energy], { self: pc.id }); await s.scheduler.pump();
  assert.equal(s.registry.get(pc.id), pc); assert.equal(pc.stats, identity);
  assert.equal(s.hitPoints(pc.id, false), hp); assert.equal(JSON.stringify(pc.authored), root);
  results.push({ filename, id: pc.id, baseBonus: before.total, extraPhysical: after.increase - before.increase,
    magicComponent: attack.damage[3], projectedDamageEffects: pc.itemCombatEffects.effects.filter(e => [13, 14].includes(e.type)).length });
  diagnostics.push(...s.diagnostics);
}
console.log(JSON.stringify({ module: resolver.moduleName, characters: results, diagnostics,
  limits: 'Startup disabled; no attack scheduled or HP damage applied. This validates shared rules/runtime integration, not native outcomes or server parity.' }));
