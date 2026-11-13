import test from 'node:test';
import assert from 'node:assert/strict';
import {terrainHeightAcceptance, terrainHeightMode} from './terrain_height_acceptance.mjs';

const fixture = () => ({ready: true, queries: 21, outside_queries: 1,
  height_calculations: {enabled: true, available: true, closed: false,
    entries: 2, active_owners: 1, payload_bytes: 512,
    maximum_entries: 256, maximum_payload_bytes: 64 * 1024 * 1024,
    maximum_input_bytes: 16 * 1024 * 1024, configured: 1,
    binding_hits: 16, native_queries: 18, native_hits: 18,
    fallback_queries: 2, unsupported_bindings: 1, budget_fallback: 0, invalidations: 0}});
test('Explicit route parser defaults to script and rejects unsupported values', () => {
  assert.equal(terrainHeightMode(), 'script');
  assert.equal(terrainHeightMode('native'), 'native');
  for (const value of ['off', '', null, 1]) assert.throws(() => terrainHeightMode(value));
});
test('Native activation preserves explicit fallback counts without changing input', () => {
  const surface = fixture(), before = structuredClone(surface);
  const result = terrainHeightAcceptance('native', surface);
  assert.equal(result.verified, true);
  assert.equal(result.nativeHits, 18);
  assert.equal(result.fallbackQueries, 2);
  assert.deepEqual(surface, before);
});
test('An older ready script control is identified explicitly, never as native', () => {
  const surface = {ready: true, queries: 2, outside_queries: 0};
  assert.deepEqual(terrainHeightAcceptance('script', surface), {
    requested: 'script', verified: true, legacyScript: true, actual: 'legacy-script',
    nativeQueries: null, nativeHits: null, fallbackQueries: null, failures: []});
  assert.equal(terrainHeightAcceptance('native', surface).verified, false);
});
test('New script control must show disabled route and no cache work', () => {
  const surface = fixture(), state = surface.height_calculations;
  for (const name of ['entries','active_owners','payload_bytes','configured','binding_hits',
    'native_queries','native_hits','fallback_queries','unsupported_bindings','budget_fallback','invalidations']) state[name] = 0;
  state.enabled = false;
  assert.equal(terrainHeightAcceptance('script', surface).verified, true);
  state.fallback_queries = 1;
  assert.equal(terrainHeightAcceptance('script', surface).verified, false);
});
const invalid = {
  'missing world owner': () => null,
  'unready surface': row => {row.ready = false;},
  'missing query count': row => {delete row.queries;},
  'outside count exceeds total': row => {row.outside_queries = 100;},
  'unknown native witness': row => {row.height_calculations = null;},
  'disabled request': row => {row.height_calculations.enabled = false;},
  'missing class': row => {row.height_calculations.available = false;},
  'closed owner': row => {row.height_calculations.closed = true;},
  'negative count': row => {row.height_calculations.binding_hits = -1;},
  'fractional count': row => {row.height_calculations.native_queries = 1.5;},
  'missing counter': row => {delete row.height_calculations.native_hits;},
  'larger undocumented budget': row => {row.height_calculations.maximum_entries = 512;},
  'entries exceed bound': row => {row.height_calculations.entries = 257;},
  'owners exceed bindings': row => {row.height_calculations.active_owners = 3;},
  'owners exceed configurations': row => {row.height_calculations.configured = 0;},
  'payload exceeds budget': row => {row.height_calculations.payload_bytes = 2 ** 30;},
  'zero charged active owner': row => {row.height_calculations.payload_bytes = 0;},
  'payload without owner': row => {row.height_calculations.active_owners = 0;},
  'more hits than queries': row => {row.height_calculations.native_hits = 19;},
  'unaccounted native miss': row => {row.height_calculations.native_hits = 1;},
  'route never queried': row => {row.height_calculations.native_queries = 0;row.height_calculations.native_hits = 0;}
};
for (const [name, change] of Object.entries(invalid)) test('Rejects ' + name, () => {
  const row = fixture(), changed = change(row);
  assert.equal(terrainHeightAcceptance('native', changed === null ? null : row).verified, false);
});
test('Unknown mode cannot pass as an older control', () => {
  assert.equal(terrainHeightAcceptance('off', {ready: true, queries: 0, outside_queries: 0}).verified, false);
});
