extends Node
# Optional eager diagnostic for installed item/spell/effect raster images.
# Ordinary menu and server admission use exact visible art instead of this census.
signal texture_ready(name: String, texture: Texture2D)
signal completed(stats: Dictionary)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const SpellIcons=preload("res://systems/native_data/spellbook_icon_sources.gd")
const ItemIcons=preload("res://systems/native_data/item_icon_sources.gd")
const SharedRasters=preload("res://systems/native_data/shared_ui_rasters.gd")
const MAX_INFLIGHT:=24
var catalog
var ui_owner
var assets
var pool:=Pool.new()
var cache_directory: String=""
var explicit_names: Array=[]
var queue: Array=[]
var jobs: Dictionary={}
var selected: Dictionary={}
var total:=0
var completed_count:=0
var retained_count:=0
var reused_count:=0
var failed_count:=0
var missing_count:=0
var failure: String=""
var started:=false
var finished:=false
var closed:=false

func configure(source,cache_path: String,names: Array=[]) -> void:
	catalog=source; cache_directory=cache_path; explicit_names=names.duplicate()
	ui_owner=catalog.ui_asset_owner() if catalog!=null else null
	assets=Assets.new(); add_child(assets); assets.configure(catalog)
	assets.cache_directory=cache_path; assets.maximum_workers=3; assets.maximum_pending=MAX_INFLIGHT
	assets.completed.connect(prepared)

func item_references() -> Dictionary:
	var names: Dictionary={}
	for table_name in ["baseitems","iprp_spells","effecticons"]:
		var bytes: PackedByteArray=catalog.get_resource(table_name,2017)
		if bytes.is_empty(): continue
		var table: Dictionary=Table.new().parse(bytes.get_string_from_ascii())
		for row in table.get("orderedRows",[]):
			var name: String=str(row.get("DefaultIcon","")) if table_name=="baseitems" else str(row.get("Icon",""))
			if name not in ["","****"]: names[name.to_lower()]=true
	return names

func discover() -> Array:
	var names: Dictionary={}
	if not explicit_names.is_empty():
		for name in explicit_names: names[str(name).to_lower()]=true
	else:
		# Item/spell/effect/action raster families and explicit GUI symbol icons.
		# Menu panels/backgrounds use their existing exact art admission gates;
		# character portraits remain demand-loaded.
		for type in [2073,2033,2059,3]:
			for name in catalog.resource_names(type):
				var key: String=str(name).to_lower()
				if ItemIcons.ui_icon_family(key): names[key]=true
		for name in item_references(): names[str(name)]=true
		for name in SpellIcons.referenced(catalog): names[str(name)]=true
	var ordered: Array=names.keys(); ordered.sort(); return ordered

func start() -> void:
	if closed or started: return
	started=true
	if catalog==null or ui_owner==null or assets==null:
		failure="Native UI icon preloader has no catalog or resident owner"; failed_count=1; finish(); return
	var names: Array=discover(); total=names.size()
	for name in names:
		var resource: String=str(name)
		var source: Dictionary=catalog.raster_location(resource)
		if source.is_empty():
			# Original tables contain references with no installed raster. These
			# are inventory warnings, not failures to decode a present resource.
			missing_count+=1; completed_count+=1; continue
		selected[resource]=int(source.type)
		var shared: Dictionary=ui_owner.lookup("raster",resource)
		if not shared.is_empty():
			reused_count+=1; completed_count+=1; texture_ready.emit(resource,shared.texture); continue
		var process_texture: Texture2D=SharedRasters.lookup(catalog,resource)
		if process_texture!=null:
			ui_owner.retain("raster",resource,process_texture)
			reused_count+=1; completed_count+=1; texture_ready.emit(resource,process_texture); continue
		queue.append(resource)
	pump()
	if completed_count>=total: finish()

func pump() -> void:
	if closed or finished: return
	while not queue.is_empty() and jobs.size()<MAX_INFLIGHT:
		var name: String=queue.pop_front()
		var id: int=assets.request(name,int(selected[name]),"raster")
		if id<0:
			# A bounded local queue should not hit the service's admission limit.
			# Record a real failure rather than silently revealing partial icons.
			record_failure(name,str(assets.failure)); completed_count+=1
		else: jobs[id]=name

func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	var reason: String=str(result.get("error",""))
	if reason.is_empty():
		var texture: Texture2D=pool.texture(result)
		if texture==null: reason="Original raster texture could not be published: "+str(pool.failure)
		else:
			ui_owner.retain("raster",name,texture)
			retained_count+=1; texture_ready.emit(name,texture)
	if not reason.is_empty(): record_failure(name,reason)
	completed_count+=1
	pump()
	if completed_count>=total: finish()

func record_failure(name: String,reason: String) -> void:
	failed_count+=1
	if failure.is_empty(): failure=name+": "+reason
	if ui_owner!=null: ui_owner.note_failure("raster",name,reason)

func progress() -> Dictionary:
	return {"phase":"item-and-spell-icons","completed":completed_count,"total":total,"retained":retained_count,"reused":reused_count,"failed":failed_count,"missing":missing_count,"queued":queue.size(),"inflight":jobs.size(),"finished":finished}

func finish() -> void:
	if finished or closed: return
	finished=true; completed.emit(progress())

func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(assets): assets.close()
	queue.clear(); jobs.clear(); selected.clear(); pool.clear(); catalog=null; ui_owner=null

func _exit_tree() -> void: close()
