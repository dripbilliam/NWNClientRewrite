import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import { nativeAsinf, nativeAtan2f } from '../src/native_math.js';
const capture = JSON.parse(await fs.readFile(process.argv[2], 'utf8'));
const bits = new DataView(new ArrayBuffer(4));
const from = raw => { bits.setUint32(0, raw, true); return bits.getFloat32(0, true); };
const to = value => { bits.setFloat32(0, value, true); return bits.getUint32(0, true); };
let asinDifferences = 0;
for (const [input, expected] of capture.asin) {
  const actual = to(nativeAsinf(from(input)));
  if (actual !== expected) {
    if (!capture.reference.startsWith('installed Windows')) assert.equal(actual, expected, `asinf ${input.toString(16)}`);
    assert.equal(Math.abs(actual - expected), 1, 'Embedded game/installed CRT difference exceeds one float32 step');
    asinDifferences++;
  }
}
for (const [y, x, expected] of capture.atan2 ?? []) assert.equal(to(nativeAtan2f(from(y), from(x))), expected, `atan2f ${y.toString(16)},${x.toString(16)}`);
console.log(JSON.stringify({reference:capture.reference, exactAsinOutputs:capture.asin.length - asinDifferences, asinDifferences, exactAtan2Outputs:capture.atan2?.length ?? 0}));
