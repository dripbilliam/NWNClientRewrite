extends SceneTree
# Bounded CPU publication cost, not frame time/FPS or a GPU benchmark.
const Owner=preload("res://tools/native_parity/ui/actor-alpha-owner.gd")
const Enhanced=preload("res://systems/native_render/native_model_material.gd")
const Pose=preload("res://systems/model_native_pose.gd")
var library: Resource
func _initialize() -> void:run.call_deferred()
func make_case(enhanced: bool,mode: int) -> Dictionary:
	var node:=Node3D.new();root.add_child(node);var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();node.add_child(mesh)
	var material=Enhanced.new() if enhanced else StandardMaterial3D.new()
	if enhanced:material.configure(StandardMaterial3D.new(),[1.0,1.0,1.0],[0.0,0.0,0.0])
	mesh.material_override=material
	var owner=Owner.new() if mode>0 else null
	if owner!=null:owner.enroll(mesh,0);owner.set_alpha(1.0 if mode==1 else 0.5)
	var source:={"id34":0,"flags98":0,"controllers78":[],"controllerCount80":0,"values88":PackedFloat32Array(),"children68":[],"childCount70":0}
	var metadata:={"root":0,"emitterFields":{},"parts":[{"type":"trimesh","node":source,"properties":{},"children":[],"transparencyHint":false}]}
	var pose:=Pose.new();pose.compiled_controls=false;pose.bulk_evaluation=false;pose.native_storage=false;pose.configure(metadata,{"parts":[0]},[node])
	var context: RefCounted=ClassDB.instantiate("NwnModelPoseStorage")
	var configured: Dictionary=context.call("dispatch",0,{"parts":pose.parts,"binding":[0],"root":0,"emitter_fields":{}})
	return {"node":node,"mesh":mesh,"owner":owner,"pose":pose,"context":context,"error":configured.get("error","")}
func run() -> void:
	library=load("res://native/particle_kernel.gdextension")
	if library==null or not ClassDB.class_exists("NwnModelPoseStorage"):quit(2);return
	var input:={"manual":{},"scope":null,"profile":false};var rows: Array=[];var errors: Array=[]
	for enhanced in [false,true]:
		var cases: Array=[]
		for mode in 3:
			var row:=make_case(enhanced,mode);cases.append(row)
			if not row.error.is_empty():errors.append(row.error)
			for index in 200:row.context.call("dispatch",2,input)
		for order in [[0,1,2],[2,0,1],[1,2,0]]:
			for mode in order:
				var row: Dictionary=cases[mode];var result: Dictionary={};var began:=Time.get_ticks_usec()
				for index in 1000:result=row.context.call("dispatch",2,input)
				var elapsed:=Time.get_ticks_usec()-began
				if result.has("error"):errors.append(result.error)
				rows.append({"enhanced":enhanced,"mode":["ordinary","enrolled-one","enrolled-half"][mode],"iterations":1000,"elapsed_us":elapsed,"us_per_publication":float(elapsed)/1000.0,"alpha":row.mesh.material_override.albedo_color.a})
		for row in cases:
			if row.owner!=null:row.owner.close()
			row.context.call("dispatch",8,{});row.pose.close();row.node.free()
	var directory:=OS.get_environment("NWN_PARITY_UI_TEST_DIR");var file:=FileAccess.open(directory.path_join("cost.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":errors.is_empty(),"rows":rows,"errors":errors,"part_count":1,"materials_per_part":1,"native_storage":true,"GPU":false,"performanceClaim":"CPU per-Part setter/publication overhead only; headless dummy renderer, no frame or FPS acceptance","source_unchanged_required":true},"  ")+"\n");file.close()
	print("NATIVE_PARITY_ACTOR_ALPHA_COST ",rows.size()," checks ",errors.size()," failures")
	quit(0 if errors.is_empty() else 1)
