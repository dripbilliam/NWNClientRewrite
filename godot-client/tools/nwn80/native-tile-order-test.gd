extends SceneTree

const AreaStream=preload("res://systems/native_render/area_stream.gd")
var checks:=0
var failures: Array=[]

class FakeAssets extends RefCounted:
	var requested_order: Array=[]
	func prioritize(_ids: Array) -> void:pass
class FakePool extends RefCounted:
	var stats: Dictionary={"templates_created":0}
class FakeTile extends Node3D:
	var parts: Array=[]
	var meshes: Array=[]
	var limitations: Array=[]
	func retire() -> void:pass
class FakeTemplate extends RefCounted:
	func create() -> Node3D:return FakeTile.new()
class FakeFailTemplate extends RefCounted:
	func create() -> Node3D:return null

func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)

func source(names: Array) -> Node3D:
	var stream:=AreaStream.new()
	stream.native_tile_order=true
	var tiles: Array=[]
	var models: Dictionary={}
	for index in names.size():
		var name: String=str(names[index])
		tiles.append({"model":name})
		if not models.has(name):models[name]=[]
		models[name].append(index)
	stream.definition={"tiles":tiles,"models":models}
	stream.diagnostics={"errors":[],"worker_ms":0.0}
	return stream

func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var stream=source(["a","b","a","c"])
	stream.queue_model_rows("c")
	stream.queue_model_rows("b")
	check(stream.take_publish_row().is_empty() and stream.publish_queue.size()==2,"later completed models wait for tile zero")
	stream.queue_model_rows("a")
	var order: Array=[]
	for index in 4:
		var row: Dictionary=stream.take_publish_row()
		order.append(int(row.get("index",-1)))
		stream.finish_native_tile()
	check(order==[0,1,2,3],"out-of-order model completion publishes native linear tile order")
	check(stream.native_tile_cursor==4 and stream.publish_queue.is_empty(),"all tiles consumed exactly once")
	stream.free()

	stream=source(["a","b","c"])
	stream.requests[71]="a"
	stream.model_prepared(71,{"error":"missing","worker_ms":0.0})
	stream.queue_model_rows("c")
	stream.queue_model_rows("b")
	var first: Dictionary=stream.take_publish_row()
	check(first.is_empty() and stream.done and stream.native_tile_failure_index==0,"failed first native tile aborts later publication")
	check(stream.failed_tiles==1 and stream.diagnostics.errors.size()==2,"failed model and native-order abort retain explicit reasons")
	check(stream.publish_queue.is_empty() and stream.requests.is_empty(),"failed native area discards later ready and outstanding rows")
	stream.free()

	stream=source(["a","b","c"])
	stream.queue_model_rows("a");stream.queue_model_rows("c")
	stream.failed_models["b"]=true
	first=stream.take_publish_row()
	check(int(first.get("index",-1))==0,"earlier good tile remains publishable before later failure")
	stream.finish_native_tile()
	check(stream.take_publish_row().is_empty() and stream.native_tile_failure_index==1 and stream.done,"later failed tile blocks the queued later success")
	stream.free()

	stream=source(["a","b"])
	stream.queue_model_rows("a")
	stream.queue_model_rows("b")
	var pending: Dictionary=stream.take_publish_row()
	stream.publish_queue.push_front(pending)
	check(int(stream.take_publish_row().index)==0 and stream.native_tile_cursor==0,"staged template or clone resume retains same tile")
	stream.finish_native_tile()
	check(int(stream.take_publish_row().index)==1,"next tile follows completed staged resume")
	stream.retire_scope()
	check(stream.native_tile_cursor==0 and stream.failed_models.is_empty() and stream.publish_queue.is_empty(),"area reset drops order state and queued rows")
	stream.free()

	stream=source(["a","b","c"])
	stream.waiting=["c","b","a"]
	stream.priority_dirty=true
	stream.assets=FakeAssets.new()
	stream.refresh_priority()
	check(stream.waiting==["a","b","c"],"native request preference follows first tile occurrence without a player origin")
	stream.free()

	stream=source(["a","b"])
	stream.native_tile_order=false
	stream.queue_model_rows("b")
	stream.queue_model_rows("a")
	check(int(stream.take_publish_row().index)==1,"ordinary route keeps ready-model arrival order")
	stream.free()

	stream=source(["a","b"])
	stream.use_terrain_batches=true
	stream.enforce_native_order_batch_contract()
	stream.queue_model_rows("b")
	stream.queue_model_rows("a")
	check(stream.native_order_active() and not stream.use_terrain_batches and int(stream.take_publish_row().index)==0,"native order forces individual tile publication when batching was requested")
	check(stream.native_tile_batch_forced_off and stream.snapshot().streaming_priority.native_tile_batch_forced_off,"snapshot records native-order batch override")
	stream.free()

	stream=source(["a","b"])
	stream.native_tile_order=false
	stream.use_terrain_batches=true
	stream.enforce_native_order_batch_contract()
	check(stream.use_terrain_batches and not stream.native_tile_batch_forced_off,"ordinary route retains optional terrain batching")
	stream.free()

	stream=source(["a","b","a","c"])
	root.add_child(stream);stream.set_process(false)
	stream.pool=FakePool.new()
	stream.light_table={"defaultValue":"0"}
	stream.publication_budget_ms=1000.0
	stream.diagnostics.merge({"templates_reused":0,"clone_ms":0.0,"attach_ms":0.0,"tile_lights":[],"max_tile_publish_ms":0.0,"publish_frames":0,"publish_ms":0.0},true)
	for tile in stream.definition.tiles:
		tile.position=Vector3.ZERO;tile.rotation_y=0.0;tile.main_lights=[0,0]
	for name in stream.definition.models:
		stream.template_keys[name]=name
		stream.templates[name]=FakeTemplate.new()
		stream.publication_remaining[name]=stream.definition.models[name].size()
	var published: Array=[]
	stream.tile_published.connect(func(index: int,_tile):published.append(index))
	stream.queue_model_rows("c")
	stream.queue_model_rows("b")
	stream._profile_process(0.0)
	check(published.is_empty() and stream.instances.is_empty(),"real publisher does not expose later ready tiles before tile zero")
	stream.queue_model_rows("a")
	stream._profile_process(0.0)
	check(published==[0,1,2,3],"real publisher emits tile signal in native index order")
	check(stream.done and stream.completed_tiles==4 and stream.failed_tiles==0,"real publisher completes full scene population")
	var child_order: Array=[]
	for child in stream.get_children():child_order.append(int(child.get_meta("native_tile_index",-1)))
	check(child_order==[0,1,2,3],"scene child installation order matches tile signal order")
	stream.free()

	stream=source(["a","b"])
	root.add_child(stream);stream.set_process(false)
	stream.pool=FakePool.new();stream.light_table={"defaultValue":"0"};stream.publication_budget_ms=1000.0
	stream.diagnostics.merge({"templates_reused":0,"clone_ms":0.0,"attach_ms":0.0,"tile_lights":[],"max_tile_publish_ms":0.0,"publish_frames":0,"publish_ms":0.0},true)
	for tile in stream.definition.tiles:
		tile.position=Vector3.ZERO;tile.rotation_y=0.0;tile.main_lights=[0,0]
	for name in stream.definition.models:
		stream.template_keys[name]=name;stream.templates[name]=FakeTemplate.new();stream.publication_remaining[name]=1
	stream.queue_model_rows("a");stream.queue_model_rows("b")
	var retired: Array=[]
	stream.tile_published.connect(func(index: int,_tile):
		retired.append(index)
		if index==0:stream.retire_scope())
	stream._profile_process(0.0)
	check(retired==[0] and stream.generation==1,"reentrant area reset stops old tile publication")
	check(stream.publish_queue.is_empty() and stream.native_tile_cursor==0 and stream.instances.is_empty(),"reentrant reset keeps new scope empty")
	stream.free()

	stream=source(["a","b"])
	root.add_child(stream);stream.set_process(false)
	stream.pool=FakePool.new();stream.light_table={"defaultValue":"0"};stream.publication_budget_ms=1000.0
	stream.diagnostics.merge({"templates_reused":0,"clone_ms":0.0,"attach_ms":0.0,"tile_lights":[],"max_tile_publish_ms":0.0,"publish_frames":0,"publish_ms":0.0},true)
	for tile in stream.definition.tiles:
		tile.position=Vector3.ZERO;tile.rotation_y=0.0;tile.main_lights=[0,0]
	stream.template_keys={"a":"a","b":"b"};stream.templates={"a":FakeFailTemplate.new(),"b":FakeTemplate.new()};stream.publication_remaining={"a":1,"b":1}
	stream.queue_model_rows("b");stream.queue_model_rows("a")
	var after_failure: Array=[]
	stream.tile_published.connect(func(index: int,_tile):after_failure.append(index))
	stream._profile_process(0.0)
	check(after_failure.is_empty() and stream.instances.is_empty() and stream.done and stream.native_tile_failure_index==0,"real clone failure aborts before any later tile installs")
	stream.free()

	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual AreaStream ready-row selection and Node3D tile publication, failed model, staged resume, reentrant reset, request preference and ordinary/batch fallback. No original asset, GPU or FPS assertion."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--result="):
			var file:=FileAccess.open(argument.trim_prefix("--result="),FileAccess.WRITE)
			file.store_string(JSON.stringify(result));file.close()
	print("NWN80_TILE_ORDER ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
