extends SceneTree
# Factory/routing and owner teardown only. Actual animated/transparent pixels
# are covered by the separate whole-character graphical fixture.
const Registry=preload("res://systems/entity_registry.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera)
	var legacy:=Registry.new();legacy.native_highlight_enabled=false;legacy.whole_character_highlight_enabled=false;world.add_child(legacy);legacy.configure_highlights(camera)
	check(legacy.native_highlight==null,"Legacy route does not instantiate an unrequested candidate")
	var native:=Registry.new();native.native_highlight_enabled=true;native.whole_character_highlight_enabled=false;world.add_child(native);native.configure_highlights(camera)
	check(native.native_highlight!=null and native.native_highlight.get_script().resource_path=="res://systems/native_render/selection_highlight.gd","Existing native route keeps its original controller")
	check(native.native_highlight.bounds.get_script().resource_path=="res://tools/native_parity/highlighting/native_highlight_bounds_kernel.gd","Default factory keeps the reviewed per-Part renderer")
	check(native.native_highlight.bounds.get_parent()==native.native_highlight and native.native_highlight.bounds.batch.get_parent()==native.native_highlight.bounds,"Default construction has exactly the expected owner hierarchy")
	var body:=Registry.new();body.native_highlight_enabled=true;body.whole_character_highlight_enabled=true;world.add_child(body);body.configure_highlights(camera)
	check(body.native_highlight!=null and body.native_highlight.get_script().resource_path=="res://tools/native_parity/highlighting/whole_character_selection.gd","Whole-character request uses the actual registry controller route")
	check(body.native_highlight.bounds.get_script().resource_path=="res://tools/native_parity/highlighting/whole_character_glow.gd","Overridden factory constructs the whole-character renderer directly")
	check(body.native_highlight.bounds.get_parent()==body.native_highlight and body.native_highlight.bounds.batch.get_parent()==body.native_highlight.bounds,"Whole-character construction preserves existing controller/batch ownership")
	var previous: int=body.native_highlight.get_instance_id();body.configure_highlights(camera)
	check(body.native_highlight.get_instance_id()==previous,"Repeated camera configuration does not rebuild the renderer")
	var batch: MeshInstance3D=body.native_highlight.bounds.batch
	check(body.native_highlight.bounds.selected.is_empty() and (not batch.visible or batch.mesh==null or batch.mesh.get_surface_count()==0),"Unselected characters draw no candidate glow")
	body.native_highlight.close();native.native_highlight.close()
	check(body.native_highlight.closed and body.native_highlight.bounds.closed and native.native_highlight.closed,"Both routes use the existing close/lifecycle contract")
	world.free();await process_frame;await process_frame
	print("NATIVE_HIGHLIGHT_FACTORY ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
