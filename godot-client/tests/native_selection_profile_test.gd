extends SceneTree
const Selection=preload("res://tools/native_parity/highlighting/whole_character_selection.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const State=preload("res://tools/native_parity/ui/actor-alpha-state.gd")
class Layer extends RefCounted:
	var models: Dictionary={}
	var closed:=false
class Owner extends Node3D:
	var parts: Array=[]
	var retired:=false
	var actor_alpha:=Layer.new()
	func renderer_alpha_model_indices() -> Array:return [0]
	func set_renderer_vector(slot: int,value: Variant,_indices: Array) -> bool:return actor_alpha.models[0].set_vector(slot,value)
var checks:=0
var failures: Array=[]
var samples: Array=[]
var report:=""
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func reset(enabled: bool) -> void:
	Timing.enabled=enabled;Timing.phase_frame=-1;Timing.phases={};Timing.record_usec=0;Timing.collected_frame=-1;Timing.postdraw_phases={};Timing.postdraw_record_usec=0
func row(label: String) -> Dictionary:
	var result: Dictionary=Timing.phases.duplicate();samples.append({"label":label,"row":result});return result
func part(owner: Node3D,offset: Vector3,skin: bool=false) -> Node3D:
	var node:=Node3D.new();owner.add_child(node);node.position=offset;node.set_meta("native_mesh_source",{"node_flags":0x61 if skin else 0x21,"native_bounds_available":true,"native_bounds_valid":true,"native_bounds":{"min":[-.5,-.25,0.],"max":[.5,.25,2.]}});return node
func body(viewport: Node,index: int,count: int) -> Owner:
	var owner:=Owner.new();viewport.add_child(owner);owner.actor_alpha.models[0]=State.new();owner.set_meta("native_selection_scope",[index])
	for at in count:owner.parts.append(part(owner,Vector3(float(at),0,0),at==1))
	return owner
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	check(DisplayServer.get_name()=="headless","Fixture remains extension-free headless CPU control")
	check(Timing.CALLBACKS.count("callback_selection")==1 and Timing.CALLBACKS.count("callback_mouse_cursor")==1,"Private profiler adds selection exactly once and preserves accepted cursor accounting")
	check(not Timing.CALLBACKS.has("effect_selection_total") and not Timing.CALLBACKS.has("physics_pointer"),"Unrelated effect/physics child spans are excluded from disjoint callback accounting")
	var viewport:=SubViewport.new();viewport.size=Vector2i(800,600);root.add_child(viewport)
	var camera:=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(0,3,10);camera.look_at(Vector3(0,1,0));camera.make_current()
	var first:=body(viewport,1,2);var second:=body(viewport,2,1)
	var selected:=Selection.new();viewport.add_child(selected);selected.configure(camera);selected.set_process(false)
	var image:=Image.create(4,4,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE);var texture:=ImageTexture.create_from_image(image)
	check(selected.bounds.configure_texture(texture,{"filter":true,"mipmap":true,"clamp":3},true),"Unchanged actual whole-character helper receives CPU control texture")
	check(selected.register_entity(7,{"color":"#00ff00"},first) and selected.register_entity(8,{"color":"#00ff00"},second),"Actual controller admits two physical lifetimes through existing source/alpha route")
	selected.mark([7],-1,true);reset(false);selected._process(0.)
	var before: PackedVector3Array=selected.bounds.positions.duplicate();var phase: float=selected.phase;var writes: int=selected.stats.channel_writes
	check(Timing.phases.is_empty() and selected.bounds.stats.source_parts==2 and selected.bounds.stats.source_corners==16,"Disabled profiling records nothing while actual helper fits rigid+Skin Parts")
	reset(true);selected._process(0.);var one:=row("one-selected")
	check(one.get("callback_selection",-1.)>=0. and not one.has("effect_selection_total"),"Top-level selection callback duration is recorded under its own owner")
	check(one.get("count_selection_entities")==1 and one.get("count_selection_source_parts")==2 and one.get("count_selection_source_corners")==16 and one.get("count_selection_tick_complete")==1,"Counters reuse actual one-entity/two-Part/sixteen-corner completed fit")
	check(selected.bounds.positions==before and selected.phase==phase and selected.stats.channel_writes==writes,"Instrumentation preserves held geometry, pulse and sparse alpha-channel publications")
	check(first.actor_alpha.models[0].alpha==1. and selected.bounds.stats.quads==1 and selected.bounds.stats.vertices==6,"Actual body alpha and one-quad geometry remain unchanged")
	selected.mark([7,8],7,true);reset(true);selected._process(0.);var two:=row("two-selected")
	check(two.count_selection_entities==2 and two.count_selection_source_parts==3 and two.count_selection_source_corners==24 and two.count_selection_tick_complete==1,"O(1) counters follow actual helper totals for two selected lifetimes")
	selected.mark([],-1,false);var frames: int=selected.stats.frames;reset(true);selected._process(0.);var idle:=row("idle")
	check(idle.count_selection_entities==0 and idle.count_selection_source_parts==0 and idle.count_selection_source_corners==0 and idle.count_selection_tick_complete==0,"Idle callback reports zeros instead of stale helper counters")
	check(selected.stats.frames==frames and selected.bounds.stats.source_parts==3,"Idle profiling does not tick or modify retained helper statistics")
	selected.mark([7],-1,true);selected.camera=null;reset(true);selected._process(0.);var no_camera:=row("camera-unavailable")
	check(no_camera.has("callback_selection") and no_camera.count_selection_entities==1 and no_camera.count_selection_tick_complete==0 and no_camera.count_selection_source_parts==0,"Invalid-camera early return is still timed and does not expose stale fit counters")
	selected.camera=weakref(camera);reset(false);selected._process(0.);selected.bounds.clear_texture();reset(true);selected._process(0.);var failed:=row("texture-unavailable")
	check(failed.has("callback_selection") and failed.count_selection_tick_complete==0 and failed.count_selection_source_parts==0 and failed.count_selection_source_corners==0,"Unavailable helper tick is timed with explicit failed/zero current-fit counters")
	check(selected.bounds.stats.source_parts==2 and selected.bounds.stats.source_corners==16,"Failed-tick profiling does not erase previous helper statistics to manufacture zeros")
	selected.bounds.configure_texture(texture,{"filter":true,"mipmap":true,"clamp":3},true);first.actor_alpha.models[0].set_presentation_draw_enabled(false);reset(true);selected._process(0.);var hidden:=row("hidden-primary")
	check(hidden.count_selection_entities==1 and hidden.count_selection_tick_complete==1 and hidden.count_selection_source_parts==0 and hidden.count_selection_source_corners==0,"Successful hidden-primary suppression reports no fitted Parts/corners")
	check(not selected.bounds.batch.visible and first.actor_alpha.models[0].alpha==1.,"Profiling preserves actual hidden draw independently of primary alpha")
	first.actor_alpha.models[0].set_presentation_draw_enabled(true);reset(true);selected._process(0.);var restored:=row("restored-primary")
	check(restored.count_selection_source_parts==2 and restored.count_selection_source_corners==16 and selected.bounds.batch.visible,"Restoring primary draw restores actual helper totals")
	first.retired=true;reset(true);selected._process(0.);var retired:=row("retired-owner")
	check(retired.count_selection_tick_complete==0 and retired.count_selection_source_parts==0 and not selected.bounds.batch.visible,"Retired physical owner remains fenced while callback is observable")
	selected.forget(7);reset(true);selected._process(0.);var removed:=row("forgotten-owner")
	check(not selected.entries.has(7) and not selected.bounds.entries.has(7) and removed.count_selection_entities==0,"Forgetting lifetime retires controller/helper references and selected counter")
	selected.close();reset(true);selected._process(0.);var closed:=row("closed-controller")
	check(closed.has("callback_selection") and closed.count_selection_entities==0 and closed.count_selection_source_parts==0 and closed.count_selection_tick_complete==0,"Closed early return stays timed and counter-safe")
	reset(false);selected.free();viewport.free();texture=null;image=null
	for frame in 2:await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"gpuRuns":0,"publicConnections":0,"nativeBuilds":0,"performanceClaim":false,"scope":"Isolated instrumentation functional/lifetime test on actual whole-character controller/helper with tiny authored CPU controls. No GPU timing, FPS/native room, full entry, new scan or shared-source activation. Counts describe requested selection membership and helper completed-fit totals; failed fits intentionally publish0 plus completion0."}
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("SELECTION_PROFILE ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
