extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Shared=preload("res://systems/native_data/shared_ui_rasters.gd")
const Art=preload("res://systems/native_ui_art.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func catalog(identity: String,type: int=3):
	var value=Catalog.new()
	var entries: Dictionary={}; entries["i_nwn84_cross_scope:"+str(type)]={}
	value.layers=[{"kind":"key","storage_class":1,"binding_identity":identity,"entries":entries}]
	value.build_resource_index()
	return value
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	var image:=Image.create(2,2,false,Image.FORMAT_RGBA8); image.fill(Color.RED)
	var texture:=ImageTexture.create_from_image(image)
	var first=catalog("installed-a"); var same=catalog("installed-a"); var override=catalog("server-override"); var different_format=catalog("installed-format",2033)
	check(Shared.lookup(first,"i_nwn84_cross_scope")==null,"uncached lookup is empty")
	Shared.retain(first,"i_nwn84_cross_scope",texture)
	check(Shared.lookup(same,"i_nwn84_cross_scope")==texture,"same selected binding shares texture")
	check(Shared.lookup(override,"i_nwn84_cross_scope")==null,"server override cannot reuse installed texture")
	check(Shared.lookup(different_format,"i_nwn84_cross_scope")==null,"different raster format cannot reuse texture")
	var art:=Art.new(); root.add_child(art); art.configure(same,"")
	var target:=TextureRect.new(); root.add_child(target)
	art.bind(target,"i_nwn84_cross_scope")
	check(target.texture==texture,"UI art binds process-resident image without a worker request")
	check(art.bitmap_jobs.is_empty(),"shared image avoids decode job")
	check(same.ui_asset_owner().lookup("raster","i_nwn84_cross_scope").get("texture")==texture,"session owner retains reused image")
	art.close(); target.free(); art.free()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"shared":Shared.snapshot()}
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")); file.close()
	quit(0 if failures.is_empty() else 1)
