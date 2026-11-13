extends SceneTree

const Motion=preload("res://systems/network_motion.gd")
var checks:=0
var failures: Array=[]

func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)

func moving(motion,id: int,point:=Vector3.ZERO) -> Dictionary:
	var state: Dictionary=motion.ensure(id,{"position":point,"animation":2,"walkRate":1000.0,"runRate":1000.0})
	state.path=[point+Vector3(10,0,0)]
	state.active=true
	state.script=1
	state.newPath=0
	return state

func dispose(motion) -> void:
	for connection: Dictionary in motion.positions_changed.get_connections():
		motion.positions_changed.disconnect(connection.callable)
	motion.facing_target_query=Callable()

func notification_contract() -> void:
	var motion=Motion.new()
	var a:=moving(motion,1,Vector3(9.95,2,3))
	var b:=moving(motion,2,Vector3(5,7,4))
	a.render=a.position-Vector3(0.5,0.25,1)
	a.correction=512
	var batches: Array=[]
	var retained: Array=[]
	motion.positions_changed.connect(func(rows: Array):
		check(a.facingTurn==null and b.facingTurn==null,"batch follows all existing facing updates")
		check(rows.size()==2,"one changed row per moving actor")
		for row: Dictionary in rows:
			check(row.size()==6 and row.has_all(["id","lifetime","motion_lifetime","motion_epoch","update","native_position"]),"detached scalar row shape")
			check(motion.position_change_is_current(row),"current row accepted synchronously")
			check(row.native_position==motion.objects[row.id].position,"row uses exact logical native position")
			check(not row.has("state") and not row.has("render"),"row exposes no mutable motion state")
		batches.append(rows.duplicate(true))
		retained.assign(rows.duplicate(true))
	)
	for i in 3:
		a.facingTurn=999
		b.facingTurn=999
		motion.update(0.1)
		check(batches.size()==i+1,"one immediate batch per update without another packet")
		check(not motion.position_change_is_current(retained[0]),"retained row rejected outside callback")
	check(batches[0][0].native_position.x>10.0,"local simulation crosses native tile seam")
	check(batches[0][0].native_position!=a.render,"native row is distinct from correction render position")
	check(batches[0][0].native_position.z==3.0 and batches[0][0].native_position.y==2.0,"native XYZ preserved before pose axis conversion")
	check(batches[0][0].native_position!=motion.pose(1).position,"Godot pose is not the native coordinate payload")
	check(batches[0][0].native_position!=batches[2][0].native_position,"prior payload stays detached from later updates")
	check(batches[0][0].update<batches[1][0].update and batches[1][0].update<batches[2][0].update,"batch revisions advance")
	dispose(motion)

func quiet_paths() -> void:
	var motion=Motion.new()
	var batches: Array=[]
	var state:=moving(motion,1)
	motion.positions_changed.connect(func(rows: Array):batches.append(rows))
	motion.update(0.0)
	check(batches.is_empty(),"zero elapsed with unchanged position is quiet")
	state.walkRate=0.0
	motion.update(0.1)
	check(batches.is_empty(),"zero distance path is quiet")
	state.active=false
	motion.update(0.1)
	check(batches.is_empty(),"idle path is quiet")
	state.render=Vector3(-1,0,0)
	state.correction=512
	var prior_render: Vector3=state.render
	motion.update(0.1)
	check(state.render!=prior_render and state.position==Vector3.ZERO,"correction-only path still updates render")
	check(batches.is_empty(),"correction-only render update emits no native position")
	motion.observe(1,{"position":[2,3,4]})
	check(batches.is_empty(),"incoming packet keeps its existing distinct publication boundary")
	motion.update(0.1)
	check(batches.is_empty(),"packet correction interpolation emits no logical path event")
	motion.update(-1.0)
	motion.update(NAN)
	motion.update(INF)
	check(batches.is_empty(),"invalid elapsed input is quiet")
	dispose(motion)

func physical_reentry() -> void:
	var motion=Motion.new()
	moving(motion,1)
	moving(motion,2)
	var old_rows: Array=[]
	var accepted: Array=[]
	var replace: Array=[true]
	motion.positions_changed.connect(func(rows: Array):
		if not replace[0]:return
		replace[0]=false
		old_rows.assign(rows.duplicate(true))
		var stale: Dictionary=rows[1]
		motion.objects.erase(2)
		var replacement:=moving(motion,2,stale.native_position)
		replacement.lifetime=stale.lifetime
		check(replacement._position_notification_lifetime!=stale.motion_lifetime,"same received lifetime gets fresh local physical token")
	)
	motion.positions_changed.connect(func(rows: Array):
		var ids: Array=[]
		for row: Dictionary in rows:
			if motion.position_change_is_current(row):ids.append(row.id)
		accepted.append(ids)
	)
	motion.update(0.1)
	check(accepted==[[1]],"earlier listener removal and reentry invalidates later stale row")
	motion.update(0.1)
	check(accepted==[[1],[1,2]],"replacement can publish its next actual path step")
	check(not motion.position_change_is_current(old_rows[1]),"removed physical row remains stale")
	var duplicate_motion=Motion.new()
	moving(duplicate_motion,1)
	var seen: Array=[]
	duplicate_motion.positions_changed.connect(func(rows: Array):
		var old: Dictionary=duplicate_motion.objects[1]
		duplicate_motion.objects[1]=old.duplicate(true)
		check(duplicate_motion.objects[1]._position_notification_lifetime==rows[0].motion_lifetime,"duplicate fixture deliberately retains local token")
	)
	duplicate_motion.positions_changed.connect(func(rows: Array):seen.append(duplicate_motion.position_change_is_current(rows[0])))
	duplicate_motion.update(0.1)
	check(seen==[false],"physical Dictionary identity required even with matching token and position")
	dispose(motion)
	dispose(duplicate_motion)

func reconnect() -> void:
	var motion=Motion.new()
	moving(motion,1)
	var replace: Array=[true]
	var stale_rows: Array=[]
	var accepted: Array=[]
	motion.positions_changed.connect(func(rows: Array):
		if not replace[0]:return
		replace[0]=false
		stale_rows.assign(rows.duplicate(true))
		var saved: Dictionary=motion.objects[1].duplicate(true)
		motion.configure([{"id":1,"state":saved}])
		check(motion.objects[1]._position_notification_lifetime!=saved._position_notification_lifetime,"configure rejects saved private identity")
		check(not motion.position_change_is_current(rows[0]),"reconnect invalidates in-flight old epoch")
	)
	motion.positions_changed.connect(func(rows: Array):
		accepted.append(motion.position_change_is_current(rows[0]))
		if rows[0].motion_epoch!=stale_rows[0].motion_epoch:
			check(not motion.position_change_is_current(stale_rows[0]),"old epoch row rejected inside new emission")
	)
	motion.update(0.1)
	motion.update(0.1)
	check(accepted==[false,true],"only new connection state publishes after configure")
	dispose(motion)

func nested_updates() -> void:
	var motion=Motion.new()
	moving(motion,1)
	var reenter: Array=[true]
	var current: Array=[]
	var revisions: Array=[]
	motion.positions_changed.connect(func(_rows: Array):
		if reenter[0]:
			reenter[0]=false
			motion.update(0.1)
	)
	motion.positions_changed.connect(func(rows: Array):
		current.append(motion.position_change_is_current(rows[0]))
		revisions.append(rows[0].update)
	)
	motion.update(0.1)
	check(current==[true,false],"nested update accepts nested batch and invalidates remaining outer batch")
	check(revisions.size()==2 and revisions[0]>revisions[1],"nested update owns newer revision")
	var detached=Motion.new()
	moving(detached,1)
	var callback: Array=[]
	callback.append(func(rows: Array):
		detached.positions_changed.disconnect(callback[0])
		detached.update(0.0)
		check(not detached.position_change_is_current(rows[0]),"reentrant update invalidates outer revision after all listeners disconnect")
	)
	detached.positions_changed.connect(callback[0])
	detached.update(0.1)
	callback.clear()
	dispose(motion)
	dispose(detached)

func callbacks_before_emission() -> void:
	var motion=Motion.new()
	var state:=moving(motion,1)
	state.facingTarget=2
	var batches: Array=[]
	motion.positions_changed.connect(func(rows: Array):batches.append(rows))
	motion.facing_target_query=func(_id):
		state.position+=Vector3(1,0,0)
		return Vector3(0,2,0)
	motion.update(0.1)
	check(batches.is_empty(),"later simulation callback mutation cannot masquerade as captured path position")
	var swapped=Motion.new()
	var old:=moving(swapped,1)
	old.facingTarget=2
	swapped.positions_changed.connect(func(rows: Array):batches.append(rows))
	swapped.facing_target_query=func(_id):
		swapped.objects[1]=old.duplicate(true)
		return Vector3(0,2,0)
	swapped.update(0.1)
	check(batches.is_empty(),"physical replacement before emission discards old pending path row")
	dispose(motion)
	dispose(swapped)

func detached_rows() -> void:
	var motion=Motion.new()
	moving(motion,1)
	motion.positions_changed.connect(func(rows: Array):
		var native_point: Vector3=motion.objects[1].position
		rows[0].native_position=Vector3(99,99,99)
		check(motion.objects[1].position==native_point,"row mutation cannot mutate motion position")
		check(not motion.position_change_is_current(rows[0]),"mutated row position rejected")
		rows[0].native_position=native_point
		rows[0].lifetime=-1
		check(not motion.position_change_is_current(rows[0]),"mutated ordinary lifetime rejected")
		rows.clear()
		check(motion.objects.size()==1,"batch mutation cannot alter motion object store")
	)
	motion.update(0.1)
	dispose(motion)

func math_preserved() -> void:
	var quiet=Motion.new()
	var observed=Motion.new()
	var left:=moving(quiet,1,Vector3(1,2,3))
	var right:=moving(observed,1,Vector3(1,2,3))
	left.script=0
	right.script=0
	left.render=Vector3(0,1,2)
	right.render=Vector3(0,1,2)
	left.correction=512
	right.correction=512
	observed.positions_changed.connect(func(_rows: Array):pass)
	for quantum in [0.0,0.001,0.016,0.1,0.5,2.0,8.0,0.1]:
		quiet.update(quantum)
		observed.update(quantum)
		for key in ["position","render","path","cursor","active","acceleration","correction","orientation","facingTurn","gait","finished"]:
			check(left.get(key)==right.get(key),"listener presence preserves existing motion math/%s/%s"%[quantum,key])
	dispose(quiet)
	dispose(observed)

func _initialize() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):
		quit(2)
		return
	notification_contract()
	quiet_paths()
	physical_reentry()
	reconnect()
	nested_updates()
	callbacks_before_emission()
	detached_rows()
	math_preserved()
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Immediate local native-position boundary, exact physical lifetime/epoch/revision and callback reentrancy; no Runtime, assets, server, GPU or FPS acceptance"}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
