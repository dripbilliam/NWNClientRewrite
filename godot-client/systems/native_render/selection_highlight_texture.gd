extends Node
# One area-scoped texture request over the world's existing native asset queue.
# Does not create workers, mount providers, block readiness or synthesize art.
const Sampler=preload("res://systems/native_data/gui_texture_info.gd")
signal texture_prepared(texture: Texture2D,sampler: Dictionary)
var service: WeakRef
var pool: RefCounted
var jobs: Dictionary={}
var raster: Dictionary={}
var sampler: Dictionary={}
var closed:=false
var started:=false
var status:="unconfigured"
var failure:=""
var source_sha:=""
var txi_sha:=""
func configure(assets: Node,catalog,shared_pool: RefCounted) -> bool:
	if closed or started:return false
	started=true
	if not is_instance_valid(assets) or assets.closed or catalog==null or shared_pool==null:
		failure="Native highlight resource context unavailable";status="unavailable";return false
	var location: Dictionary=catalog.raster_location("fxpa_dot02")
	if location.is_empty():failure="Original highlight texture absent from active catalog";status="unavailable";return false
	service=weakref(assets);pool=shared_pool;sampler=Sampler.defaults()
	assets.completed.connect(_completed)
	var id: int=assets.request("fxpa_dot02",int(location.type),"raster")
	if id<0:failure=assets.failure;status="unavailable";_disconnect();return false
	jobs[id]="raster"
	if catalog.has_resource("fxpa_dot02",2022):
		id=assets.request("fxpa_dot02",2022,"bytes")
		if id<0:failure=assets.failure;status="unavailable";jobs.clear();_disconnect();return false
		jobs[id]="txi"
	status="loading";return true
func _completed(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id):return
	var kind: String=jobs[id];jobs.erase(id)
	if not str(result.get("error","")).is_empty():
		failure=str(result.error);status="unavailable";jobs.clear();raster.clear();_disconnect();return
	if kind=="raster":raster=result;source_sha=str(result.get("sha256",""))
	else:
		if not result.get("bytes") is PackedByteArray:
			failure="Native highlight TXI bytes unavailable";status="unavailable";jobs.clear();_disconnect();return
		sampler=Sampler.parse(result.bytes);txi_sha=str(result.get("sha256",""))
	if not jobs.is_empty():return
	var texture: Texture2D=pool.texture(raster)
	raster={};_disconnect()
	if texture==null:failure=pool.failure;status="unavailable";return
	status="ready";texture_prepared.emit(texture,sampler.duplicate(true))
func _disconnect() -> void:
	var owner: Node=service.get_ref() if service!=null else null
	if is_instance_valid(owner) and owner.completed.is_connected(_completed):owner.completed.disconnect(_completed)
func snapshot() -> Dictionary:
	return {"status":status,"failure":failure,"resref":"fxpa_dot02","source_sha256":source_sha,"txi_sha256":txi_sha,"pending":jobs.size(),"sampler":sampler.duplicate(true),"workers_created":0}
func close() -> void:
	if closed:return
	closed=true;_disconnect();jobs.clear();raster.clear();pool=null;service=null
func _exit_tree() -> void:close()
