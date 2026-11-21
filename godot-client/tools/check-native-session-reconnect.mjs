// Offline audit. These are scoped lifecycle tests, never whole-game acceptance.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url),read=f=>fs.readFile(new URL(f,project));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),json=async f=>JSON.parse(await read(f));
const bad=/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m;
const checked=[];
for(const name of ['native-session-stream-reconnect-v2','native-session-reconnect-default-v2','native-session-reconnect-menu-v2']){
 const report=await json('reports/'+name+'.json'),native=await json('reports/'+name+'.native.json');
 for(const [key,value]of Object.entries({success:true,protocolOnly:true,renderingPrepared:false,publicConnections:0,nativeExit:0,debuggerArmed:true,nativeException:false,sourceUnchanged:true}))assert.equal(report[key],value,name+' '+key);
 assert.notEqual(report.forcedNativeStop,true);assert.equal(native.success,true);
 for(const [file,digest]of Object.entries(report.sourceSha256))assert.equal(sha(await read(file)),digest,'Current pinned input '+file);
 for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+name+suffix))),name+suffix);
 const commands=String(await read('reports/'+name+'.cdb.txt'));for(const code of ['av','0xc0000374','0xc0000409','0xc000001d'])assert.ok(commands.includes(code));
 assert.ok(!report.loadedProtocolModules.some(file=>/(?:^|\/)(?:model_parser|prepared_model_geometry|network_scene|native_ui_assets|model_particles|particle_[^/]+)\.js$|(?:^|\/)three\//.test(file)));
 if(name.includes('-menu-')){assert.equal(native.browser_ready,true);assert.equal(native.network_connections,0);}
 else{
  assert.equal(native.object_visuals_complete,true);assert.equal(native.workers_remaining,0);assert.equal(native.protocol_finish_ack,true);assert.deepEqual(native.world.errors,[]);assert.deepEqual(native.world.failed_objects,{});assert.equal(native.world.entities,20);assert.equal(native.world.terrain.rendered_tiles,9);assert.equal(native.world.native_particles.failed,49);assert.ok(Object.values(native.render_cache_after_release.retained).every(n=>n===0));
  assert.equal(report.localCycles.length,report.requestedLocalCycles);
  for(const row of report.localCycles){assert.ok(Number.isSafeInteger(row.nativeProcessId)&&row.nativeProcessId>0);assert.equal(row.generation,1);assert.ok(row.nativeDistance>.2&&row.nativeDistance<2&&row.serverDistance>.2&&row.serverDistance<2);assert.ok(Math.abs(row.nativeDistance-row.serverDistance)<.001);assert.equal(row.state.entities+row.state.hidden,row.state.desired);assert.equal(row.state.object_visuals_complete,true);assert.deepEqual(row.state.errors,[]);assert.deepEqual(row.state.failed_objects,{});assert.ok(row.firstPlayable.entities<row.firstPlayable.desired&&row.firstPlayable.pendingBatches>0);}
 }
 if(name==='native-session-stream-reconnect-v2'){
  assert.equal(report.localStreamAbortRequested,true);assert.equal(report.localAbortedCycles.length,1);assert.equal(report.localCycles.length,3);assert.deepEqual(report.localCycles.map(r=>r.connection),[3,5,7]);
  const aborted=report.localAbortedCycles[0];assert.equal(aborted.connection,1);assert.ok(aborted.state.entities<aborted.state.desired&&aborted.state.pending_batches>0);assert.equal(new Set([aborted,...report.localCycles].map(r=>r.nativeProcessId)).size,1);
  assert.equal(native.session_disconnect_probes.length,3);assert.equal(native.session_disconnect_probes[0].connection,1);assert.ok(native.session_disconnect_probes[0].unfinished_workers>0);assert.equal(native.session_disconnect_probes[0].entities,1);assert.equal(native.session_disconnect_probes[0].pending_batches,2);
  assert.equal(native.stale_session_messages,12);assert.equal(native.stale_input_probes,3);assert.equal(report.retiredCommands.length,12);
  for(const kind of ['walk','catalog-ready','raw-world-accepted','observed'])assert.equal(report.retiredCommands.filter(r=>r.kind===kind&&r.connection<r.current).length,3);
  assert.equal(native.world_retirement.retired,3);assert.equal(native.world_retirement.released,3);assert.ok(native.world_retirement.peak_workers>0);assert.equal(native.world_retirement.pending_workers,0);assert.equal(native.world_retirement.pending_worlds,0);assert.equal(native.world_retirement.forced_drains,0);
  const first=report.localCycles[0].state.pool;
  for(const row of report.localCycles)for(const field of ['meshes_created','textures_created','materials_created','templates_created'])assert.equal(row.state.pool[field],first[field]);
  assert.ok(report.localCycles.at(-1).state.pool.template_hits>first.template_hits);assert.ok((await read('reports/'+name+'.native.png')).length>1000);
 }
 checked.push({run:name,sha256:sha(await read('reports/'+name+'.json'))});
}
const original=JSON.parse(await fs.readFile(new URL('../../backups/animations/native-session-disconnect-v1.json',import.meta.url)));
assert.equal(original.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(original.rows.length,270);assert.equal(original.imageInvalidWord,4294967293);
for(const row of original.rows){
 const c=row.case,eligible=c.index!==-1&&c.active!==0;assert.equal(row.result,Number(eligible));assert.equal(row.calls.some(r=>r[0]==='window-shutdown'),eligible&&c.mutation==='none');
 if(eligible){assert.deepEqual(row.calls[0],['send-bndm',c.invalidWord]);assert.equal(row.index,c.mutation==='active'?c.index:-1);}else assert.deepEqual(row.calls,[]);
}
const tap=String(await read('reports/native-reconnect-protocol-tests-v1.tap'));assert.match(tap,/# tests 58\s/);assert.match(tap,/# pass 58\s/);assert.match(tap,/# fail 0\s/);
const result={success:true,reports:checked,protocolTests:58,originalDisconnectCases:270,sameProcessReconnectVerified:true,realPendingStreamDisconnectVerified:true,retiredMessagesRejectedBothDirections:12,publicConnections:0,fullEffectsAccepted:false,remoteTransferAccepted:false,performanceAccepted:false,fullMigrationAccepted:false,nativeShutdownFaultResolved:false,scope:'Actual default native menu, ordinary owned Prelude join and one real pending-worker disconnect followed by three joins in one Godot PID. Original disconnect coordinator with explicit lower providers. Bridge connection fences do not change original server packets. Full effects, public/server handoffs, dense cold/warm/moving replay and FPS remain open.'};
await fs.writeFile(new URL('reports/native-session-reconnect-v1.verified.json',project),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
