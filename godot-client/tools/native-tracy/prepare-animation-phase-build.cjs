'use strict';

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const { project, sha, child, read } = require('./prepare-engine.cjs');

const [label, mode, ...extra] = process.argv.slice(2);
assert(/^rig-phase-[a-z0-9-]+$/.test(label ?? '') &&
	['--check', '--stage', '--stage-client'].includes(mode) && extra.length === 0,
	'Usage: node prepare-animation-phase-build.cjs rig-phase-LABEL --check|--stage|--stage-client');

const tracyRoot = path.join(project, '.cache/native-tracy');
const stage = child(tracyRoot, 'rig-phases/' + label);
const overlayFile = child(stage, 'manifest.json');
const overlayPin = { file: overlayFile, sha256: sha(overlayFile) };
const overlay = read(overlayFile, overlayPin.sha256);
assert.equal(overlay.kind, 'private-animation-mixer-phase-overlay');
assert.equal(overlay.version, 1);
assert.equal(overlay.compiled, false);

const archive = {
	file: path.join(project, '.cache/native-text-build/godot-source.tar.gz'),
	sha256: 'e607e9985e1c201bc9cdc1aec8a120f0c3f53b9603f1f828e2b748534a2471ef',
};
const engineRoot = path.join(project, '.cache/native-text-build/source');
assert.equal(overlay.engineSource, engineRoot);
assert.equal(sha(archive.file), archive.sha256, 'Godot source archive changed');

const configEdits = [
	['core/profiling/SCsub',
		'env_tracy.Append(CPPDEFINES=["TRACY_ENABLE"])',
		'env_tracy.Append(CPPDEFINES=["TRACY_ENABLE", "TRACY_NO_SYSTEM_TRACING", "TRACY_ONLY_LOCALHOST", ("TRACY_PORT", 48135)])'],
	['core/profiling/profiling_builders.py',
		'file.write("#define GODOT_USE_TRACY\\n")',
		'file.write("#define GODOT_USE_TRACY\\n#define TRACY_NO_SYSTEM_TRACING\\n#define TRACY_ONLY_LOCALHOST\\n#define TRACY_PORT 48135\\n")'],
	['core/profiling/profiling.h',
		'// Memory allocation\n#ifdef GODOT_PROFILER_TRACK_MEMORY',
		`// Keep frame marks and the direct NWN rig zones. Broad script and engine
// scopes distort short setters and can fill the trace before the steady window.
#undef GodotProfileZone
#undef GodotProfileZoneGroupedFirst
#undef GodotProfileZoneGroupedEndEarly
#undef GodotProfileZoneGrouped
#undef GodotProfileZoneScript
#undef GodotProfileZoneScriptSystemCall
#define GodotProfileZone(m_zone_name)
#define GodotProfileZoneGroupedFirst(m_group_name, m_zone_name)
#define GodotProfileZoneGroupedEndEarly(m_group_name, m_zone_name)
#define GodotProfileZoneGrouped(m_group_name, m_zone_name)
#define GodotProfileZoneScript(m_ptr, m_file, m_function, m_name, m_line)
#define GodotProfileZoneScriptSystemCall(m_ptr, m_file, m_function, m_name, m_line)

// Memory allocation
#ifdef GODOT_PROFILER_TRACK_MEMORY`],
];
const engineInputs = [
	'scene/animation/animation_mixer.cpp',
	'scene/3d/node_3d.cpp',
	'core/profiling/profiling.h',
];
const clientInputs = ['systems/model_rigs.gd', 'systems/native_render/actor_instance.gd'];
assert.deepEqual(overlay.inputs.map(row => row.file), [
	...engineInputs.map(relative => child(engineRoot, relative)),
	...clientInputs.map(relative => child(project, relative)),
]);
const engineOverrides = [
	...engineInputs.slice(0, 2),
	'scene/animation/nwn_rig_phase_profile.h',
];
assert.deepEqual(overlay.outputs.map(row => row.relative), [
	...engineOverrides.map(relative => 'engine/' + relative),
	...clientInputs.map(relative => 'client/' + relative),
]);
for (const pin of overlay.inputs) assert.equal(sha(pin.file), pin.sha256, 'Overlay input changed');
const overlayOutputs = overlay.outputs.map(row => ({
	file: child(stage, row.relative),
	sha256: row.sha256,
}));
for (const pin of overlayOutputs) assert.equal(sha(pin.file), pin.sha256, 'Overlay output changed');
for (const [relative, needle] of configEdits) {
	assert.equal(fs.readFileSync(child(engineRoot, relative), 'utf8').split(needle).length, 2,
		'Expected Tracy configuration seam differs in ' + relative);
}

const python = {
	file: path.join(project, '.cache/native-140fps/render-agent/engine-build-tools-v1/python/python.exe'),
	sha256: '4d6f5f81a4bca11191c4c7c6b43632694d0a4ce74e068619d8fdc161d469859a',
};
assert.equal(sha(python.file), python.sha256, 'Private Python executable changed');
const vendor = child(tracyRoot, 'vendor/tracy-0.13.0');
const vendorPins = ['public/TracyClient.cpp', 'public/tracy/Tracy.hpp'].map(relative => {
	const file = child(vendor, relative);
	return { file, sha256: sha(file) };
});
const engineArguments = ['-m', 'SCons', 'platform=windows', 'target=template_release', 'arch=x86_64',
	'use_mingw=no', 'msvc_version=14.5', 'disable_path_overrides=no', 'd3d12=no',
	'accesskit=no', 'angle=no',
	'debug_symbols=yes', 'optimize=speed', 'lto=none', 'profiler=tracy', 'profiler_path=' + vendor,
	'profiler_sample_callstack=no', 'profiler_track_memory=no', 'profiler_record_on_demand=yes', '-j', '8'];
const source = child(stage, 'build-source');
const output = child(stage, 'build-output');
const planFile = child(stage, 'build-plan.json');
const receipt = { source, output, plan: planFile, archive, overlay: overlayPin, compiled: false };

function stageClient() {
	const { sourceIdentity } = require('../native-feature-manifest.cjs');
	const identity = sourceIdentity(project);
	const files = new Set(identity.files.map(row => row.file));
	for (const relative of [
		'.cache/native-kernel/build-manifest.json', '.cache/native-resource-index/build-manifest.json',
		'.godot/global_script_class_cache.cfg', '.godot/extension_list.cfg', 'data/native_text_codepages.json',
	]) files.add(relative);
	function includeCode(relative) {
		for (const entry of fs.readdirSync(child(project, relative), { withFileTypes: true })) {
			if (entry.isSymbolicLink() || entry.name.startsWith('.')) continue;
			const name = relative + '/' + entry.name;
			if (entry.isDirectory()) includeCode(name);
			else if (/\.(gd|gdextension|gdshader|gdshaderinc|tscn|tres|cpp|hpp|h|c|uid)$/.test(name)) files.add(name);
		}
	}
	for (const relative of ['native', 'experiments', 'scripts', 'tests']) includeCode(relative);
	const sourceProject = child(stage, 'project');
	fs.mkdirSync(sourceProject);
	for (const relative of files) {
		const destination = child(sourceProject, relative);
		fs.mkdirSync(path.dirname(destination), { recursive: true });
		fs.copyFileSync(child(project, relative), destination, fs.constants.COPYFILE_EXCL);
	}
	assert.equal(sourceIdentity(sourceProject).sha256, identity.sha256, 'Live client source changed during copy');
	for (const relative of clientInputs) {
		fs.copyFileSync(child(stage, 'client/' + relative), child(sourceProject, relative));
	}
	console.log(JSON.stringify({ sourceProject, baseSourceSha256: identity.sha256,
		sourceSha256: sourceIdentity(sourceProject).sha256, files: files.size }));
}

if (mode === '--check') {
	console.log(JSON.stringify({ ...receipt, engineArguments, readyToStage: true }));
} else if (mode === '--stage-client') {
	stageClient();
} else {
	assert(!fs.existsSync(planFile) && !fs.existsSync(output), 'Preserve earlier build evidence');
	fs.mkdirSync(source);
	const tar = spawnSync('tar.exe', ['-xzf', archive.file, '--strip-components=1', '-C', source],
		{ windowsHide: true, encoding: 'utf8', maxBuffer: 1024 * 1024, timeout: 120000 });
	assert.equal(tar.status, 0, tar.error?.message ?? tar.stderr);
	for (const [index, relative] of engineInputs.entries()) {
		assert.equal(sha(child(source, relative)), overlay.inputs[index].sha256, 'Archive source differs');
	}
	for (const [index, relative] of engineOverrides.entries()) {
		fs.copyFileSync(overlayOutputs[index].file, child(source, relative));
	}
	for (const [relative, needle, replacement] of configEdits) {
		const file = child(source, relative);
		const content = fs.readFileSync(file, 'utf8');
		assert.equal(content.split(needle).length, 2, 'Archive Tracy configuration differs');
		fs.writeFileSync(file, content.replace(needle, replacement));
	}
	const trackedEngine = [...engineOverrides, ...configEdits.map(edit => edit[0])]
		.map(relative => {
			const file = child(source, relative);
			return { file, sha256: sha(file) };
		});
	const plan = {
		version: 1,
		kind: 'private-animation-phase-tracy-build',
		source, output, archive, overlay: overlayPin, python, engineArguments,
		engineTrackedSources: [archive, overlayPin, ...overlay.inputs, ...overlayOutputs, ...vendorPins, ...trackedEngine],
		scope: 'Godot ed1daf0bf001b61586d9930840f2f1394092c079 release template with the ordinary-rig phase probe. Localhost-only Tracy 0.13 on port 48135, on-demand rig zones and frame marks.',
	};
	fs.writeFileSync(planFile, JSON.stringify(plan, null, 2) + '\n', { flag: 'wx' });
	console.log(JSON.stringify({ ...receipt, planSha256: sha(planFile) }));
}
