extends SceneTree
const Group=preload("res://systems/native_render/particle_stream_group.gd")
const Emitter=preload("res://systems/native_render/particle_emitter.gd")
class FakeSurface extends Node3D:
	var retired:=false
	var restored:=false
	func retire() -> void: retired=true
	func configure(_texture: Variant,_a: int,_b: bool,_c: bool,_d: bool) -> void: restored=true
class FakeEmitter extends Node3D:
	var retired:=false
	var failure:=""
	var native_owner: RefCounted
	var native_frame_group: Node
	var native_stream_group: Node
	var particles_enabled:=true
	var surface: FakeSurface
	var queued_detonate:=false
	var collision_flags_pending:=false
	var original_texture: Texture2D
	var _state:={}
	var old_ticks:=0
	func grouped_fallback_tick(_delta: float) -> void: old_ticks+=1
	func effective_flags() -> int: return 0
var failures: Array[String]=[]
func check(condition: bool,message: String) -> void:
	if not condition: failures.append(message);push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2);return
	var world:=Node3D.new();root.add_child(world)
	var group:=Group.new();world.add_child(group);group.set_process(false)
	group.scope_root=world;group.geometry_worker=true;group.native=ClassDB.instantiate("NwnParticlePresentation")
	world.set_meta("native_particle_stream_group",group)
	var emitter:=FakeEmitter.new();world.add_child(emitter)
	emitter.surface=FakeSurface.new();emitter.add_child(emitter.surface)
	check(group.register(emitter),"Strict group registers unsupported emitter")
	check(emitter.surface.retired and not emitter.is_processing(),"Unsupported emitter surface and old tick are disabled")
	var planes:=PackedFloat32Array([1,0,0,100,-1,0,0,100,0,0,-1,100,0,0,1,100,0,1,0,100,0,-1,0,100])
	var view:={"stamp":1,"position":[0.0,0.0,0.0],"camera":[1.0,0.0,0.0,0.0],"planes":planes.to_byte_array()}
	var result: Dictionary=group.native.call("dispatch",1,{"delta":1.0/60.0,"view":view,"geometry_worker":true})
	check(not result.has("error"),"Strict fallback frame succeeds "+str(result.get("error","")))
	var state: Dictionary=group.snapshot()
	check(emitter.old_ticks==0 and state.suppressed_fallbacks==1 and state.fallback_reasons.get("reference/custom owner",0)==1,"No old fallback path ran")
	check(int(state.native.fallbacks)==1,"Suppressed effect is counted explicitly")
	group.close()
	check(not emitter.surface.restored and not emitter.is_processing(),"Closing strict group does not silently reactivate the old path")
	var old_ticks:=emitter.old_ticks
	world.free()
	var outside:=Node3D.new();root.add_child(outside)
	var unregistered:=Emitter.new();unregistered.source_path=NodePath("..");unregistered.source_model_flags=0
	unregistered.original_properties={"update":"Fountain","render":"Normal","blend":"Normal","birthrate":8,"lifeexp":1,"sizestart":0.1,"sizeend":0.1,"alphastart":1,"alphaend":1}
	outside.add_child(unregistered)
	check(unregistered.strict_geometry_worker and not unregistered.is_processing() and is_instance_valid(unregistered.surface) and unregistered.surface.retired,"Unregistered emitter cannot use the old particle path")
	unregistered.set_particles_enabled(false);unregistered.set_particles_enabled(true);unregistered.tick(1.0/60.0)
	check(not unregistered.is_processing() and unregistered.frames==0 and unregistered.surface.retired,"Preference toggle and direct tick do not revive the old path")
	outside.free()
	await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"failures":failures,"suppressed":state.suppressed_fallbacks,"old_ticks":old_ticks,"native_fallbacks":state.native.fallbacks,"scope":"Private strict opt-in unsupported emitter suppression without old-path rollback"},"\t"));file.close()
	quit(0 if failures.is_empty() else 1)
