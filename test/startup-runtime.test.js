import test from 'node:test';
import assert from 'node:assert/strict';
import { ModuleSession } from '../src/module_session.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';
import { decodeImaWav } from '../src/ima_adpcm.js';
import { GameAudio } from '../src/game_audio.js';

function fixture() {
  const messages = [], sounds = [], s = new ModuleSession({}, { onMessage: m => messages.push(m), onSound: m => sounds.push(m) });
  const pc = s.register('player', 'pc', { isPC: true, position: [0, 0, 0], stats: { xp: 100, level: 1, nextXP: 1000, currentHP: 5, maxHP: 10 }, authored: { LvlStatList: [{}] } });
  const area = s.register('area', 'area', { objects: [pc.id] }); pc.areaId = area.id; s.player = pc;
  return { s, pc, area, messages, sounds, self: { self: pc.id } };
}

test('effects use a separate uint64 sequence, preserve cloned handles, and native validity excludes instant values', () => {
  const { s, pc, self } = fixture();
  s.effects.nextId = 0x20000000000001n;
  const e = s.commands.EffectCutsceneGhost([], self);
  assert.equal(e.id, '0020000000000001'); assert.equal(e.creatorId, pc.id);
  assert.equal(s.commands.GetIsEffectValid([e]), 0);
  s.commands.ApplyEffectToObject([1, e, pc.id, 30]);
  const found = s.commands.GetFirstEffect([pc.id]);
  assert.equal(found.id, e.id); assert.equal(s.commands.GetIsEffectValid([found]), 1);
  assert.equal(s.commands.GetEffectType([found]), 83); assert.equal(s.commands.GetEffectSubType([found]), 0);
  assert.equal(s.commands.GetEffectCreator([found]), pc.id);
  assert.equal(s.commands.GetEffectDurationType([found]), 1); assert.equal(s.commands.GetEffectSpellId([found]), -1);
  assert.equal(s.commands.GetIsEffectValid([e]), 0, 'Apply mutates its VM copy, not the caller value');
  found.creatorId = OBJECT_INVALID; assert.equal(pc.effects[0].creatorId, pc.id);
});

test('ghost duplicates are consumed; temporary effects expire strictly after their deadline', () => {
  const { s, pc, self } = fixture();
  s.commands.ApplyEffectToObject([1, s.commands.EffectCutsceneGhost([], self), pc.id, 0.25]);
  s.commands.ApplyEffectToObject([2, s.commands.EffectCutsceneGhost([], self), pc.id]);
  assert.equal(pc.effects.length, 1); assert.equal(pc.cutsceneGhost, true);
  s.scheduler.advance(250); s.effects.update(); assert.equal(pc.cutsceneGhost, true);
  s.scheduler.advance(1); s.effects.update(); assert.equal(pc.cutsceneGhost, false); assert.equal(pc.effects.length, 0);
  s.commands.ApplyEffectToObject([9, s.commands.EffectCutsceneGhost([], self), pc.id]);
  s.scheduler.advance(100000); s.effects.update(); assert.equal(pc.cutsceneGhost, true);
  assert.equal(pc.effects[0].durationType, 2, 'Other duration values follow the native permanent branch');
  assert.throws(() => s.effects.apply(1, s.commands.EffectCutsceneGhost([], self), pc.id, -1), /duration/);
});

test('effect removal matches value IDs and is deferred; enumeration hides removed records before deletion', async () => {
  const { s, pc, self } = fixture();
  const ghost = s.commands.EffectCutsceneGhost([], self);
  s.commands.ApplyEffectToObject([2, ghost, pc.id]);
  const copy = s.commands.GetFirstEffect([pc.id]);
  s.commands.RemoveEffect([pc.id, structuredClone(copy)], self);
  assert.equal(pc.cutsceneGhost, true); assert.equal(pc.effects.length, 1);
  assert.equal(s.commands.GetIsEffectValid([s.commands.GetFirstEffect([pc.id])]), 0);
  assert.equal(s.commands.GetIsEffectValid([copy]), 1, 'A returned snapshot is not a live pointer');
  await s.scheduler.pump(); assert.equal(pc.cutsceneGhost, false); assert.equal(pc.effects.length, 0);
  s.commands.RemoveEffect([OBJECT_INVALID, copy], self);
});

test('heal clamps to maximum HP, consumes even permanent effects, and does not resurrect dead creatures', () => {
  const { s, pc, self, messages } = fixture();
  const heal = s.commands.EffectHeal([500], self);
  assert.equal(heal.subtype, 8); assert.equal(s.commands.GetEffectType([heal]), 0); assert.equal(s.commands.GetEffectType([heal, 1]), 96);
  s.commands.ApplyEffectToObject([2, heal, pc.id]);
  assert.equal(pc.stats.currentHP, 10); assert.equal(messages.at(-1).amount, 5); assert.equal(pc.effects, undefined);
  pc.stats.currentHP = -10; s.commands.ApplyEffectToObject([0, heal, pc.id]); assert.equal(pc.stats.currentHP, -10);
  pc.stats.currentHP = -3; s.commands.ApplyEffectToObject([0, heal, pc.id]); assert.equal(pc.stats.currentHP, 10);
  for (const n of [0, -10]) assert.equal(s.commands.EffectHeal([n], self).type, 0);
  assert.throws(() => s.effects.apply(0, { type: 1 }, pc.id), /not implemented/);
});

test('enumeration has an object-local cursor, restarts after exhaustion, and rejects saved unknown effects', () => {
  const { s, pc, area, self } = fixture();
  const placeable = s.register('placeable', 'prop', { authored: {}, areaId: area.id });
  for (let i = 0; i < 2; i++) s.commands.ApplyEffectToObject([2, s.commands.EffectCutsceneGhost([], self), placeable.id]);
  const first = s.commands.GetFirstEffect([placeable.id]), second = s.commands.GetNextEffect([placeable.id]);
  assert.notEqual(first.id, second.id); assert.equal(placeable.cutsceneGhost, undefined);
  assert.equal(s.commands.GetIsEffectValid([s.commands.GetNextEffect([placeable.id])]), 0);
  assert.equal(s.commands.GetNextEffect([placeable.id]).id, first.id);
  assert.equal(s.commands.GetIsEffectValid([s.commands.GetFirstEffect([pc.id])]), 0);
  // Reapplying a copied handle retains its uint64 ID. The removal scan hides
  // every matching live record before posting a single native-style event.
  s.commands.ApplyEffectToObject([2, first, placeable.id]);
  s.commands.RemoveEffect([placeable.id, first], self);
  assert.equal(placeable.effects.filter(e => e.id === first.id).every(e => !e.exposed), true);
  pc.authored.EffectList = [{}]; assert.throws(() => s.commands.GetFirstEffect([pc.id]), /import/);
});

test('SetXP assigns without multiclass penalties, ignores negatives/DMs, and rejects corrupt history atomically', () => {
  const { s, pc, messages } = fixture();
  s.characterRules = { exptable: { rows: new Map([[0, { XP: '0' }], [1, { XP: '1000' }]]) } };
  pc.associateType = 1; s.commands.SetXP([pc.id, 50]); assert.equal(pc.stats.xp, 50); assert.equal(messages.at(-1).amount, -50);
  s.commands.SetXP([pc.id, 1000]); assert.equal(pc.stats.canLevelUp, true); assert.equal(pc.stats.level, 1);
  s.commands.SetXP([pc.id, -1]); assert.equal(pc.stats.xp, 1000);
  pc.isDM = true; s.commands.SetXP([pc.id, 0]); assert.equal(pc.stats.xp, 1000);
  pc.isDM = false; pc.stats.level = 2; pc.stats.nextXP = 3000;
  s.commands.SetXP([pc.id, 1100]); s.commands.SetXP([pc.id, 1000]); assert.equal(pc.stats.xp, 1000);
  assert.throws(() => s.commands.SetXP([pc.id, 0]), /history/); assert.equal(pc.stats.xp, 1000);
  s.characterRules = null; assert.throws(() => s.commands.SetXP([pc.id, 900]), /threshold/); assert.equal(pc.stats.xp, 1000);
  s.commands.SetXP([OBJECT_INVALID, 100]);
});

test('PlaySound is deferred, cancellable, and routes same-area recipients at inclusive 20m 3D distance', async () => {
  const { s, pc, area, sounds } = fixture();
  const npc = s.register('creature', 'speaker', { position: [20, 0, 0], areaId: area.id });
  const play = () => s.commands.PlaySound(['cue'], { self: npc.id });
  play(); assert.equal(sounds.length, 0); await s.scheduler.pump(); assert.equal(sounds.length, 1); assert.equal(sounds[0].objectId, npc.id);
  npc.position[1] = 1; play(); await s.scheduler.pump(); assert.equal(sounds.length, 1);
  npc.position = [0, 0, 0]; npc.areaId = OBJECT_INVALID; play(); await s.scheduler.pump(); assert.equal(sounds.length, 1);
  npc.areaId = area.id; play(); s.commands.ClearAllActions([], { self: npc.id }); await s.scheduler.pump(); assert.equal(sounds.length, 1);
  npc.commandable = false; play(); assert.equal(s.scheduler.events.length, 0);
  s.commands.PlaySound(['cue'], { self: area.id }); assert.equal(s.scheduler.events.length, 0);
  assert.equal(pc.id, 0, 'All routing works with object ID zero');
});

function wav({ stereo = false, predictor = 0, index = 0, payload = [0x71, 0x08, 0x77, 0xff], fact } = {}) {
  const channels = stereo ? 2 : 1, block = channels * 4 + payload.length, bytes = new Uint8Array(60 + block), v = new DataView(bytes.buffer);
  const tag = (p, text) => bytes.set(new TextEncoder().encode(text), p);
  tag(0, 'RIFF'); v.setUint32(4, bytes.length - 8, true); tag(8, 'WAVE'); tag(12, 'fmt '); v.setUint32(16, 20, true);
  v.setUint16(20, 17, true); v.setUint16(22, channels, true); v.setUint32(24, 8000, true); v.setUint16(32, block, true); v.setUint16(34, 4, true); v.setUint16(36, 2, true); v.setUint16(38, 1 + payload.length * 2 / channels, true);
  tag(40, 'fact'); v.setUint32(44, 4, true); v.setUint32(48, fact ?? 1 + payload.length * 2 / channels, true); tag(52, 'data'); v.setUint32(56, block, true);
  for (let c = 0; c < channels; c++) { v.setInt16(60 + c * 4, c ? -predictor : predictor, true); bytes[62 + c * 4] = index; }
  bytes.set(payload, 60 + channels * 4); return bytes;
}
test('IMA WAVE uses low-first nibbles, header predictors, channel groups and fact trimming', () => {
  const decoded = decodeImaWav(wav());
  // Independently checked with Python 3.12 audioop.adpcm2lin (byte nibble swap).
  assert.deepEqual([...decoded.samples[0]].map(n => n * 32768), [0, 1, 12, 10, 11, 34, 86, -26, -269]);
  const stereo = decodeImaWav(wav({ stereo: true, predictor: 100, payload: Array(4).fill(0x11).concat(Array(4).fill(0x99)), fact: 3 }));
  assert.deepEqual([...stereo.samples[0]].map(n => n * 32768), [100, 101, 102]);
  assert.deepEqual([...stereo.samples[1]].map(n => n * 32768), [-100, -101, -102]);
  assert.equal(stereo.channels, 2); assert.equal(stereo.frames, 3); assert.equal(stereo.sampleRate, 8000);
});
test('IMA WAVE clamps prediction and rejects corrupt headers, sample counts and truncation', () => {
  const decoded = decodeImaWav(wav({ predictor: 32760, index: 88, payload: [0x77, 0xff, 0, 0] }));
  assert.equal(decoded.samples[0][1] * 32768, 32767); assert.equal(decoded.samples[0][4] * 32768, -32768);
  assert.throws(() => decodeImaWav(wav({ index: 89 })), /block header/);
  assert.throws(() => decodeImaWav(wav({ fact: 100 })), /sample count/);
  assert.throws(() => decodeImaWav(wav().slice(0, -1)), /Truncated/);
  assert.equal(decodeImaWav(new Uint8Array(16)), null);
});

test('audio decoding caches resources, queues suspended output, resumes on input and disposes pending sources', async () => {
  const listeners = {}, starts = [], sources = []; let loads = 0;
  const context = { state: 'suspended', destination: {}, listener: { positionX: {}, positionY: {}, positionZ: {} },
    addEventListener: (n, f) => { listeners[n] = f; }, async resume() { this.state = 'running'; listeners.statechange(); }, async close() { this.state = 'closed'; },
    createBuffer: (channels, length, sampleRate) => ({ numberOfChannels: channels, length, sampleRate, duration: length / sampleRate, copyToChannel() {} }),
    createBufferSource: () => { const source = { connect() {}, disconnect() {}, addEventListener() {}, start() { starts.push(this.buffer); }, stop() {} }; sources.push(source); return source; }
  };
  const states = [], audio = new GameAudio({ getResource: async () => { loads++; return wav().buffer; } }, { getPlayer: () => ({ id: 0, position: [1, 2, 3] }), getObject: () => null, createContext: () => context, onState: state => states.push(state) });
  const event = { resRef: 'cue', objectId: 0, position: [1, 2, 3] };
  await audio.play(event); await audio.play(event); assert.equal(loads, 1); assert.equal(starts.length, 0); assert.equal(states.at(-1).pending, 2);
  await audio.unlock(); assert.equal(starts.length, 2); assert.equal(states.at(-1).context, 'running'); assert.equal(states.at(-1).played, 2);
  audio.dispose(); await audio.play(event); assert.equal(loads, 1); assert.equal(audio.active.size, 0);
});
