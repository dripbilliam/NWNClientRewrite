'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const project=path.resolve(__dirname,'..'),tool=path.join(project,'tools/summarize-native-live-profile.cjs'),source=fs.readFileSync(tool,'utf8');
const children=['world_receive_rows_ms','world_receive_population_ms','world_receive_combat_and_drive_ms','world_receive_lifetimes_and_poses_ms','world_receive_draw_admission_ms','snapshot_metadata_poll_ms','entry_snapshot_commit_ms'];
const metric=max=>({mean:max/10,when_present_mean:max/2,max,samples:240,active_samples:20});
function row(ready,wall=50){
 const values={wall_ms:wall,entry_snapshot_commit_ms:30,entry_snapshot_core_ms:25,snapshot_world_apply:20,snapshot_world_and_ui_apply:22,world_receive_rows_ms:12,world_receive_population_ms:3,world_receive_combat_and_drive_ms:4,world_receive_lifetimes_and_poses_ms:2,world_receive_draw_admission_ms:1,snapshot_metadata_poll_ms:2,worker_cpu_ms:9999};
 return {at:100,elapsedMs:1000,ready,connection:1,generation:2,areaId:3,fps:60,entities:100,profile_presentation:{camera:{controlled:{script:0,driveHeld:false},fov_degrees:65},viewport:[1280,720],focused:true},frame_profile:{pending:false,frames:240,captured_at_ms:2000,metrics:Object.fromEntries(Object.entries(values).map(([key,value])=>[key,metric(value)])),worst_frame:{...values,world_receive_rows_ms:11}}};
}
function invoke(rows,tail=''){
 const bytes=Buffer.from(rows.map(row=>JSON.stringify(row)).join('\n')+'\n'+tail);let output='';
 const context={require:name=>['fs','node:fs'].includes(name)?{readFileSync:file=>{assert.equal(file,path.join(project,'reports','fixture.performance.jsonl'));return bytes;}}:require(name),__dirname:path.dirname(tool),process:{argv:['node',tool,'fixture'],stdout:{write:text=>{output+=text;}}}};
 vm.runInNewContext(source,context,{filename:tool,timeout:1000});return JSON.parse(output);
}
test('finite snapshot children and legacy parents retain separate ready and loading tails',()=>{
 const ready=row(true),loading=row(false,90);loading.frame_profile.metrics.entry_snapshot_commit_ms=metric(70);loading.frame_profile.worst_frame.entry_snapshot_commit_ms=70;
 const result=invoke([ready,loading]);
 for(const name of children)assert(result.allCompletedWindows.metrics[name],name);
 for(const name of ['snapshot_world_apply','snapshot_world_and_ui_apply','entry_snapshot_core_ms'])assert(result.allCompletedWindows.metrics[name],name);
 assert.equal(result.groups[0].observations,1);assert.equal(result.allCompletedWindows.observations,2);
 assert.equal(result.groups[0].metrics.entry_snapshot_commit_ms.largestWindowMaximum,30);assert.equal(result.allCompletedWindows.metrics.entry_snapshot_commit_ms.largestWindowMaximum,70);
 assert.equal(result.allCompletedWindows.metrics.entry_snapshot_commit_ms.largestMaximumContext.ready,false);assert.equal(result.allCompletedWindows.metrics.entry_snapshot_commit_ms.largestMaximumRetainedWorstWallMatches,true);
});
test('window maxima retain context without borrowing unmatched children from worst-wall snapshots',()=>{
 const a=row(true),b=structuredClone(a);b.at=200;b.elapsedMs=1100;
 const result=invoke([a,b]),metric=result.groups[0].metrics.world_receive_rows_ms;
 assert.equal(metric.largestWindowMaximum,12);assert.equal(metric.medianOfWindowMeans,1.2);assert.equal(metric.largestMaximumRetainedWorstWallMatches,false);
 assert.equal(result.groups[0].retainedWorstWallSnapshots.length,1);assert.equal(result.groups[0].retainedWorstWallSnapshots[0].contexts.length,2);
 assert.equal(result.groups[0].retainedWorstWallSnapshots[0].spans.world_receive_rows_ms,11);
 assert.match(result.scope,/not additive/);assert.match(result.scope,/not a unique hitch count/);
});
test('worker CPU is never relabeled main-thread time and incomplete tails remain explicit',()=>{
 const result=invoke([row(true)],'{"incomplete":');
 assert.equal(result.input.incompleteTail,true);assert.equal(result.allCompletedWindows.metrics.worker_cpu_ms,undefined);
 assert.equal(result.allCompletedWindows.retainedWorstWallSnapshots[0].spans.worker_cpu_ms,undefined);
 assert.match(result.scope,/worker CPU duration is not imported as main-thread stall/);
});
