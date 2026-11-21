// Cold route witness only. Arithmetic, stale-owner, authoritative movement and
// performance acceptance remain separate. No per-frame polling is introduced.
const counters = ['entries', 'active_owners', 'payload_bytes', 'configured',
  'binding_hits', 'native_queries', 'native_hits', 'fallback_queries',
  'unsupported_bindings', 'budget_fallback', 'invalidations'];
const isCount = value => Number.isSafeInteger(value) && value >= 0;

export function terrainHeightMode(value = 'script') {
  if (!['script', 'native'].includes(value)) throw new Error('Invalid terrain height route');
  return value;
}

export function terrainHeightAcceptance(requested, surface) {
  const result = {requested, verified: false, legacyScript: false,
    actual: null, nativeQueries: null, nativeHits: null, fallbackQueries: null,
    failures: []};
  const fail = reason => result.failures.push(reason);
  if (!['script', 'native'].includes(requested)) {
    fail('Unknown requested terrain height route');
    return result;
  }
  if (!surface || surface.ready !== true || !isCount(surface.queries) ||
      !isCount(surface.outside_queries) || surface.outside_queries > surface.queries) {
    fail('Ready terrain owner/query witness is unavailable or invalid');
    return result;
  }
  if (!Object.hasOwn(surface, 'height_calculations')) {
    // Frozen controls predate the optional height class. Do not manufacture
    // native counters or accept that absence for an explicit native request.
    result.legacyScript = requested === 'script';
    result.actual = result.legacyScript ? 'legacy-script' : null;
    result.verified = result.legacyScript;
    if (!result.verified) fail('Explicit native height route has no calculation witness');
    return result;
  }
  const state = surface.height_calculations;
  if (!state || typeof state.enabled !== 'boolean' || typeof state.available !== 'boolean' ||
      state.closed !== false || counters.some(name => !isCount(state[name])) ||
      state.maximum_entries !== 256 || state.maximum_payload_bytes !== 64 * 1024 * 1024 ||
      state.maximum_input_bytes !== 16 * 1024 * 1024) {
    fail('Terrain calculation state, counters or declared bounds are invalid');
    return result;
  }
  result.actual = state.enabled ? 'native' : 'script';
  result.nativeQueries = state.native_queries;
  result.nativeHits = state.native_hits;
  result.fallbackQueries = state.fallback_queries;
  if (result.actual !== requested) fail('Requested and actual terrain height routes differ');
  if (state.entries > state.maximum_entries || state.active_owners > state.entries ||
      state.active_owners > state.configured || state.payload_bytes > state.maximum_payload_bytes ||
      state.native_hits > state.native_queries ||
      state.native_queries - state.native_hits > state.fallback_queries ||
      (state.active_owners === 0) !== (state.payload_bytes === 0)) {
    fail('Terrain cache accounting/query witness is inconsistent');
  }
  if (requested === 'script') {
    if (counters.some(name => state[name] !== 0)) fail('Script control performed native cache work');
  } else {
    if (!state.available || state.configured === 0 || state.active_owners === 0 ||
        state.native_queries === 0 || state.native_hits === 0) {
      fail('Native height class did not configure and supply an actual query result');
    }
  }
  // Nonzero fallbacks are recorded rather than hidden or rejected: unusual WOK
  // inputs deliberately retain the exact original algorithm. A hit proves
  // activation only; it does not prove equivalence or a speed improvement.
  result.verified = result.failures.length === 0;
  return result;
}
