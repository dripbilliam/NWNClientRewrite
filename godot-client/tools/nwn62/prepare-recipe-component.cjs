"use strict";
// Source-only fixture. It does not launch Godot or change application source.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");

const root = path.resolve(__dirname, "../..");
const label = process.argv[2] || "recipe-component-20261110-a";
assert.match(label, /^[a-z0-9][a-z0-9-]{0,59}$/);
const directory = path.join(root, ".cache/nwn62", label);
assert(!fs.existsSync(directory), "Refusing to overwrite an existing gate");
const sha = bytes => crypto.createHash("sha256").update(bytes).digest("hex");
const source = new Map([
  ["tests/native_staged_model_publication_test.gd", "4747fa821c9793ed9e06812e2ca5904ae93ec3897e64b84902b09fb73ff32f00"],
  ["tests/nwn62_construction_test.gd", "3c23b377109c772778a525dab71c7ff7fe30d2b70a27cbd9b81405f38407739b"],
  ["tests/nwn62_publication_benchmark.gd", "3dcef3e905e362ccea aad0eb51cb219235c64ee8c66998f665deca60957a7f8d".replace(" ", "")],
  ["systems/native_render/model_template.gd", "51f219b5fdcb99f9a929eb04941b4ebb8a1bb60271d5b9c88fe4c722036e4924"],
  ["systems/native_render/native_model_recipe.gd", "39e60ac3254c74dbc5d043262bd0413c98779fd21732c6c291f44b28e5040a2a"],
  [".cache/nwn62/review-final-consolidated-a/source/systems/native_render/native_model_recipe.gd", "8ea3067fc469698940ae8ebb54f21c31766647a803a6951bcb189e6b48f17bd5"],
  [".cache/nwn70/counts-b/tcn01_a01_01-original.var", "aa449ce06d8fb14a47296edc968de5232efe99080ee1ab7662ad374eb69db6d6"],
  [".tools/native-core/Godot_native_core_e_win64.exe", "753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b"],
]);
const contents = new Map();
for (const [relative, expected] of source) {
  const bytes = fs.readFileSync(path.join(root, relative));
  assert.equal(sha(bytes), expected, `Input drift: ${relative}`);
  contents.set(relative, bytes);
}
const replaceOnce = (text, from, to) => {
  assert.equal(text.split(from).length, 2, `Missing or repeated anchor: ${from}`);
  return text.replace(from, to);
};
const put = (relative, text) => {
  const file = path.join(directory, relative);
  fs.mkdirSync(path.dirname(file), {recursive: true});
  fs.writeFileSync(file, text, {flag: "wx"});
  return {file: path.relative(root, file).replaceAll("\\", "/"), sha256: sha(Buffer.from(text))};
};
const outputs = [];
const originalBase = contents.get("tests/native_staged_model_publication_test.gd").toString("utf8");
const originalConstruction = contents.get("tests/nwn62_construction_test.gd").toString("utf8");
const originalBenchmark = contents.get("tests/nwn62_publication_benchmark.gd").toString("utf8");
const originalTemplate = contents.get("systems/native_render/model_template.gd").toString("utf8");
const currentRecipe = "res://systems/native_render/native_model_recipe.gd";
const baselineRecipe = "res://.cache/nwn62/review-final-consolidated-a/source/systems/native_render/native_model_recipe.gd";
for (const leg of ["control", "candidate"]) {
  const prefix = `res://.cache/nwn62/${label}/`;
  const recipePath = leg === "control" ? baselineRecipe : currentRecipe;
  outputs.push(put(`template-${leg}.gd`, replaceOnce(originalTemplate, `preload("${currentRecipe}")`, `preload("${recipePath}")`)));
  outputs.push(put(`base-${leg}.gd`, replaceOnce(originalBase,
    'preload("res://systems/native_render/model_template.gd")', `preload("${prefix}template-${leg}.gd")`)));
  outputs.push(put(`construction-${leg}.gd`, replaceOnce(originalConstruction,
    'extends "res://tests/native_staged_model_publication_test.gd"', `extends "${prefix}base-${leg}.gd"`)));
  let benchmark = replaceOnce(originalBenchmark,
    'extends "res://tests/nwn62_construction_test.gd"', `extends "${prefix}construction-${leg}.gd"`);
  benchmark = replaceOnce(benchmark,
    'for leg in ([false,true] if preflight else [false,true,true,false]):\n\t\t\tobservations.append(await measure(item.bundle,leg,2 if preflight else int(item.placements),str(item.name)+"-"+str(observations.size())))',
    'observations.append(await measure(item.bundle,true,2 if preflight else int(item.placements),str(item.name)+"-"+str(observations.size())))');
  const actorsStart = benchmark.indexOf('\n\tauthored.value.rig_asset=ActorData.new().rig_asset(authored.value)');
  const actorsEnd = benchmark.indexOf('\n\tvar result:=', actorsStart);
  assert(actorsStart > 0 && actorsEnd > actorsStart);
  benchmark = benchmark.slice(0, actorsStart) + benchmark.slice(actorsEnd);
  benchmark = replaceOnce(benchmark,
    '"Headless normal-engine ABBA component construction; identical per-leg configured shared ledger (ordinary3ms or PRIVATE entry experiment),60Hz engine-frame pacing, all placements retained until end. Original installed tile and separately labelled authored larger graph. First/full publication latency and actual callback/unit active CPU; no renderer/FPS claim."',
    '"One pinned recipe leg per process; 3ms shared publication ledger and 60Hz engine pacing. Original installed tile plus separately labelled authored larger graph; all placements retained. First/full publication latency and callback/unit active CPU, no FPS claim."');
  outputs.push(put(`benchmark-${leg}.gd`, benchmark));
}
const manifest = {
  ticket: "NWN-62", kind: "private-recipe-only-headless-component-pair", label,
  source: [...source].map(([file, sha256]) => ({file, sha256})), outputs,
  onlyRuntimeDifference: "ModelTemplate Recipe preload: reviewed frozen 8ea3067f... versus current candidate 39e60ac3...",
  caseOrder: ["original-tile:24 placements", "authored-257-mesh:8 placements"],
  processOrder: ["control", "candidate", "candidate", "control"],
  flags: ["--model-template=recipe"],
  preflightFlags: ["--model-template=recipe", "--preflight"],
  engine: ".tools/native-core/Godot_native_core_e_win64.exe",
  measurement: "first_us, full_us, callbacks/units total/max/p95, first_active_us, phase_at_start_cpu_us, template mode/fallback, checks",
  restrictions: "No engine launch, build or FPS measurement during staging. Root owns timing lease.",
};
put("manifest.json", JSON.stringify(manifest, null, 2) + "\n");
process.stdout.write(JSON.stringify({directory: path.relative(root, directory), manifest: sha(fs.readFileSync(path.join(directory, "manifest.json"))), outputs: outputs.length}) + "\n");
