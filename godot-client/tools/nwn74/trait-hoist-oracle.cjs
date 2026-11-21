'use strict';
// Source-level guard and exhaustive descriptor-mask equivalence, no engine/client launch.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const sourcePath = path.join(root, '.cache/nwn74/trait-hoist-a/overlay.cpp');
const bytes = fs.readFileSync(sourcePath);
const source = bytes.toString();
const body = source.split('void RenderingDevice::draw_list_draw(')[1]?.split('void RenderingDevice::draw_list_draw_indirect(')[0];
assert(body, 'draw_list_draw body absent');
const hoist = 'const bool driver_honors_pipeline_barriers = driver->api_trait_get(RDD::API_TRAIT_HONORS_PIPELINE_BARRIERS);';
assert(body.includes(hoist));
assert(body.slice(body.indexOf(hoist)).includes('for (uint32_t i = 0; i < draw_list.state.set_count; i++)'));
assert(body.includes('if (!driver_honors_pipeline_barriers)'));
assert.equal((body.match(/API_TRAIT_HONORS_PIPELINE_BARRIERS/g) || []).length, 1);
assert.equal((body.match(/if \(!driver_honors_pipeline_barriers\)/g) || []).length, 1);

function original(mask, honors) {
  let calls = 0, prepares = [];
  for (let i = 0; i < mask.length; i++) {
    if (!mask[i]) continue;
    calls++;
    if (!honors) prepares.push(i);
  }
  return { calls, prepares };
}
function hoisted(mask, honors) {
  const calls = 1;
  const prepares = [];
  for (let i = 0; i < mask.length; i++) {
    if (!mask[i]) continue;
    if (!honors) prepares.push(i);
  }
  return { calls, prepares };
}
let checks = 0, activeSlotCases = 0;
for (let slots = 0; slots <= 8; slots++) {
  for (let bits = 0; bits < 1 << slots; bits++) {
    const mask = Array.from({ length: slots }, (_, i) => !!(bits & (1 << i)));
    for (const honors of [false, true]) {
      const a = original(mask, honors), b = hoisted(mask, honors);
      assert.deepEqual(b.prepares, a.prepares);
      if (a.calls > 0) {
        assert.equal(b.calls, 1);
        activeSlotCases++;
      }
      checks++;
    }
  }
}
const sha256 = crypto.createHash('sha256').update(bytes).digest('hex');
assert.equal(sha256, '9de657dbbe6a2d020b0775a9401806b051004f92c48123a1a382267e2d712e45');
console.log(JSON.stringify({ sourcePath, sourceSha256: sha256, checks, activeSlotCases, outputParity: true, getterCallsBefore: 'active expected-format slots', getterCallsAfter: 1, emptyMaskBoundary: 'new hoisted getter executes once even if no expected-format slot; output unchanged' }));
