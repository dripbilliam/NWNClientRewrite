extends RefCounted
# SceneTree --script launches skip Godot's autoload initialization. Such consumer
# scripts preload this accessor as ClientAPI to use the same ClientAPI.entities.
static var entities: RefCounted:
	get:
		var tree:=Engine.get_main_loop()
		if not tree is SceneTree: return null
		var api: Node=tree.root.get_node_or_null("ClientAPI")
		if api==null or api.get_script()!=load("res://systems/client_api/client_api.gd"): return null
		return api.entities
	set(_value): push_error("ClientAPI.entities is read-only")

static func stop_rest() -> void:
	var tree:=Engine.get_main_loop()
	if not tree is SceneTree: return
	var api: Node=tree.root.get_node_or_null("ClientAPI")
	if api!=null and api.get_script()==load("res://systems/client_api/client_api.gd"): api.stop_rest()
