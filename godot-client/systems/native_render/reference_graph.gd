extends RefCounted
const State=preload("res://systems/model_reference_state.gd")
# Native physical graph adapter around the existing original-derived BFS owner.
# The caller supplies an already-resolved target Part, never a name/distance guess.
var owner: Node3D
var rows: Array=[]
var root_part: Dictionary={}
var failure:=""
var _construction: Dictionary={}
func configure(source: Node3D,original: Array,parts: Array) -> bool:
	if not begin_configure(source,original,parts):return false
	while not _construction.is_empty():
		var progress:=configure_step(65536,0)
		if progress.status=="failed":return false
	return not root_part.is_empty()
func begin_configure(source: Node3D,original: Array,parts: Array,helper_overrides: Dictionary={}) -> bool:
	_construction={};owner=source;rows.clear();root_part={};failure=""
	if original.size()!=parts.size(): failure="Native reference physical graph count mismatch"; return false
	# modelParentIndices resolves the complete source graph before creating its
	# physical parts. A child can precede its parent; duplicate names resolve to
	# the last matching node when an explicit parentIndex is absent.
	var names: Dictionary={}
	for index in original.size():names[str(original[index].get("name",""))]=index
	var parents: Array=[]
	for index in original.size():
		var node: Dictionary=original[index]
		# Decoded ASCII Parts carry their physical index in parent. Binary
		# records can supply parentIndex or the original parent name.
		var explicit: Variant=node.get("parentIndex",node.get("parent"))
		var parent: int=int(explicit) if explicit is int or explicit is float and is_finite(explicit) and floorf(explicit)==explicit else (-1 if str(node.get("parent",""))=="NULL" else int(names.get(str(node.get("parent","")),-1)))
		if parent< -1 or parent>=original.size():failure="Native reference physical parent mismatch";return false
		parents.append(parent)
	var state: Array=[]
	state.resize(original.size());state.fill(0)
	for index in original.size():
		var pending: Array=[];var at:=index
		while at>=0 and int(state[at])!=2:
			if int(state[at])==1:failure="Native reference physical parent cycle";return false
			state[at]=1;pending.append(at);at=int(parents[at])
		for visited in pending:state[int(visited)]=2
	_construction={"original":original,"parts":parts,"helpers":helper_overrides,"parents":parents,"phase":"parts","index":0};return true
func configure_step(maximum_nodes: int=8,budget_us: int=1500)->Dictionary:
	if _construction.is_empty():return {"status":"ready" if not root_part.is_empty() else "failed","reason":failure,"units":0}
	var began:=Time.get_ticks_usec();var units:=0;var original: Array=_construction.original;var parts: Array=_construction.parts
	while not _construction.is_empty() and units<maxi(1,maximum_nodes):
		if units>0 and budget_us>0 and Time.get_ticks_usec()-began>=budget_us:break
		if int(_construction.index)>=original.size():
			if _construction.phase=="parts":_construction.phase="links";_construction.index=0;continue
			_construction={};return {"status":"ready" if not root_part.is_empty() else "failed","reason":failure,"units":units}
		var index:=int(_construction.index);_construction.index=index+1;units+=1
		if _construction.phase=="parts":
			if not is_instance_valid(parts[index]):failure="Native reference physical part "+str(index)+" is unavailable";_construction={};return {"status":"failed","reason":failure,"units":units}
			var reference=_construction.helpers.get(parts[index].get_instance_id()) if _construction.helpers.has(parts[index].get_instance_id()) else parts[index].get_node_or_null("native_reference")
			var node: Dictionary=original[index];var source_header: Variant=node.get("nativeNode");var source_reference: Variant=node.get("reference");var properties: Variant=node.get("properties")
			var flags: Variant=source_header.get("flags98") if source_header is Dictionary else null
			var model_name: Variant=source_reference.get("model") if source_reference is Dictionary else null
			var reattachable: Variant=source_reference.get("reattachable") if source_reference is Dictionary else null
			if model_name==null and properties is Dictionary:model_name=properties.get("refmodel")
			if reattachable==null and properties is Dictionary:reattachable=properties.get("reattachable")
			var header: Dictionary={"flags98":int(flags) if flags!=null else (0x11 if reference!=null else 1),"modelA0":model_name,"reattachableE0":reattachable}
			if str(node.get("type",""))=="reference" and (reference==null or (int(header.flags98)&0x11)!=0x11):failure="Native reference creation has no valid physical header";_construction={};return {"status":"failed","reason":failure,"units":units}
			rows.append({"object":parts[index],"node":node,"name":str(node.get("name","")),"helper":reference,"model68":null,"header8":header,"children38":[]})
			continue
		var parent:=int(_construction.parents[index])
		if parent<0:
			if not root_part.is_empty():failure="Native reference model has multiple physical roots";_construction={};return {"status":"failed","reason":failure,"units":units}
			root_part=rows[index]
		else: rows[parent].children38.append(rows[index])
	return {"status":"pending","units":units}
func cancel_configure()->void:
	_construction={};owner=null;rows.clear();root_part={}
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
func attach(model: Node3D,target: Node3D,_part: String,_flags: int,external: bool) -> bool:
	for row in rows:
		if is_instance_valid(row.helper) and row.helper.model68==model:
			if not row.helper.reattach_to(target if external else null): failure="Native reference target anchor is unavailable"; return false
			return true
	failure="Native reference attachment has no physical owner"
	return false
func reattach(target: Node3D) -> bool:
	failure=""
	if not is_instance_valid(owner) or root_part.is_empty(): failure="Native reference model owner unavailable"; return false
	if not State.reattach(owner,target,"",{"root":func(_model):return root_part,"asReference":reference_view,"name":func(part):return part.name,"attach":attach.bind(target!=null),"position":position,"orientation":orientation,"setOrientation":set_orientation}):return false
	return failure.is_empty()
