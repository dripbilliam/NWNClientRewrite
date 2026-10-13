// Replacement integration, not an independent native encounter oracle.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import { openLocalModule } from './local-module.mjs';
import { ModuleSession } from '../src/module_session.js';
import { setRoundPaused, setPauseTimer } from '../src/combat_timing.js';

const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-combat-scheduler.mjs <install> <module>');
const session = await new ModuleSession(await openLocalModule(install, modulePath), { runStartupScripts: false }).initialize([]);
const filename = (await fs.readdir(path.join(install, 'data/lcv'))).find(f => /\.bic$/i.test(f));
await session.loadCharacter(await fs.readFile(path.join(install, 'data/lcv', filename)), filename);
const actors = [...session.registry.objects.values()].filter(o => o.objectType === 5 && o.stats);
const target = actors.find(o => !o.isPC), ranges = [];
for (const actor of actors) {
  const authored = JSON.stringify(actor.authored), stats = actor.stats, hp = session.hitPoints(actor.id, false);
  const values = session.combat.ranges(actor, target);
  assert.ok(Number.isFinite(values.desired) && Number.isFinite(values.maximum));
  assert.equal(session.registry.get(actor.id), actor); assert.equal(actor.stats, stats);
  assert.equal(session.hitPoints(actor.id, false), hp); assert.equal(JSON.stringify(actor.authored), authored);
  ranges.push({ id: actor.id, source: actor.sourceKey, ...values });
}
const pc = session.player, round = pc.combatRound;
session.combat.setCombatState(pc, 1);
pc.animationState = 9; setRoundPaused(round, 1, pc.id); setPauseTimer(round, 1000);
session.scheduler.advance(1000); await session.scheduler.pump();
assert.equal(round.paused, true); assert.equal(round.pauseTimer, 0);
session.scheduler.advance(1); await session.scheduler.pump();
assert.equal(round.paused, false); assert.equal(pc.animationState, 1);
round.started = true; round.length = 100; round.timer = 0;
session.scheduler.advance(100); await session.scheduler.pump(); assert.equal(round.started, true);
session.scheduler.advance(1); await session.scheduler.pump(); assert.equal(round.started, false);
console.log(JSON.stringify({ module: session.resolver.moduleName, actors: actors.length, ranges, diagnostics: session.diagnostics,
  limits: 'Startup disabled. No attack requested, strike resolved or HP applied; AI-level ordering, perception, clip routing and native/server outcomes remain unverified.' }));
