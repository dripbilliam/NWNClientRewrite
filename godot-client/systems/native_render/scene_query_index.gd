extends RefCounted
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
const Query=preload("res://systems/native_render/projectile_scene.gd")
# Conservative broad phase for published, fixed tile roots. Physical Parts and
# exact original polygon/normal tests still use their current scene transforms.
var cells: Dictionary={}
var entries: Dictionary={}
var global_entries: Dictionary={}
var cell_candidates: Dictionary={}
var native_owner: RefCounted
var native_count:=0
var native_attempted:=false
var native_failure:=""
var native_queries_enabled:=true # Diagnostic A/B; no effect on membership.
var cell_size:=10.0
var maximum_cells:=1024
var serial:=0
var stats:={"queries":0,"candidates":0,"all_candidates":0,"fallback_queries":0,"single_cell_queries":0,"cell_cache_hits":0}
func limits(box: AABB) -> Array:
	return [floori(box.position.x/cell_size),floori(box.position.z/cell_size),floori(box.end.x/cell_size),floori(box.end.z/cell_size)]
func put(node: Node3D) -> void:
	cell_candidates.clear()
	var id:=node.get_instance_id(); var order:=serial
	if entries.has(id): order=int(entries[id].order); erase(id)
	else: serial+=1
	var entry:={"node":weakref(node),"order":order,"cells":[],"pose":node.global_transform}; entries[id]=entry
	put_native(node)
	if not node.has_meta("native_scene_bounds"): global_entries[id]=true; return
	var box: AABB=node.global_transform*node.get_meta("native_scene_bounds")
	if not box.position.is_finite() or not box.end.is_finite(): global_entries[id]=true; return
	box=box.grow(maxf(1.0,maxf(box.position.abs().length(),box.end.abs().length()))*0.000003814697265625)
	entry.bounds=box
	var b:=limits(box)
	if (int(b[2])-int(b[0])+1)*(int(b[3])-int(b[1])+1)>maximum_cells: global_entries[id]=true; return
	for x in range(b[0],b[2]+1):
		for z in range(b[1],b[3]+1):
			var key:=Vector2i(x,z)
			if not cells.has(key): cells[key]=[]
			cells[key].append(id); entry.cells.append(key)
func erase(id: int) -> void:
	if not entries.has(id): return
	if entries[id].get("native",false):
		native_owner.call("dispatch",2,{"node":id}); native_count-=1
	cell_candidates.clear()
	for key in entries[id].cells:
		cells[key].erase(id)
		if cells[key].is_empty(): cells.erase(key)
	global_entries.erase(id); entries.erase(id)
func query(start: Vector3,end: Vector3) -> Array:
	stats.queries+=1; stats.all_candidates+=entries.size()
	var first:=Vector2i(floori(start.x/cell_size),floori(start.z/cell_size)); var last:=Vector2i(floori(end.x/cell_size),floori(end.z/cell_size))
	if first==last:
		stats.single_cell_queries+=1
		if cell_candidates.has(first): stats.cell_cache_hits+=1
		else:
			var ids: Array=cells.get(first,[]).duplicate(); ids.append_array(global_entries.keys())
			ids.sort_custom(func(a,b):return int(entries[a].order)<int(entries[b].order)); cell_candidates[first]=ids
		var nearby: Array=[]
		for id in cell_candidates[first]:
			if entries[id].has("bounds") and entries[id].bounds.intersects_segment(start,end)==null: continue
			var node: Object=entries[id].node.get_ref()
			if is_instance_valid(node) and not node.is_queued_for_deletion(): nearby.append(node)
		stats.candidates+=nearby.size(); return nearby
	var box:=AABB(start,Vector3.ZERO).expand(end); var b:=limits(box); var ids: Dictionary={}
	if (int(b[2])-int(b[0])+1)*(int(b[3])-int(b[1])+1)>maximum_cells:
		stats.fallback_queries+=1
		for id in entries: ids[id]=true
	else:
		for id in global_entries: ids[id]=true
		for x in range(b[0],b[2]+1):
			for z in range(b[1],b[3]+1):
				for id in cells.get(Vector2i(x,z),[]): ids[id]=true
	# Grid cells overlap at tile boundaries. Reject those coarse-cell neighbors
	# against their cached conservative fixed-root box before touching scene Parts.
	var selected: Array=[]
	for id in ids:
		if not entries[id].has("bounds") or entries[id].bounds.intersects_segment(start,end)!=null: selected.append(id)
	selected.sort_custom(func(a,b):return int(entries[a].order)<int(entries[b].order))
	var result: Array=[]
	for id in selected:
		var node: Object=entries[id].node.get_ref()
		if is_instance_valid(node) and not node.is_queued_for_deletion(): result.append(node)
	stats.candidates+=result.size(); return result
func snapshot() -> Dictionary:
	var result:=stats.duplicate(); result.entries=entries.size(); result.cells=cells.size(); result.global_entries=global_entries.size(); result.native=native_owner.call("dispatch",4,{}) if native_owner!=null else {}; result.native_failure=native_failure; return result
func put_native(node: Node3D) -> void:
	if not native_attempted:
		native_attempted=true
		if not OS.get_cmdline_user_args().has("--scene-index=gd") and Kernel.enabled() and Kernel.available() and ClassDB.class_exists("NwnSceneIndex"): native_owner=ClassDB.instantiate("NwnSceneIndex")
	if native_owner==null or not node.get("meshes") is Array: return
	var model: RefCounted=Query.prepare_model(node)
	if model==null: return
	var input:={"node":node.get_instance_id(),"model":model.call("dispatch",2,{}),"order":entries[node.get_instance_id()].order}
	if node.has_meta("native_scene_bounds"):
		var box: AABB=node.global_transform*node.get_meta("native_scene_bounds")
		if box.position.is_finite() and box.end.is_finite():
			input.exact=box; input.bounds=box.grow(maxf(1.0,maxf(box.position.abs().length(),box.end.abs().length()))*0.000003814697265625)
	var result: Variant=native_owner.call("dispatch",0,input)
	if result is Dictionary and result.has("error"): native_failure=str(result.error); return
	entries[node.get_instance_id()].native=true; native_count+=1
func native_ready() -> bool: return native_queries_enabled and native_owner!=null and native_failure.is_empty() and native_count==entries.size()
func nearest(start: Array,end: Array) -> Variant:
	var result: Variant=native_owner.call("dispatch",1,{"start":start,"end":end})
	if result is Dictionary and result.has("error"):
		native_failure=str(result.error); push_error(native_failure); return null
	return result
func clear() -> void:
	cells.clear(); entries.clear(); global_entries.clear(); cell_candidates.clear(); serial=0
	if native_owner!=null: native_owner.call("dispatch",3,{})
	native_count=0
