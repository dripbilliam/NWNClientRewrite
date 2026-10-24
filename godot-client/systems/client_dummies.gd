extends Node3D

# Private original c_dummy instances. No registry, collision, pick meshes or
# canonical pivots. Their expiry runs on the native frame loop, after admission.
const Resources = preload("res://systems/visual_resources.gd")
const Fade = preload("res://systems/client_fade.gd")
var client
var cache := Resources.new()
var entries: Dictionary = {}
var closed := false
var last_token := 0
var previous_ticks := 0
var stats := {"created":0,"expired":0,"failed":0,"retired":0,"displayCalls":0}

func configure(owner) -> void:
	client = owner
	cache.configure({"connection":client.connection,"areaId":client.area_id,"generation":client.generation,"transferId":client.world_scope.ticket})
	previous_ticks = Time.get_ticks_usec()
	process_priority = 40

func _world_time() -> Dictionary:
	# Explicit local clock projection. The original subtraction/fade decisions
	# are retained; server pause/time offset synchronization remains unported.
	var length := 7200000
	if is_instance_valid(client.owner_scene.environment_owner):
		length = maxi(1,int(client.owner_scene.environment_owner.source.get("minutesPerHour",5))&255)*1440000
	var ticks := Time.get_ticks_msec()
	return {"day":(ticks/length)&0xffffffff,"time":ticks%length,"length":length}

func _providers(snapshot: int) -> Dictionary:
	return {"worldTime":_world_time,"difference":func(a,b):
		var days := (int(a.day)-int(b.day))&0xffffffff
		var elapsed := (int(a.time)-int(b.time))&0xffffffff
		if elapsed >= int(a.length): days = (days-1)&0xffffffff;elapsed = (elapsed+int(a.length))&0xffffffff
		return {"day":days,"time":elapsed},
		"snapshotDifference":func():return snapshot,"modelHandle":func(s):return s.model,
		"mode":func():return 2,"controlledId":func():return client.controlled_id,
		"display":func(_s,_offset):stats.displayCalls += 1,
		"targetAlpha":func(_s):return 1.0,"alpha":func(_s,_opacity,_part):pass,"handleScene":func(_s,_on):pass}

func receive(message: Dictionary) -> bool:
	if closed: return false
	var id := int(message.get("id",-1));var token := int(message.get("token",-1))
	if id < 0 or id >= 0x7effffff or token <= last_token or entries.has(id) or message.get("role") not in ["point","target"] or int(message.get("appearance",-1)) != 201: return false
	last_token = token
	var point: Variant = message.get("position")
	var delay: Variant = message.get("delay")
	if not point is Array or point.size() != 3 or not delay is Array or delay.size() != 3 or int(delay[0]) != 1 or int(delay[1]) != 1 or float(delay[2]) < 0 or float(delay[2]) > 4294967295: return false
	for value in point:
		if not is_finite(float(value)): return false
	if not message.get("resource") is Dictionary or not cache.prepare_resource("c_dummy",message.resource):
		stats.failed += 1;_status(id,token,"failed");return false
	var model = cache.instantiate_model("c_dummy",self)
	if model == null or model.metadata.modelResources[0].to_lower() != "c_dummy":
		if model != null: model.retire()
		stats.failed += 1;_status(id,token,"failed");return false
	model.position = Vector3(float(point[0]),float(point[2]),-float(point[1]))
	var state := {"id":id,"temporary":0,"blocked":0,"fadeTarget":1,"fadeState":1,"delayEnabled":0,"duration":0,"since":{"day":0,"time":0},"opacity":1.0,"visible":1,"model":model}
	Fade.set_fade(state,1,1,int(delay[2]),_providers(0))
	state.temporary = 1
	entries[id] = {"id":id,"token":token,"model":model,"state":state}
	stats.created += 1;_status(id,token,"ready")
	return true

func host(id: int,token: int) -> Node3D:
	if closed or not entries.has(id) or int(entries[id].token) != token: return null
	return entries[id].model

func anchor(id: int,token: int,part: String) -> Node3D:
	var model = host(id,token)
	return model.node_for(0,part) if model != null else null

func _process(_delta: float) -> void:
	if closed: return
	var ticks := Time.get_ticks_usec();var providers := _providers(ticks-previous_ticks);previous_ticks = ticks
	for id in entries.keys():
		if Fade.update(entries[id].state,providers) != 0:
			var token: int = entries[id].token
			_remove(id);stats.expired += 1;_status(id,token,"expired")

func _status(id: int,token: int,stage: String) -> void:
	client.command({"kind":"client-dummy-status","id":id,"token":token,"stage":stage,"transferId":client.world_scope.ticket})

func _remove(id: int) -> void:
	var record: Dictionary = entries[id];entries.erase(id)
	record.state.model = null;record.model.retire();stats.retired += 1

func sample() -> Dictionary:
	return {"stats":stats.duplicate(true),"active":entries.size(),"cache":cache.stats.duplicate(true),"clock":"local monotonic projection; server pause/time synchronization pending"}

func close() -> void:
	if closed: return
	closed = true;set_process(false)
	for id in entries.keys(): _remove(id)
	cache.clear()

func _exit_tree() -> void: close()
