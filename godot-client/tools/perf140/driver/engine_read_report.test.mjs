import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {engineReadAcceptance,engineReadReportAcceptance} from './engine_read_acceptance.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const snapshot=()=>({requested_mode:'full',actual_mode:'full',available:true,cumulative:true,
  abi_revision:1,features:31,retained_node_rows:0,retained_callbacks:0,
  counts:{eligible_calls:10,eligible_handled:10,validate_calls:12,validate_handled:12,
    transform_calls:3,transform_handled:3,unsupported:0,inactive:0,missing:0,
    wrong_type:0,extra_miss_validation_attempts:3,bad_responses:0}});
test('Frozen shutdown source and future stager write the particle modes field',()=>{
  const entry=fs.readFileSync(path.join(project,'.cache/native-140fps/root/builtin-light-fenced-v2/project/native_live_world.gd'),'utf8');
  const stager=fs.readFileSync(path.join(project,'tools/perf140/driver/stage_engine_reads.mjs'),'utf8');
  assert.equal(entry.includes('report.perf140_particle_modes=preload("res://tools/perf140/driver/particle_modes_dump.gd").capture(world)'),true);
  assert.equal(stager.includes('preload("res://tools/perf140/driver/engine_read_modes_dump.gd").capture(world)'),true);
});
test('Actual shutdown section supplies a verified full-mode witness',()=>{
  const input={perf140_particle_modes:{engine_reads:snapshot()},perf140_cold_particles:{emitters:[]}};
  const before=structuredClone(input);
  assert.equal(engineReadAcceptance('full',input.perf140_cold_particles.engine_reads).verified,false,
    'The previous wrong-section expression rejects this otherwise valid output');
  assert.equal(engineReadReportAcceptance('full',input).verified,true);
  assert.deepEqual(input,before);
});
test('Other particle census field cannot stand in for a missing mode witness',()=>{
  const input={perf140_cold_particles:{engine_reads:snapshot()}};
  assert.equal(engineReadReportAcceptance('full',input).verified,false);
});
test('Wrong-section data cannot hide an invalid actual witness',()=>{
  const bad=snapshot();bad.counts.bad_responses=1;
  assert.equal(engineReadReportAcceptance('full',{
    perf140_particle_modes:{engine_reads:bad},perf140_cold_particles:{engine_reads:snapshot()}
  }).verified,false);
});
test('Legacy ordinary controls remain explicit and full mode cannot use them',()=>{
  const input={perf140_particle_modes:{frame_pose_reuse:{}},perf140_cold_particles:{emitters:[]}};
  const ordinary=engineReadReportAcceptance('ordinary',input);
  assert.equal(ordinary.verified,true);assert.equal(ordinary.legacyOrdinary,true);
  assert.equal(engineReadReportAcceptance('full',input).verified,false);
});
