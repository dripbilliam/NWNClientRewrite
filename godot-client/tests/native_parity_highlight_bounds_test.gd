extends SceneTree
const Bounds=preload("res://tools/native_parity/highlighting/native_highlight_bounds.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func box() -> Dictionary:return {"min":[-1.0,-2.0,-3.0],"max":[1.0,2.0,3.0]}
func descriptor(part: Node3D,skin: bool=false,enabled: bool=true) -> Dictionary:return {"anchor":part,"native_bounds":box(),"is_skin":skin,"subtree_enabled":enabled,"model_index":0}
func run() -> void:
	var out:=Bounds.project(box(),Transform3D.IDENTITY,Vector3(10,0,0),1.0,1.0,Color.RED,1.0)
	check(out.available and out.vertices.size()==18 and out.colors.size()==72,"Exactly18 vertices and72 RGBA bytes for one native authored box")
	check(out.vertices[0].is_equal_approx(Vector3(-0.001,-3,2)) and out.vertices[1].is_equal_approx(Vector3(-0.001,-3,-2)) and out.vertices[2].is_equal_approx(Vector3(-0.001,3,2)),"First native plane follows original corner order and source-to-Godot coordinate mapping")
	check(out.vertices[2]==out.vertices[3] and out.vertices[1]==out.vertices[4],"Six native triangle vertices retain shared corner topology")
	check(out.colors[0]==255 and out.colors[1]==0 and out.colors[2]==0 and out.colors[3]==255,"Camera-facing native plane uses exact red byte and full squared-facing alpha")
	check(out.colors[6*4+3]==0 and out.colors[12*4+3]==0,"Orthogonal planes have zero facing contribution")
	check(Bounds.native_normalize(Vector3.ZERO)==Vector3.RIGHT,"Original zero-vector normalization returns native X axis")
	var near_unit:=Vector3(1.000002,0,0);check(Bounds.native_normalize(near_unit)==near_unit,"Original near-unit band preserves input rather than renormalizing")
	var same_position:=Bounds.project(box(),Transform3D.IDENTITY,Vector3.ZERO,1,1,Color.RED,1)
	check(same_position.available and same_position.colors[3]==255,"Camera at Part origin follows original zero-direction fallback")
	var faded:=Bounds.project(box(),Transform3D.IDENTITY,Vector3(10,0,0),1,1,Color.RED,0.2)
	check(faded.colors[0]==127 and faded.colors[3]==255,"Gob alpha below.4 dims RGB without applying ordinary Part alpha")
	var moved:=Bounds.project(box(),Transform3D(Basis.IDENTITY,Vector3(4,5,6)),Vector3(14,5,6),1,1,Color.RED,1)
	check(moved.vertices[0].is_equal_approx(out.vertices[0]+Vector3(4,5,6)),"Current Part translation is included without changing authored geometry")
	check(not Bounds.project(box(),Transform3D(Basis.from_scale(Vector3(1,2,1)),Vector3.ZERO),Vector3(10,0,0),1,1,Color.WHITE,1).available,"Unsupported nonuniform native pose is explicit rather than invented bounds")
	check(not Bounds.project({},Transform3D.IDENTITY,Vector3.ZERO,1,1,Color.WHITE,1).available and not Bounds.project(box(),Transform3D.IDENTITY,Vector3.ZERO,NAN,1,Color.WHITE,1).available,"Missing bounds and nonfinite pulse are unavailable")
	var owner:=Node3D.new();root.add_child(owner);var physical:=MeshInstance3D.new();owner.add_child(physical);physical.visible=false
	var helper:=Bounds.new();root.add_child(helper);var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(10,0,0)
	var descriptions: Array=[descriptor(physical)];var alpha_reads: Array=[0]
	check(helper.register_entity(7,owner,[1,2,3],descriptions,Color.RED,func(_model):alpha_reads[0]+=1;return 0.2),"Explicit physical authored-bound owner registers without reading draw visibility")
	descriptions[0].native_bounds.min[0]=-999.0
	helper.mark([7]);check(helper.tick(camera,1.0,1.0),"Active highlighted Part builds and updates retained surface headlessly")
	check(helper.stats.parts==1 and helper.stats.vertices==18 and helper.surface.get_surface_count()==1 and not physical.visible,"Invisible ordinary mesh still contributes bounds; no force-visible or triangle copy")
	check(helper.batch.custom_aabb.size.length()>1.0 and helper.batch.custom_aabb.has_point(helper.positions[0]),"Retained region uploads publish a truthful current culling box rather than original zero bounds")
	check(helper.positions[0].x>-0.01 and helper.entries[7].lifetime==[1,2,3],"Caller mutation cannot alter detached authored geometry/lifetime token")
	var mesh_id:=helper.surface.get_instance_id();var rebuilds: int=helper.stats.membership_rebuilds
	helper.mark([7,7]);helper.tick(camera,1,1)
	check(helper.surface.get_instance_id()==mesh_id and helper.stats.membership_rebuilds==rebuilds and alpha_reads[0]==2,"Held Tab reuses one retained surface and reads alpha once per highlighted model")
	helper.mark([]);helper.tick(camera,1,1);check(helper.stats.vertices==0 and not helper.batch.visible,"Unmark clears draw membership without touching source Part")
	helper.register_entity(8,owner,[],[descriptor(physical,true)],Color.GREEN,func(_model):return 1.0);helper.mark([8]);helper.tick(camera,1,1)
	check(helper.stats.parts==0,"Native Skin Parts are excluded instead of adding coincident skinned overlays")
	helper.mark([7]);helper.set_subtree_enabled(7,physical.get_instance_id(),false);helper.tick(camera,1,1)
	check(helper.stats.parts==0,"Explicit native subtree gate suppresses membership independently from material alpha")
	helper.set_subtree_enabled(7,physical.get_instance_id(),true);helper.tick(camera,1,1)
	check(helper.stats.parts==1,"Explicit subtree reactivation restores original geometry")
	check(not helper.register_entity(9,owner,[],[{"anchor":physical,"native_bounds":box()}],Color.WHITE),"Unknown native type/subtree admission cannot silently become visible")
	helper.register_entity(10,owner,[],[descriptor(physical)],Color.WHITE,func(_model):helper.forget(10);return 1.0);helper.mark([10])
	var updates: int=helper.stats.updates
	check(not helper.tick(camera,1,1) and helper.stats.updates==updates and not helper.entries.has(10) and not helper.batch.visible,"Alpha callback retirement invalidates and hides the batch before publishing retained buffers")
	helper.register_entity(11,owner,[],[descriptor(physical)],Color.WHITE);helper.mark([11])
	check(not helper.tick(camera,1,1) and Array(helper.positions).all(func(value):return value==Vector3.ZERO),"Missing current Gob alpha stays unavailable instead of assuming opacity1")
	helper.mark([7]);helper.tick(camera,1,1);owner.free()
	check(not helper.tick(camera,1,1) and Array(helper.positions).all(func(value):return value==Vector3.ZERO),"Freed full-ID owner/Part cannot resolve stale retained geometry")
	var state:=helper.snapshot();state.vertices=999;check(helper.snapshot().vertices!=999,"Cold diagnostics expose detached counts only")
	helper.close();check(helper.closed and helper.entries.is_empty() and helper.members.is_empty() and helper.batch.mesh==null,"Close releases retained geometry and weak membership")
	check(not helper.register_entity(12,camera,[],[],Color.WHITE) and not helper.tick(camera,1,1),"Closed helper cannot resurrect membership")
	helper.free();camera.free();await process_frame
	print("NATIVE_PARITY_HIGHLIGHT_BOUNDS ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
