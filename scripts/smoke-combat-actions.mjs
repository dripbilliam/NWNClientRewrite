// Installed-data integration; explicit visibility/placement fixtures are not
// native perception, pathfinding or an independent encounter oracle.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import { openLocalModule } from './local-module.mjs';
import { ModuleSession } from '../src/module_session.js';
import { computeAIState } from '../src/object_actions.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';
import { runtimeDiagnostics } from '../src/runtime_diagnostics.js';

const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-combat-actions.mjs <install> <module>');
const session = await new ModuleSession(await openLocalModule(install, modulePath), { runStartupScripts: false,serverPvpSetting:0 }).initialize([]);
const filename = (await fs.readdir(path.join(install, 'data/lcv'))).find(file => /\.bic$/i.test(file));
assert.ok(filename, 'Installed character corpus is missing');
await session.loadCharacter(await fs.readFile(path.join(install, 'data/lcv', filename)), filename);
const actors = [...session.registry.objects.values()].filter(object => object.objectType === 5 && object.stats);
assert.equal(new Set(actors.map(actor => actor.objectActionState)).size, actors.length);
assert.equal(new Set(actors.map(actor => actor.perception)).size, actors.length);
for (const actor of actors) {
  const authored = JSON.stringify(actor.authored), stats = actor.stats, hp = session.hitPoints(actor.id, false);
  const state = actor.objectActionState;
  assert.equal(session.registry.get(actor.id), actor);
  assert.equal(state.list.count, 0); assert.equal(state.executingId, 65535);
  assert.equal(state.executingTargetId, OBJECT_INVALID); assert.equal(state.nextGroup, 0);
  assert.equal(actor.perception.ownerId, actor.id); assert.equal(actor.perception.nodes.length, 0);
  assert.equal(actor.perceptionUpdateFlags, actor.nativeMovementRate===1?253:255); assert.equal(actor.nativeField700, 0);
  computeAIState(actor);
  assert.equal(actor.creatureAnimation, 0); assert.equal(actor.currentAITargetId, OBJECT_INVALID);
  assert.equal(actor.stats, stats); assert.equal(session.hitPoints(actor.id, false), hp);
  assert.equal(JSON.stringify(actor.authored), authored);
}
const pc = session.player, target = actors.find(actor => !actor.isPC && !session.isDead(actor)&&session.factionTable.isNPC(actor.factionId));
assert.ok(target, 'No living placed target available');
const savedArea = pc.areaId, savedPosition = pc.position, draws = session.random.draws;
const before = runtimeDiagnostics.records.length;
const factionIndex=target.factionId-1,savedReputation=pc.factionReputation[factionIndex];
try {
  // Move only this fixture actor; do not run area-entry/startup scripts or
  // infer visibility from the mere existence of placed module objects.
  pc.areaId = target.areaId; pc.position = target.position.slice();
  assert.equal((await session.combat.evaluateAttack(pc, target.id)).targetValid, false);
  pc.perception.set(target.id, 3);
  assert.equal(session.commands.GetObjectSeen([target.id, pc.id]), 1);
  assert.equal(session.commands.GetObjectHeard([target.id, pc.id]), 1);
  assert.equal((await session.combat.evaluateAttack(pc,target.id)).targetValid,true);
  // Explicit friendly/hostile fixture values exercise the real reputation
  // reader; neither installed NPC selection nor campaign names drive runtime.
  pc.factionReputation[factionIndex]=100;
  assert.equal(await session.combat.requestAttack(pc,target.id,0,0,0),0);
  assert.equal(pc.objectActionState.list.count,0);assert.equal(session.random.draws,draws);
  pc.factionReputation[factionIndex]=0;
  assert.equal(await session.combat.requestAttack(pc,target.id,0,0,0),1);
  const node=pc.objectActionState.list.head.action;
  assert.equal(node.actionId,12);assert.equal(node.parameterData[0]>>>0,target.id);
  assert.ok(session.random.draws>draws);
  assert.equal(pc.objectActionState.list.head.action,node);
} finally {
  await session.combat.clearActions(pc);
  pc.factionReputation[factionIndex]=savedReputation;
  pc.areaId = savedArea; pc.position = savedPosition; pc.perception.remove(target.id);
}
console.log(JSON.stringify({ module: session.resolver.moduleName, actors: actors.length, playerId: pc.id,
  targetId: target.id, expectedDependencyFailures: runtimeDiagnostics.records.slice(before).filter(record => record.code === 'session.failure'),
  limits: 'Startup disabled; placement and cached visibility are explicit fixtures. No native perception, live approach, strike, casting or native/server outcome verified.' }));
