# Per-input temporary geometry view. The ordinary query/authority path remains
# unrestricted. This class still owns all data; no second world registry exists.
var preview_revision:=0
var preview_revision_valid:=true
var preview_stats:={"collections":0,"reused_clears":0,"fallback_clears":0,"collection_failures":0}
func invalidate_preview_geometry()->void:
	if preview_revision==0x7fffffffffffffff:preview_revision_valid=false
	else:preview_revision+=1
func preview_geometry_current(ticket: Dictionary,id: int,witness: Array,revision: int,published: int,frame: int)->bool:
	return preview_revision_valid and preview_revision==revision and publication_revision==published and Engine.get_process_frames()==frame and ready() and spatial_ticket==ticket and source_rows.has(id) and source_rows[id].witness==witness
static func preview_inside(point: Vector3,minimum: Vector3,maximum: Vector3)->bool:
	return point.is_finite() and point.x>=minimum.x and point.x<=maximum.x and point.y>=minimum.y and point.y<=maximum.y
func query_preview(id: int,from: Vector3,target: Vector3,render: Vector3,radius_override: float=-1)->Callable:
	# Keep the exact original capture of dimensions/ticket/lifetime for fallback.
	var ordinary: Callable=query(id,radius_override)
	if not ordinary.is_valid() or not preview_revision_valid:return ordinary
	if not from.is_finite() or not target.is_finite() or not render.is_finite():return ordinary
	var dims:=dimensions(id);var radius:=dims.x if radius_override<0 else radius_override
	if not is_finite(radius) or radius<0:return ordinary
	var length:=preload("res://systems/network_motion.gd").length32(target-from)
	if not is_finite(length):return ordinary
	# Generous ordinary-input envelope. Correctness never relies on a normalizer
	# rounding bound: every actual endpoint is checked below, and escapes use the
	# unchanged unrestricted query. Z is intentionally not used for broadphase.
	var magnitude:=1.0
	for coordinate in [from.x,from.y,target.x,target.y,render.x,render.y]:magnitude=maxf(magnitude,absf(coordinate))
	var reach:=float(length)*2.0+magnitude*0.00001+0.0001
	if not is_finite(reach):return ordinary
	var minimum:=Vector3(minf(from.x,minf(target.x,render.x-reach)),minf(from.y,minf(target.y,render.y-reach)),0)
	var maximum:=Vector3(maxf(from.x,maxf(target.x,render.x+reach)),maxf(from.y,maxf(target.y,render.y+reach)),0)
	if not minimum.is_finite() or not maximum.is_finite():return ordinary
	# These are the actual float32 synthetic query endpoints. The containment
	# test uses precisely these bounds, including any outward/inward rounding.
	var ticket:=spatial_ticket.duplicate(true);var witness: Array=source_rows[id].witness.duplicate()
	var revision:=preview_revision;var published:=publication_revision;var frame:=Engine.get_process_frames()
	var began:=DriveProfile.begin();var geometry:=collect_preview_geometry(ticket,id,minimum,maximum,radius,radius_override<0)
	DriveProfile.finish("drive_preview_collection",began);DriveProfile.count("count_drive_preview_collections",1)
	preview_stats.collections+=1
	if not geometry.get("ready",false) or not preview_geometry_current(ticket,id,witness,revision,published,frame):
		preview_stats.collection_failures+=1;return ordinary
	return func(a: Vector3,b: Vector3):
		if not preview_geometry_current(ticket,id,witness,revision,published,frame) or not preview_inside(a,minimum,maximum) or not preview_inside(b,minimum,maximum):
			preview_stats.fallback_clears+=1;DriveProfile.count("count_drive_preview_fallback_clears",1)
			return ordinary.call(a,b)
		preview_stats.reused_clears+=1;DriveProfile.count("count_drive_preview_reused_clears",1)
		return clear(a,b,radius,dims.y if radius_override<0 else radius_override,geometry.obstacles,geometry.creatures,geometry.pending)
func collect_preview_geometry(ticket: Dictionary,id: int,minimum: Vector3,maximum: Vector3,radius: float,include_creatures: bool)->Dictionary:
	var candidates:=spatial.query_flat_control(ticket,minimum,maximum,radius,id,include_creatures) if retained_flat_control else spatial.query(ticket,minimum,maximum,radius,id,include_creatures)
	if not candidates.ready:return {"ready":false}
	var statics:=static_candidates(minimum,maximum,radius,id)
	if not statics.ready:return {"ready":false}
	candidates.rows.append_array(statics.rows)
	candidates.rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.order)<int(b.order))
	var obstacles: Array=[];var creatures: Array=[];var pending: Array=[]
	for selected in candidates.rows:
		var key:=int(selected.id)
		if not source_rows.has(key) or source_rows[key].witness!=selected.witness:return {"ready":false}
		var binding: Dictionary=source_rows[key]
		if selected.kind=="pending":pending.append(binding.point)
		elif selected.kind=="creature":creatures.append({"point":binding.point,"radius":float(binding.published_radius)+radius})
		else:
			var version:=int(model_versions.get(str(binding.model_key),0))
			if int(binding.get("precise_version",-1))!=version:objects.erase(key);binding.precise_version=version
			var shape:=obstacle(key,binding.object,binding.spec)
			if shape.get("pending",false):return {"ready":false}
			if not shape.is_empty() and not shape.triangles.is_empty():obstacles.append(shape)
	return {"ready":true,"obstacles":obstacles,"creatures":creatures,"pending":pending}
