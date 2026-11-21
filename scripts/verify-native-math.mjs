import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import { nativeSinf, nativeCosf } from '../src/native_math.js';
const capture = JSON.parse(await fs.readFile(process.argv[2], 'utf8'));
const view = new DataView(new ArrayBuffer(4));
function fromBits(bits) { view.setUint32(0, bits, true); return view.getFloat32(0, true); }
function toBits(value) { view.setFloat32(0, value, true); return view.getUint32(0, true); }
let checked = 0, unsupported = [];
for (const [input, sine, cosine] of capture.observations) {
  for (const [operation, fn, expected] of [['sin', nativeSinf, sine], ['cos', nativeCosf, cosine]]) {
    let actual;
    try { actual = toBits(fn(fromBits(input))); }
    catch (error) {
      assert.match(error.message, /CPU dispatch produces different/);
      assert.ok(expected === toBits(error.sse) || expected === toBits(error.fused), 'Neither native dispatch branch matches the reference');
      unsupported.push({ operation, input, value: fromBits(input), reason: error.message, sse: error.sse, fused: error.fused }); continue;
    }
    assert.equal(actual, expected, `CRT ${operation} mismatch at float32 bits ${input.toString(16)}`); checked++;
  }
}
console.log(JSON.stringify({ reference: capture.reference, inputCount: capture.observations.length, checkedOutputs: checked, unsupported }));
assert.ok(checked > 0);
