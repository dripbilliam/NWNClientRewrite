"use strict";

// Offline extraction only. This never launches a client or changes a source capsule.
const fs = require("node:fs");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const sha = bytes => crypto.createHash("sha256").update(bytes).digest("hex");
const run = process.argv[2] || "nwn62-entry-policy-a";
const output = process.argv[3] || ".cache/nwn62/checks/entry-policy-a-review.json";
assert(!fs.existsSync(output), `Refusing to overwrite ${output}`);
const legs = {};
for (const leg of ["control", "candidate"]) {
  const file = `reports/${run}-${leg}.json`;
  const bytes = fs.readFileSync(file);
  const data = JSON.parse(bytes);
  const native = data.native;
  const world = native.world;
  const terrain = world.terrain;
  legs[leg] = {
    file, sha256: sha(bytes),
    strictSuccess: data.success,
    sourceUnchanged: data.sourceUnchanged,
    driverUnchanged: data.driverUnchanged,
    runtimeUnchanged: data.runtimeUnchanged,
    engineOrLifetimeError: data.engineOrLifetimeError,
    selection: data.productionSelection,
    measurement: data.measurement,
    protocolCount: native.protocol_objects.length,
    protocolJSONSHA256: sha(JSON.stringify(native.protocol_objects)),
    world: {
      desired: world.desired, admitted: world.entities, hidden: world.hidden,
      pendingBatches: world.pending_batches, completedBatches: world.completed_batches,
      failedAdmissions: world.failed_admissions, errors: world.errors,
      visualsComplete: world.object_visuals_complete,
      templates: world.pool.templates_created, staleResults: world.stale_results,
      firstPlayableMs: world.playable_ms,
      firstBaseResolvedMs: world.base_scenery_first_resolved_ms,
      firstKnownBaseCompleteMs: world.base_scenery_first_known_complete_ms,
      firstKnownBaseExpected: world.base_scenery_first_known_complete_expected,
      base: world.base_scenery,
    },
    terrain: {
      tiles: terrain.tiles, rendered: terrain.rendered_tiles,
      failed: terrain.failed_tiles, complete: terrain.complete,
      firstMs: terrain.first_tile_ms, completeMs: terrain.complete_ms,
      maximumPublicationMs: terrain.max_publish_ms,
      maximumTilePublicationMs: terrain.max_tile_publish_ms,
    },
    entryBudget: world.pool.publication_budget.private_entry,
    frameIntervals: native.frame_intervals,
    loading: native.loading_screen,
    construction: world.pool.template_construction,
    resources: {
      meshes: world.pool.meshes_created, materials: world.pool.materials_created,
      textures: world.pool.textures_created,
    },
  };
  assert.equal(data.success, true);
  assert.equal(data.sourceUnchanged, true);
  assert.equal(data.driverUnchanged, true);
  assert.equal(data.engineOrLifetimeError, false);
  assert.equal(world.failed_admissions, 0);
  assert.equal(world.pending_batches, 0);
  assert.equal(terrain.failed_tiles, 0);
}
assert.equal(legs.control.protocolJSONSHA256, legs.candidate.protocolJSONSHA256);
assert.equal(legs.control.entryBudget.requested_us, 0);
assert.equal(legs.candidate.entryBudget.requested_us, 8000);
assert.equal(legs.candidate.entryBudget.activations, 1);
assert.equal(legs.candidate.entryBudget.clears, 1);
assert.equal(legs.candidate.entryBudget.effective_us, 3000);
assert.equal(legs.candidate.entryBudget.last_reason, "loading-mark-cleared");
const delta = (control, candidate) => ({control, candidate, differenceMs: candidate-control, percent: 100*(candidate-control)/control});
const result = {
  ticket: "NWN-62",
  scope: "Identical frozen V5 publication algorithm plus audited61 entry and exact pre70 worker/decode. Pinned private project setting 0 versus 8000 only. Headless bounded original-entry loading observation; not FPS, full replay, visual or Arelith acceptance.",
  legs,
  comparisons: {
    firstPlayable: delta(legs.control.world.firstPlayableMs, legs.candidate.world.firstPlayableMs),
    terrainComplete: delta(legs.control.terrain.completeMs, legs.candidate.terrain.completeMs),
    firstBaseResolved: delta(legs.control.world.firstBaseResolvedMs, legs.candidate.world.firstBaseResolvedMs),
    allKnownBaseComplete: delta(legs.control.world.firstKnownBaseCompleteMs, legs.candidate.world.firstKnownBaseCompleteMs),
  },
  conclusion: "Private 8 ms loading allowance improved first playable and terrain completion in this single pair, but only slightly improved full base-population latency. It does not resolve the prior V4 late-population regression. Ordinary ready-world effective budget returned to 3 ms. No default promotion.",
  limitations: [
    "One matched headless pair; frame intervals include loading and are not clean steady FPS acceptance.",
    "The bounded run reports measurement.completed=false despite reaching its final known population.",
    "Derived recording supplements only seven advertised original shader payloads. Missing fxpa_cloud02 and recorded-notfound alc_chunk resources remain explicit; complete original visual parity and live Arelith acceptance are not demonstrated.",
    "Native scene activation, uploads, pack and other individual engine operations remain indivisible measured calls, not a hard 3 ms preemption guarantee.",
  ],
};
fs.writeFileSync(output, JSON.stringify(result, null, 2)+"\n");
console.log(JSON.stringify({output, sha256: sha(fs.readFileSync(output)), comparisons: result.comparisons}, null, 2));
