const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const project=path.resolve(__dirname,'..');
const bytes=fs.readFileSync(path.join(project,'native_live_world.gd'),'utf8');
const source=bytes.replaceAll('\r\n','\n');
const before=fs.readFileSync(path.join(project,'.cache/native-clock-runtime-before-v1/godot-client/native_live_world.gd'),'utf8');
function body(name,next){const a=source.indexOf('func '+name),b=source.indexOf('func '+next,a+1);assert.ok(a>=0&&b>a);return source.slice(a,b);}
test('default hooks are unique no-ops and perform no service/provider work',()=>{
 for(const name of ['startup','prefix','post_receive']){
  assert.equal(source.split('func native_clock_'+name+'() -> void: pass').length-1,1);
  assert.equal(source.split('\tnative_clock_'+name+'()\n').length-1,1);
 }
});
test('startup hook is immediately before protocol connect and after ticket/setup',()=>{
 const run=body('run()','activate_window_from_click');
 const connect=run.indexOf('if peer.connect_to_host('),hook=run.indexOf('native_clock_startup()');
 assert.ok(hook>run.indexOf('ticket.get("host")'));
 assert.ok(hook>run.indexOf('host=Node3D.new()'));
 assert.ok(hook<connect);
 assert.match(run,/\tnative_clock_startup\(\)\n\tif peer\.connect_to_host/);
 assert.ok(connect<run.indexOf('process_frame.connect(tick)'));
});
test('prefix precedes all poll/dispatch and post-receive survives a missing World',()=>{
 const tick=body('_profile_tick()','gameplay_presentation_allowed');
 assert.match(tick,/^func _profile_tick\(\) -> void:\n\tif closing: return\n\tnative_clock_prefix\(\)\n/);
 const prefix=tick.indexOf('native_clock_prefix()'),poll=tick.indexOf('peer.poll()'),dispatch=tick.indexOf('for message in messages: receive(message)'),flush=tick.indexOf('\tflush_protocol_output()'),post=tick.indexOf('native_clock_post_receive()'),noWorld=tick.indexOf('if closing or not is_instance_valid(world): return');
 assert.ok(prefix<tick.indexOf('creation_runtime.begin_frame('));
 assert.ok(prefix<poll&&poll<dispatch&&dispatch<flush&&flush<post&&post<noWorld);
 assert.match(tick,/FrameProfile\.finish\("root_protocol",phase_began\)\n\tnative_clock_post_receive\(\)\n\tif closing or not is_instance_valid\(world\): return/);
});
test('removing the six declared lines exactly recovers dirty before bytes',()=>{
 let restored=bytes;
 const nl=bytes.includes('\r\n')?'\r\n':'\n';
 for(const name of ['startup','prefix','post_receive']){
  restored=restored.replace('func native_clock_'+name+'() -> void: pass'+nl,'');
  restored=restored.replace('\tnative_clock_'+name+'()'+nl,'');
 }
 assert.equal(restored,before,'All existing async handlers, ACK drain and finish/shutdown paths must remain byte-identical');
});
