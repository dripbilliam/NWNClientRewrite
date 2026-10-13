import test from 'node:test';
import assert from 'node:assert/strict';
import { nativeSinf, nativeCosf } from '../src/native_math.js';
const bits = new DataView(new ArrayBuffer(4));
const float = raw => { bits.setUint32(0, raw, true); return bits.getFloat32(0, true); };
const raw = value => { bits.setFloat32(0, value, true); return bits.getUint32(0, true); };

// Independent installed Windows CRT capture, not the original game's CRT.
// Broader 30,013-input capture/check is scripts/capture-crt-math.py +
// verify-native-math.mjs; it also records actual CPU-dispatch differences.
test('native traced finite trig branches match independent CRT captured quadrant and signed-zero outputs', () => {
  for (const [input, sine, cosine] of [
    [0x00000000, 0x00000000, 0x3f800000], [0x80000000, 0x80000000, 0x3f800000],
    [0x00000001, 0x00000001, 0x3f800000], [0x80000001, 0x80000001, 0x3f800000],
    [0x3fc90fdb, 0x3f800000, 0xb33bbd2e], [0x40490fdb, 0xb3bbbd2e, 0xbf800000],
    [0x40c90fdb, 0x343bbd2e, 0x3f800000], [0xc0c90fdb, 0xb43bbd2e, 0x3f800000]
  ]) {
    assert.equal(raw(nativeSinf(float(input))), sine); assert.equal(raw(nativeCosf(float(input))), cosine);
  }
});
test('native CRT SSE/FMA disagreement is explicitly rejected until actual process dispatch is known', () => {
  for (const input of [3152380171, 1005801374])
    assert.throws(() => nativeCosf(float(input)), error => /CPU dispatch/.test(error.message) && raw(error.sse) !== raw(error.fused));
});
test('unmapped native trig input branches remain explicit failures', () => {
  for (const input of [Infinity, NaN, 33, -33]) assert.throws(() => nativeSinf(input), /input branch/);
});
