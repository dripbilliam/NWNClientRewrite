extends RefCounted
# Selection-only authored MDL bounds. Internal weak physical-Part references
# never leave this owner in snapshots; no Resource/Node is exposed by the API.
const Box=preload("res://tools/native_parity/doors/native_box_hit.gd")
var _owner: WeakRef
var _owner_id:=0
var _object_id:=-1
var _regions: Array=[]
var _missing: Array=[]
var _retired:=false
var _stats:={"queries":0,"part_checks":0,"hits":0,"inside_unresolved":0,"invalid_transforms":0}

static func native(point: Vector3) -> Vector3:return Vector3(point.x,-point.z,point.y)
static func engine(point: Vector3) -> Vector3:return Vector3(point.x,point.z,-point.y)
static func source_vector(value: Variant) -> Variant:
	if not value is Array or value.size()!=3:return null
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)):return null
	var point:=Vector3(value[0],value[1],value[2])
	return point if point.is_finite() else null

func configure(owner: Node3D,bundle: Dictionary,rigs,id: int) -> bool:
	if _retired or _owner!=null or not is_instance_valid(owner) or not is_instance_valid(rigs):return false
	_owner=weakref(owner);_owner_id=owner.get_instance_id();_object_id=id
	var nodes: Array=bundle.get("value",{}).get("nodes",[])
	var models: Array=rigs.entities.get(id,{}).get("models",[])
	if models.is_empty():_missing.append({"reason":"Original door physical model unavailable"});return false
	var model_parts: Array=rigs.entities.get(id,{}).get("model_parts",[])
	var parts: Array=model_parts[0] if not model_parts.is_empty() else []
	for index in nodes.size():
		var row: Dictionary=nodes[index];var data: Dictionary=row.get("mesh",{})
		if data.is_empty() or data.get("indices",PackedInt32Array()).is_empty():continue
		var bounds: Variant=data.get("native_bounds")
		if not data.get("native_bounds_available",false) or not data.get("native_bounds_valid",false) or not bounds is Dictionary:
			_missing.append({"part":index,"name":str(row.get("name","")),"reason":"Original authored/runtime MDL bounds unavailable","source":data.get("native_bounds_source")});continue
		var low: Variant=source_vector(bounds.get("min"));var high: Variant=source_vector(bounds.get("max"))
		if low==null or high==null or low.x>high.x or low.y>high.y or low.z>high.z:
			_missing.append({"part":index,"reason":"Invalid original MDL bounds"});continue
		var anchor: Node3D=rigs.node_at(id,int(parts[index])) if index<parts.size() else null
		if not is_instance_valid(anchor):_missing.append({"part":index,"reason":"Original physical Part unavailable"});continue
		# Authored render/alpha do not reject native box picking. Keep the actual
		# animated physical anchor; do not target a frozen closed-door pose.
		_regions.append({"anchor":weakref(anchor),"part":index,"name":str(row.get("name","")),"low":low,"high":high,"source":str(data.get("native_bounds_source",""))})
	return _missing.is_empty()

func pick(origin: Vector3,end: Vector3) -> Dictionary:
	_stats.queries+=1
	var owner: Node3D=_owner.get_ref() as Node3D if _owner!=null else null
	if _retired or not is_instance_valid(owner) or owner.get_instance_id()!=_owner_id or owner.is_queued_for_deletion() or not owner.is_inside_tree() or not owner.is_visible_in_tree() or owner.get("retired")==true:
		return {"available":false,"reason":"Door target lifetime unavailable"}
	if not origin.is_finite() or not end.is_finite():return {"available":false,"reason":"Invalid selection segment"}
	var best: Dictionary={};var limit:=end;var best_distance:=INF;var inside:=false
	for region in _regions:
		var anchor: Node3D=region.anchor.get_ref() as Node3D
		if not is_instance_valid(anchor) or not anchor.is_inside_tree() or anchor.is_queued_for_deletion():continue
		_stats.part_checks+=1
		var pose:=anchor.global_transform
		if not pose.origin.is_finite() or not is_finite(pose.basis.determinant()) or pose.basis.determinant()==0:
			_stats.invalid_transforms+=1;continue
		var inverse:=pose.affine_inverse()
		var hit:=Box.hit(native(inverse*origin),native(inverse*limit),region.low,region.high)
		if not hit.get("available",false):continue
		if int(hit.face)==-1:
			# BoxIntersect itself does not write an inside point. The outer native
			# caller's CHitInfo+78 behavior is still an explicit acceptance gap.
			inside=true;_stats.inside_unresolved+=1;continue
		if int(hit.face)<=0:continue
		var point: Vector3=pose*engine(hit.point)
		var distance:=origin.distance_squared_to(point)
		if not point.is_finite() or distance>=best_distance:continue
		limit=point;best_distance=distance
		best={"available":true,"hit":true,"position":point,"part":int(region.part),"face":int(hit.face),"object_id":_object_id}
	if inside:return {"available":false,"reason":"Native inside-hit caller semantics pending","candidate":best}
	if not best.is_empty():_stats.hits+=1;return best
	return {"available":true,"hit":false,"partial":not _missing.is_empty()}

func snapshot() -> Dictionary:
	var result: Dictionary=_stats.duplicate()
	result.merge({"object_id":_object_id,"owner_instance":_owner_id,"retired":_retired,"regions":_regions.size(),"missing":_missing.duplicate(true),"scope":"Authored Part bounds; zero native default expansion; selection only; unvalidated candidate"})
	return result

func retire() -> void:
	_retired=true;_owner=null;_regions.clear()
