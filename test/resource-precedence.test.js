import test from 'node:test';
import assert from 'node:assert/strict';
import { ResourceResolver, decodeResourceText } from '../src/resource_archive.js';
import { ModuleSession } from '../src/module_session.js';
import { parse2da } from '../src/area.js';

const encode = text => new TextEncoder().encode(text);
const file = (name, bytes) => ({ name: name.split('/').at(-1), webkitRelativePath: name,
  async arrayBuffer() { return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength); } });
function key(bif, names) {
  const filename = encode(bif + '\0'), nameOffset = 76 + names.length * 22;
  const bytes = new Uint8Array(nameOffset + filename.length), v = new DataView(bytes.buffer);
  bytes.set(encode('KEY V1  ')); v.setUint32(8, 1, true); v.setUint32(12, names.length, true);
  v.setUint32(16, 64, true); v.setUint32(20, 76, true);
  v.setUint32(68, nameOffset, true); v.setUint16(72, filename.length, true); bytes.set(filename, nameOffset);
  for (const [i, name] of names.entries()) { bytes.set(encode(name), 76 + i * 22); v.setUint16(92 + i * 22, 2017, true); v.setUint32(94 + i * 22, i, true); }
  return bytes;
}
function bif(texts) {
  const data = texts.map(encode), offset = 20 + data.length * 16;
  const bytes = new Uint8Array(offset + data.reduce((n, b) => n + b.length, 0)), v = new DataView(bytes.buffer);
  bytes.set(encode('BIFFV1  ')); v.setUint32(8, data.length, true); v.setUint32(16, 20, true);
  let next = offset;
  for (const [i, value] of data.entries()) {
    v.setUint32(20 + i * 16, i, true); v.setUint32(24 + i * 16, next, true);
    v.setUint32(28 + i * 16, value.length, true); v.setUint32(32 + i * 16, 2017, true);
    bytes.set(value, next); next += value.length;
  }
  return bytes;
}
const files = () => [
  file('data/nwn_base.key', key('data/base.bif', ['shared', 'baseonly'])),
  file('data/base.bif', bif(['base shared', 'base only'])),
  file('data/nwn_retail.key', key('data/retail.bif', ['retailonly', 'shared'])),
  file('data/retail.bif', bif(['retail only', 'retail shared']))
];

test('installed retail overrides base while both catalogs retain local BIF resource indices', async () => {
  const resolver = await ResourceResolver.createGameData(files());
  const text = async name => decodeResourceText(await resolver.getResource(name, 2017));
  assert.equal(await text('shared'), 'retail shared');
  assert.equal(await text('retailonly'), 'retail only');
  assert.equal(await text('baseonly'), 'base only');
  assert.deepEqual(resolver.key.sources, ['nwn_retail.key', 'nwn_base.key']);
  assert.equal(resolver.key.resources.get('shared:2017').keySource, 'nwn_retail.key');
  resolver.haks.push({ name: 'custom', entries: new Map([['shared:2017', encode('HAK shared')]]) });
  assert.equal(await text('shared'), 'HAK shared');
  resolver.module.entries.set('shared:2017', encode('module shared'));
  assert.equal(await text('shared'), 'module shared');
});

test('a corrupt selected retail resource fails without substituting lower-priority base data', async () => {
  const selected = files(); selected[3] = file('data/retail.bif', encode('broken'));
  const resolver = await ResourceResolver.createGameData(selected);
  await assert.rejects(resolver.getResource('shared', 2017), /BIF header/);
  assert.equal(decodeResourceText(await resolver.getResource('baseonly', 2017)), 'base only');
  await assert.rejects(ResourceResolver.createGameData([...files(), file('duplicate/nwn_retail.key', key('data/retail.bif', ['shared']))]), /uniquely locate/);
});

test('EffectDamage constructs a canonical uint64 effect from active damage type row count and exposes native script type', async () => {
  const session = new ModuleSession({}), creator = session.register('creature', 'creator', {});
  session.characterRules = { damagetypes: parse2da('2DA V2.0\n\nLabel\n99 first\n77 second') };
  const effect = session.commands.EffectDamage([5, 4, 23], { self: creator.id });
  assert.equal(effect.type, 38); assert.equal(effect.creatorId, creator.id);
  assert.equal(effect.id, '0000000000000001'); assert.equal(effect.subtype, 8);
  assert.equal(effect.integers[0], 5, 'Unsupported flag uses native fallback; labels are not row indices');
  assert.equal(effect.integers[35], 0);
  assert.equal(session.commands.GetEffectType([effect]), 0);
  assert.equal(session.commands.GetEffectType([effect, 1]), 93);
  await assert.rejects(session.effects.apply(0, effect, creator.id), /HP provider is unavailable/,
    'Damage rejects targets whose live HP has not been loaded');
});
