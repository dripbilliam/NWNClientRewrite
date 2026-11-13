extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const TextureSource=preload("res://systems/native_render/selection_highlight_texture.gd")
var checks:=0
var failures: Array=[]
class MissingCatalog:
	extends RefCounted
	func raster_location(_name: String) -> Dictionary:return {}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var catalog:=Catalog.new()
	check(catalog.mount_install("C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall"),"Actual original provider mounts read-only")
	check(catalog.mount_directory("C:/Users/Niflheim/Documents/Neverwinter Nights.0/override",10000000),"Active user overrides participate in original texture binding")
	var service:=Assets.new();root.add_child(service);service.configure(catalog)
	var pool:=Pool.new();var source:=TextureSource.new();root.add_child(source)
	var events: Array=[];source.texture_prepared.connect(func(texture,sampler):events.append({"texture":texture,"sampler":sampler}))
	check(source.configure(service,catalog,pool) and source.jobs.size()==2,"Texture and TXI use the existing borrowed asset queue")
	var deadline:=Time.get_ticks_msec()+15000
	while source.status=="loading" and Time.get_ticks_msec()<deadline:await process_frame
	check(source.status=="ready" and source.failure.is_empty() and events.size()==1,"Actual worker completion publishes exactly one ready native texture")
	if not events.is_empty():
		check(events[0].texture.get_width()==32 and events[0].texture.get_height()==32 and source.source_sha=="4f3688a2e18273278988eb748a217b3316b59ab23bbec2dd3ac806b8acd7c8ec","Borrowed service retains selected original DDS identity")
		check(events[0].sampler.filter and events[0].sampler.mipmap and events[0].sampler.clamp==0,"Borrowed service reads native TXI sampling flags")
	check(not source.configure(service,catalog,pool),"An area owner cannot rebind a completed source to another catalog")
	check(not service.completed.is_connected(source._completed) and not service.closed,"Completed request releases only its subscription, preserving borrowed service")
	var missing:=TextureSource.new();root.add_child(missing)
	check(not missing.configure(service,MissingCatalog.new(),pool) and missing.status=="unavailable","Missing native resource remains unavailable without placeholder art")
	var retired:=TextureSource.new();root.add_child(retired);var stale: Array=[]
	retired.texture_prepared.connect(func(_texture,_sampler):stale.append(true))
	check(retired.configure(service,catalog,pool),"Second scoped source starts on the same shared native service")
	retired.close();deadline=Time.get_ticks_msec()+15000
	while not service.running.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(stale.is_empty() and retired.closed and not service.completed.is_connected(retired._completed),"Retired scope cannot publish late worker results or close borrowed service")
	check(not service.closed and source.snapshot().workers_created==0,"Texture source creates no worker owner or duplicate world resource store")
	source.close();source.free();retired.free();missing.free();service.close();service.free();pool.clear()
	await process_frame
	print("NATIVE_SELECTION_TEXTURE ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
