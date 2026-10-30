extends SceneTree
const NativeEntry=preload("res://native_session_world.gd")
const Names=preload("res://systems/native_data/object_animation.gd")
const Rigs=preload("res://systems/model_rigs.gd")
const Combat=preload("res://systems/combat_animation.gd")
const Store=preload("res://systems/native_data/preparation_store.gd")
const Targets=preload("res://systems/native_render/transition_targets.gd")
const Registry=preload("res://systems/entity_registry.gd")
var checks:=0
var failures: Array=[]
var measurements: Dictionary={}
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func gait_check() -> void:
	var physical:=Node3D.new(); root.add_child(physical)
	var rigs:=Rigs.new(); physical.add_child(rigs); rigs.set_process(false)
	var context:={"fieldDE":1,"fieldDD":1,"fieldDF":2,"fieldE0":0}
	var defaults:=[{"position":[0,0,0],"quaternion":[0,0,0,1],"scale":[1,1,1]}]
	var clip:={"name":"run","length":0.1,"transition":0.0,"events":[],"tracks":[{"part":0,"property":"position","keys":[{"time":0.0,"value":[0,0,0]},{"time":0.1,"value":[0,1,0]}]}]}
	var mapping: Dictionary={}
	for code in [2,3,4,78,79,84,85,86,87]: mapping[str(code)]="run"
	var source:={"id":1,"context":context,"nodes":[{"name":"root","parent":-1,"position":[0,0,0],"quaternion":[0,0,0,1],"scale":[1,1,1]}],"models":[{"asset":0,"parts":[0],"follow":true,"clip":"run","loop":true}],"clipMap":mapping}
	var registry:={"meshes_by_name":{}}
	rigs.configure(registry,{1:physical},{"rigs":{"version":1,"assets":[{"name":"authored","defaults":defaults,"clips":[clip]}],"entities":[source]},"meshes":[]})
	var combat:=Combat.new(); combat.configure(rigs,{1:physical}); combat.actors[1]={"id":1,"lifetime":1,"objectType":5}
	for code in [2,3,4,78,79,84,85,86,87]:
		combat.base_frame(1,code,1.0)
		var moving:=false; var previous: Vector3=rigs.entities[1].nodes[0].position
		for _frame in 60:
			combat.base_frame(1,code,1.0); rigs._update(0.025)
			var current: Vector3=rigs.entities[1].nodes[0].position
			if _frame>40 and current.distance_to(previous)>0.01: moving=true
			previous=current
		var model: Dictionary=rigs.entities[1].models[0]
		check(model.loop and model.player.is_playing() and moving,"Unchanged gait "+str(code)+" keeps actually animating after fifteen complete clip lengths")
		var serial:=int(model.play_serial); combat.base_frame(1,code,0.75)
		check(int(model.play_serial)==serial and model.player.speed_scale==0.75,"Held gait speed changes preserve phase without restarting "+str(code))
	combat.reset(); rigs.forget_entity(1); physical.free()
func hold_metadata(store,started: Semaphore,release: Semaphore) -> void:
	store.mutex.lock(); started.post()
	var deadline:=Time.get_ticks_msec()+1000
	while not release.try_wait() and Time.get_ticks_msec()<deadline: OS.delay_msec(1)
	store.mutex.unlock()
func cache_check() -> void:
	var store:=Store.new(); store.maximum_entries=1; var epoch:=store.generation()
	store.save_data("one","a",{"values":[{"x":1}]},epoch)
	var initial:=store.snapshot(); var started:=Semaphore.new(); var release:=Semaphore.new()
	var worker:=WorkerThreadPool.add_task(hold_metadata.bind(store,started,release),false,"Controlled model metadata lock")
	started.wait(); var began:=Time.get_ticks_usec(); var busy:=store.snapshot(); var elapsed:=(Time.get_ticks_usec()-began)/1000.0
	release.post(); WorkerThreadPool.wait_for_task_completion(worker)
	check(busy.metadata_busy and busy.entries==initial.entries and elapsed<250,"Frame diagnostics return the last metadata snapshot without waiting for a held worker lock")
	measurements.metadata_observer_ms=elapsed
	store.save_data("two","b",{"values":[{"x":2}]},epoch)
	check(store.load_data("one",epoch).is_empty() and store.snapshot().evictions==1,"Evicted model request bindings cannot alias a newer cached resource")
	var copy:=store.load_data("two",epoch); copy.values[0].x=9
	check(store.load_data("two",epoch).values[0].x==2,"A caller still receives private prepared model data")
	store.clear(); store.save_data("late","c",{"x":3},epoch)
	check(store.snapshot().entries==0 and store.generation()!=epoch,"Catalog reset rejects an old worker publication")
func trigger(id: int=7) -> Dictionary:
	return {"id":id,"objectType":7,"areaId":42,"replicated":{"hasTransition":true,"isTrap":false,"vertices":[[0,0,0],[2,0,0],[2,2,0],[1,1,0],[0,2,0]]}}
func transition_check() -> void:
	var host:=Node3D.new(); root.add_child(host); var registry:=Registry.new(); host.add_child(registry)
	var targets:=Targets.new(); host.add_child(targets); targets.configure(registry,42)
	var object:=trigger(); var before:=JSON.stringify(object)
	check(targets.receive([object]) and registry.eligible_ids().has(7),"Server transition polygon enters actual Tab-eligible selection without a streamed model")
	check(JSON.stringify(object)==before and not targets.receive([object],[],true),"Unchanged trigger snapshots preserve source data and reuse the existing selection target")
	var visual=targets.instances[7].meshes[0]; registry.mark([7])
	check(visual.material_overlay!=null and registry.marked.has(7),"Normal registry highlighting applies to the transition surface")
	registry.mark([]); check(visual.material_overlay==null,"Releasing Tab removes the transition highlight")
	var destination: Array=registry.entities[7].destination
	check(Geometry2D.is_point_in_polygon(Vector2(destination[0],destination[1]),PackedVector2Array([Vector2(0,0),Vector2(2,0),Vector2(2,2),Vector2(1,1),Vector2(0,2)])),"Click approach point lies inside the actual concave transition polygon")
	var camera:=Camera3D.new(); host.add_child(camera); camera.current=true; camera.position=Vector3(destination[0],5,-destination[1]); camera.look_at(Vector3(destination[0],0,-destination[1]),Vector3.FORWARD)
	await physics_frame; await physics_frame
	var hit: Dictionary=registry.pick(camera,camera.unproject_position(Vector3(destination[0],0.05,-destination[1])))
	check(hit.get("id",-1)==7 and hit.entity.type==7,"A real physics hover ray picks the server transition polygon")
	check(targets.receive([], [7],true) and not registry.eligible_ids().has(7),"Delta removal unregisters the transition immediately")
	object=trigger(8); object.replicated.isTrap=true
	check(not targets.receive([object],[],true) and not registry.entities.has(8),"A server trap is not promoted to an area transition")
	targets.receive([trigger(9)],[],true); targets.receive([],[],false)
	check(targets.objects.is_empty() and not registry.entities.has(9),"A full snapshot removes omitted transition targets")
	targets.close(); check(not targets.receive([trigger()]),"Retired transition owner rejects late snapshots")
	host.free(); await process_frame
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var path:="res://../backups/animations/native-object-animation-name-observations.json"
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(corpus.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and corpus.cases.size()==1281,"Original object animation-name corpus and target hash")
	for row in corpus.cases: check(Names.name(int(row.type),int(row.id),int(row.doorDestroyed))==str(row.value),"Original object animation selector "+str(row.type)+"/"+str(row.id)+"/"+str(row.doorDestroyed))
	gait_check(); cache_check(); await transition_check()
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"measurements":measurements,"originalSelectorSha256":FileAccess.get_sha256(path),"scope":"Original1281 selector cases; actual AnimationPlayer repeated-gait cycles; controlled worker contention/cache isolation; actual transition physics/highlight registry. No real server or graphical acceptance."},"\t")); file.close(); print("NATIVE_PLAYABILITY_REGRESSIONS ",checks," checks"); quit(0 if failures.is_empty() else 1)
