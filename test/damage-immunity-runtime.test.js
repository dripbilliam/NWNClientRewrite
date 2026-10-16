import test from 'node:test';
import assert from 'node:assert/strict';
import { parse2da } from '../src/area.js';
import { ModuleSession } from '../src/module_session.js';
import { damageImmunityEffectIntegers, damageImmunityByFlags, setDamageImmunity } from '../src/damage_effect.js';

function fixture() {
  const s = new ModuleSession(null);
  s.characterRules = { damagetypes: parse2da(`2DA V2.0\n\nLabel\n${Array.from({ length: 13 }, (_, i) => `${i} Type`).join('\n')}`) };
  const pc = s.register('player', 'owned-immunity-test', { isPC: true, stats: { currentHP: 10,feats:[] }, authored: { FeatList: [], Race: 0 } });
  return { s, pc, self: { self: pc.id } };
}

test('immunity constructor bounds differ by sign and use active damage flag range', () => {
  assert.deepEqual(damageImmunityEffectIntegers(256, -1, true, 13), [256, 0]);
  assert.deepEqual(damageImmunityEffectIntegers(8192, 101, false, 13), [8, 100]);
  assert.deepEqual(damageImmunityEffectIntegers(-1, -101, false, 13), [8, -100]);
  assert.deepEqual(damageImmunityEffectIntegers(0, 1, true, 13), [0, 1]);
  const cache = Array(32).fill(0); setDamageImmunity(cache, 3, 150);
  assert.equal(cache[0], 100); assert.equal(cache[1], 0);
  setDamageImmunity(cache, 0, -50); assert.equal(cache[0], 100);
});

test('runtime recomputes immunity after capped stacking and deferred removal without changing canonical IDs', async () => {
  const { s, pc, self } = fixture(), id = pc.id, shared = pc.stats;
  const first = s.commands.EffectDamageImmunityIncrease([256, 70], self);
  const second = s.commands.EffectDamageImmunityIncrease([256, 70], self);
  assert.equal(s.commands.GetEffectType([first]), 44); assert.equal(first.subtype, 8);
  await s.commands.ApplyEffectToObject([2, first, id]); await s.commands.ApplyEffectToObject([2, second, id]);
  assert.equal(damageImmunityByFlags(256, pc.damageImmunityCache), 100);
  s.commands.RemoveEffect([id, first], self);
  assert.equal(damageImmunityByFlags(256, pc.damageImmunityCache), 100, 'Native script removal is deferred');
  await s.scheduler.pump();
  assert.equal(damageImmunityByFlags(256, pc.damageImmunityCache), 70);
  const decrease = s.commands.EffectDamageImmunityDecrease([256, 30], self);
  assert.equal(s.commands.GetEffectType([decrease]), 45);
  await s.commands.ApplyEffectToObject([1, decrease, id, 0.01]);
  assert.equal(damageImmunityByFlags(256, pc.damageImmunityCache), 40);
  s.scheduler.advance(11); await s.effects.update(); assert.equal(damageImmunityByFlags(256, pc.damageImmunityCache), 70);
  assert.equal(s.registry.get(id), pc); assert.equal(pc.stats, shared);
  assert.ok(pc.nativeEffectIcons778.records.some(r=>r.iconId===116));
});

test('combined flag effects update the lowest byte and recompute only exact flag matches', async () => {
  const { s, pc, self } = fixture();
  const single = s.commands.EffectDamageImmunityIncrease([1, 20], self);
  const combined = s.commands.EffectDamageImmunityIncrease([3, 60], self);
  await s.commands.ApplyEffectToObject([2, single, pc.id]); await s.commands.ApplyEffectToObject([2, combined, pc.id]);
  assert.equal(pc.damageImmunityCache[0], 60); assert.equal(pc.damageImmunityCache[1], 0);
  assert.equal(damageImmunityByFlags(3, pc.damageImmunityCache), 0);
  s.effects.remove(pc.id, combined.id);
  assert.equal(pc.damageImmunityCache[0], 0, 'Removing flags 3 does not recompute effects whose flags are 1');
  assert.deepEqual(pc.effects.map(e=>e.type),[16,67]);
});

test('negative decrease constructors are consumed on apply; live plot/immunity gates reject decreases but preserve prior effects', async () => {
  const { s, pc, self } = fixture();
  await s.commands.ApplyEffectToObject([2, s.commands.EffectDamageImmunityDecrease([256, -30], self), pc.id]);
  assert.deepEqual(pc.effects, []);
  pc.plot = true;
  await s.commands.ApplyEffectToObject([2, s.commands.EffectDamageImmunityDecrease([256, 30], self), pc.id]);
  assert.deepEqual(pc.effects, []);
  pc.plot = false; pc.authored.Plot = 1;
  await s.commands.ApplyEffectToObject([2, s.commands.EffectDamageImmunityDecrease([256, 30], self), pc.id]);
  assert.equal(pc.damageImmunityCache[8], -30, 'Live plot flag overrides the authored snapshot');
  pc.effects.push({ type: 22, integers: [22, 28, 0, 0] });
  await s.commands.ApplyEffectToObject([2, s.commands.EffectDamageImmunityDecrease([256, 20], self), pc.id]);
  assert.equal(pc.damageImmunityCache[8], -30);
  await s.commands.ApplyEffectToObject([2, s.commands.EffectDamageImmunityIncrease([256, 80], self), pc.id]);
  assert.equal(pc.damageImmunityCache[8], 50);
});
