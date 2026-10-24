extends RefCounted
# Prepare a native PackedScene once; repeat instances clone in engine code.
# Private physical nodes and shared immutable resources are both preserved.
const Instance=preload("res://systems/native_render/model_instance.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var scene: PackedScene
var limitations: Array=[]
var failure:=""
class Placement:
	extends Node3D
	var parts: Array=[]
	var meshes: Array=[]
	var limitations: Array=[]
	var retired:=false
	func retire() -> void:
		if retired: return
		retired=true
		for child in get_children(): child.free()
		parts.clear(); meshes.clear(); queue_free()
static func identity(bundle: Dictionary, pool) -> String:
	var textures: Array=[]; var names: Array=bundle.get("textures",{}).keys(); names.sort()
	for name in names: textures.append([name,bundle.textures[name].get("sha256","recorded-missing")])
	return Cache.digest(var_to_bytes([bundle.sha256,textures,pool.unshaded,pool.texture_filter]))
func build(bundle: Dictionary, pool) -> bool:
	if OS.get_thread_caller_id()!=OS.get_main_thread_id(): failure="Native scene publication requires main thread"; return false
	if scene!=null: failure="Native template already prepared"; return false
	var source:=Instance.new()
	if not source.install(bundle,pool): failure=source.failure; source.free(); return false
	limitations=source.limitations.duplicate()
	var root_node:=Node3D.new()
	for part in source.parts:
		if part.get_parent()==source: part.reparent(root_node,false)
	for node in root_node.find_children("*","",true,false): node.owner=root_node
	source.parts.clear(); source.meshes.clear(); source.free()
	scene=PackedScene.new(); var result:=scene.pack(root_node); root_node.free()
	if result!=OK: failure="Native model template pack failed"; scene=null; return false
	return true
func create() -> Placement:
	if scene==null or OS.get_thread_caller_id()!=OS.get_main_thread_id(): return null
	var placement:=Placement.new(); var root_node:=scene.instantiate()
	if root_node==null: placement.free(); return null
	placement.add_child(root_node)
	placement.parts=root_node.find_children("part_*","Node3D",true,false)
	placement.meshes=root_node.find_children("*","MeshInstance3D",true,false)
	placement.limitations=limitations.duplicate()
	return placement
