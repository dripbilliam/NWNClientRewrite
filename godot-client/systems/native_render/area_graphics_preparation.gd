extends RefCounted
# RendererModelPreparation.prepareArea retains independent materials for the
# current area's color, fade and shadow variants while requesting their GPU
# programs. Godot exposes material RIDs, but no compileAsync-equivalent
# completion result. This owner preserves the reached material/area lifetime
# and reports that narrower platform limit to its admission caller.
var generation := -1
var world_id := 0
var resource_world_id:=0
var resource_pool: WeakRef
var retired_resource_areas: Array=[]
var colors: Array[Material] = []
var fades: Array[Material] = []
var shadows: Array[Material] = []
var retired: Array[Material] = []
var models: Dictionary = {}
var failure := ""
var holds:=0
var program_lease
var profile_provider: Callable
var profile_scans:=0
var profile_us:=0
var cache_epoch:=-1
var area_profile:=""
var ready:=false

func bind_program_lease(value) -> void:
	program_lease=value
func bind_area_resource_pool(area: Node,pool: RefCounted) -> void:
	if not is_instance_valid(area) or pool==null:return
	resource_world_id=area.get_instance_id()
	resource_pool=weakref(pool)
func _retire_resource_area() -> void:
	if resource_world_id>0 and resource_pool!=null:
		retired_resource_areas.append({"world_id":resource_world_id,"pool":resource_pool})
	resource_world_id=0
	resource_pool=null
func read_profile() -> String:
	if not profile_provider.is_valid():return ""
	var began:=Time.get_ticks_usec()
	profile_scans+=1
	var profile: Variant=profile_provider.call()
	profile_us+=Time.get_ticks_usec()-began
	return JSON.stringify(profile)

func reset_programs() -> void:
	# RendererModelPreparation.resetPrograms closes the old session's cache
	# epoch. A later area/model prepare must no longer reuse that lease.
	if program_lease!=null and not program_lease.closed:program_lease.clear()

func _adopt_private_variants() -> void:
	if not ready or not failure.is_empty() or program_lease==null or program_lease.closed or cache_epoch!=program_lease.epoch:return
	for material in colors + fades + shadows:program_lease.adopt(material,cache_epoch)
func _adopt_model(record: Dictionary) -> void:
	if not bool(record.get("ready",false)) or program_lease==null or program_lease.closed or int(record.get("epoch",-1))!=program_lease.epoch:return
	for material in record.colors + record.fades + record.shadows:program_lease.adopt(material,int(record.epoch))

func begin() -> Callable:
	holds+=1
	var ended:=false
	return func():
		if ended:return
		ended=true
		holds=maxi(0,holds-1)
		if holds==0:flush()

func release_current() -> void:
	colors.clear()
	fades.clear()
	shadows.clear()
	ready=false
	cache_epoch=-1
	area_profile=""
	generation = -1
	world_id = 0
	failure = ""
func retire() -> void:
	# RendererResourceRetirement.retire defers disposal while a new area's
	# preparation hold is open. Keep these copied program owners through it.
	_adopt_private_variants()
	if holds>0:
		retired.append_array(colors)
		retired.append_array(fades)
		retired.append_array(shadows)
	# NetworkScene retains parsed asset preparation records until the entire
	# outgoing scene is disposed, including after individual actor replacement.
	for key in models.keys():release_model(str(key))
	_retire_resource_area()
	release_current()
	flush()
func flush() -> void:
	if holds!=0:return
	retired.clear()
	for row in retired_resource_areas:
		var pool: Variant=row.pool.get_ref()
		if pool!=null and pool.has_method("release_area_bindings"):pool.release_area_bindings(int(row.world_id))
	retired_resource_areas.clear()
func release() -> void:
	retire()
	holds=0
	flush()

func release_model(key: String) -> void:
	if not models.has(key):return
	var record: Dictionary=models[key]
	models.erase(key)
	_adopt_model(record)
	if holds>0:
		retired.append_array(record.colors)
		retired.append_array(record.fades)
		retired.append_array(record.shadows)

func prepare_model(root: Node3D,key: String,model_index: int=-1) -> Dictionary:
	if not is_instance_valid(root):return {"ready":false,"error":"Model preparation root is unavailable"}
	var current_epoch: int=int(program_lease.epoch) if program_lease!=null and not program_lease.closed else -1
	var current_profile:=read_profile()
	return _prepare_model_snapshot(root,key,model_index,current_epoch,current_profile)

func _prepare_model_snapshot(root: Node3D,key: String,model_index: int,current_epoch: int,current_profile: String) -> Dictionary:
	if models.has(key):
		var old: Dictionary=models[key]
		if bool(old.ready) and int(old.epoch)==current_epoch and str(old.profile)==current_profile:return {"ready":true}
		release_model(key)
	var record: Dictionary={"colors":[],"fades":[],"shadows":[],"epoch":current_epoch,"profile":current_profile,"ready":false}
	models[key]=record
	var prepared: Dictionary=_capture_variants(root,record.colors,record.fades,record.shadows,model_index)
	if prepared.has("error"):
		release_model(key)
		return prepared
	# Material.get_rid requests a Godot resource handle, not completion of
	# the GPU color/fade/depth/distance programs compiled by the old renderer.
	record.ready=true
	return {"ready":true}

func prepare_model_batch(entries: Array,current: Callable=Callable()) -> Dictionary:
	# The old batch reserves each source asset in first-seen order. Godot's
	# synchronous RID request has no compiler poll to serialize, but all members
	# must share one profile/cache epoch and become ready as a group.
	if current.is_valid() and not bool(current.call()):return {"ready":false}
	var ordered: Array=[]
	var seen: Dictionary={}
	for entry in entries:
		var key:=str(entry.get("key",""))
		if seen.has(key):continue
		seen[key]=true
		ordered.append(entry)
	if ordered.is_empty():return {"ready":true}
	var current_epoch: int=int(program_lease.epoch) if program_lease!=null and not program_lease.closed else -1
	var current_profile:=read_profile()
	var pending: Array[String]=[]
	for entry in ordered:
		var root: Node3D=entry.get("root")
		var key:=str(entry.get("key",""))
		if not is_instance_valid(root):
			for prepared_key in pending:release_model(prepared_key)
			return {"ready":false,"error":"Model preparation root is unavailable","failed_key":key}
		var was_ready:=models.has(key) and bool(models[key].ready) and int(models[key].epoch)==current_epoch and str(models[key].profile)==current_profile
		if was_ready:continue
		var record: Dictionary={"colors":[],"fades":[],"shadows":[],"epoch":current_epoch,"profile":current_profile,"ready":false}
		if models.has(key):release_model(key)
		models[key]=record
		pending.append(key)
		var prepared: Dictionary=_capture_variants(root,record.colors,record.fades,record.shadows,int(entry.get("model_index",-1)))
		if prepared.has("error"):
			for prepared_key in pending:release_model(prepared_key)
			return {"ready":false,"error":str(prepared.error),"failed_key":key}
	if current.is_valid() and not bool(current.call()):
		for key in pending:release_model(key)
		return {"ready":false}
	for key in pending:
		var record: Dictionary=models[key]
		record.ready=true
	return {"ready":true}

func _materials(node: GeometryInstance3D) -> Array[Material]:
	var result: Array[Material] = []
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			for surface in mesh_node.mesh.get_surface_count():
				var material := mesh_node.get_active_material(surface)
				if material != null: result.append(material)
	elif node is MultiMeshInstance3D:
		var multi := node as MultiMeshInstance3D
		if multi.multimesh != null and multi.multimesh.mesh != null:
			for surface in multi.multimesh.mesh.get_surface_count():
				var material: Material = multi.material_override if multi.material_override != null else multi.multimesh.mesh.surface_get_material(surface)
				if material != null: result.append(material)
	return result

func _capture_variants(root: Node3D, color_variants: Array, fade_variants: Array, shadow_variants: Array,model_index: int=-1) -> Dictionary:
	var seen: Dictionary={}
	var shadow_seen: Dictionary={}
	for candidate in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry:=candidate as GeometryInstance3D
		if geometry==null:continue
		if model_index>=0 and int(geometry.get_meta("native_source_model_index",-1))!=model_index:continue
		if model_index==-2 and geometry.has_meta("native_source_model_index"):continue
		for original in _materials(geometry):
			if geometry.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and not shadow_seen.has(original.get_instance_id()):
				shadow_seen[original.get_instance_id()]=true
				# The old shadowRoot owns separate depth and distance materials.
				# Godot does not expose those renderer-created shadow programs, so
				# these private source variants remain only resource owners.
				var depth:=original.duplicate(false) as Material
				var distance:=original.duplicate(false) as Material
				if depth==null or distance==null:return {"ready":false,"error":"Shadow material variant could not be copied"}
				shadow_variants.append(depth)
				shadow_variants.append(distance)
			if seen.has(original.get_instance_id()):continue
			seen[original.get_instance_id()]=true
			var color:=original.duplicate(false) as Material
			var fade:=original.duplicate(false) as Material
			if color==null or fade==null:return {"ready":false,"error":"Material variant could not be copied"}
			if fade is BaseMaterial3D:
				fade.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED if fade.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA else BaseMaterial3D.TRANSPARENCY_ALPHA
			elif fade.has_method("refresh_shader"):
				fade.set("transparency",BaseMaterial3D.TRANSPARENCY_DISABLED if int(fade.get("transparency"))==BaseMaterial3D.TRANSPARENCY_ALPHA else BaseMaterial3D.TRANSPARENCY_ALPHA)
			color_variants.append(color)
			fade_variants.append(fade)
	for material in color_variants + fade_variants + shadow_variants:
		if not material.get_rid().is_valid():return {"ready":false,"error":"Material variant returned an invalid RID"}
	return {"ready":true}

func prepare(area: Node3D, area_generation: int) -> Dictionary:
	if not is_instance_valid(area): return {"ready":false,"error":"Area graphics owner is unavailable"}
	var current_epoch: int=int(program_lease.epoch) if program_lease!=null and not program_lease.closed else -1
	var current_profile:=read_profile()
	if area_generation == generation and area.get_instance_id() == world_id and current_epoch==cache_epoch and current_profile==area_profile:
		if not failure.is_empty(): return {"ready":false,"error":failure}
		return {"ready":ready}
	_adopt_private_variants()
	release_current()
	generation = area_generation
	world_id = area.get_instance_id()
	cache_epoch=current_epoch
	area_profile=current_profile
	var prepared: Dictionary=_capture_variants(area,colors,fades,shadows)
	if prepared.has("error"):
		failure=str(prepared.error)
		return prepared
	ready=true
	return {"ready":true}

func snapshot() -> Dictionary:
	return {"activeTemplates":models.size(),"activeAreas":1 if world_id!=0 else 0,
		"holds":holds,"areaReady":ready,"failure":failure,
		"colorVariants":colors.size(),"fadeVariants":fades.size(),"shadowVariants":shadows.size(),
		"retiredVariants":retired.size(),"programCache":program_lease.snapshot() if program_lease!=null else null,
		"profileScans":profile_scans,"profileMs":profile_us/1000.0,"areaProfile":area_profile,
		"gpuCompileCompletionAvailable":false}
