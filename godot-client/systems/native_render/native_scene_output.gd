extends Node
# Explicit full-world research switch. Normal/enhanced-only sessions retain the
# existing renderer. The coordinator waits for real area/admission state before
# binding the verified final tonal chain; it never fabricates missing resources.
const Post=preload("res://systems/native_render/native_postprocess.gd")
var selected: Dictionary={}
var world_ref: WeakRef
var area_ref: WeakRef
var gamma_ref: WeakRef
var configured:=false
var failed:=false
var error:=""
var waiting_frames:=0
func _init() -> void: process_priority=115; set_process(false)
static func options(args: Dictionary,history: bool) -> Dictionary:
	var value:=str(args.get("native-surface-output","false"))
	if value not in ["true","false"]: return {"error":"Invalid native surface-output research switch"}
	if value=="false": return {"enabled":false,"postprocess":{}}
	if args.get("native-lighting","")!="enhanced" or not history: return {"error":"Native surface output requires enhanced lighting and native light history"}
	var mask:=str(args.get("native-postprocess-mask","16"))
	if not mask.is_valid_int() or int(mask)<0 or (int(mask)&~28)!=0: return {"error":"Unsupported native postprocess stage mask"}
	var result:={"mask":int(mask)}
	for field in {"midpoint":.4,"intensity":0.0,"vibrance":0.0}:
		var raw:=str(args.get("native-postprocess-"+field,{"midpoint":.4,"intensity":0.0,"vibrance":0.0}[field]))
		if not raw.is_valid_float() or not is_finite(float(raw)) or not is_finite(Vector3(float(raw),0,0).x): return {"error":"Invalid native postprocess parameter: "+field}
		result[field]=float(raw)
	return {"enabled":true,"postprocess":result}
func bind(world: Node3D,area: Node,gamma: Node,settings: Dictionary) -> void:
	if gamma_ref!=null:
		var previous=gamma_ref.get_ref()
		if is_instance_valid(previous): previous.clear_postprocess()
	world_ref=weakref(world); area_ref=weakref(area); gamma_ref=weakref(gamma); selected=settings.duplicate(true)
	configured=false; failed=false; error=""; waiting_frames=0; set_process(bool(settings.get("enabled",false)))
func _process(_delta: float) -> void:
	var world=world_ref.get_ref() if world_ref!=null else null; var area=area_ref.get_ref() if area_ref!=null else null; var gamma=gamma_ref.get_ref() if gamma_ref!=null else null
	if not is_instance_valid(world) or world.closed or world.retiring or not is_instance_valid(area) or not is_instance_valid(gamma): set_process(false); return
	var input: Dictionary=Post.capture(world,area,gamma.camera)
	if input.has("error"): waiting_frames+=1; error=str(input.error); return
	# No repeated profile I/O while waiting for the first real admitted frame.
	configured=gamma.configure_postprocess(world,area,selected.postprocess)
	failed=not configured; error=gamma.post_error; set_process(false)
static func coverage(world: Node3D) -> Dictionary:
	var result:={"geometry":0,"materials":0,"native":0,"unsupported":[],"private_viewports":0,"scope":"Visible 3D materials in this world; UI/private viewports are separate. A supported contract is not proof of full original shader parity."}
	var queue: Array=[world]; var seen: Dictionary={}
	while not queue.is_empty():
		var node: Node=queue.pop_back()
		if node is SubViewport: result.private_viewports+=1; continue
		queue.append_array(node.get_children())
		if not node is GeometryInstance3D or not node.is_visible_in_tree(): continue
		result.geometry+=1
		var materials: Array=[]
		if node.material_override!=null: materials.append(node.material_override)
		else:
			var mesh: Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh!=null else null
			if mesh!=null:
				for index in mesh.get_surface_count(): materials.append(node.get_active_material(index) if node is MeshInstance3D else mesh.surface_get_material(index))
		if node.material_overlay!=null: materials.append(node.material_overlay)
		for material in materials:
			if material==null:
				result.materials+=1; result.unsupported.append({"node":str(world.get_path_to(node)),"class":"EngineDefaultMaterial","resource":""}); continue
			var steps:=0
			while material!=null and steps<32:
				steps+=1
				if not seen.has(material.get_instance_id()):
					seen[material.get_instance_id()]=true; result.materials+=1
					if material.get_meta("native_surface_output",false) or material.get_meta("native_invisible_pick",false): result.native+=1
					else: result.unsupported.append({"node":str(world.get_path_to(node)),"class":material.get_class(),"resource":material.resource_path})
				material=material.next_pass
			if material!=null: result.unsupported.append({"node":str(world.get_path_to(node)),"class":"UnboundedMaterialPassChain","resource":""})
	var particles=world.get("particle_stream_group")
	result.shared_particles={"present":is_instance_valid(particles),"native_surface_output":particles.native_surface_output if is_instance_valid(particles) else false,"failure":particles.failure if is_instance_valid(particles) else ""}
	return result
func snapshot() -> Dictionary:
	var world=world_ref.get_ref() if world_ref!=null else null
	return {"requested":selected.duplicate(true),"configured":configured,"failed":failed,"error":error,"waiting_frames":waiting_frames,"coverage":coverage(world) if is_instance_valid(world) else {},"full_parity":false}
