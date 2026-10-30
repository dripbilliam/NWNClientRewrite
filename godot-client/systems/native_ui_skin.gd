extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Native resource ownership reusable by gameplay controls and the NUI renderer.
# The original skin, SFNT fonts and images prepare on bounded workers; GPU/font
# objects publish here on the main thread. No PNG/base64 or browser staging.
signal fonts_ready
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
var assets
var catalog
var pool:=Pool.new()
var skin: Dictionary={}
var fonts: Dictionary={}
var font_hashes: Dictionary={}
var images: Dictionary={}
var jobs: Dictionary={}
var waiting: Array=[]
var done:=false
var closed:=false
var announced:=false
var stats:={"fonts":0,"images":0,"cache_hits":0,"worker_threads":[],"worker_ms":0.0,"errors":[],"native_only":true,"full_ui_migration":false}
func configure(source,cache_path: String) -> void:
	catalog=source; assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(prepared)
	jobs[assets.request("nui_skin",2076,"nui-skin-v1")]={"kind":"skin","name":"nui_skin"}
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var job: Dictionary=jobs[id]; jobs.erase(id)
	stats.worker_ms+=float(result.worker_ms)
	if not stats.worker_threads.has(int(result.thread)): stats.worker_threads.append(int(result.thread))
	if result.cache_hit: stats.cache_hits+=1
	if not str(result.error).is_empty(): stats.errors.append({"resource":job.name,"reason":result.error}); return
	if job.kind=="skin":
		skin=result.value
		var selected: Dictionary={"fnt_default":true,"fnt_maintext":true}
		for spec in skin.fonts:
			if spec.get("resref") is String: selected[str(spec.resref)]=true
		for name in selected: waiting.append({"kind":"font","name":name,"type":2074,"decoder":"font-v1"})
		var image_names: Dictionary={}; var valid:=RegEx.new(); valid.compile("^[a-zA-Z0-9_]{1,32}$")
		for table in skin.tables.values():
			for value in table.values():
				if value is String and valid.search(value)!=null: image_names[value]=true
		for name in image_names:
			var location: Dictionary=catalog.raster_location(name)
			if location.is_empty(): stats.errors.append({"resource":name,"reason":"Original NUI skin image is unavailable"})
			else: waiting.append({"kind":"image","name":name,"type":int(location.type),"decoder":"raster"})
	elif job.kind=="font":
		var font: FontFile
		if font_hashes.has(str(result.sha256)): font=font_hashes[str(result.sha256)]
		else:
			font=FontFile.new(); font.data=result.value.data; font.multichannel_signed_distance_field=false; font.allow_system_fallback=false; font.generate_mipmaps=false
			font_hashes[str(result.sha256)]=font
		fonts[str(job.name)]=font; stats.fonts+=1
	else:
		var texture=pool.texture(result)
		if texture==null: stats.errors.append({"resource":job.name,"reason":pool.failure})
		else: images[str(job.name)]=texture; stats.images+=1
	if not announced and fonts.has("fnt_default") and fonts.has("fnt_maintext"): announced=true; fonts_ready.emit()
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_fonts",began)
func _profile_process(_delta: float) -> void:
	if closed or done: return
	while not waiting.is_empty() and assets.pending.size()+assets.running.size()<assets.maximum_pending:
		var job: Dictionary=waiting.pop_front(); var id: int=assets.request(str(job.name),int(job.type),str(job.decoder))
		if id<0: stats.errors.append({"resource":job.name,"reason":assets.failure})
		else: jobs[id]=job
	if waiting.is_empty() and jobs.is_empty(): done=true
func theme() -> Theme:
	var result:=Theme.new()
	if fonts.has("fnt_maintext"):
		result.default_font=fonts.fnt_maintext; result.default_font_size=17
		for name in ["normal_font","bold_font","italics_font","bold_italics_font","mono_font"]: result.set_font(name,"RichTextLabel",fonts.fnt_maintext)
	if fonts.has("fnt_default"):
		for kind in ["Button","OptionButton","PopupMenu"]: result.set_font("font",kind,fonts.get("fnt_maintext",fonts.fnt_default))
	return result
func install_nui(owner) -> bool:
	if not done or not stats.errors.is_empty(): return false
	owner.install_native_skin(skin,fonts,images); return true
func snapshot() -> Dictionary:
	var state:=stats.duplicate(true); state.merge({"done":done,"pending":waiting.size()+jobs.size(),"fonts_ready":announced,"scope":"Original native skin/font/image preparation; full NUI layout/input migration and visual acceptance pending"}); return state
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(assets): assets.close()
	fonts.clear(); font_hashes.clear(); images.clear(); waiting.clear(); jobs.clear(); skin.clear(); pool.clear(); catalog=null
func _exit_tree() -> void: close()
