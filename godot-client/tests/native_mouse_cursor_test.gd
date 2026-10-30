extends SceneTree
const Cursor=preload("res://systems/native_mouse_cursor.gd")
const Policy=preload("res://systems/native_data/mouse_cursor.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Slot=preload("res://systems/inventory_slot.gd")
class Desktop:
	extends RefCounted
	var objects: Dictionary={}
	var actor_id:=101
	var state: Dictionary={}
	var target: Dictionary={}
	func target_cursor(_id: int,_ground: bool=false) -> Dictionary: return {}
class Owner:
	extends RefCounted
	var desktop:=Desktop.new()
class Inventory:
	extends Node
	var view_id:=7
	var wanted:=true
	var examine_mode:=false
	func select_item(_id: int) -> void: pass
class OverrideCatalog:
	extends RefCounted
	var source
	var failure:=""
	var stats: Dictionary:
		get: return source.stats
	func fork():
		var copy:=OverrideCatalog.new(); copy.source=source.fork(); return copy
	func has_resource(name: String,type: int) -> bool: return true if name=="gui_mp_custom00u" and type==3 else source.has_resource(name,type)
	func get_resource(name: String,type: int) -> PackedByteArray:
		if name=="cursors" and type==2017: return "2DA V2.0\n\nLabel ResRef CursorID\n0 None **** ****\n1 Custom arbitrary_image_name 93\n".to_ascii_buffer()
		var bytes: PackedByteArray=source.get_resource("gui_mp_talku" if name=="gui_mp_custom00u" and type==3 else name,type); failure=source.failure; return bytes
	func preparation_cache(): return source.preparation_cache()
	func decoded_cache(): return source.decoded_cache()
var checks:=0
var failures: Array=[]
var packets: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func _initialize() -> void: call_deferred("run")
func wait_until(test: Callable) -> bool:
	var end:=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<end:
		if test.call(): return true
		await process_frame
	return false
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var output:=str(args.get("report","")); var oracle_path:=str(args.get("oracle",""))
	if output.is_empty() or FileAccess.file_exists(output) or oracle_path.is_empty(): quit(2); return
	root.unfocusable=true; root.size=Vector2i(1100,650)
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Oracle identifies the unchanged shipped original")
	for index in oracle.names.size(): check(Policy.resource(index)==str(oracle.names[index]),"Original initializer cursor name "+str(index))
	for row in oracle.selection:
		var id:=Policy.variant(int(row.id),bool(row.allowPressed),bool(row.pressed))
		check(Policy.resource(id)==str(row.name),"Original press flags/name "+str(row))
	for row in oracle.press:
		check(Policy.resource(Policy.variant(int(row.id),bool(row.allowPressed),true))==str(row.publications[1].name) and Policy.resource(int(row.id))==str(row.publications[2].name),"Original forced press/release flags "+str(row.id))
	check(Policy.resource(-1).is_empty() and Policy.resource(293).is_empty(),"No invented named resource for the original empty/out-of-name-table boundaries")
	var catalog:=Catalog.new(); var install:=str(args.get("install",""))
	check(catalog.mount_install(install) and catalog.build_resource_index(),"Original installed catalog opens locally")
	var owner:=Owner.new(); var cursor:=Cursor.new(); root.add_child(cursor); cursor.set_process(false)
	cursor.publisher=func(packet): packets.append(packet.duplicate())
	var cache:=output.trim_suffix(".json")+"-cache"; cursor.configure(owner,catalog,cache)
	check(await wait_until(func():return cursor.jobs.is_empty()),"All stock cursor native jobs complete")
	check(cursor.images.size()==92 and cursor.failures.is_empty() and cursor.cursors.get("orderedRows",[]).size()>1,"Original92 TGA images and transition table decode without errors")
	for id in range(1,93):
		var bytes: PackedByteArray=catalog.get_resource(Policy.resource(id),3)
		var parser=Cursor.Assets.Raster.new(); var raster: Dictionary=parser.parse(bytes,3); var source: PackedByteArray=raster.mips[0].data
		var expected:=Image.create_from_data(int(raster.width),int(raster.height),false,Image.FORMAT_RGBA8,source); expected.flip_y()
		check(cursor.images[id].get_data()==expected.get_data() and cursor.images[id].get_size()==Vector2i(32,32),"Original hardware row order and unstretched32px cursor "+str(id))
	var stock:=cursor.cursors
	check(Policy.trigger_id(stock,1)==21 and Policy.trigger_id(stock,2)==25 and Policy.trigger_id(stock,3)==17,"Native physical transition table CursorID values")
	check(Policy.trigger_id({"orderedRows":[{}, {"ResRef":"arbitrary_not_a_filename_map","CursorID":"95"}]},257)==95,"Server CursorID overrides use BYTE physical row, independent of ResRef")
	var objects:={101:{"id":101,"objectType":5},102:{"id":102,"objectType":5,"replicated":{"reaction":2}},103:{"id":103,"objectType":5,"replicated":{"reaction":1}},104:{"id":104,"objectType":6},105:{"id":105,"objectType":9},106:{"id":106,"objectType":10,"replicated":{"animation":22,"hasTransition":true}},107:{"id":107,"objectType":7,"replicated":{"displayType":3}}}
	for pair in [[101,1],[102,7],[103,11],[104,91],[105,25],[106,23],[107,17]]: check(Policy.world({"id":pair[0]},objects,101,stock).id==pair[1],"World self/hostile/talk/item/use/closed-door/trigger "+str(pair))
	check(Policy.world({"id":103},objects,101,stock,[103]).id==1,"Other player arrow differs from an ordinary NPC talk cursor")
	objects[106].replicated.animation=50
	check(Policy.world({"id":106},objects,101,stock).id==21,"Open transitioning door uses transition cursor")
	objects[105].replicated={"light":{"field260":95}}
	check(Policy.world({"id":105},objects,101,stock).id==95,"Received custom cursor enum overrides ordinary object cursor")
	check(Policy.world({},objects,101,stock)==Policy.selection(5,true) and Policy.world({"id":-1},objects,101,stock)==Policy.selection(3),"Unwalkable miss and real WOK ground use separate cursors/hotspots")
	var inventory:=Inventory.new(); root.add_child(inventory)
	var slot:=Slot.new(); root.add_child(slot); slot.setup(inventory,{"entryId":4,"name":"Item","channel":"M"})
	check(cursor.hovered_selection(slot.image,false)==Policy.selection(91,true) and cursor.hovered_selection(slot,true)==Policy.selection(92,true),"Inventory/store/trade shared item hover and dragging are centered pickup cursors")
	inventory.view_id=8
	check(cursor.hovered_selection(slot,false)==Policy.selection(),"Retired inventory view cannot keep an item cursor")
	var ui_host:=Control.new(); root.add_child(ui_host)
	var atlas:=Image.create(1024,384,false,Image.FORMAT_RGBA8); atlas.fill(Color(0.06,0.075,0.07))
	for id in range(1,93): atlas.blit_rect(cursor.images[id],Rect2i(0,0,32,32),Vector2i(((id-1)%16)*64+16,((id-1)/16)*64+16))
	check(atlas.save_png(output.trim_suffix(".json")+"-atlas.png")==OK,"Original cursor atlas exported for visual review")
	for scale in [1.0,1.5,2.0,4.0]:
		for centered in [false,true]:
			cursor.publish(Policy.selection(91,centered),true,scale)
			var packet: Dictionary=packets[-1]; var geometry:=Policy.geometry(scale,centered)
			check(packet.id==92 and packet.hotspot==Vector2(geometry.hotspot) and packet.texture.get_size()==Vector2(geometry.size,geometry.size),"Pressed pickup published with original scale and hotspot "+str([scale,centered]))
			var image: Image=cursor.images[92].duplicate(); image.resize(geometry.size,geometry.size,Image.INTERPOLATE_NEAREST)
			check(packet.texture.get_image().get_data()==image.get_data(),"Published native cursor pixels preserve image content at scale "+str(scale))
			var view:=TextureRect.new(); ui_host.add_child(view); view.texture=packet.texture; view.position=Vector2((scale-1)*180,430 if centered else 280); view.size=packet.texture.get_size()
	var count:=packets.size(); cursor.publish(Policy.selection(91,true),true,4.0)
	check(packets.size()==count,"Unchanged cursor does not re-publish each frame")
	cursor.publish(Policy.selection(95),false,1.0); count=packets.size(); cursor.publish(Policy.selection(95),false,1.0)
	check(packets.size()==count and packets[-1].id==1,"Absent custom artwork falls back to native arrow without repeated publication")
	# Completion after pointer changes must never publish its old image directly.
	cursor.select(Policy.selection(23)); var raster:=Cursor.Assets.Raster.new().parse(catalog.get_resource("gui_mp_talku",3),3)
	cursor.jobs[999999]=11; count=packets.size(); cursor.prepared(999999,{"error":"","value":raster,"bytes":catalog.get_resource("gui_mp_talku",3)})
	check(packets.size()==count and cursor.desired.id==23,"A stale prepared cursor cannot steal newer hover selection")
	var override_catalog:=OverrideCatalog.new(); override_catalog.source=catalog.fork()
	var second:=Cursor.new(); root.add_child(second); second.set_process(false)
	second.publisher=func(packet): packets.append(packet.duplicate())
	second.configure(owner,override_catalog,cache+"-custom"); second.select(Policy.selection(93))
	check(await wait_until(func():return second.jobs.is_empty()),"Separate active-catalog cursor scope finishes without borrowing another owner's misses")
	check(second.images.has(93) and second.images[93].get_data()==cursor.images[11].get_data() and Policy.trigger_id(second.cursors,1)==93,"Active catalog supplies custom TGA artwork and physical trigger CursorID without misusing ResRef")
	second.publish(Policy.selection(93),false,1.0)
	check(packets[-1].name=="gui_mp_custom00u" and packets[-1].id==93 and not cursor.images.has(93),"Custom cursor publication stays isolated from the stock catalog's earlier missing custom image")
	second.close(); second.free(); override_catalog=null
	if DisplayServer.get_name()!="headless":
		await process_frame; await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(output.trim_suffix(".json")+"-scales.png")
	var before:=cursor.snapshot(); cursor.close()
	check(packets[-1].get("reset",false) and cursor.images.is_empty() and cursor.textures.is_empty() and cursor.assets.running.is_empty(),"Teardown resets publication and joins workers before releasing images")
	count=packets.size(); cursor.publish(Policy.selection(),false,1.0); cursor.prepared(1,{})
	check(packets.size()==count,"Closed cursor owner rejects publication and late completion")
	cursor.free(); slot.free(); inventory.free(); ui_host.free(); owner=null; catalog=null; packets.clear(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"state":before,"temporary_cache":cache,"publicConnections":0,"physical_pointer_changes":0,"scope":"Unchanged original initializer/selection oracle; active-catalog TGA pixels, common world/GUI policy, native publication geometry, cache/missing/stale/teardown. Injected publisher never changes OS cursor. Target/associate/DM/directional policy, exact SDL scaler and interactive original-client comparison remain incomplete."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
