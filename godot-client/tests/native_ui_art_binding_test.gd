extends SceneTree
const Art=preload("res://systems/native_ui_art.gd")
class Catalog extends RefCounted:
	func raster_location(_name: String) -> Dictionary: return {"type":3}
class Assets extends Node:
	var serial:=0
	func request(_name: String,_type: int,_decoder: String) -> int: serial+=1; return serial
	func close() -> void: pass
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
	var art:=Art.new(); root.add_child(art); art.catalog=Catalog.new(); art.assets=Assets.new(); art.add_child(art.assets)
	var image:=Image.create(8,8,false,Image.FORMAT_RGBA8); image.fill(Color.RED); var first:=ImageTexture.create_from_image(image)
	image.fill(Color.GREEN); var second:=ImageTexture.create_from_image(image)
	var target:=TextureRect.new(); root.add_child(target)
	art.bind(target,"old-menu"); art.bind(target,"new-menu")
	art.deliver("old-menu",first); check(target.texture==null,"A previous menu cannot decorate its replacement before the new image arrives")
	art.deliver("new-menu",second); check(target.texture==second,"The current native image is applied")
	art.bind(target,"late"); art.bind(target,"old-menu")
	check(target.texture==first,"A cached current binding applies immediately")
	art.deliver("late",second); check(target.texture==first,"A late result cannot replace an immediately cached current image")
	art.bind(target,"cleared"); art.bind(target,""); target.texture=null
	art.deliver("cleared",first); check(target.texture==null,"Clearing a native icon retires its pending binding")
	var another:=TextureRect.new(); root.add_child(another)
	art.bind(target,"shared"); art.bind(another,"shared"); art.bind(target,"new-menu")
	art.deliver("shared",first)
	check(target.texture==second and another.texture==first,"Coalesced reads preserve independent target identities")
	art.bind(another,"freed"); another.free(); art.deliver("freed",first)
	check(art.stale_bindings==5,"Freed or superseded listeners are discarded without scene mutation")
	check(art.waiting.is_empty() and art.bindings.is_empty(),"Completed/canceled UI bindings retain no listener identities")
	art.close(); art.free(); target.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Native asynchronous GUI artwork binding identity across menu replacement, cached hits, clearing, coalescing and freed targets. Authored deterministic delivery; no server/asset fidelity claim."},"  ")); file.close(); quit(0 if failures.is_empty() else 1)
