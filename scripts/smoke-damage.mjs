// Exercise real installed actors through the live effect/HP/session adapters.
// This is a replacement-runtime integration check, not a native game oracle.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { openLocalModule } from './local-module.mjs';
import { ModuleSession } from '../src/module_session.js';
import { NativeRandom } from '../src/native_random.js';
import { runtimeDiagnostics } from '../src/runtime_diagnostics.js';

const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-damage.mjs <install> <module>');
const messages = [], session = await new ModuleSession(await openLocalModule(install, modulePath),
  { runStartupScripts: false, onMessage: message => messages.push(message) }).initialize([]);
const bic = (await fs.readdir(path.join(install, 'data/lcv'))).find(f => /\.bic$/i.test(f));
assert.ok(bic, 'Installed player corpus is missing');
await session.loadCharacter(await fs.readFile(path.join(install, 'data/lcv', bic)), bic);
session.random = new NativeRandom(1);
const pc = session.player, creator = { self: pc.id }, shared = pc.stats, id = pc.id, authored = JSON.stringify(pc.authored);
const base = pc.stats.currentHP;
const temp = session.commands.EffectTemporaryHitpoints([5], creator);
session.commands.ApplyEffectToObject([2, temp, id]);
assert.equal(session.hitPoints(id, false), ((base + 5) << 16) >> 16);
session.refreshCombat(pc); assert.equal(pc.stats.temporaryHP, 5);
assert.equal(pc.stats, shared); assert.equal(session.registry.get(id), pc);
const damage = session.commands.EffectDamage([7, 8], creator);
await session.commands.ApplyEffectToObject([0, damage, id]);
const dealt = messages.filter(m => m.type === 'damage' && m.id === id).at(-1)?.amount;
assert.equal(dealt, 7); assert.equal(pc.stats.currentHP, base - 2); assert.equal(pc.stats.temporaryHP, 0);
assert.equal(pc.effects.length, 0); assert.equal(JSON.stringify(pc.authored), authored);
assert.equal(pc.creatureData.CurrentHitPoints, base - 2);

// Use authored OnDamaged/OnDeath scripts on ordinary installed actors. Their
// unsupported calls stay in the occurrence journal; never replace the scripts
// with campaign-specific exceptions to claim this encounter succeeded.
const targets = [...session.registry.objects.values()].filter(o => o.kind === 'creature' && o.stats &&
  !o.plot && !o.isPC && !(o.creatureData.Immortal ?? 0) && session.hitPoints(o.id, false) > 10).slice(0, 3);
assert.ok(targets.length, 'No living placed creature available');
const results = [];
for (const target of targets) {
  const targetId = target.id, targetStats = target.stats, snapshot = JSON.stringify(target.authored);
  const before = session.hitPoints(targetId, false);
  await session.commands.ApplyEffectToObject([0, session.commands.EffectDamage([3, 8], creator), targetId]);
  assert.equal(session.registry.get(targetId), target); assert.equal(target.stats, targetStats);
  assert.equal(JSON.stringify(target.authored), snapshot);
  assert.equal(session.commands.GetLastDamager([targetId]), id);
  const amount = messages.filter(m => m.type === 'damage' && m.id === targetId).at(-1).amount;
  results.push({ id: targetId, source: target.sourceKey, before, after: session.hitPoints(targetId, false),
    amount, lastDamage: session.commands.GetTotalDamageDealt([], { self: targetId }), script: target.scripts.damaged });
}
const doomed = targets[0];
await session.commands.ApplyEffectToObject([0, session.commands.EffectDamage([10000, 8], creator), doomed.id]);
assert.equal(session.isDead(doomed), true); assert.equal(doomed.deathHandled, true);
assert.equal(session.registry.get(doomed.id), doomed);
console.log(JSON.stringify({ module: session.resolver.moduleName, player: { file: bic, id, before: base,
  after: pc.stats.currentHP, temporaryHP: pc.stats.temporaryHP }, targets: results,
  death: { id: doomed.id, hp: session.hitPoints(doomed.id, false), killerId: doomed.lastKillerId },
  difficulty: session.difficultyLevel, diagnostics: session.diagnostics,
  omissions: [...new Set(runtimeDiagnostics.records.filter(r => r.code === 'combat.lifecycle-unimplemented').map(r => r.message))],
  limits: 'No player attack was scheduled. Startup is disabled. Authored script failures and missing death/AI/presentation providers are retained; this does not demonstrate native/server parity.' }));
