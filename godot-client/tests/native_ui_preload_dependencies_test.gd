extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Controller=preload("res://systems/native_ui_preload.gd")
const Icons=preload("res://systems/native_item_icons.gd")
var checks:=0
var failures: Array=[]
var folder:=""
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func write(path: String,data: PackedByteArray) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(data); file.close()
func texture(color: PackedByteArray) -> PackedByteArray:
	var tga:=PackedByteArray(); tga.resize(18); tga[2]=2; tga[12]=1; tga[14]=1; tga[16]=32; tga[17]=40; tga.append_array(color); return tga
func model(name: String) -> PackedByteArray:
	return ("newmodel %s\nbeginmodelgeom %s\nnode trimesh root\nparent NULL\nbitmap paint\nverts 3\n0 0 0\n1 0 0\n0 1 0\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom %s\n"%[name,name,name]).to_utf8_buffer()
func source():
	var catalog:=Catalog.new(); check(catalog.mount_directory(folder.path_join("input")),"Authored custom UI mounts without a stock resource list"); catalog.build_resource_index(); return catalog
func wait_owner(owner) -> void:
	var deadline:=Time.get_ticks_msec()+30000
	while owner.state.active and Time.get_ticks_msec()<deadline: await process_frame
	check(not owner.state.active,"UI action completes or cancels before its deadline")
func image(owner,region: Rect2=Rect2()) -> Dictionary:
	var key: String=owner.request_model("gui_fixture","up",{},0,"",[],region)
	var deadline:=Time.get_ticks_msec()+30000
	while owner.pending.has(key) and Time.get_ticks_msec()<deadline: await process_frame
	check(owner.textures.has(key),"Custom menu image is available")
	return {"key":key,"pixels":owner.textures[key].get_image().get_data(),"bounds":owner.image_bounds[key]} if owner.textures.has(key) else {}
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	folder=OS.get_temp_dir().path_join("nwn-ui-preload-dependencies-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(folder.path_join("input")); write(folder.path_join("input/gui_fixture.mdl"),model("gui_fixture")); write(folder.path_join("input/paint.tga"),texture(PackedByteArray([20,120,240,255])))
	var catalog=source(); var cache:=folder.path_join("cache")
	var existing:=Icons.new(); root.add_child(existing); existing.configure(catalog,cache)
	var region:=Rect2(0,0,0.5,0.5); var cropped:=await image(existing,region)
	var owner:=Controller.new(); root.add_child(owner); owner.capture_opened=true
	check(owner.start(catalog,cache),"UI preload accepts a locally mounted custom catalog")
	await wait_owner(owner)
	check(int(owner.state.failed)==0 and int(owner.state.saved)>=3 and int(owner.state.completed)==int(owner.state.total),"Unopened custom states and existing generated-region artwork are persistently prepared")
	check(is_instance_valid(existing) and existing.textures.has(cropped.get("key","")),"Baking never releases or mutates a live menu consumer's textures")
	existing.close(); existing.queue_free()
	var consumer:=Icons.new(); root.add_child(consumer); consumer.configure(source(),cache)
	var before:=await image(consumer)
	var restored:=await image(consumer,region)
	check(int(consumer.stats.rendered)==0 and int(consumer.stats.get("prework_hits",0))==2 and restored.get("pixels")==cropped.get("pixels") and restored.get("bounds")==cropped.get("bounds"),"Fresh consumers reuse custom/default/generated GUI images with exact pixels and bounds")
	consumer.close(); consumer.queue_free(); await process_frame
	write(folder.path_join("input/paint.tga"),texture(PackedByteArray([240,120,20,255])))
	catalog=source(); owner.capture_opened=false; check(owner.start(catalog,cache),"UI preparation restarts against changed local resources")
	await wait_owner(owner)
	check(int(owner.state.failed)==0 and int(owner.state.rendered)==2 and int(owner.state.reused)==0,"A changed texture invalidates both saved menu states and rebuilds their pixels")
	consumer=Icons.new(); root.add_child(consumer); consumer.configure(source(),cache)
	var after:=await image(consumer)
	check(after.get("pixels")!=before.get("pixels") and int(consumer.stats.rendered)==0 and int(consumer.stats.get("prework_hits",0))==1,"Rebuilt dependency-validated pixels reach actual menu consumers from disk")
	consumer.close(); consumer.queue_free()
	for index in 48:
		var name:="gui_fixture"+str(index); write(folder.path_join("input/"+name+".mdl"),model(name))
	catalog=source(); check(owner.start(catalog,cache),"A larger custom UI catalog starts through the same controller")
	var deadline:=Time.get_ticks_msec()+30000
	while owner.state.active and int(owner.state.completed)==0 and Time.get_ticks_msec()<deadline: await process_frame
	owner.cancel(); await wait_owner(owner)
	check(owner.state.cancelled and int(owner.state.completed)<int(owner.state.total) and owner.plan_task<0 and owner.saves.is_empty() and owner.icons==null and owner.assets==null,"Mid-preparation cancellation stops queueing and drains discovery, assets, native GPU work and writes")
	var final_state: Dictionary=owner.state.duplicate(true); owner.close(); owner.free(); catalog=null; await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"cancelled":final_state,"temporary_fixture":folder,"publicConnections":0,"scope":"Native custom-resource discovery, generated-region capture, source-validated persistent pixels, texture dependency invalidation, live-owner isolation and mid-bake cancellation."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
