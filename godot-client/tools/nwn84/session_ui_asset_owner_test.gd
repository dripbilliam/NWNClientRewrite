extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const ItemPlan=preload("res://systems/native_data/item_icon.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]

func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog=Catalog.new()
	catalog.layers=[{"binding_identity":"install-a","entries":{}}]
	catalog.build_resource_index()
	var early_fork=catalog.fork()
	var second_early_fork=catalog.fork()
	var owner=catalog.ui_asset_owner()
	check(early_fork.ui_asset_owner()==null and second_early_fork.ui_asset_owner()==null,"Payload forks made before first UI request cannot acquire the GPU owner")
	var fork=catalog.fork()
	check(fork.ui_asset_owner()==null,"Payload fork made after first UI request cannot retain GPU images")
	check(owner.snapshot().binding_identities==["install-a"],"Owner records ordered source binding identity")
	var image:=Image.create(8,8,false,Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var texture:=ImageTexture.create_from_image(image)
	var first:=Art.new(); root.add_child(first); first.configure(catalog,"")
	first.deliver("menu_raster",texture)
	var model_key:=Icons.model_key("gui_button","up")
	var bounds:={"origin":Vector2(1,2),"size":Vector2(8,8)}
	first.bounds[model_key]=bounds
	first.deliver(model_key,texture)
	first.close(); first.free()
	check(owner.lookup("raster","menu_raster").get("texture")==texture,"Raster texture survives first UI owner closing")
	check(owner.lookup("model",model_key).get("texture")==texture,"GUI model texture survives first UI owner closing")
	var second:=Art.new(); root.add_child(second); second.configure(catalog,"")
	var target:=TextureRect.new(); root.add_child(target)
	second.bind(target,"menu_raster")
	check(target.texture==texture and second.jobs.is_empty(),"Reopened raster binds the identical texture without a new asset job")
	second.bind(target,"gui_button","texture",true,"up")
	check(target.texture==texture and second.bounds.get(model_key)==bounds and second.models.pending.is_empty(),"Reopened GUI model reuses texture and exact bounds without render request")
	var alternate:=Icons.model_key("gui_button","up",{"palette":1})
	check(alternate!=model_key and owner.lookup("model",alternate).is_empty(),"Override variants cannot reuse another model image")
	var region:=Icons.model_key("gui_button","up",{},0,"",[],Rect2(1,2,3,4))
	check(region!=model_key and owner.lookup("model",region).is_empty(),"Render-region variants remain distinct")
	second.close(); second.free(); target.free()
	var icon_first:=Icons.new(); root.add_child(icon_first); icon_first.configure(catalog,"")
	var icon_key:=Icons.model_key("gui_icon","down",{},0,"",[["down",0]])
	icon_first.image_bounds[icon_key]=bounds
	icon_first.finish(icon_key,null,texture,"")
	icon_first.close(); icon_first.free()
	var icon_second:=Icons.new(); root.add_child(icon_second); icon_second.configure(catalog,"")
	var reused:=icon_second.request_model("gui_icon","down",{},0,"",[["down",0]])
	check(reused==icon_key and icon_second.textures.get(icon_key)==texture and icon_second.image_bounds.get(icon_key)==bounds,"Icon renderer reuses exact pose texture and bounds across owners")
	check(int(icon_second.stats.get("requested",0))==0 and int(icon_second.stats.get("shared_reused",0))==1,"Shared icon hit does no model request")
	var item:={"baseItem":0,"parts":[1]}
	var tables:={"baseitems":{"orderedRows":[{"InvSlotWidth":"1","InvSlotHeight":"1","ModelType":"0","ItemClass":"it","DefaultIcon":"****"}]}}
	var composite_key:=Cache.digest(var_to_bytes(ItemPlan.new().plan(item,tables)))
	owner.retain("item",composite_key,texture,bounds)
	check(icon_second.request(item,tables)==composite_key and icon_second.textures.get(composite_key)==texture,"Received item composite reuses exact planned texture before source selection")
	check(int(icon_second.stats.get("requested",0))==0,"Composite hit submits no item icon asset request")
	icon_second.close(); icon_second.free()
	var prebake:=Icons.new(); root.add_child(prebake); prebake.configure(catalog,""); prebake.assets.prework_write=true
	check(prebake.request_model("gui_icon","down",{},0,"",[["down",0]]).is_empty(),"Explicit disk prebake does not consume resident UI texture")
	var prebake_key:=Icons.model_key("prebake_only","up")
	prebake.finish(prebake_key,null,texture,"")
	check(owner.lookup("model",prebake_key).is_empty(),"Explicit disk prebake does not retain its image in session GPU owner")
	prebake.close(); prebake.free()
	owner.note_failure("raster","missing","Missing source bitmap")
	check(owner.failure("raster","missing")=="Missing source bitmap","Missing/corrupt reason remains inspectable")
	catalog.release_ui_assets()
	check(owner.closed and owner.lookup("model",model_key).is_empty(),"Explicit session release drops retained images")
	catalog.invalidate()
	check(catalog.ui_asset_owner()!=owner and fork.ui_asset_owner()==null and early_fork.ui_asset_owner()==null,"Changing catalog bindings starts a new scope without granting worker forks GPU ownership")
	var other=Catalog.new(); other.layers=[{"binding_identity":"install-b","entries":{}}]; other.build_resource_index()
	check(other.ui_asset_owner().lookup("model",model_key).is_empty(),"Different source catalogs never share a variant key")
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Catalog-scoped strong UI image ownership, exact variant keys, reuse and release; no startup preload or graphical fidelity claim."},"  "))
	file.close(); quit(0 if failures.is_empty() else 1)
