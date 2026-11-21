// Validate installed BICs and compiled scripts in memory; no asset extraction.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import { openLocalModule } from './local-module.mjs';
import { parseCharacter, loadCharacterRules, characterStats } from '../src/character.js';
import { getGffStructType } from '../src/gff.js';
import { ModuleSession } from '../src/module_session.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-character.mjs <install> <WitchsWake.mod>');
const resolver = await openLocalModule(install, modulePath), rules = await loadCharacterRules(resolver);
const directory = path.join(install, 'data/lcv'); let parsed = 0; const hpDifferences = [];
for (const filename of await fs.readdir(directory)) {
  if (!/\.bic$/i.test(filename)) continue;
  const root = parseCharacter(await fs.readFile(path.join(directory, filename))), stats = characterStats(root, rules);
  if (stats.maxHP !== root.MaxHitPoints) hpDifferences.push({ filename, loaded: stats.maxHP, savedSnapshot: root.MaxHitPoints });
  parsed++;
}
const messages = [], sounds = [];
const s = await new ModuleSession(resolver, { onMessage: m => messages.push(m), onSound: m => sounds.push(m) }).initialize([], { character: await fs.readFile(path.join(directory, 'wizard.bic')) });
const p = s.player, id = p.id, before = p.stats.xp;
assert.equal(p.characterLoaded, true); assert.equal(p.stats.maxHP, 77); assert.equal(p.stats.classes[0].id, 10);
assert.ok(p.appearance.parts.length); assert.equal(s.registry.get(id), p);
const items = p.inventory.map(i => s.registry.get(i));
assert.equal(items.length, p.authored.ItemList.length + p.authored.Equip_ItemList.length);
assert.ok(items.every(i => i.ownerId === id && i.areaId === OBJECT_INVALID));
assert.ok(p.authored.Equip_ItemList.every(source => items.some(i => i.authored === source && i.equipmentSlot === getGffStructType(source))));
assert.ok(items.every(i => i.id !== i.authored.ObjectId));
const area = [...s.areas.values()].find(a => a.scripts.enter === 'ww_enter_brogan');
assert.ok(area); area.eventObjects.entering = id;
p.areaId = area.id;
await s.vm.run(await s.program('ww_enter_brogan'), area.id);
assert.equal(p.stats.xp, before + 100); assert.equal(messages.find(m => m.type === 'xp').id, id);
await s.scheduler.pump();
assert.equal(sounds.length, 1); assert.equal(sounds[0].objectId, id);
assert.ok(!s.diagnostics.some(d => d.includes('PlaySound') || d.includes('GiveXP')));
await s.vm.run(await s.program('ww_enter_brogan'), area.id); assert.equal(p.stats.xp, before + 100, 'Native local flag prevents repeated entry reward');
await assert.rejects(s.loadCharacter(await fs.readFile(path.join(directory, 'fighter.bic'))), /Replacing/);
assert.equal(s.player.id, id); assert.equal(s.registry.objects.size, 3370);
console.log(JSON.stringify({ parsed, hpDifferences, actorId: id, items: items.map(i => ({ id: i.id, ownerId: i.ownerId, equipmentSlot: i.equipmentSlot })), model: p.appearance.model, xpBefore: before, xpAfter: p.stats.xp, journalScriptAvailable: true, sounds, diagnostics: s.diagnostics }));
