'use strict';
// Source-structure and draw-state oracle for the private NWN-74 candidate.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const receipt = JSON.parse(fs.readFileSync(path.join(root, '.cache/nwn74/pipeline-key-skip-a/receipt.json')));
const oldSource = fs.readFileSync(receipt.source, 'utf8');
const nextSource = fs.readFileSync(receipt.candidate, 'utf8');
const header = fs.readFileSync(path.join(root, '.cache/native-tracy/engine-msvc-a/source/servers/rendering/renderer_rd/forward_clustered/scene_shader_forward_clustered.h'), 'utf8');
const body = header.match(/uint32_t hash\(\) const \{([\s\S]*?)return hash_fmix32\(h\);/)[1];
const hashFields = [...body.matchAll(/hash_murmur3_one_\d+\(([^,()]+)/g)].map(m => m[1].trim());
const compareFields = [...nextSource.matchAll(/pipeline_key\.([\w.]+) == prev_pipeline_key\.\1/g)].map(m => m[1]);
assert.deepEqual(compareFields, hashFields, 'Exact comparison must cover hash fields in the same order');
assert.equal(hashFields.length, 11);
assert(nextSource.includes('pipeline_hash = same_pipeline_key ? prev_pipeline_hash : pipeline_key.hash();'));
assert(nextSource.includes('prev_pipeline_key = pipeline_key;'));
assert(nextSource.includes('prev_pipeline_key_valid = true;'));
assert.equal((oldSource.match(/pipeline_hash = pipeline_key\.hash\(\);/g) || []).length, 1);

// Same state transitions as the C++ while loop. Hash collisions and failed lookups
// deliberately exercise the original hash-based reuse semantics.
function simulate(draws, candidate, hash) {
  let prevShader = null, prevHash = 0, prevKey = null, validKey = false;
  let hashCalls = 0, lookups = 0, binds = 0;
  const decisions = [];
  for (const draw of draws) {
    let pipelineValid = false;
    for (let pass = 0; pass < 2; pass++) {
      const key = { ...draw.key, ubershader: pass };
      const same = candidate && validKey && draw.shader === prevShader && hashFields.every(field => key[field] === prevKey[field]);
      const currentHash = same ? prevHash : hash(key);
      if (!same) hashCalls++;
      if (draw.shader !== prevShader || currentHash !== prevHash) {
        lookups++;
        const success = !(draw.failFirst && pass === 0);
        decisions.push(['lookup', draw.id, pass, success]);
        if (success) {
          pipelineValid = true;
          prevShader = draw.shader;
          prevHash = currentHash;
          if (candidate) { prevKey = key; validKey = true; }
          binds++;
          break;
        }
      } else {
        decisions.push(['reuse', draw.id, pass]);
        pipelineValid = true;
        break;
      }
    }
    decisions.push(['valid', draw.id, pipelineValid]);
  }
  return { decisions, hashCalls, lookups, binds };
}
const base = Object.fromEntries(hashFields.map((field, i) => [field, i + 3]));
const draws = [];
function add(shader, key, failFirst = false) { draws.push({ id: draws.length, shader, key, failFirst }); }
add('A', base);
for (let i = 0; i < 100; i++) add('A', base);
for (const field of hashFields) add('A', { ...base, [field]: base[field] + 100 });
add('B', base);
add('A', base, true);
for (let i = 0; i < 100; i++) add('A', base);
const regularHash = key => hashFields.reduce((h, field) => Math.imul(h ^ key[field], 16777619) >>> 0, 2166136261);
const checks = [];
for (const [name, hash] of [['normal', regularHash], ['forced-collision', () => 1]]) {
  const old = simulate(draws, false, hash);
  const next = simulate(draws, true, hash);
  assert.deepEqual(next.decisions, old.decisions, name);
  assert.equal(next.lookups, old.lookups, name);
  assert.equal(next.binds, old.binds, name);
  assert(next.hashCalls < old.hashCalls, name);
  checks.push({ name, draws: draws.length, oldHashCalls: old.hashCalls, candidateHashCalls: next.hashCalls, lookups: old.lookups, binds: old.binds });
}
console.log(JSON.stringify({ issue: 'NWN-74', private: true, hashFields, checks }));
