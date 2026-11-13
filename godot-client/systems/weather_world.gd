extends Node3D
const Resources = preload("res://systems/visual_resources.gd")
const Placement = preload("res://systems/weather_placement.gd")
var client
var environment_owner
var resources = Resources.new()
var types: Dictionary = {}
var models: Dictionary = {}
var batch_id := 0
var serial := 0
var current_type := 0
var particle_ready := false
var last_intensity := -1.0
var retired := false
var error := ""
var stats := {"created":0,"removed":0,"samples":0,"failures":0}

func configure(owner,environment,scope: Dictionary) -> void:
	client = owner;environment_owner = environment;resources.configure(scope)

func receive_resource(message: Dictionary) -> bool:
	if retired or types.has(int(message.type)): return false
	var key := str(int(message.resourceId))
	if not resources.prepare_resource(key,message.resource): error = resources.error;stats.failures += 1;return false
	types[int(message.type)] = {"resourceId":int(message.resourceId),"key":key,"animation":str(message.animation)}
	return true

func model_for(id: int): return models.get(id)

func advance(state) -> void:
	if retired or not is_instance_valid(client) or not client.world_scope.admitted: return
	if current_type != state.current or state.instances == 0:
		_release(true)
	if state.instances > 0 and models.is_empty() and types.has(state.current):
		var type: Dictionary = types[state.current]
		var ids: Array = []
		for i in 6:
			var instance = resources.instantiate_model(type.key,self)
			if instance == null: error = resources.error;stats.failures += 1;_release(false);return
			serial += 1;models[serial] = instance;ids.append(serial)
			# These are original particle texture templates, not billboards to
			# draw before the worker's first actual particle frame arrives.
			for row in instance.metadata.meshes:
				var mesh: MeshInstance3D = instance.meshes.meshes_by_name[row.name]
				if row.get("particle",false): mesh.hide()
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.rigs.set_process(false)
		batch_id += 1;current_type = state.current;stats.created += 6;last_intensity = -1;particle_ready = false
		client.command({"kind":"weather-create","resourceId":type.resourceId,"type":current_type,"batchId":batch_id,"ids":ids,"transferId":client.world_scope.ticket})
	if models.is_empty(): return
	if not client.pivots.has(client.controlled_id) or not is_instance_valid(environment_owner.camera): return
	var layout := Placement.from_camera(client.pivots[client.controlled_id].global_position,environment_owner.camera)
	var index := 0
	var sampled_intensity := NAN
	var clip_fraction := 0.0
	for model in models.values():
		var p: Array = layout[index].position;var q: Array = layout[index].quaternion
		model.global_transform = Transform3D(Basis(Quaternion(q[1],q[3],-q[2],q[0])),Vector3(p[0],p[2],-p[1]));index += 1
		if last_intensity != state.intensity:
			# A zero may change sign while comparing equal; keep its exact clip input.
			if sampled_intensity != state.intensity or state.intensity == 0.0:
				sampled_intensity = state.intensity
				clip_fraction = state.snapshot().clipFraction
			if not model.sample_weather_clip(types[current_type].animation,clip_fraction):
				error = "Original weather animation/controller is unavailable";stats.failures += 1
	if last_intensity != state.intensity: stats.samples += 1;last_intensity = state.intensity

func receive_particles(message: Dictionary) -> bool:
	if retired or int(message.batchId) != batch_id or models.size() != 6 or int(message.resourceId) != types[current_type].resourceId: return false
	for id in models:
		var emitters: Array = message.emitters.filter(func(row):return int(row.get("weatherModel",-1)) == id)
		client.particles.adopt({"particles":{"emitters":emitters}},models[id].meshes)
	particle_ready = true
	return true

func _release(notify: bool) -> void:
	if models.is_empty(): current_type = 0;return
	if is_instance_valid(client.particles):
		for id in models: client.particles.forget_entity(-(4294967296+id))
	for model in models.values(): model.retire();stats.removed += 1
	models.clear();current_type = 0;particle_ready = false
	if notify and client.world_scope.admitted: client.command({"kind":"weather-release","batchId":batch_id,"transferId":client.world_scope.ticket})

func retire() -> void:
	if retired: return
	retired = true;_release(false);resources.clear();types.clear()

func _exit_tree() -> void: retire()

func snapshot() -> Dictionary:
	var instances: Array = []
	for id in models:
		var instance = models[id]
		var model: Dictionary = instance.rigs.entities[0].models[0]
		var emitters: Array = []
		if model.has("native_owner"):
			for row in instance.metadata.particles.emitters:
				var properties: Dictionary = model.native_owner.pose.emitter_properties(int(row.nativeParent.rigNode))
				emitters.append({"node":row.node,"birthrate":properties.get("birthrate"),"velocity":properties.get("velocity")})
		instances.append({"id":id,"resources":instance.metadata.modelResources,"clip":model.get("clip",""),"speed":model.get("speed",0),"time":model.get("last_time",0),"emitters":emitters})
	return {"models":models.size(),"current":current_type,"particleReady":particle_ready,"batchId":batch_id,"imports":resources.stats.imports,"stats":stats.duplicate(),"error":error,"instances":instances}
