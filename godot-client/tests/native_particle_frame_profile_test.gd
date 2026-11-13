extends SceneTree
# Actual inherited step/_process before vs after instrumentation. Only native
# dispatch, renderer submission, lighting DTO and camera compositor installation
# are doubles; camera/fog/view, queue/register/control/close and Profile are real.
const Profile=preload("res://systems/native_render/frame_profile.gd")
const SPANS=["particle_frame_queues_ms","particle_frame_inputs_ms","particle_frame_lighting_dto_ms","particle_frame_collision_indices_ms","particle_frame_native_presentation_ms","particle_frame_scene_publication_ms","particle_frame_renderer_submit_ms","particle_frame_renderer_status_ms"]
var checks:=0
var failures: Array=[]
var observations: Array=[]
var view_camera: Camera3D

class CurrentStream extends "res://systems/native_render/particle_stream_group.gd":
	var trace: Array=[]
	func attach_camera(next: Camera3D) -> void:
		trace.append("camera.attach"); camera=next
class BeforeStream extends "res://tests/fixtures/native_particle_stream_profile_before.gd":
	var trace: Array=[]
	func attach_camera(next: Camera3D) -> void:
		trace.append("camera.attach"); camera=next
class Emitter extends Node3D:
	var native_owner: RefCounted
	var native_pose_bound:=false
	var native_frame_group: Node
	var native_stream_group: Node
	var particles_enabled:=true
	var retired:=false
	var failure:=""
	var queued_detonate:=false
	var collision_flags_pending:=false
	func grouped_fallback_tick(_delta: float) -> void: pass
class NativeDouble extends RefCounted:
	var trace: Array=[]
	var commands: Array=[]
	var stream: WeakRef
	var emitter_id:=0
	var mode:=""
	var running_at_dispatch:=false
	func dispatch(operation: int,input: Dictionary) -> Dictionary:
		trace.append("native."+str(operation))
		var captured: Dictionary=input.duplicate(true)
		if int(captured.get("id",0))==emitter_id: captured.id="new-emitter"
		if captured.has("fallback"): captured.fallback={"method":captured.fallback.get_method(),"valid":captured.fallback.is_valid()}
		commands.append({"op":operation,"input":captured})
		if operation==1:
			var owner=stream.get_ref(); running_at_dispatch=owner.running
			if mode=="deferred-close": owner.close()
			if mode=="native-error": return {"error":"authored native presentation refusal"}
			return {"generation":7,"active":3,"vertices":18}
		if operation==9: return {"generation":7,"batches":[]}
		return {}
class RendererDouble extends RefCounted:
	var trace: Array=[]
	var commands: Array=[]
	var mode:=""
	func dispatch(operation: int,input: Dictionary) -> Dictionary:
		trace.append("renderer."+str(operation)); commands.append({"op":operation,"input":input.duplicate(true)})
		if operation==1 and mode=="submit-error": return {"error":"authored renderer submission refusal"}
		if operation==2: return {"error":1 if mode=="status-error" else 0,"failure":"authored renderer status refusal" if mode=="status-error" else ""}
		return {}
class LightDouble extends RefCounted:
	var trace: Array=[]
	func particle_lighting() -> Dictionary:
		trace.append("lighting.dto")
		return {"lights":[{"position":[1.0,2.0,3.0],"color":[0.25,0.5,0.75],"radius":4.0,"fade":0.5}],"headlight":false}
class SceneDouble extends Node:
	var trace: Array=[]
	var failure:="authored scene publication refusal"
	var mode:=""
	var received: Array=[]
	func consume(frame: Dictionary) -> bool:
		trace.append("scene.consume"); received.append(frame.duplicate(true)); return mode!="scene-error"
	func close() -> void: trace.append("scene.close")

func _initialize() -> void: call_deferred("run_test")
func expect(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func reset_profile(enabled: bool) -> void:
	Profile.enabled=enabled; Profile.phase_frame=Engine.get_process_frames(); Profile.phases={"sentinel":3.0}
	Profile.record_usec=0; Profile.collected_frame=-1; Profile.postdraw_phases={}; Profile.postdraw_record_usec=0
func capture(stream: Node,mode: String,profile_enabled: bool) -> Dictionary:
	var world:=Node3D.new(); root.add_child(world); world.add_child(stream); stream.set_process(false)
	var trace: Array=[]; stream.trace=trace; stream.scope_root=world; stream.native_surface_output=mode!="legacy"; stream.pooled_lighting=true
	world.set_meta("native_particle_stream_group",stream)
	var emitter:=Emitter.new(); world.add_child(emitter); emitter.set_process(false)
	var native_double:=NativeDouble.new(); native_double.trace=trace; native_double.stream=weakref(stream); native_double.emitter_id=emitter.get_instance_id(); native_double.mode=mode
	var renderer_double:=RendererDouble.new(); renderer_double.trace=trace; renderer_double.mode=mode
	stream.native=native_double; stream.renderer=renderer_double
	stream.pending_removals[301]=true; stream.pending_registrations[emitter.get_instance_id()]=weakref(emitter); stream.pending_controls[302]={"id":302,"patch":{"flags":16},"detonate":true}
	var light:=LightDouble.new(); light.trace=trace; world.set_meta("native_focus_light_owner",weakref(light))
	var scene_double: SceneDouble
	if mode!="legacy":
		scene_double=SceneDouble.new(); scene_double.trace=trace; scene_double.mode=mode; world.add_child(scene_double); stream.scene_batches=scene_double
		stream.collision_provider=func(): trace.append("collision.indices"); return [91,92]
	if mode=="unsupported-fog": stream.fast_members=1
	reset_profile(profile_enabled)
	stream._process(0.125)
	var input: Dictionary={}
	for command in native_double.commands:
		if command.op==1: input=command.input
	var result: Dictionary={"calls":trace.duplicate(),"native":native_double.commands.duplicate(true),"renderer":renderer_double.commands.duplicate(true),"last":stream.last.duplicate(true),"failure":stream.failure,"closed":stream.closed,"running":stream.running,"closeRequested":stream.close_requested,"queuesEmpty":stream.pending_removals.is_empty() and stream.pending_controls.is_empty() and stream.pending_registrations.is_empty(),"frameInput":input,"runningAtDispatch":native_double.running_at_dispatch,"phases":Profile.phases.duplicate(),"recordUsec":Profile.record_usec,"postdraw":Profile.postdraw_phases.duplicate(),"sceneFrames":scene_double.received.duplicate(true) if scene_double!=null else []}
	Profile.enabled=false
	stream.close(); world.free()
	return result
func expected_spans(mode: String) -> Array:
	var result: Array=[SPANS[0],SPANS[1]]
	if mode in ["no-camera","unsupported-fog"]: return result
	if mode!="legacy": result.append_array([SPANS[2],SPANS[3]])
	result.append(SPANS[4])
	if mode=="native-error": return result
	if mode!="legacy": result.append(SPANS[5])
	if mode=="scene-error": return result
	result.append(SPANS[6])
	if mode=="submit-error": return result
	result.append(SPANS[7]); return result
func expected_calls(mode: String) -> Array:
	var result: Array=["native.3","native.0","native.4"]
	if mode=="no-camera": return result
	if mode=="unsupported-fog": result.append_array(["native.3","native.5","scene.close"]); return result
	result.append("camera.attach")
	if mode!="legacy": result.append_array(["lighting.dto","collision.indices"])
	result.append("native.1")
	if mode!="native-error":
		if mode!="legacy": result.append_array(["native.9","scene.consume"])
		if mode!="scene-error":
			result.append("renderer.1")
			if mode!="submit-error": result.append("renderer.2")
	if mode in ["native-error","scene-error","submit-error","status-error","deferred-close"]: result.append_array(["native.3","native.5","scene.close"])
	return result
func run_test() -> void:
	view_camera=Camera3D.new(); root.add_child(view_camera); view_camera.position=Vector3(2,3,4); view_camera.make_current()
	for mode: String in ["full","legacy","native-error","scene-error","submit-error","status-error","deferred-close","no-camera","unsupported-fog"]:
		view_camera.environment=null
		if mode=="no-camera": view_camera.clear_current(false)
		else: view_camera.make_current()
		if mode=="unsupported-fog":
			var environment:=Environment.new(); environment.fog_enabled=true; environment.fog_height_density=0.25; view_camera.environment=environment
		for profile_enabled: bool in [false,true]:
			var before: Dictionary=capture(BeforeStream.new(),mode,profile_enabled)
			var current: Dictionary=capture(CurrentStream.new(),mode,profile_enabled)
			var label:=mode+"/profile="+str(profile_enabled)
			expect(current.calls==before.calls,label+" actual call order equals sealed before")
			expect(current.calls==expected_calls(mode),label+" exact expected boundaries and cleanup")
			expect(current.native==before.native,label+" native command/input bytes unchanged")
			expect(current.renderer==before.renderer,label+" renderer commands unchanged")
			expect(current.sceneFrames==before.sceneFrames,label+" scene publication unchanged")
			expect(current.last==before.last and current.failure==before.failure,label+" result/refusal unchanged")
			expect(current.closed==before.closed and current.closeRequested==before.closeRequested,label+" lifetime unchanged")
			expect(current.queuesEmpty and not current.running,label+" queues drained and running cleared")
			var dispatched:=mode not in ["no-camera","unsupported-fog"]
			expect(current.runningAtDispatch==dispatched,label+" native dispatch keeps actual running fence")
			expect(current.frameInput.is_empty() if not dispatched else current.frameInput.delta==0.125 and current.frameInput.profile==profile_enabled and current.frameInput.native_surface_output==(mode!="legacy") and current.frameInput.scene_instances==true,label+" exact actual input flags/delta")
			var expected: Array=expected_spans(mode) if profile_enabled else []
			var actual: Array=[]
			for span: String in SPANS:
				if current.phases.has(span): actual.append(span)
			expect(actual==expected,label+" only reached finite phase spans")
			var finite:=true
			for span: String in actual: finite=finite and is_finite(float(current.phases[span])) and float(current.phases[span])>=0
			expect(finite,label+" nonnegative finite durations")
			expect(current.phases=={"sentinel":3.0} and current.recordUsec==0 and current.postdraw.is_empty() if not profile_enabled else current.phases.has("callback_particles") and current.phases.size()==expected.size()+2,label+" off inert / on keeps original inclusive owner")
			observations.append({"case":label,"calls":current.calls,"spans":actual,"closed":current.closed,"failure":current.failure})
	var additive:=false
	for span: String in SPANS: additive=additive or Profile.CALLBACKS.has(span)
	expect(not additive,"subspans are not new additive callback owners")
	expect(observations.size()==18,"nine branches tested before/current with profiling off/on")
	view_camera.environment=null; view_camera.free(); Profile.enabled=false; Profile.phases={}; Profile.postdraw_phases={}
	var result: Dictionary={"success":failures.is_empty(),"checks":checks,"failures":failures,"cases":observations,"scope":"Actual inherited particle_stream_group step/_process and queue/register/control/close, actual Camera/Fog/Bounds/Profile; controlled native dispatch/renderer/light DTO/scene consumer and compositor-install adapter. No native simulation, GPU, cost benchmark or finer simulation attribution claim."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--result="):
			var file:=FileAccess.open(argument.trim_prefix("--result="),FileAccess.WRITE); file.store_string(JSON.stringify(result)); file.close()
	print("PARTICLE_FRAME_PROFILE ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
