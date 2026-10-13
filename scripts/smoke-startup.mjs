// Executes installed startup NCS with no startup bypass. This checkpoint also
// asserts the remaining blockers; passing is NOT a complete-opening exit gate.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import { openLocalModule } from './local-module.mjs';
import { ModuleSession } from '../src/module_session.js';
import { decodeImaWav } from '../src/ima_adpcm.js';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-startup.mjs <install> <WitchsWake.mod>');
const resolver = await openLocalModule(install, modulePath), sounds = [], messages = [];
const s = await new ModuleSession(resolver, { onMessage: m => messages.push(m), onSound: m => sounds.push(m),
  onTransition: async ({ destination }) => { await s.enterArea(s.registry.get(destination.areaId).resRef, [...destination.position]); }
}).initialize([], { character: await fs.readFile(path.join(install, 'data/lcv/wizard.bic')) });
const playerId = s.player.id, ownedIds = [...s.player.inventory], xp = s.player.stats.xp;
assert.equal(s.runStartupScripts, true);
await s.enterArea(s.ifo.Mod_Entry_Area, [s.ifo.Mod_Entry_X, s.ifo.Mod_Entry_Z, -s.ifo.Mod_Entry_Y]);
await s.scheduler.pump();
assert.equal(s.player.cutscene.enabled, true); assert.equal(s.player.cutsceneGhost, true);
const ghost = s.commands.GetFirstEffect([playerId]);
assert.equal(s.commands.GetEffectType([ghost]), 83); assert.equal(ghost.creatorId, s.currentArea.id);
assert.equal(ghost.duration, 30); assert.equal(ghost.id.length, 16);
for (let i = 0; i < 30; i++) { s.scheduler.advance(1000); s.effects.update(); await s.scheduler.pump(); }
assert.equal(s.player.cutsceneGhost, true); s.scheduler.advance(1); s.effects.update(); assert.equal(s.player.cutsceneGhost, false);
assert.ok(s.diagnostics.some(d => /ww1_start_onent@0x245: Engine call CopyObject/.test(d)));
assert.ok(!s.diagnostics.some(d => /SetXP|character level history|spell gain rules/.test(d)));
assert.ok(!s.diagnostics.some(d => /EffectCutsceneGhost|EffectHeal|ApplyEffectToObject|PlaySound/.test(d)));
assert.equal(s.player.stats.xp, 0); assert.equal(s.player.stats.level, 1);
assert.equal(s.player.creatureData.LvlStatList.length, 1); assert.deepEqual(s.player.inventory, ownedIds);
// Exercise the real old-area exit healing script and the reward sound in the
// next authored area. The forced transfer is a test action, not an opening fix.
s.player.stats.currentHP = 1; const healAmount = s.player.stats.maxHP - 1;
await s.enterArea('brogansarm', [0, 0, 0]); await s.scheduler.pump();
assert.equal(s.player.stats.currentHP, s.player.stats.maxHP); assert.equal(s.player.id, playerId);
assert.ok(messages.some(m => m.type === 'heal' && m.amount === healAmount));
assert.equal(sounds[0].resRef, 'gui_spell_mem'); assert.equal(sounds[0].objectId, playerId);
const waveBytes = await resolver.getResource(sounds[0].resRef, 4), decoded = decodeImaWav(waveBytes);
assert.equal(decoded.channels, 1); assert.equal(decoded.sampleRate, 44100); assert.equal(decoded.frames, 60645);
const pcm = Buffer.alloc(decoded.frames * 2);
decoded.samples[0].forEach((v, i) => pcm.writeInt16LE(v * 32768, i * 2));
const audio = { frames: decoded.frames, rate: decoded.sampleRate, pcmSha256: createHash('sha256').update(pcm).digest('hex') };
if (process.argv.includes('--python-reference')) {
  const reference = JSON.parse(execFileSync(process.platform === 'win32' ? 'py' : 'python3', [fileURLToPath(new URL('./verify-ima-reference.py', import.meta.url))], { input: Buffer.from(waveBytes), encoding: 'utf8' }));
  assert.deepEqual(reference, audio); audio.independentDecoderMatched = true;
}
console.log(JSON.stringify({ startupEnabled: true, openingComplete: false, actorId: playerId, ghostCreatorId: ghost.creatorId,
  ghostExpiresStrictlyAfter30s: true, xpBefore: xp, xpAfter: s.player.stats.xp, level: s.player.stats.level, exitHealed: healAmount, canonicalIdsPreserved: true, sounds,
  audio, remainingBlockers: s.diagnostics }));
