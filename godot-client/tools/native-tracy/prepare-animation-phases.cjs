'use strict';

// Stage only the source overlay for a private Tracy build and a matching replay.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const project = path.resolve(__dirname, '../..');
const engine = path.join(project, '.cache/native-text-build/source');
const mixer = 'scene/animation/animation_mixer.cpp';
const node = 'scene/3d/node_3d.cpp';
const header = 'scene/animation/nwn_rig_phase_profile.h';
const rigs = 'systems/model_rigs.gd';
const actor = 'systems/native_render/actor_instance.gd';
const inputs = [];
const outputs = [];

const digest = value => crypto.createHash('sha256').update(value).digest('hex');

function read(root, relative, expected) {
	const file = path.join(root, relative);
	const bytes = fs.readFileSync(file);
	const sha256 = digest(bytes);
	if (expected) assert.equal(sha256, expected, `Pinned source changed: ${relative}`);
	inputs.push({ file, sha256 });
	return bytes.toString('utf8').replaceAll('\r\n', '\n');
}

function replaceOnce(source, before, after) {
	assert.equal(source.split(before).length, 2, `Expected one source seam: ${before.split('\n')[0]}`);
	return source.replace(before, () => after);
}

function stage(relative, source) {
	outputs.push({ relative, source, sha256: digest(source) });
}

const profileIncludes = `#include "core/profiling/profiling.h"

#ifdef GODOT_USE_TRACY
#include "scene/animation/nwn_rig_phase_profile.h"
#endif`;

const originalProcess = `void AnimationMixer::_process_animation(double p_delta, bool p_update_only) {
	_blend_init();
	if (cache_valid && _blend_pre_process(p_delta, track_count, track_map)) {
		_blend_capture(p_delta);
		_blend_calc_total_weight();
		_blend_process(p_delta, p_update_only);
		clear_animation_instances();
		_blend_apply();
		_blend_post_process();
		emit_signal(SNAME("mixer_applied"));
	} else {
		clear_animation_instances();
	}
}`;

const profiledProcess = `void AnimationMixer::_process_animation(double p_delta, bool p_update_only) {
#ifdef GODOT_USE_TRACY
	const bool trace = nwn_rig_phase::advance_active && !nwn_rig_phase::process_active;
	const nwn_rig_phase::ScopedFlag process_scope(nwn_rig_phase::process_active, nwn_rig_phase::process_active || trace);
	ZoneNamedN(rig_process_zone, "NWN.Rig.Process", trace);
#endif
	bool can_blend;
	{
#ifdef GODOT_USE_TRACY
		ZoneNamedN(rig_setup_zone, "NWN.Rig.SetupAndClocks", trace);
#endif
		_blend_init();
		can_blend = cache_valid && _blend_pre_process(p_delta, track_count, track_map);
	}
	if (can_blend) {
		{
#ifdef GODOT_USE_TRACY
			ZoneNamedN(rig_sampling_zone, "NWN.Rig.SampleAndBlend", trace);
#endif
			_blend_capture(p_delta);
			_blend_calc_total_weight();
			_blend_process(p_delta, p_update_only);
		}
		clear_animation_instances();
		{
#ifdef GODOT_USE_TRACY
			ZoneNamedN(rig_apply_zone, "NWN.Rig.PoseApply", trace);
			const nwn_rig_phase::ScopedFlag propagation_scope(nwn_rig_phase::propagation_active, trace);
#endif
			_blend_apply();
		}
		_blend_post_process();
		emit_signal(SNAME("mixer_applied"));
	} else {
		clear_animation_instances();
	}
}`;

const originalAdvance = `void AnimationMixer::advance(double p_time) {
	_process_animation(p_time);
}`;

const profiledAdvance = `void AnimationMixer::advance(double p_time) {
#ifdef GODOT_USE_TRACY
	bool trace = false;
	if (TracyIsConnected && !nwn_rig_phase::advance_active &&
			!nwn_rig_phase::process_active && has_meta(SNAME("_nwn_rig_phase_player"))) {
		const uint64_t frame = Engine::get_singleton()->get_process_frames();
		trace = (frame & 7u) == 0u;
		if (trace && frame != nwn_rig_phase::last_sampled_frame) {
			nwn_rig_phase::last_sampled_frame = frame;
			ZoneNamedN(rig_frame_zone, "NWN.Rig.SampledFrame", true);
		}
	}
	const nwn_rig_phase::ScopedFlag advance_scope(nwn_rig_phase::advance_active, trace);
	ZoneNamedN(rig_advance_zone, "NWN.Rig.Advance", trace);
#endif
	_process_animation(p_time);
}`;

const propagationCall = `	{
#ifdef GODOT_USE_TRACY
		ZoneNamedN(rig_propagation_zone, "NWN.Rig.TransformPropagation", nwn_rig_phase::propagation_active);
#endif
		_propagate_transform_changed(this);
	}`;

function instrumentSetter(source, signature) {
	const start = source.indexOf(signature);
	assert.ok(start >= 0, signature);
	const end = source.indexOf('\n}', start);
	assert.ok(end > start, signature);
	const body = source.slice(start, end);
	const instrumented = replaceOnce(body, '\t_propagate_transform_changed(this);', propagationCall);
	return source.slice(0, start) + instrumented + source.slice(end);
}

const mixerSource = read(engine, mixer, 'e41ffd0f9e49a8327f2bee2246c44af1cbe666379f1f92ff201dca4be0a598da');
const nodeSource = read(engine, node, '449a81317e6b59a8bc2fe1a62eef06bbf632473c6c11d40e44bc832892da31e3');
read(engine, 'core/profiling/profiling.h', '6e0cab4e17ec28b3f37b85eb996789bb6168687875fae016cee0fbe70c964208');

const mixerWithHeaders = replaceOnce(mixerSource, '#include "animation_mixer.h"', `#include "animation_mixer.h"\n\n${profileIncludes}`);
const mixerWithPhases = replaceOnce(mixerWithHeaders, originalProcess, profiledProcess);
stage(`engine/${mixer}`, replaceOnce(mixerWithPhases, originalAdvance, profiledAdvance));

const setters = [
	'void Node3D::set_transform(const Transform3D &p_transform) {',
	'void Node3D::set_position(const Vector3 &p_position) {',
	'void Node3D::set_rotation(const Vector3 &p_euler_rad) {',
	'void Node3D::set_scale(const Vector3 &p_scale) {',
];
stage(`engine/${node}`, setters.reduce(instrumentSetter, replaceOnce(nodeSource, '#include "node_3d.h"', `#include "node_3d.h"\n\n${profileIncludes}`)));

stage(`engine/${header}`, `#pragma once

#include <cstdint>

// Private diagnostic state. The two consumers include this only with Tracy.
namespace nwn_rig_phase {
inline thread_local bool advance_active = false;
inline thread_local bool process_active = false;
inline thread_local bool propagation_active = false;
inline thread_local std::uint64_t last_sampled_frame = UINT64_MAX;

class ScopedFlag {
	bool &flag;
	bool previous;

public:
	ScopedFlag(bool &p_flag, bool p_value) :
			flag(p_flag), previous(p_flag) {
		flag = p_value;
	}
	ScopedFlag(const ScopedFlag &) = delete;
	ScopedFlag &operator=(const ScopedFlag &) = delete;
	~ScopedFlag() { flag = previous; }
};
} // namespace nwn_rig_phase
`);

const rigSource = read(project, rigs);
const playerMarker = '\tif has_meta("_nwn_rig_phase_owner"):\n\t\tplayer.set_meta("_nwn_rig_phase_player", true)\n';
stage(`client/${rigs}`, rigSource.includes(playerMarker) ? rigSource :
	replaceOnce(rigSource, '\tvar player := AnimationPlayer.new()\n', '\tvar player := AnimationPlayer.new()\n' + playerMarker));

const actorSource = read(project, actor);
const immediateRig = '\trigs=SkeletalRigs.new() if use_skeleton else Rigs.new(); add_child(rigs); rigs.configure(registry,{id:self},{"rigs":{"version":1,"assets":assets,"entities":[source]},"meshes":bindings})';
const stagedRig = '\trigs=SkeletalRigs.new() if use_skeleton else Rigs.new();add_child(rigs)';
const markActor = '\trigs=SkeletalRigs.new() if use_skeleton else Rigs.new()\n\tif not use_skeleton:\n\t\trigs.set_meta("_nwn_rig_phase_owner", true)\n\tadd_child(rigs)';
stage(`client/${actor}`, actorSource.split(markActor).length === 3 ? actorSource :
	replaceOnce(replaceOnce(actorSource, immediateRig, markActor + '\n\trigs.configure(registry,{id:self},{"rigs":{"version":1,"assets":assets,"entities":[source]},"meshes":bindings})'), stagedRig, markActor));

const [mode = '--check', extra] = process.argv.slice(2);
assert.equal(extra, undefined, 'Use --check or --stage=<label>');
const manifest = {
	version: 1,
	kind: 'private-animation-mixer-phase-overlay',
	engineSource: engine,
	compiled: false,
	inputs,
	outputs: outputs.map(({ relative, sha256 }) => ({ relative, sha256 })),
	sampling: 'One in eight Godot process frames. Explicit advances of ordinary ActorInstance-owned AnimationPlayers only. A frame marker bounds the sampled advances. Tracy connection required.',
	phaseAccounting: 'Advance includes Process. SetupAndClocks, SampleAndBlend, and PoseApply are direct children of Process. TransformPropagation is nested inside PoseApply and should be subtracted for exclusive apply time. The advance remainder includes clear, post-process, signals and probe overhead. Deferred SceneTree and renderer work is outside this split.',
};

if (mode === '--check') {
	console.log(JSON.stringify({ checked: true, ...manifest }));
} else {
	assert.match(mode, /^--stage=[a-z0-9][a-z0-9-]{0,55}$/);
	const destination = path.join(project, '.cache/native-tracy/rig-phases', mode.slice(8));
	assert.ok(!fs.existsSync(destination), 'Use a fresh overlay label');
	for (const { relative, source } of outputs) {
		const file = path.join(destination, relative);
		fs.mkdirSync(path.dirname(file), { recursive: true });
		fs.writeFileSync(file, source, { flag: 'wx' });
	}
	const receipt = path.join(destination, 'manifest.json');
	fs.writeFileSync(receipt, JSON.stringify(manifest, null, 2) + '\n', { flag: 'wx' });
	console.log(JSON.stringify({ checked: true, receipt, compiled: false }));
}
