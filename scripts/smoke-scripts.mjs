// Execute installed NCS resources in memory. Never extract proprietary scripts.
import assert from 'node:assert/strict';
import { openLocalModule } from './local-module.mjs';
import { ModuleSession } from '../src/module_session.js';
import { parseNcs } from '../src/ncs.js';

const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-scripts.mjs <install> <WitchsWake.mod>');
const resolver = await openLocalModule(install, modulePath, process.env.NWN_HAK_PATH);
const keys = [...new Set([...resolver.module.entries.keys(), ...resolver.haks.flatMap(hak => [...hak.entries.keys()])])];
const areas = keys.filter(key => key.endsWith(':2012')).map(key => key.split(':')[0]);
const messages = [], jumps = [], diagnostics = [];
const session = await new ModuleSession(resolver, {
  onMessage: message => messages.push(message), onDiagnostic: message => diagnostics.push(message),
  onTransition: async ({ actor, destination }) => {
    jumps.push({ actorId: actor.id, destinationId: destination.id, areaId: destination.areaId });
    await session.enterArea(session.registry.get(destination.areaId).resRef, [...destination.position]);
  }
}).initialize(areas);
const player = session.player, id = player.id;
assert.equal(session.registry.objects.size, new Set([...session.registry.objects.keys()]).size);
assert.ok([...session.registry.objects.values()].every(object => Number.isInteger(object.id) && object.id >= 0));
const inventory = [...session.registry.objects.values()].filter(object => object.ownerId !== undefined);
assert.ok(inventory.length > 0); assert.ok(inventory.every(item => session.registry.get(item.ownerId)?.inventory.includes(item.id)));
let scriptsDecoded = 0;
for (const key of keys.filter(key => key.endsWith(':2010'))) {
  const name = key.split(':')[0]; parseNcs(await resolver.getResource(name, 2010), name); scriptsDecoded++;
}
session.module.eventObjects.entering = id;
await session.vm.run(await session.program('ww_cliententer'), session.module.id);
assert.equal(player.journal.size, 11); assert.equal(session.local(id, 'WW_SUBRACE_JOURNAL_ADDED', 'int'), 1);
const journal = [...player.journal];
await session.vm.run(await session.program('ww_cliententer'), session.module.id);
assert.deepEqual([...player.journal], journal);
const source = session.byTag('Angmar_Brogan')[0], target = session.transitionTarget(source);
source.eventObjects.clicking = id;
player.isPossessedFamiliar = true;
await session.vm.run(await session.program('ww_trans_nofamil'), source.id);
await session.scheduler.pump();
assert.equal(jumps.length, 0); assert.equal(messages.length, 1); assert.equal(messages[0].type, 'floating');
player.isPossessedFamiliar = false;
session.started = true;
await session.enterArea('angmarshouse', [...source.position]); await session.scheduler.pump();
session.commands.SetLocalObject([id, 'source_door', source.id]);
for (const door of [source, target]) {
  door.eventObjects.clicking = id;
  await session.vm.run(await session.program('ww_trans_nofamil'), door.id);
  const before = jumps.length;
  assert.ok(session.scheduler.events.length, 'AssignCommand must queue a continuation');
  assert.equal(jumps.length, before);
  await session.scheduler.pump();
}
assert.equal(jumps.length, 2); assert.equal(jumps[0].destinationId, target.id); assert.equal(jumps[1].destinationId, source.id);
assert.equal(player.id, id); assert.equal(player.areaId, session.areas.get('angmarshouse').id);
assert.equal(session.local(id, 'source_door', 'object'), source.id); assert.deepEqual([...player.journal], journal);
assert.ok(diagnostics.some(message => /not implemented/.test(message)), 'Unsupported campaign calls should be explicit');
console.log(JSON.stringify({ areas: areas.length, objects: session.registry.objects.size, ownedItems: inventory.length,
  scriptsDecoded, actorId: id, doorIds: [source.id, target.id], journalEntries: player.journal.size,
  familiarRejected: true, deferredRoundTrip: jumps, diagnostics }));
