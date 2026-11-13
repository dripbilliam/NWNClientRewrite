extends SceneTree
# Bounded headless component A/B: a completed one-shot owner stays scheduled
# because its authored skin and attachment still require publication.
const Current=preload("res://systems/model_rigs.gd")
const Candidate=preload("res://tools/nwn65/seek_restore/model_rigs_seek.gd")
var checks:=0
var failures: Array=[]
var output:=""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func make(skip: bool) -> Dictionary:
	var host:=Node3D.new();root.add_child(host)
	var rigs=(Candidate if skip else Current).new();host.add_child(rigs);rigs.set_process(false)
	rigs.use_native_skin_publisher=false
	var log: Array=[]
	rigs.model_event.connect(func(id,index,name,serial):log.append([id,index,name,serial]))
	var defaults: Array=[{"position":[0,0,0],"quaternion":[1,0,0,0],"scale":[1,1,1]}]
	var clip:={"name":"motion","length":0.5,"transition":0.0,"events":[{"time":0.25,"name":"step"}],"tracks":[{"part":0,"property":"position","sourceInterpolation":"linear","keys":[{"time":0.0,"value":[0,0,0]},{"time":0.5,"value":[1,2,3]}]}]}
	var asset:={"defaults":defaults,"unsupported":[],"clips":[clip]}
	var rows: Array=[]
	for index in 12:
		var owner:=Node3D.new();rigs.add_child(owner)
		var node:=Node3D.new();owner.add_child(node)
		var held:=Node3D.new();owner.add_child(held)
		var skeleton:=Skeleton3D.new();owner.add_child(skeleton);skeleton.add_bone("root")
		var nodes: Array[Node3D]=[node,held]
		var binding:={"parts":[0],"defaults":defaults,"follow":true,"clip":"motion","loop":false,"speed":1.0,"time":0.0}
		var model: Dictionary=rigs._model(owner,nodes,binding,asset)
		model.event_source=true
		var entry:={"root":owner,"nodes":nodes,"parents":[-1,-1],"models":[model],"animated_models":[0],"manual_poses":{},"attachments":[{"node":1,"anchor":0,"scale":[1,1,1],"flags":0}],"skins":[{"part":0,"bones":[0],"skeleton":skeleton}],"counts":{}}
		rigs.entities[index+1]=entry
		rows.append({"model":model,"node":node,"held":held,"skeleton":skeleton})
	for frame in 8:rigs._update(0.125)
	return {"host":host,"rigs":rigs,"rows":rows,"log":log}

func state(row: Dictionary) -> Array:
	var result: Array=[row.log.duplicate(true),row.rigs.is_processing()]
	for item in row.rows:
		var model: Dictionary=item.model
		var player: AnimationPlayer=model.player
		result.append([model.clip,model.last_time,model.play_serial,model.dormant_finished,player.is_playing(),player.current_animation,player.current_animation_position,player.get_queue(),item.node.transform,item.held.transform,item.skeleton.get_bone_pose(0)])
	return result

func median(values: Array) -> int:
	values.sort();return values[int(values.size()/2)]

func leg(skip: bool,tag: String) -> Dictionary:
	var row:=make(skip)
	var samples: Array=[]
	for frame in 160:
		var began:=Time.get_ticks_usec();row.rigs._update(1.0/60.0)
		if frame>=16:samples.append(Time.get_ticks_usec()-began)
	var result:={"tag":tag,"skip":skip,"median_us":median(samples),"state":var_to_bytes(state(row)).hex_encode(),"finished":row.rows.all(func(item):return item.model.dormant_finished and not item.model.player.is_playing())}
	for index in 12:row.rigs.forget_entity(index+1)
	row.host.free()
	return result

func run() -> void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var original:=make(false);var candidate:=make(true)
	check(original.rigs.is_processing() and candidate.rigs.is_processing(),"skin and attachment keep both owners scheduled")
	for frame in 24:
		if frame==8:
			for row in [original,candidate]:
				row.rigs._play(row.rows[0].model,"motion",false,1.0,0.0,true)
		if frame==16:
			for row in [original,candidate]:
				row.rows[1].model.player.play("clip_0")
		original.rigs._update(0.125);candidate.rigs._update(0.125)
		check(var_to_bytes(state(original))==var_to_bytes(state(candidate)),"completed pose/clock/event/attachment/skin and restart parity frame %d"%frame)
	for row in [original,candidate]:
		row.rows[2].model.player.seek(0.125,true)
		row.rows[3].model.player.queue("clip_0")
	for frame in 8:
		original.rigs._update(0.125);candidate.rigs._update(0.125)
		var old_state:=state(original);var new_state:=state(candidate)
		if frame==0 and var_to_bytes(old_state)!=var_to_bytes(new_state):
			for index in old_state.size():
				if var_to_bytes(old_state[index])!=var_to_bytes(new_state[index]):print("DIFF ",index," old=",var_to_str(old_state[index])," new=",var_to_str(new_state[index]))
		check(var_to_bytes(old_state)==var_to_bytes(new_state),"external stopped seek and queued replay parity frame %d"%frame)
	for row in [original,candidate]:row.rows[4].node.position=Vector3(7,8,9)
	original.rigs._update(0.125);candidate.rigs._update(0.125)
	check(var_to_bytes(state(original))==var_to_bytes(state(candidate)),"external authored node edit after one-shot completion remains identical")
	for row in [original,candidate]:
		for index in 12:row.rigs.forget_entity(index+1)
		row.host.free()
	var legs: Array=[]
	for pair in [[false,"A1"],[true,"B1"],[true,"B2"],[false,"A2"]]:
		legs.append(leg(pair[0],pair[1]));await process_frame
	for item in legs:check(item.finished,"all one-shots completed in %s"%item.tag)
	for item in legs:check(item.state==legs[0].state,"final state matches %s"%item.tag)
	var report:={"issue":"NWN-65","passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":FileAccess.get_sha256("res://systems/model_rigs.gd"),"legs":legs.map(func(item):return {"tag":item.tag,"skip":item.skip,"median_us":item.median_us,"finished":item.finished}),"scope":"Synthetic actual AnimationPlayer one-shot with skin and attachment; exact completed/restart pose, event, clock, skin and transform state plus headless component A/B. No original asset, GPU, scene or FPS claim."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
