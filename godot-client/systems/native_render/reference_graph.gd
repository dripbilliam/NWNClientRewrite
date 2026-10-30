extends RefCounted
const State=preload("res://systems/model_reference_state.gd")
# Native physical graph adapter around the existing original-derived BFS owner.
# The caller supplies an already-resolved target Part, never a name/distance guess.
var owner: Node3D
var rows: Array=[]
var root_part: Dictionary={}
var failure:=""
func configure(source: Node3D,original: Array,parts: Array) -> bool:
	owner=source; rows.clear(); root_part={}; failure=""
	if original.size()!=parts.size(): failure="Native reference physical graph count mismatch"; return false
	for index in original.size():
		var reference=parts[index].get_node_or_null("native_reference")
		var row:={"object":parts[index],"name":str(original[index].name),"helper":reference,"model68":null,"header8":null,"children38":[]}
		if reference!=null: row.header8={"flags98":0x11,"reattachableE0":int(reference.original_header.get("reattachable",0))}
		rows.append(row)
		var parent:=int(original[index].parent)
		if parent>=index or parent< -1: failure="Native reference physical parent mismatch"; return false
		if parent<0:
			if not root_part.is_empty(): failure="Native reference model has multiple physical roots"; return false
			root_part=row
		else: rows[parent].children38.append(row)
	return not root_part.is_empty()
static func position(node: Node3D) -> Array:
	var p:=node.global_position; return [p.x,-p.z,p.y]
static func orientation(node: Node3D) -> Array:
	var q:=node.global_basis.orthonormalized().get_rotation_quaternion(); return [q.w,q.x,-q.z,q.y]
static func set_orientation(node: Node3D,q: Array) -> void:
	var scale_value:=node.global_basis.get_scale(); node.global_basis=Basis(Quaternion(q[1],q[3],-q[2],q[0])).scaled(scale_value)
func reference_view(row: Dictionary) -> Variant:
	if not is_instance_valid(row.helper): return null
	row.model68=row.helper.model68 if is_instance_valid(row.helper.model68) and not row.helper.model68.is_queued_for_deletion() else null
	return row
func attach(model: Node3D,target: Node3D,_part: String,_flags: int,external: bool) -> void:
	for row in rows:
		if is_instance_valid(row.helper) and row.helper.model68==model:
			if not row.helper.reattach_to(target if external else null): failure="Native reference target anchor is unavailable"
			return
	failure="Native reference attachment has no physical owner"
func reattach(target: Node3D) -> bool:
	failure=""
	if not is_instance_valid(owner) or root_part.is_empty(): failure="Native reference model owner unavailable"; return false
	State.reattach(owner,target,"",{"root":func(_model):return root_part,"asReference":reference_view,"name":func(part):return part.name,"attach":attach.bind(target!=null),"position":position,"orientation":orientation,"setOrientation":set_orientation})
	return failure.is_empty()
