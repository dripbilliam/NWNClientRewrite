// Installed BIC snapshots are a corpus cross-check, not a live native oracle.
// Assets are read in memory; no binary or resource data is copied to the repo.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import { openLocalModule } from './local-module.mjs';
import { parseCharacter, loadCharacterRules, characterStats } from '../src/character.js';
import { abilityModifier } from '../src/combat_stats.js';
import { cloneGff } from '../src/gff.js';
import { reconcileExperience } from '../src/character_progression.js';
import { ModuleSession } from '../src/module_session.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-combat.mjs <install> <module>');
const rules = await loadCharacterRules(await openLocalModule(install, modulePath));
const characters = [];
for (const filename of (await fs.readdir(path.join(install, 'data/lcv'))).filter(f => /\.bic$/i.test(f))) {
  const root = parseCharacter(await fs.readFile(path.join(install, 'data/lcv', filename))), source = JSON.stringify(root);
  const stats = characterStats(root, rules), live = stats.combat;
  const importedLevel = stats.level;
  const ability = { fortitude: 'Con', reflex: 'Dex', will: 'Wis' };
  const saveFields = { fortitude: 'FortSaveThrow', reflex: 'RefSaveThrow', will: 'WillSaveThrow' };
  const partialSaves = Object.fromEntries(Object.keys(ability).map(name => [name, live.baseSaves[name] + abilityModifier(stats.equippedAbilities[ability[name]], rules)]));
  const snapshot = { attack: root.BaseAttackBonus, armorClass: root.ArmorClass, saves: Object.fromEntries(Object.entries(saveFields).map(([name, field]) => [name, root[field]])) };
  const session = new ModuleSession(null); session.characterRules = rules;
  const pc = session.register('player', 'combat-corpus', { authored: root, stats });
  const id = pc.id, shared = pc.stats;
  assert.equal(session.commands.GetBaseAttackBonus([id]), live.baseAttackBonus);
  assert.equal(session.commands.GetBaseAttackBonus([OBJECT_INVALID]), 0);
  assert.equal(session.commands.GetAC([id]), live.armorClass);
  for (const [save, command] of Object.entries({ fortitude: 'GetFortitudeSavingThrow', reflex: 'GetReflexSavingThrow', will: 'GetWillSavingThrow' })) assert.equal(session.commands[command]([id]), live.saves[save]);
  let rollback = null;
  if (stats.level > 1) {
    const down = reconcileExperience(root, stats, 0, rules);
    const prepared = cloneGff(down.root); prepared.LvlStatList = cloneGff(root.LvlStatList);
    const up = reconcileExperience(prepared, down.stats, stats.xp, rules);
    assert.deepEqual(up.stats.combat, live, `${filename}: combat providers recompute after future-history replay`);
    const temporary = session.commands.EffectSavingThrowIncrease([0, 3], { self: id });
    session.commands.ApplyEffectToObject([1, temporary, id, 1]);
    session.commands.SetXP([id, 0]);
    assert.equal(pc.stats, shared); assert.equal(session.registry.get(id), pc);
    assert.equal(session.commands.GetBaseAttackBonus([id]), down.stats.combat.baseAttackBonus);
    assert.deepEqual(pc.stats.combat.saves, Object.fromEntries(Object.entries(down.stats.combat.saves).map(([key, value]) => [key, value + 3])), 'Live effects survive XP rollback');
    session.effects.remove(id, temporary.id);
    assert.deepEqual(pc.stats.combat.saves, down.stats.combat.saves, 'Removing the temporary source restores class/gear-derived saves');
    rollback = { level: down.stats.level, attack: down.stats.combat.baseAttackBonus, saves: down.stats.combat.baseSaves, finalSaves: down.stats.combat.saves, armorClass: down.stats.combat.armorClass };
  }
  assert.equal(JSON.stringify(root), source, 'Imported BIC stays immutable');
  characters.push({ filename, level: importedLevel, attack: live.baseAttackBonus, baseSaves: live.baseSaves, partialSaves, snapshot,
    armorClass: live.armorClass, attackBonuses: live.attackBonuses, finalSaves: live.saves, unsupported: live.unsupportedItemProperties,
    armorSnapshotMatch: snapshot.armorClass === undefined ? null : live.armorClass === snapshot.armorClass,
    finalSavesSnapshotMatch: Object.keys(ability).every(name => live.saves[name] === snapshot.saves[name]),
    attackSnapshotMatch: snapshot.attack === undefined ? null : live.baseAttackBonus === snapshot.attack,
    savesSnapshotMatch: Object.keys(ability).every(name => partialSaves[name] === snapshot.saves[name]), rollback });
}
console.log(JSON.stringify({ module: path.basename(modulePath), count: characters.length,
  attackSnapshots: characters.filter(c => c.attackSnapshotMatch !== null).length,
  attackSnapshotMatches: characters.filter(c => c.attackSnapshotMatch).length,
  savesSnapshotMatches: characters.filter(c => c.savesSnapshotMatch).length, characters,
  armorSnapshots: characters.filter(c => c.armorSnapshotMatch !== null).length,
  armorSnapshotMatches: characters.filter(c => c.armorSnapshotMatch).length,
  finalSavesSnapshotMatches: characters.filter(c => c.finalSavesSnapshotMatch).length,
  limits: 'Snapshots are serialized historical values, not an independent live native oracle. Opponent-dependent AC/attack, active ability effects, unsupported item properties, save rolls and multiplayer parity remain open.' }));
