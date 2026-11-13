extends Node
# Register this script as the ClientAPI autoload for literal ClientAPI.entities.
# install() also supports SceneTree-script entry points which do not run a scene.
const Entities=preload("res://systems/client_api/entities.gd")
const Binding=preload("res://systems/client_api/native_binding.gd")
const RestServer=preload("res://systems/client_api/rest_server.gd")
const RestOptions=preload("res://systems/client_api/rest_options.gd")
const API_VERSION:=1
var _entities:=Entities.new()
var _rest_server: Node
var _rest_status: Dictionary={"enabled":false,"listening":false,"error":null}
var entities: RefCounted:
	get: return _entities
	set(_value): push_error("ClientAPI.entities is read-only")

func _ready() -> void:
	var environment: Dictionary={}
	for key in ["NWN_ENTITY_API_REST","NWN_ENTITY_API_REST_PORT","NWN_ENTITY_API_REST_DISCOVERY"]:
		if OS.has_environment(key): environment[key]=OS.get_environment(key)
	start_rest_from_arguments(OS.get_cmdline_user_args(),environment)

func start_rest_from_arguments(arguments: Variant,environment: Dictionary={}) -> Dictionary:
	if is_instance_valid(_rest_server): return _rest_server.status()
	var options:=RestOptions.parse(arguments,environment)
	if not options.get("enabled",false):
		_rest_status={"enabled":false,"listening":false,"error":options.get("error")}; return rest_status()
	_rest_server=RestServer.new(); _rest_server.name="EntityRest"; add_child(_rest_server)
	_rest_status=_rest_server.start(_entities,options)
	if not _rest_status.listening: _rest_server.queue_free(); _rest_server=null
	return rest_status()

func rest_status() -> Dictionary:
	return _rest_server.status() if is_instance_valid(_rest_server) else _rest_status.duplicate(true)

func stop_rest() -> void:
	if not is_instance_valid(_rest_server): return
	_rest_server.stop(); _rest_status=_rest_server.status(); _rest_server.queue_free(); _rest_server=null

func _exit_tree() -> void: stop_rest()

static func install(tree_root: Node) -> Node:
	var existing:=tree_root.get_node_or_null("ClientAPI")
	if existing!=null:
		if existing.get_script()==load("res://systems/client_api/client_api.gd"): return existing
		push_error("The ClientAPI root name is already owned by another node"); return null
	var api: Node=load("res://systems/client_api/client_api.gd").new()
	api.name="ClientAPI"; tree_root.add_child(api)
	return api

func bind_native(received_lookup: Callable,presentation_lookup: Callable=Callable()) -> RefCounted:
	var binding:=Binding.new(_entities)
	binding.bind_sources(received_lookup,presentation_lookup)
	return binding
