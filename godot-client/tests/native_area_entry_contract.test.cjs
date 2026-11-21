'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const project=path.resolve(__dirname,'..'),session=fs.readFileSync(path.join(project,'native_session_world.gd'),'utf8'),world=fs.readFileSync(path.join(project,'native_live_world.gd'),'utf8'),menu=fs.readFileSync(path.join(project,'systems/native_main_menu.gd'),'utf8');
test('entry commit retains synchronous core, visibility, observer and acknowledgment order',()=>{
 const block=session.slice(session.indexOf('func apply_raw_snapshot('));
 const barrier=session.slice(session.indexOf('\t\t"raw-world-end":'),session.indexOf('\t\t"browser-open":',session.indexOf('\t\t"raw-world-end":')));
 assert.match(barrier,/snapshot_preparation\.seal\(\)/);
 assert.match(barrier,/snapshot_preparation\.take\(snapshot_preparation_scope\(snapshot\)\)/);
 assert.match(barrier,/metadata\.is_empty\(\):pending_prepared_snapshot=snapshot;return/);
 assert.match(barrier,/commit_raw_snapshot\(snapshot,metadata\)/);
 assert.doesNotMatch(barrier,/wait_for_task_completion|\bawait\b/);
 const calls=['super.receive({"kind":"snapshot"','native_visibility_runtime.accepted_world(snapshot.data)','entity_api_snapshot(snapshot,received_before)','accepted_raw_serial=raw_serial','refresh_entry_menu_scope(render_menu,','send({"kind":"raw-world-accepted"'];
 let previous=-1;for(const call of calls){const index=block.indexOf(call);assert.ok(index>previous,call+' must retain commit order');previous=index;}
 assert.doesNotMatch(block,/\bawait\b|call_deferred\(|Thread\.new\(/);
 assert.match(block,/if received==received_before\+1 and native_visibility_runtime!=null:/);
 assert.match(block,/"serial":raw_serial,"generation":snapshot\.generation/);
});
test('identical scope suppression guards actual setter and keeps all four owner coordinates',()=>{
 const helper=session.match(/static func refresh_entry_menu_scope\([^]*?(?=\nfunc )/)?.[0];assert.ok(helper);
 assert.match(helper,/if value==menu\.native_scope:return false\s+menu\.set_native_scope\(value\);return true/);
 assert.match(session,/refresh_entry_menu_scope\(render_menu,\[session_connection,gameplay_ui\.generation,gameplay_ui\.area_id,gameplay_ui\.controlled_id\]\)/);
});
test('independent lobby, readiness, art and key-binding refresh paths remain intact',()=>{
 assert.match(menu,/func observe_lobby\(value: Dictionary\) -> void:\s+lobby_state=value\.duplicate\(true\); update_native\(\)/);
 for(const signal of ['native_frame.prepared.connect','native_frame.artwork_ready.connect','video_owner.prepared.connect','key_owner.prepared.connect','observed_bindings.changed.connect'])assert.ok(menu.includes(signal),signal);
 assert.match(menu,/func set_native_scope\(value: Array\) -> void:\s+if value!=native_scope: dismiss\(\)\s+native_scope=value\.duplicate\(\); update_native\(\)/);
});
test('entry subowner instrumentation uses finite labels and preserves the old world/UI parent boundary',()=>{
 for(const label of ['entry_snapshot_core_ms','entry_blocker_policy_ms','entry_visibility_commit_ms','entry_camera_bind_ms','entry_entity_api_commit_ms','entry_options_configure_ms','entry_ui_scope_ms','entry_ack_ms'])assert.ok(session.includes('FrameProfile.finish("'+label+'",'),label);
 for(const label of ['transition_camera_setup_ms','transition_registry_hud_ms','transition_input_keyboard_ms','transition_environment_bind_ms','snapshot_environment_header_ms','snapshot_placeable_lights_ms','snapshot_wind_voice_ms','snapshot_transition_targets_ms','snapshot_flush_combat_ms'])assert.ok(world.includes('FrameProfile.finish("'+label+'",'),label);
 assert.match(world,/var state_began:=FrameProfile\.begin\(\)\s+var lights_began:=FrameProfile\.begin\(\)/);
 assert.ok(world.indexOf('FrameProfile.finish("snapshot_world_and_ui_apply",state_began)')>world.indexOf('FrameProfile.finish("snapshot_placeable_lights_ms",lights_began)'));
});
