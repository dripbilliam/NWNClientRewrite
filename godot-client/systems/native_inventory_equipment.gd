extends Node
# Original INV_EQUIP GUI/model attachment owner. Existing inventory view IDs,
# item commands, membership and drag/drop remain server-authoritative.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Layout=preload("res://systems/native_data/inventory_equipment_layout.gd")
var inventory
var assets
var art
var jobs: Dictionary={}
var root: Dictionary={}
var models: Dictionary={}
var definition: Dictionary={}
var background: Control
var layout_ready:=false
var closed:=false
var failure:=""
var requests:=0
func configure(owner,catalog,cache_path: String) -> void:
	inventory=owner
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
	art=Art.new(); add_child(art); art.configure(catalog,cache_path)
	background=Control.new(); background.set_meta("native_inventory_art",true); background.mouse_filter=Control.MOUSE_FILTER_IGNORE; inventory.equipment.add_child(background)
	jobs[assets.request("inv_equip",2047,"gff") ]="@layout"
func fail(reason: String) -> void:
	if failure.is_empty(): failure=reason
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name:=str(jobs[id]); jobs.erase(id)
	if not str(result.get("error","")).is_empty(): fail(str(result.error)); return
	if name=="@layout":
		root=result.value.root
		var wanted: Dictionary={}
		for child in root.get("Obj_ChildList",[]):
			var model:=str(child.get("Obj_ResRef","")).to_lower()
			if not model.is_empty(): wanted[model]=true
		for model in wanted:
			var job: int=assets.request(model,2002,"mdl-original")
			if job<0: fail(assets.failure); return
			jobs[job]=model
	else: models[name]=result.value
	if not jobs.is_empty() or not failure.is_empty(): return
	definition=Layout.parse(root,models)
	if not str(definition.error).is_empty(): fail(str(definition.error)); return
	layout_ready=true; build_frames()
	if not inventory.state.is_empty(): inventory.render()
func origin() -> Vector2: return -definition.bounds.position if layout_ready else Vector2.ZERO
func build_frames() -> void:
	for entry in definition.slots:
		var image:=TextureRect.new(); image.mouse_filter=Control.MOUSE_FILTER_IGNORE; image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_SCALE
		image.position=entry.rect.position+origin(); image.size=entry.rect.size; background.add_child(image)
		art.bind(image,str(entry.resource),"texture",true,"")
	background.move_to_front() # New slot controls will be above this artwork.
func rows(creature_slots: bool) -> Array:
	var result: Array=[]
	if not layout_ready: return result
	for entry in definition.slots:
		var rect: Rect2=entry.rect; rect.position+=origin()
		result.append({"slot":entry.slot,"x":rect.position.x,"y":rect.position.y,"w":rect.size.x,"h":rect.size.y,"label":entry.label,"native":entry})
	if creature_slots:
		for index in 4: result.append({"slot":1<<(14+index),"x":index*definition.bounds.size.x/4,"y":definition.bounds.size.y,"w":definition.bounds.size.x/4,"h":80,"label":"Creature equipment"})
	return result
func apply_label() -> void:
	if not layout_ready or not definition.labels.has("armorclasslabel"): return
	var rect: Rect2=definition.labels.armorclasslabel.rect
	inventory.ac.position=rect.position+origin(); inventory.ac.size=rect.size; inventory.ac.add_theme_font_size_override("font_size",14)
	if inventory.native_frame!=null: inventory.native_frame.font_style(inventory.ac,definition.labels.armorclasslabel.caption)
func bind_slot(button,entry: Dictionary) -> void:
	if not layout_ready or not entry.has("native"): return
	var source: Dictionary=entry.native
	button.native_icon_center=source.icon+origin()-button.position
	button.add_theme_stylebox_override("normal",StyleBoxEmpty.new()); button.add_theme_stylebox_override("pressed",StyleBoxEmpty.new())
	var hover:=StyleBoxFlat.new(); hover.bg_color=Color(0,0,0,0); hover.border_color=Color("b6a16a"); hover.set_border_width_all(1); button.add_theme_stylebox_override("hover",hover)
	button.caption.hide(); button.refresh_icon()
	if button.row.is_empty():
		button.image.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		button.image.size=Vector2(int(source.width)*32,int(source.height)*32)
		button.image.position=button.native_icon_center-button.image.size*0.5
		art.bind(button.image,"gui_icon_%dx%dl"%[source.width,source.height],"texture",true,"",false,{"gui_replace01":str(source.empty)})
	requests+=1
func snapshot() -> Dictionary:
	return {"ready":layout_ready,"failure":failure,"slots":definition.get("slots",[]).size(),"bindings":requests,"art_errors":art.failed.keys() if art!=null else [],"models":models.keys(),"scope":"Original INV_EQUIP positions, box meshes, private icon anchors and empty-slot art; main inventory/container/store framing and exact native hover/count/tooltip parity remain pending"}
func close() -> void:
	if closed: return
	closed=true; layout_ready=false
	if is_instance_valid(assets): assets.close()
	if is_instance_valid(art): art.close()
	jobs.clear(); models.clear(); inventory=null
func _exit_tree() -> void: close()
