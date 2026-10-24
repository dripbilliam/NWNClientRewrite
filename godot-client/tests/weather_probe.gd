extends "res://tests/camera_mode_probe.gd"
var phases: Array = []
var render_samples: Array = []
func environment_owner(): return client.owner_scene.environment_owner
func weather_rows() -> Array: return client.particles.rows.values().filter(func(row):return row.has("weatherModel"))
func populated() -> bool:
	return weather_rows().size() == 24 and weather_rows().all(func(row):return client.particles.surfaces[int(row.id)].vertex_count > 0)
func render_sample(path: String) -> Dictionary:
	var viewport := SubViewport.new();viewport.size = Vector2i(640,360);viewport.world_3d = client.owner_scene.camera.get_world_3d();viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;client.add_child(viewport)
	var camera := Camera3D.new();viewport.add_child(camera)
	var original: Camera3D = client.owner_scene.camera
	camera.global_transform = original.global_transform;camera.fov = original.fov;camera.near = original.near;camera.far = original.far;camera.cull_mask = 0;camera.make_current()
	await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
	var background := viewport.get_texture().get_image()
	camera.cull_mask = 2
	await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var changed := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y) != background.get_pixel(x,y): changed += 1
	var saved := image.save_png(path) == OK
	viewport.queue_free();await client.get_tree().process_frame
	return {"changedPixels":changed,"saved":saved,"screenshot":path,"models":environment_owner().weather_world.snapshot(),"emitters":weather_rows().size(),"vertices":weather_rows().reduce(func(sum,row):return sum+client.particles.surfaces[int(row.id)].vertex_count,0)}
func run(owner,message: Dictionary) -> void:
	client = owner;connection = client.connection
	check(await wait_until(func():return environment_owner().weather_revision >= 0),"Initial native area weather metadata reaches the admitted world")
	var first := true
	for row in [["rain",1,true],["snow",2,true],["clear",0,true],["rain",1,true],["clear",0,true]]:
		var revision: int = environment_owner().weather_revision
		var before: int = client.chat_ui.rows.size()
		client.command({"kind":"chat","channel":1,"text":"-native-weather-"+row[0]})
		var received := await wait_until(func():return environment_owner().weather_revision > revision and client.chat_ui.rows.slice(before).any(func(v):return str(v.get("rich",{}).get("text",v.get("text",""))) == "GODOT_WEATHER_"+str(row[0]).to_upper()),12)
		check(received,"Actual server acknowledges weather "+row[0])
		if not received: break
		var weather = environment_owner().weather
		check(weather.target == (row[1] if row[2] else 0),"Received weather sets native desired type "+row[0])
		if first:
			first = false
			check(await wait_until(func():return weather.remaining < 5900 and weather.remaining > 0 and weather.intensity > 0 and weather.intensity < 100,3),"Original fade advances over native frames instead of jumping to full rain")
		var completed := await wait_until(func():return weather.remaining == 0,9)
		check(completed and weather.current == (row[1] if row[2] else 0) and weather.intensity == (100 if row[1] != 0 and row[2] else 0),"Native weather transition reaches endpoint "+row[0])
		check(weather.instances == (6 if row[1] != 0 and row[2] else 0),"Six original weather-model instances are planned or retired for "+row[0])
		if row[1] != 0:
			var ready := await wait_until(func():return is_instance_valid(environment_owner().weather_world) and environment_owner().weather_world.models.size() == 6 and environment_owner().weather_world.particle_ready and populated(),12)
			check(ready,"Six actual original models and24 independent emitters produce vertices for "+row[0])
			if ready:
				var render := await render_sample(str(message.screenshot).get_basename()+"-"+str(phases.size())+"-"+row[0]+".png")
				render_samples.append(render)
				check(render.changedPixels >= 16 and render.saved,"Weather-only native Vulkan pass draws original "+row[0]+" bitmap pixels")
				check(environment_owner().weather_world.stats.failures == 0,"Native original weather clips sample without missing-controller fallbacks")
		else:
			check(await wait_until(func():return is_instance_valid(environment_owner().weather_world) and environment_owner().weather_world.models.is_empty() and weather_rows().is_empty()),"Clear retires all actual native weather models and particle surfaces")
		phases.append({"type":row[1],"enabled":row[2],"revision":environment_owner().weather_revision,"acknowledged":received,"state":weather.snapshot()})
	var first_renderer: Dictionary = environment_owner().weather_world.snapshot() if is_instance_valid(environment_owner().weather_world) else {}
	# Leave actual rain alive during replacement, then quit with live rain on
	# return. Old model/surface owners must not survive either world boundary.
	client.command({"kind":"chat","channel":1,"text":"-native-weather-rain"})
	check(await wait_until(func():return is_instance_valid(environment_owner().weather_world) and environment_owner().weather_world.current_type == 1 and populated(),12),"Actual rain is running before whole-world replacement")
	for destination in ["-native-b","-native-a"]:
		var old_area: int = client.area_id;var old_generation: int = client.generation
		var old_weather: WeakRef = weakref(environment_owner().weather_world)
		var old_models: Array = environment_owner().weather_world.models.values().map(func(model):return weakref(model))
		client.command({"kind":"chat","channel":1,"text":destination})
		var arrived := await wait_until(func():return client.world_scope.admitted and client.area_id != old_area and client.generation > old_generation and client.following and client.smoke_frame_complete,30)
		check(arrived,"Actual native world admits weather transition "+destination)
		if not arrived: break
		check(old_weather.get_ref() == null and old_models.all(func(ref):return ref.get_ref() == null),"All old weather models/owners release during "+destination)
		if destination == "-native-b": client.command({"kind":"chat","channel":1,"text":"-native-weather-snow"})
		var expected := 2 if destination == "-native-b" else 1
		var ready := await wait_until(func():return is_instance_valid(environment_owner().weather_world) and environment_owner().weather_world.current_type == expected and populated(),15)
		check(ready,"Fresh native world renders its own original precipitation "+destination)
		transitions.append({"areaId":client.area_id,"generation":client.generation,"ready":ready,"oldModelsAlive":old_models.filter(func(ref):return ref.get_ref() != null).size(),"oldWeatherAlive":old_weather.get_ref() != null,"renderer":environment_owner().weather_world.snapshot() if is_instance_valid(environment_owner().weather_world) else null})
	var complete := phases.size() == 5 and transitions.size() == 2 and checks.all(func(v):return v.passed)
	if valid(): client.command({"kind":"weather-tested","result":{"completed":complete,"checks":checks,"phases":phases,"renderSamples":render_samples,"firstRenderer":first_renderer,"transitions":transitions,"renderer":environment_owner().weather_world.snapshot() if is_instance_valid(environment_owner().weather_world) else null,"renderingRequired":true,"presentationPending":true,"scope":"Actual local SetWeather packets, six original-model instances, original frozen clip/controller sampling, weather-only Vulkan pixels and live weather A-B-A retirement; thunder/native pause timing/full weather parity pending"}})
