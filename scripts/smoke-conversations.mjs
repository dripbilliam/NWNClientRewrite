// Execute shipped dialogue/NCS directly from the user's installation; no asset extraction.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { openLocalModule } from './local-module.mjs';
import { ModuleSession } from '../src/module_session.js';
import { parseConversation } from '../src/conversation.js';

const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-conversations.mjs <install> <WitchsWake.mod>');
const resolver = await openLocalModule(install, modulePath, process.env.NWN_HAK_PATH);
const keys = [...new Set([...resolver.module.entries.keys(), ...resolver.haks.flatMap(h => [...h.entries.keys()])])];
const messages = [], diagnostics = [];
const session = await new ModuleSession(resolver, { onMessage: m => messages.push(m), onDiagnostic: m => diagnostics.push(m) })
  .initialize([], { character: new Uint8Array(await fs.readFile(path.join(install, 'data/lcv/wizard.bic'))) });
let dialoguesDecoded = 0;
for (const key of keys.filter(k => k.endsWith(':2029'))) { parseConversation(await resolver.getResource(key.split(':')[0], 2029)); dialoguesDecoded++; }
const player = session.player, playerId = player.id, inventoryIds = [...player.inventory];
session.started = true; // This fixture isolates interactions from unsupported campaign startup.
const angmar = session.byTag('Angmar')[0]; assert.ok(angmar);
await session.enterArea(session.registry.get(angmar.areaId).resRef, [...angmar.position]); await session.scheduler.pump();
const xp = player.stats.xp;
assert.equal(session.requestTalk(angmar.id), true); await session.scheduler.pump();
assert.equal(session.conversation.state.resRef, 'ww1_angmar'); assert.equal(session.conversation.state.entryIndex, 0);
assert.deepEqual(session.conversation.state.replies.map(r => r.ordinal), [2, 4, 6, 8]);
assert.equal(session.commands.GetPCSpeaker([], { self: angmar.id }), playerId);
let version = session.conversation.version;
assert.equal(await session.conversation.choose(6, version), true);
assert.equal(session.conversation.state.entryIndex, 1); assert.equal(player.stats.xp, xp + 15);
assert.equal(await session.conversation.choose(6, version), false); assert.equal(player.stats.xp, xp + 15);
await session.conversation.finish(true); await session.scheduler.pump();
assert.equal(session.requestTalk(angmar.id), true); await session.scheduler.pump();
assert.equal(await session.conversation.choose(6, session.conversation.version), true);
assert.equal(player.stats.xp, xp + 15, 'The authored once-only local must prevent repeat XP');
await session.conversation.finish(true); await session.scheduler.pump();

const message = session.byTag('TearsMessage')[0]; assert.ok(message);
await session.enterArea(session.registry.get(message.areaId).resRef, [...message.position]); await session.scheduler.pump();
const questXP = player.stats.xp;
session.scheduler.enqueue(message.id, { type: 'use', playerId }); await session.scheduler.pump();
assert.equal(message.lastUsedBy, playerId); assert.equal(session.conversation.state.resRef, 'ww1_tearsmessage');
assert.deepEqual(session.conversation.state.replies.map(r => r.ordinal), [0, 2]);
assert.equal(await session.conversation.choose(0, session.conversation.version), true);
assert.equal(session.conversation.state.entryIndex, 4); assert.equal(player.stats.xp, questXP + 50);
assert.equal(player.journal.get('WW_TearsUntranslated'), 20);
await session.conversation.finish(true); await session.scheduler.pump();

const triggerOn = session.byTag('FilchableOn')[0], triggerOff = session.byTag('FilchableOff').find(t => t.areaId === triggerOn.areaId);
assert.ok(triggerOn && triggerOff);
const center = t => [t.geometry.reduce((n, p) => n + p[0], 0) / t.geometry.length, 0, -t.geometry.reduce((n, p) => n + p[1], 0) / t.geometry.length];
await session.enterArea(session.registry.get(triggerOn.areaId).resRef, center(triggerOn)); await session.scheduler.pump();
assert.equal(session.local(playerId, 'bPCInFilchMaze', 'int'), 1);
player.position = center(triggerOff); session.updateTriggers(player); await session.scheduler.pump();
assert.equal(session.local(playerId, 'bPCInFilchMaze', 'int'), 0);
assert.equal(player.id, playerId); assert.deepEqual(player.inventory, inventoryIds);
console.log(JSON.stringify({ dialoguesDecoded, actorId: playerId, angmarId: angmar.id, questObjectId: message.id,
  angmarXP: 15, repeatedXP: 0, questXP: 50, journal: [...player.journal], triggerIds: [triggerOn.id, triggerOff.id],
  canonicalIdsPreserved: true, messages, diagnostics }));
