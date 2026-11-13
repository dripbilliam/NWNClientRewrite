extends RefCounted
# Native TileData+c4/c8 presentation, separate from exploration and Part alpha.
# Existing area/draw owners supply scope and collected tile IDs. This owner
# creates no timer, geometry, material clone, visibility/room rule or map store.
const MAX_TILES:=65536
const PARAMETER:="nwn_tile_fog_factor"
var _world: WeakRef
var _guard: Callable
var _batch: Callable
var _scope: Array=[]
var _closed:=true
var _fogged:=PackedByteArray()
var _factors:=PackedFloat32Array()
var _visuals: Dictionary={}
var _issues: Array=[]
var _revision:=0
var stats:={"fog_updates":0,"collected":0,"factor_changes":0,"mesh_writes":0,"batch_writes":0,"adoptions":0,"unavailable":0,"stale":0}

static func f(value: float) -> float:return Color(value,0,0,0).r
static func integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high and float(value)==floor(float(value))

# Recovered RenderDrawBucket0cd210 math. Raw native fog RGB is scaled before
# its existing color-space transfer. Native ordered comparison skips NaN.
static func packet(scene: Variant,factor: float) -> Dictionary:
	if not scene is Array or scene.size()!=8:return {"available":false,"reason":"native-scene-fog-packet-unavailable"}
	for value in scene:
		if not (value is int or value is float) or not is_finite(float(value)):return {"available":false,"reason":"native-scene-fog-packet-unavailable"}
	var size:=f(factor)
	if not size<1.0:return {"available":true,"forced":false,"packet":scene.duplicate(),"factor":size}
	var square:=f(size*size)
	var begin:=f(f(float(scene[4]))*size)
	var end:=f(f(f(float(scene[5]))*size)+f(0.1))
	var extent:=f(end-begin)
	if extent==0.0:return {"available":false,"reason":"native-fog-reciprocal-nonfinite","forced":true,"factor":size,"begin":begin,"end":end}
	var value: Array=[f(square*f(float(scene[0]))),f(square*f(float(scene[1]))),f(square*f(float(scene[2]))),0.0,begin,end,f(1.0/extent),3.0]
	return {"available":true,"forced":true,"packet":value,"factor":size}

func _issue(reason: String,index: int=-1) -> Dictionary:
	stats.unavailable+=1
	if _issues.size()<32:_issues.append({"reason":reason,"tile":index})
	return {"available":false,"accepted":false,"reason":reason}

# Initialization stage is explicit. Constructor088130 gives c4=0/c8=1.
# After area-loader850120(map=0), flags&3 also invoke fog(true), resettingc8.
func configure(world: Node,scope: Array,count: int,stage: String,area_flags: Variant,guard: Callable,batch_publish: Callable=Callable()) -> Dictionary:
	if not _closed:return _issue("tile-fog-already-configured")
	if not is_instance_valid(world) or scope.is_empty() or count<1 or count>MAX_TILES or stage not in ["constructor","post-area-loader"] or not integer(area_flags,-2147483648,4294967295) or not guard.is_valid():return _issue("tile-fog-configuration-unavailable")
	_world=weakref(world);_scope=scope.duplicate(true);_guard=guard;_batch=batch_publish;_closed=false;_revision+=1
	_fogged.resize(count);_factors.resize(count)
	var fogged: bool=stage=="post-area-loader" and (int(area_flags)&3)!=0
	_fogged.fill(1 if fogged else 0);_factors.fill(0.0 if fogged else 1.0)
	# Batched meshes may publish before the next raw reveal event. Retain exact
	# constructor/loader factors in their existing sparse batch owner now.
	if _batch.is_valid():
		for index in count:
			if not _publish(index).available:return _issue("tile-fog-initial-batch-publication-unavailable",index)
	return {"available":true,"accepted":true,"stage":stage,"initial_fogged":fogged,"initial_factor":0.0 if fogged else 1.0}

func _current() -> bool:
	var world: Node=_world.get_ref() if _world!=null else null
	if _closed or not is_instance_valid(world) or world.is_queued_for_deletion() or not _guard.is_valid():return false
	var accepted: Variant=_guard.call(_scope.duplicate(true))
	return accepted==true and not _closed and _world!=null and _world.get_ref()==world

func _valid(index: int) -> bool:return index>=0 and index<_factors.size()

func _material_supported(mesh: MeshInstance3D) -> bool:
	var material: Material=mesh.material_override
	return material is ShaderMaterial and material.get_meta("native_surface_output",false)==true and material.shader!=null and material.shader.code.contains("nwn_tile_fog_factor")

func _visual_current(index: int,record: Dictionary) -> Node3D:
	var instance: Node3D=record.instance.get_ref()
	if not is_instance_valid(instance) or instance.get_instance_id()!=record.id or instance.is_queued_for_deletion() or not instance.is_inside_tree() or instance.get("retired")==true:return null
	var world: Node=_world.get_ref()
	var terrain: Variant=world.get("terrain")
	if not is_instance_valid(terrain) or not terrain.get("instances") is Dictionary or terrain.get("instances").get(index)!=instance:return null
	return instance

func _publish(index: int) -> Dictionary:
	if not _current() or not _valid(index):return _issue("tile-fog-scope-unavailable",index)
	var epoch:=_revision
	if _batch.is_valid():
		var accepted: Variant=_batch.call(index,float(_factors[index]))
		if not _current() or _revision!=epoch:return _issue("tile-fog-scope-changed-during-batch",index)
		if accepted==true:stats.batch_writes+=1;return {"available":true,"accepted":true,"route":"native-batched-tile-custom-data"}
		if not _visuals.has(index):return _issue("tile-fog-batch-publication-unavailable",index)
	if not _visuals.has(index):return {"available":true,"accepted":false,"pending":true,"reason":"tile-visual-not-published"}
	var record: Dictionary=_visuals[index]
	var instance:=_visual_current(index,record)
	if instance==null:stats.stale+=1;return _issue("tile-visual-retired",index)
	for endpoint in record.meshes:
		var mesh: MeshInstance3D=endpoint.reference.get_ref()
		var material: Material=endpoint.material.get_ref()
		if not is_instance_valid(mesh) or mesh.get_instance_id()!=endpoint.id or mesh.is_queued_for_deletion() or not is_instance_valid(material) or material.get_instance_id()!=endpoint.material_id or mesh.material_override!=material:return _issue("tile-fog-shader-endpoint-unavailable",index)
	for endpoint in record.meshes:
		if not _current() or _revision!=epoch or _visual_current(index,record)!=instance:return _issue("tile-fog-visual-changed-during-publication",index)
		var mesh: MeshInstance3D=endpoint.reference.get_ref()
		mesh.set_instance_shader_parameter(PARAMETER,float(_factors[index]));stats.mesh_writes+=1
	return {"available":true,"accepted":true,"route":"native-tile-instance-uniform","meshes":record.meshes.size()}

# Cold area-stream tile_published boundary only. Immutable materials/geometry,
# Part alpha, shadows, lights and collision remain with their existing owners.
func model_ready(index: int,instance: Node3D) -> Dictionary:
	if not _current() or not _valid(index) or not is_instance_valid(instance):return _issue("tile-model-scope-unavailable",index)
	var meshes: Variant=instance.get("meshes")
	if not meshes is Array:return _issue("tile-mesh-owner-unavailable",index)
	var endpoints: Array=[]
	for mesh in meshes:
		if not mesh is MeshInstance3D or not _material_supported(mesh):return _issue("tile-native-fog-shader-unavailable",index)
		endpoints.append({"reference":weakref(mesh),"id":mesh.get_instance_id(),"material":weakref(mesh.material_override),"material_id":mesh.material_override.get_instance_id()})
	_visuals[index]={"instance":weakref(instance),"id":instance.get_instance_id(),"meshes":endpoints};_revision+=1;stats.adoptions+=1
	return _publish(index)

# Actual AuroraSetTileFoggedByWar always stores the flag. True resets factor0
# even if already true; upstream850120 owns its own same-map-state early-out.
func receive(event: Dictionary) -> bool:
	var index: Variant=event.get("tile_index")
	var flag: Variant=event.get("fogged")
	if not integer(index,0,_factors.size()-1) or not flag is bool or not _current():_issue("tile-fog-event-unavailable");return false
	index=int(index);_fogged[index]=int(flag);stats.fog_updates+=1
	if flag:_factors[index]=0.0;stats.factor_changes+=1
	_revision+=1
	return _publish(index).available

# Existing native draw/cull owner supplies only collected tiles and its DeltaT.
# No timer, all-world scan, camera heuristic or immediate hidden-room ramp.
func advance_collected(indices: Array,delta: float) -> Dictionary:
	if not _current() or not is_finite(delta):return _issue("native-collected-tile-time-unavailable")
	var step:=f(f(delta)*4.0)
	var changed: Array=[];var changed_members: Dictionary={}
	for value in indices:
		if not integer(value,0,_factors.size()-1):return _issue("native-collected-tile-index-unavailable")
	for value in indices:
		var index:=int(value)
		stats.collected+=1
		if _factors[index]<1.0 and _fogged[index]==0:
			var next:=f(float(_factors[index])+step)
			_factors[index]=1.0 if next>1.0 else next
			if not changed_members.has(index):changed.append(index);changed_members[index]=true
			stats.factor_changes+=1
	if not changed.is_empty():_revision+=1
	for index in changed:
		if not _publish(index).available:return _issue("native-collected-tile-publication-unavailable",index)
	return {"available":_current(),"changed":changed.size(),"collected":indices.size()}

func snapshot() -> Dictionary:
	return {"closed":_closed,"scope":_scope.duplicate(true),"count":_factors.size(),"fogged":_fogged.duplicate(),"factors":_factors.duplicate(),"visuals":_visuals.size(),"stats":stats.duplicate(),"issues":_issues.duplicate(true),"native_owner":"TileData+c4/c8 fog, never Part alpha or room visibility"}

func close() -> void:
	if _closed:return
	_closed=true;_revision+=1;_world=null;_guard=Callable();_batch=Callable();_scope.clear();_fogged.clear();_factors.clear();_visuals.clear()
