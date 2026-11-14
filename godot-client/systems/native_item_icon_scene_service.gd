extends Node
# Retained original GUI_ICON model and replacement-texture preparation for a
# shared 3D GUI scene. This owner never renders an icon into a bitmap.
# Callers choose "normal" or "small". Native flat and composite constructors
# both copy BASEITEMS.CanRotateIcon into the small-model R/S selector.
signal prepared(key: String,bundle: Dictionary,error: String)
const Plan=preload("res://systems/native_data/item_icon.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const GuiTextureInfo=preload("res://systems/native_data/gui_texture_info.gd")
var pool:=Pool.new()
var assets
var catalog
var bundles: Dictionary={}
var pending: Dictionary={}
var failed: Dictionary={}
var request_ids: Dictionary={}
var last_request_error: String=""
var closed:=true

func configure(source,cache_path: String) -> void:
	if not closed: close()
	closed=false; catalog=source; last_request_error=""
	pool=Pool.new(); pool.unshaded=true; pool.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	assets=Assets.new(); add_child(assets)
	assets.maximum_workers=4; assets.configure(catalog); assets.cache_directory=cache_path
	assets.completed.connect(_asset_ready)

func binding_scope() -> Array:
	# Mounts are immutable snapshots for asset workers. Include every ordered
	# binding identity so an NWSync/HAK/loose mount changes the public key.
	var scope: Array=[]
	if catalog==null: return scope
	for layer in catalog.layers:
		scope.append([str(layer.get("kind","")),int(layer.get("priority",0)),str(layer.get("binding_identity",""))])
	return scope

func resource_binding(name: String,type: int) -> Array:
	var found: Dictionary=catalog.location(name,type)
	if found.is_empty(): return [name.to_lower(),type,"absent"]
	var layer: Dictionary=found.layer; var entry: Dictionary=found.entry
	var identity: Array=[name.to_lower(),type,str(layer.get("binding_identity","")),entry]
	if str(layer.get("kind",""))=="loose":
		# A loose override can be edited without remounting its directory. The
		# selected entry's stat joins the mount identity, without reading pixels.
		var path:=str(entry.get("path",""))
		var file:=FileAccess.open(path,FileAccess.READ)
		identity.append([FileAccess.get_modified_time(path),file.get_length() if file!=null else -1])
		if file!=null: file.close()
	return identity

func source_bindings(selected: Dictionary,model_name: String) -> Array:
	# Include the exact winning resources, not just their ordered mounts. This
	# also distinguishes a replaced entry in a live mount with the same ID.
	var sources: Array=[resource_binding(model_name,2002)]
	var palettes: Dictionary={}
	for layer in selected.layers:
		var name:=str(layer.name); var type:=int(layer.type)
		if type==6:
			sources.append(resource_binding(name,6))
			for palette in ["pal_skin01","pal_hair01","pal_armor01","pal_armor02","pal_cloth01","pal_leath01","pal_tattoo01"]: palettes[palette]=true
		else:
			var raster: Dictionary=catalog.raster_location(name)
			sources.append(resource_binding(name,int(raster.type)) if not raster.is_empty() else [name,"raster-absent"])
		sources.append(resource_binding(name,2022))
	var names: Array=palettes.keys(); names.sort()
	for palette in names: sources.append(resource_binding(str(palette),3))
	return sources

static func presentation_model(selected: Dictionary,presentation: String) -> String:
	if presentation=="normal": return str(selected.model)
	if presentation not in ["small_r","small_s"]: return ""
	if str(selected.kind)=="armor": return "gui_icon_armr"+str(selected.layers.size())+"s"
	var stem:="gui_icon_%sx%s"%[int(selected.width),int(selected.height)]
	if str(selected.kind)=="composite": return stem+("rc" if presentation=="small_r" else "sc")
	return stem+("r" if presentation=="small_r" else "s")

static func small_presentation(item: Dictionary,tables: Dictionary,gender: int=0) -> String:
	var plan: Dictionary=Plan.new().plan(item,tables,gender)
	if plan.is_empty(): return ""
	return _small_presentation_for_plan(plan,item,tables)
static func _small_presentation_for_plan(plan: Dictionary,item: Dictionary,tables: Dictionary) -> String:
	match str(plan.kind):
		"armor": return "small_s"
		"layered": return "small_r" # Native layered constructor passes literal 10.
		"flat","composite":
			var base: Dictionary=Plan.row(tables,"baseitems",int(item.get("baseItem",-1)))
			return "small_r" if Plan.number(base.get("CanRotateIcon"),0)!=0 else "small_s"
	return ""

func request(item: Dictionary,tables: Dictionary,gender: int=0,presentation: String="normal") -> String:
	last_request_error=""
	if closed or catalog==null or assets==null:
		last_request_error="Original item icon scene service is unavailable"; return ""
	if presentation not in ["normal","small","small_r","small_s"]:
		last_request_error="Unsupported original item icon presentation: "+presentation; return ""
	var decoder:=Plan.new(); var plan: Dictionary=decoder.plan(item,tables,gender)
	if plan.is_empty(): last_request_error=decoder.failure; return ""
	var resolved_presentation:=presentation
	if presentation=="small":
		resolved_presentation=_small_presentation_for_plan(plan,item,tables)
		if resolved_presentation.is_empty():
			last_request_error="Original item small-icon R/S selector is unavailable"; return ""
	var selected: Dictionary=decoder.select(plan,catalog)
	if selected.is_empty(): last_request_error=decoder.failure; return ""
	if str(selected.kind)=="armor" and resolved_presentation in ["small_r","small_s"]: resolved_presentation="small_s"
	var model_name:=presentation_model(selected,resolved_presentation)
	if model_name.is_empty() or not catalog.has_resource(model_name,2002):
		last_request_error="Original item icon model is unavailable: "+model_name; return ""
	var scope:=binding_scope()
	var source_scope:=source_bindings(selected,model_name)
	var source_epoch: int=catalog.source_store.get_instance_id()
	var key:=Cache.digest(var_to_bytes(["native-item-icon-scene-v1",plan,selected,resolved_presentation,model_name,scope,source_scope,source_epoch]))
	if bundles.has(key) or pending.has(key): return key
	if failed.has(key): last_request_error=str(failed[key]); return key
	# Omit icon_descriptor: AssetService can reuse prepared model data, but must
	# never substitute a finished, readback-based icon pixel cache entry.
	var id: int=assets.request(model_name,2002,"gui-icon-v1",{"icon_layers":selected.layers,"gui_texture_info":GuiTextureInfo.REVISION})
	if id<0: last_request_error=assets.failure; return ""
	request_ids[id]={"key":key,"presentation":resolved_presentation,"requested_presentation":presentation,"model":model_name,"plan":plan,"selected":selected,"bindings":scope,"source_bindings":source_scope,"source_epoch":source_epoch}
	pending[key]=true
	return key

func _asset_ready(id: int,result: Dictionary) -> void:
	if closed or not request_ids.has(id): return
	var request_row: Dictionary=request_ids[id]; request_ids.erase(id)
	var key: String=request_row.key; pending.erase(key)
	var error:=str(result.get("error",""))
	if error.is_empty() and (not result.get("value") is Dictionary or not result.get("textures") is Dictionary):
		error="Original item icon model bundle is incomplete"
	if error.is_empty():
		var bundle: Dictionary=result.duplicate(false)
		bundle.icon_scene={"key":key,"presentation":request_row.presentation,"requested_presentation":request_row.requested_presentation,"model":request_row.model,"plan":request_row.plan,"selected":request_row.selected,"bindings":request_row.bindings,"source_bindings":request_row.source_bindings,"source_epoch":request_row.source_epoch}
		bundles[key]=bundle
		prepared.emit(key,bundle,"")
	else:
		failed[key]=error; prepared.emit(key,{},error)

func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(assets):
		assets.completed.disconnect(_asset_ready)
		assets.close(); assets.free()
	assets=null; request_ids.clear(); pending.clear(); bundles.clear(); failed.clear()
	pool.clear(); catalog=null

func _exit_tree() -> void: close()
