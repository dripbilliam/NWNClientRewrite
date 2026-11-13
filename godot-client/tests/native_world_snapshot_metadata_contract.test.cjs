'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'..'),read=p=>fs.readFileSync(path.join(project,p),'utf8');
const metadata=read('systems/native_data/world_snapshot_metadata.gd'),job=read('systems/native_data/world_snapshot_metadata_job.gd'),owner=read('systems/native_data/world_snapshot_preparation.gd');
const origin=JSON.parse(read('tests/fixtures/native_world_snapshot_metadata_origin.json'));
function fn(source,name){const re=new RegExp('^(?:static )?func '+name+'\\(','m'),m=re.exec(source);assert.ok(m,name);const next=/^(?:static )?func /gm;next.lastIndex=m.index+1;const end=next.exec(source);return source.slice(m.index,end?end.index:source.length).trimEnd()+'\n';}
const sha=s=>crypto.createHash('sha256').update(s).digest('hex');

test('frozen oracle retains the original signature and pose functions',()=>{
 const oracle=read(origin.oracle.file);assert.equal(sha(oracle),origin.oracle.sha256);
 assert.equal(sha(fn(oracle,'signature')),origin.oracle.source_functions.signature);
 assert.equal(sha(fn(oracle,'creature_pose').replace('func creature_pose(','func pose(')),origin.oracle.source_functions.creature_pose);
 assert.equal(sha(fn(oracle,'static_pose').replace('func static_pose(','func pose(')),origin.oracle.source_functions.static_pose);
 assert.equal(sha(fn(oracle,'object_pose').replace('creature_pose(object)','Creatures.pose(object)').replace('static_pose(object)','Objects.pose(object)')),origin.oracle.source_functions.object_pose);
 const currentSignature=fn(metadata,'signature').replace('static func signature(','func signature(').replace('and requires_animation(state)','and preload("res://systems/native_render/placeable_instance.gd").requires_animation(state)').replace('return digest(','return Cache.digest(');
 assert.equal(currentSignature,fn(oracle,'signature'));
 assert.equal(fn(metadata,'creature_pose'),fn(oracle,'creature_pose'));
 assert.equal(fn(metadata,'static_pose'),fn(oracle,'static_pose'));
});

test('worker dependency closure consists of pure data classes',()=>{
 const visited=new Set();function inspect(relative){if(visited.has(relative))return;visited.add(relative);const source=read(relative);assert.match(source,/^extends RefCounted\s/m,relative);assert.doesNotMatch(source,/\b(?:get_tree|get_node|add_child|call_deferred|load|ResourceLoader|RenderingServer|PhysicsServer3D|DisplayServer|FileAccess)\s*\(/,relative);for(const m of source.matchAll(/preload\("res:\/\/([^"\n]+)"\)/g))inspect(m[1]);}
 inspect('systems/native_data/world_snapshot_metadata_job.gd');
 assert.deepEqual([...visited].sort(),['systems/native_data/entity_presentation_lifetime.gd','systems/native_data/object_animation.gd','systems/native_data/world_snapshot_metadata.gd','systems/native_data/world_snapshot_metadata_job.gd','systems/native_render/base_world_scenery.gd'].sort());
});

test('only private argument Array is released by the worker and result reads follow completion joins',()=>{
 assert.match(job,/owned_rows\.clear\(\)/);assert.doesNotMatch(job,/\.object\s*=|rows\[[^\]]+\]\s*=|\.erase\(/);
 assert.match(owner,/"rows":rows\.duplicate\(\)/);assert.doesNotMatch(fn(owner,'submit'),/duplicate\(true\)|make_read_only|Semaphore/);
 const poll=fn(owner,'poll');assert.ok(poll.indexOf('is_task_completed(int(entry.task))')<poll.indexOf('wait_for_task_completion(int(entry.task))'));
 const runningAt=poll.indexOf('for entry in running');assert.ok(poll.indexOf('wait_for_task_completion(int(entry.task))',runningAt)<poll.indexOf('entry.job.result',runningAt));
 assert.match(poll,/running\.size\(\)\+retired\.size\(\)<MAXIMUM_TASKS/);
 assert.match(owner,/const MAXIMUM_TASKS:=2/);assert.match(owner,/const MAXIMUM_ROWS:=65536/);assert.match(owner,/const CHUNK_ROWS:=64/);
});

test('cancellation never waits and terminal cleanup avoids RefCounted self dispatch',()=>{
 const cancel=fn(owner,'cancel');assert.doesNotMatch(cancel,/wait_for_task_completion|poll\(|\.job\.|\.clear\(/);
 assert.match(cancel,/retired\.append_array\(running\)/);
 const destructor=fn(owner,'_notification');assert.doesNotMatch(destructor,/\bclose\(|\bcancel\(/);assert.match(destructor,/for entry in running:WorkerThreadPool.wait_for_task_completion/);assert.match(destructor,/for entry in retired:WorkerThreadPool.wait_for_task_completion/);
});

test('admission packet preserves ordered duplicates and never owns canonical rows',()=>{
 const prepare=fn(metadata,'prepare');assert.match(prepare,/for index in rows\.size\(\)/);assert.match(prepare,/"index":offset\+index/);assert.match(prepare,/"accepted":accepted/);assert.match(prepare,/"classification":BaseScenery\.classify/);assert.doesNotMatch(prepare,/"object":object|"source":object|\[int\(object\.id\)\]\s*=/);
 const take=fn(owner,'take');assert.match(take,/expected_scope!=scope or not poll\(\):return \{\}/);assert.match(owner,/sealed and completed_count==expected_count/);
});

test('queued chunks coalesce before dispatch and packet count is captured before worker may clear input',()=>{
 const group=fn(owner,'take_packet');assert.match(group,/owned_rows\.size\(\)\+packets\[0\]\.rows\.size\(\)<=JOB_ROWS/);assert.match(owner,/const JOB_ROWS:=512/);
 assert.match(group,/owned_rows\.append_array\(next\.rows\);next\.rows\.clear\(\)/);
 const poll=fn(owner,'poll');assert.ok(poll.indexOf('var packet_count:=owned_rows.size()')<poll.indexOf('WorkerThreadPool.add_task'));
 assert.match(poll,/"count":packet_count/);
});

test('unsupported shape or interrupted preparation is terminal and cannot bypass remaining borrowers',()=>{
 const run=fn(job,'run');assert.ok(run.indexOf('"error":"worker-preparation-interrupted"')<run.indexOf('Metadata.prepare('));assert.match(run,/Metadata\.validation_error\(row\)/);
 const poll=fn(owner,'poll');assert.match(poll,/completed_count\+=int\(entry\.count\)/);assert.doesNotMatch(poll,/completed_count\+=result\.rows\.size\(\)/);
 assert.match(poll,/completed_count==expected_count and pending\.is_empty\(\) and running\.is_empty\(\)/);
 assert.match(fn(owner,'take'),/"rows":prepared if error\.is_empty\(\) else \[\]/);
});

test('bounded diagnostic snapshot neither drives preparation nor exposes row payloads',()=>{
 const snapshot=fn(owner,'snapshot');assert.doesNotMatch(snapshot,/poll\(|wait_for_task_completion|add_task|"rows":|"scope":/);
 for(const field of ['active','sealed','closed','current_tasks','retired_tasks','pending_rows','stats'])assert.ok(snapshot.includes('"'+field+'":'),field);
 assert.match(owner,/"main_thread":OS\.get_main_thread_id\(\)/);assert.match(owner,/const MAXIMUM_THREAD_IDS:=64/);
 assert.match(fn(owner,'poll'),/stats\.threads\.size\(\)<MAXIMUM_THREAD_IDS/);
});

test('non-Dictionary JSON rows use the complete-snapshot worker error barrier',()=>{
 const submit=fn(owner,'submit');assert.doesNotMatch(submit,/for row in rows|not row is Dictionary/);
 assert.match(fn(metadata,'validation_error'),/if not value is Dictionary:return "row-not-dictionary"/);
 const run=fn(job,'run');assert.match(run,/var reason:=Metadata\.validation_error\(row\)/);assert.match(run,/owned_rows\.clear\(\);result\.error=reason;[^\n]*return/);
 assert.match(fn(owner,'poll'),/completed_count\+=int\(entry\.count\)/);
});
