// Read installed placed creature stats; these are resource/runtime integration
// checks, not an independent native combat oracle. Do not copy original assets.
import assert from 'node:assert/strict';
import { openLocalModule } from './local-module.mjs';
import { ModuleSession } from '../src/module_session.js';

const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-creatures.mjs <install> <module>');
const session = await new ModuleSession(await openLocalModule(install, modulePath), { runStartupScripts: false }).initialize([]);
const creatures = [...session.registry.objects.values()].filter(o => o.kind === 'creature');
const loaded = creatures.filter(o => o.stats), skipped = creatures.filter(o => !o.stats);
for (const creature of loaded) {
  const identity = creature.stats, id = creature.id, source = JSON.stringify(creature.authored);
  session.refreshCombat(creature);
  assert.equal(creature.stats, identity); assert.equal(session.registry.get(id), creature);
  assert.equal(session.commands.GetAC([id]), creature.stats.combat.armorClass);
  assert.equal(session.hitPoints(id, true), creature.stats.maxHP);
  assert.equal(JSON.stringify(creature.authored), source);
}
assert.ok(loaded.length, 'No placed creatures loaded');
console.log(JSON.stringify({ module: session.resolver.moduleName, creatures: creatures.length, loaded: loaded.length,
  skipped: skipped.map(o => ({ id: o.id, source: o.sourceKey })), diagnostics: session.diagnostics,
  stats: loaded.map(o => ({ id: o.id, source: o.sourceKey, tag: o.tag, level: o.stats.level, hp: [o.stats.currentHP, o.stats.maxHP],
    ac: o.stats.combat.armorClass, attack: o.stats.combat.attackBonuses, saves: o.stats.combat.saves })) }));
