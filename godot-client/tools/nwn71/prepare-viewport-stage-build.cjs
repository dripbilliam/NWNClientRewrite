'use strict';

// Prepare a private, single-translation-unit Tracy diagnostic. Never modify
// the engine source tree here; the coordinator's transaction runner applies
// and restores the exact snapshots around its incremental build.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../..');
const parentFile = path.join(root, '.cache/nwn71/incremental-render-pump-b/build-plan.json');
const parent = JSON.parse(fs.readFileSync(parentFile, 'utf8'));
const label = process.argv.find(value => value.startsWith('--label='))?.slice('--label='.length) ?? 'a';
assert(/^[a-z0-9]+$/.test(label), 'Private output label must be simple');
const out = path.join(root, `.cache/nwn71/incremental-viewport-stages-${label}`);
const relative = 'servers/rendering/renderer_viewport.cpp';
const source = path.join(parent.source, relative);
const before = fs.readFileSync(source);
const shaBuffer = value => crypto.createHash('sha256').update(value).digest('hex');
const shaFile = file => shaBuffer(fs.readFileSync(file));

function insertOnce(input, needle, replacement) {
	const start = input.indexOf(needle);
	assert(start >= 0, `Missing viewport marker: ${needle}`);
	assert(input.indexOf(needle, start + needle.length) < 0, `Ambiguous viewport marker: ${needle}`);
	return input.slice(0, start) + replacement + input.slice(start + needle.length);
}

assert(!fs.existsSync(out), 'Private output already exists');
assert.equal(shaFile(source), shaBuffer(before));
for (const pin of [...parent.engineTrackedSources, parent.python, ...parent.protectedInputs, ...parent.headerClosure]) {
	assert.equal(shaFile(pin.file), pin.sha256, pin.file);
}
for (const pin of parent.profilingPrepopulate) {
	assert.equal(shaFile(pin.reconstructedFile), pin.sha256, pin.reconstructedFile);
}
for (const change of parent.changes) {
	assert.equal(shaFile(change.file), change.beforeSha256, change.file);
	assert.equal(shaFile(change.afterFile), change.afterSha256, change.afterFile);
}

const newline = before.includes(Buffer.from('\r\n')) ? '\r\n' : '\n';
let after = before.toString('utf8');
after = insertOnce(after,
	`void RendererViewport::_draw_3d(Viewport *p_viewport) {${newline}#ifndef _3D_DISABLED`,
	`void RendererViewport::_draw_3d(Viewport *p_viewport) {${newline}#if defined(GODOT_USE_TRACY)${newline}\tZoneNamedN(nwn71_viewport_3d, "NWN71/Viewport/scene_3d", true);${newline}#endif${newline}#ifndef _3D_DISABLED`);
after = insertOnce(after,
	`\tRSG::scene->render_camera(`,
	`#if defined(GODOT_USE_TRACY)${newline}\tZoneNamedN(nwn71_viewport_camera, "NWN71/Viewport/render_camera", true);${newline}#endif${newline}\tRSG::scene->render_camera(`);
after = insertOnce(after,
	`\tif ((scenario_draw_canvas_bg || can_draw_3d) && !p_viewport->render_buffers.is_valid()) {${newline}`,
	`\tif ((scenario_draw_canvas_bg || can_draw_3d) && !p_viewport->render_buffers.is_valid()) {${newline}#if defined(GODOT_USE_TRACY)${newline}\t\tZoneNamedN(nwn71_viewport_setup, "NWN71/Viewport/render_buffer_setup", true);${newline}#endif${newline}`);
after = insertOnce(after,
	`\tif (can_draw_2d) {${newline}\t\tRBMap<Viewport::CanvasKey, Viewport::CanvasData *> canvas_map;`,
	`\tif (can_draw_2d) {${newline}#if defined(GODOT_USE_TRACY)${newline}\t\tZoneNamedN(nwn71_viewport_2d, "NWN71/Viewport/canvas_2d", true);${newline}#endif${newline}\t\tRBMap<Viewport::CanvasKey, Viewport::CanvasData *> canvas_map;`);
const afterBytes = Buffer.from(after, 'utf8');
assert.notEqual(shaBuffer(afterBytes), shaBuffer(before));

const beforeFile = path.join(out, 'before', relative);
const afterFile = path.join(out, 'after', relative);
fs.mkdirSync(path.dirname(beforeFile), { recursive: true });
fs.mkdirSync(path.dirname(afterFile), { recursive: true });
fs.writeFileSync(beforeFile, before, { flag: 'wx' });
fs.writeFileSync(afterFile, afterBytes, { flag: 'wx' });
const change = { file: source, relative, beforeSha256: shaBuffer(before), afterFile, afterSha256: shaBuffer(afterBytes) };
const protectedInputs = [...parent.protectedInputs];
for (const name of ['Godot_nwn71_group_labels_win64.exe', 'godot.windows.template_release.x86_64.pdb']) {
	const file = path.join(parent.output, name);
	protectedInputs.push({ file, bytes: fs.statSync(file).size, sha256: shaFile(file) });
}
const plan = {
	...parent,
	createdUtc: new Date().toISOString(),
	output: out,
	parentBuild: { file: parentFile, sha256: shaFile(parentFile) },
	changes: [...parent.changes, change],
	protectedInputs,
	expectedCompiles: [relative],
	maxSeconds: 300,
	compiled: false,
	patch: { file: afterFile, sha256: change.afterSha256 },
	scope: 'Private Tracy-only viewport stage labels: 3D, camera, render-buffer setup and 2D canvas. No scheduling or accepted-client change. Exactly one viewport translation unit may compile.',
	rollback: 'Transaction runner restores six source CPP files, generated inputs and build environment; accepted Core E and prior diagnostic binaries are protected by hash.'
};
fs.copyFileSync(parent.runner.file, path.join(out, 'build-private-diagnostic.ps1'), fs.constants.COPYFILE_EXCL);
const planFile = path.join(out, 'build-plan.json');
fs.writeFileSync(planFile, JSON.stringify(plan, null, 2) + '\n', { flag: 'wx' });
console.log(JSON.stringify({ plan: planFile, sha256: shaFile(planFile), change, protectedInputs: protectedInputs.length, expectedCompiles: plan.expectedCompiles, compiled: false }));
