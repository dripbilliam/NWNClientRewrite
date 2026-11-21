extends RefCounted
const Graph=preload("res://systems/native_render/reference_graph.gd")
var placement
var root_node: Node3D
var reference_rows: Array=[]
var pending: Array=[]
var part_slots: Array=[]
var phase:="nodes"
var index:=0
var graph
var status:="pending"
var failure:=""
func configure(root: Node3D,target,model_name: String,limitations: Array,references: Array,proof: Dictionary,clone_index: Dictionary={})->void:
	root_node=root;placement=target;reference_rows=references
	placement.set_meta("native_model_name",model_name);placement.static_draw_proof=proof;placement.limitations=limitations.duplicate();placement.add_child(root)
	if root.has_meta("native_scene_bounds"):placement.set_meta("native_scene_bounds",root.get_meta("native_scene_bounds"))
	if clone_index.is_empty():
		var children:=root.get_children()
		for child in range(children.size()-1,-1,-1):pending.append(children[child])
	else:
		# The recipe creator already visited these same nodes in depth-first
		# order. Continue with the original sorted-part and reference phases.
		placement.meshes=clone_index.meshes;part_slots=clone_index.part_slots
		failure=str(clone_index.failure);phase="parts"
func step(maximum_nodes: int=8,budget_us: int=1500)->Dictionary:
	if status!="pending":return {"status":status,"reason":failure,"units":0}
	if not failure.is_empty():cancel();status="failed";return {"status":status,"reason":failure,"units":0}
	var began:=Time.get_ticks_usec();var units:=0
	while units<maxi(1,maximum_nodes):
		if units>0 and budget_us>0 and Time.get_ticks_usec()-began>=budget_us:break
		if phase=="nodes":
			if pending.is_empty():phase="parts";index=0;continue
			var node: Node=pending.pop_back()
			if node is Node3D and str(node.name).match("part_*"):
				var part:=int(node.get_meta("native_part_index"))
				if part<0 or part>=65536:failure="Native placement physical part index is unavailable";cancel();status="failed";break
				if part_slots.size()<=part:part_slots.resize(part+1)
				part_slots[part]=node
			if node is MeshInstance3D:placement.meshes.append(node)
			var children:=node.get_children()
			for child in range(children.size()-1,-1,-1):pending.append(children[child])
			units+=1
		elif phase=="parts":
			if index>=part_slots.size():phase="references";continue
			var part=part_slots[index];index+=1
			if part!=null:
				placement.parts.append(part)
				if not part is MeshInstance3D and part.has_meta("native_pick_geometry"):placement.pick_surfaces.append(part)
			units+=1
		elif phase=="references":
			if reference_rows.is_empty():status="ready";break
			if graph==null:
				graph=Graph.new()
				if not graph.begin_configure(placement,reference_rows,placement.parts):failure=graph.failure;cancel();status="failed";break
			var result: Dictionary=graph.configure_step(maxi(1,maximum_nodes-units),maxi(1,budget_us-(Time.get_ticks_usec()-began)) if budget_us>0 else 0);units+=int(result.units)
			if result.status=="pending":break
			if result.status=="failed":failure=str(result.reason);cancel();status="failed";break
			placement.reference_graph=graph;status="ready";break
	return {"status":status,"reason":failure,"units":units}
func take():
	if status!="ready":return null
	var result=placement;placement=null;root_node=null;status="taken";pending.clear();part_slots.clear();return result
func cancel()->void:
	if graph!=null:graph.cancel_configure();graph=null
	if is_instance_valid(placement):placement.free()
	placement=null;root_node=null;pending.clear();part_slots.clear();status="cancelled"
func _notification(what: int)->void:
	if what!=NOTIFICATION_PREDELETE:return
	# Inline ownership release: RefCounted self-method dispatch is unavailable
	# during script teardown. A taken placement is no longer ours to release.
	if is_instance_valid(placement):placement.free()
	placement=null;root_node=null
