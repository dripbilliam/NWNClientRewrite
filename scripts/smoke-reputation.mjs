// Installed FAC/BIC integration; not an independent native encounter oracle.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import { openLocalModule } from './local-module.mjs';
import { ModuleSession } from '../src/module_session.js';
import { parseGff } from '../src/gff.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-reputation.mjs <install> <module>');
const resolver = await openLocalModule(install, modulePath);
const fac = parseGff(await resolver.getResource('repute', 2038), 'FAC ').root;
const session = await new ModuleSession(resolver, { runStartupScripts: false }).initialize([]);
const filename = (await fs.readdir(path.join(install, 'data/lcv'))).find(file => /\.bic$/i.test(file));
await session.loadCharacter(await fs.readFile(path.join(install, 'data/lcv', filename)), filename);
const actors = [...session.registry.objects.values()].filter(object => object.objectType === 5 && object.stats);
assert.equal(session.factionTable.npcCount, fac.FactionList.length - 1);
const expectedVector = Array(fac.FactionList.length - 1).fill(100);
for (const entry of fac.RepList ?? []) if (entry.FactionID1 === 0 && entry.FactionID2 > 0 && entry.FactionID2 <= expectedVector.length)
  expectedVector[entry.FactionID2 - 1] = Math.max(0, Math.min(100, entry.FactionRep));
assert.deepEqual(session.factionTable.defaultPC(), expectedVector);
const pc = session.player;
assert.equal(pc.factionId, expectedVector.length + 1); assert.equal(pc.masterId, OBJECT_INVALID);
assert.notEqual(pc.factionReputation, session.factionTable.values);
assert.deepEqual(pc.factionReputation, pc.creatureData.ReputationList?.map(entry => entry.Amount | 0) ?? expectedVector);
const original = pc.factionReputation.slice(), hp = session.hitPoints(pc.id, false), draws = session.random.draws, checks = [];
for (const npc of actors.filter(object => object !== pc && object.masterId === OBJECT_INVALID && object.factionId > 0 && object.factionId <= expectedVector.length)) {
  if (npc.personalReputationList.length) continue; // World clock import remains a diagnosed boundary.
  const expected = Math.max(0, Math.min(100, original[npc.factionId - 1]));
  assert.equal(session.reputation(pc, npc), expected); assert.equal(session.reputation(npc, pc), expected);
  assert.equal(session.commands.GetReputation([pc.id, npc.id]), expected);
  assert.equal(session.registry.get(npc.id), npc);
  checks.push({ id: npc.id, faction: npc.factionId, reputation: expected });
}
const npc = actors.find(object => object !== pc && object.factionId > 0 && object.factionId <= expectedVector.length && object.personalReputationList.length === 0);
assert.ok(npc, 'No ordinary placed NPC faction available');
pc.factionReputation[npc.factionId - 1] = 37;
assert.equal(session.reputation(pc, npc), 37); assert.equal(session.reputation(npc, pc), 37);
pc.factionReputation.splice(0, pc.factionReputation.length, ...original);
assert.equal(session.hitPoints(pc.id, false), hp); assert.equal(session.random.draws, draws);
assert.equal(new Set(actors.map(object => object.personalReputationList)).size, actors.length);
console.log(JSON.stringify({ module: resolver.moduleName, actors: actors.length, npcFactions: expectedVector.length, playerId: pc.id,
  playerFaction: pc.factionId, checks, limits: 'Startup disabled. Native-traced FAC/BIC ownership and live queries only; perception, timed reputation mutation, native encounter outcomes and server authority remain unverified.' }));
