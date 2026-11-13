var private_camera_probe: Dictionary={}

func private_camera_probe_admit(message: Dictionary,view: Dictionary) -> bool:
	if str(args.get("camera-motion-probe",""))!="true" or str(args.get("offline-replay",""))!="true":return false
	var probe: Variant=view.get("camera_probe")
	var problem:=""
	if not probe is Dictionary:problem="probe metadata missing"
	elif not is_instance_valid(world) or int(message.get("generation",-1))!=epoch or int(message.get("areaId",-1))!=world.area_id or not world.ready_for_control():problem="world scope/readiness changed"
	elif not is_instance_valid(controller) or controller.follow_state==null:problem="camera owner unavailable"
	elif view.size()!=2 or not view.get("camera_state") is Dictionary or view.camera_state.size()!=1 or not view.camera_state.has("yaw") or not is_finite(float(view.camera_state.yaw)):problem="camera-only yaw request required"
	elif not (probe.get("sequence") is int or probe.get("sequence") is float) or not is_finite(float(probe.sequence)) or float(probe.sequence)!=floor(float(probe.sequence)) or int(probe.sequence)<1 or int(probe.sequence)>2500 or not probe.get("observe") is bool:problem="invalid bounded request"
	elif str(probe.get("phase","")) not in ["bind","prewarm","warm-restored","measure-start","measure","measure-end","restored"]:problem="unsupported phase"
	if problem.is_empty():
		var actual: Dictionary=observed_camera_snapshot()
		var current: Dictionary=actual.get("controlled",{})
		if current.is_empty() or bool(current.get("active",true)) or int(current.get("script",-1))!=0 or bool(current.get("driveHeld",true)):problem="actor no longer idle"
		elif private_camera_probe.is_empty():
			var expected: Variant=probe.get("expected")
			if str(probe.phase)!="bind" or not expected is Dictionary:problem="initial binding required"
			elif int(expected.get("actorId",-1))!=int(current.actor_id) or int(expected.get("lifetime",-1))!=int(current.lifetime) or int(expected.get("generation",-1))!=epoch or int(expected.get("areaId",-1))!=world.area_id or int(expected.get("connection",-1))!=session_connection:problem="actor binding differs"
			else:
				private_camera_probe={"connection":session_connection,"generation":epoch,"areaId":world.area_id,"actor":int(current.actor_id),"lifetime":int(current.lifetime),"origin":current.get("received_position",[]).duplicate(),"sequence":0,"observations":0,"pending":0,"commands":0}
				report.camera_probe_native={"commands":0,"observations":0,"scope":"Private offline camera-only diagnostic; Engine process frames are not displayed/GPU frame measurements."}
		else:
			if int(private_camera_probe.connection)!=session_connection or int(private_camera_probe.generation)!=epoch or int(private_camera_probe.areaId)!=world.area_id or int(private_camera_probe.actor)!=int(current.actor_id) or int(private_camera_probe.lifetime)!=int(current.lifetime):problem="actor lifetime/scope changed"
		if problem.is_empty():
			if int(probe.sequence)!=int(private_camera_probe.sequence)+1:problem="request order differs"
			elif not private_camera_probe_position_equal(current.get("received_position",[]),private_camera_probe.origin) or not private_camera_probe_position_equal(current.get("position",[]),private_camera_probe.origin) or not private_camera_probe_position_equal(current.get("render",[]),private_camera_probe.origin):problem="actor authority/presentation changed"
	if not problem.is_empty():
		send({"kind":"camera-probe-error","reason":problem});return false
	private_camera_probe.sequence=int(probe.sequence);private_camera_probe.commands+=1
	report.camera_probe_native.commands=private_camera_probe.commands
	if bool(probe.observe):
		if int(private_camera_probe.observations)+int(private_camera_probe.pending)>=256 or int(private_camera_probe.pending)>=3:
			send({"kind":"camera-probe-error","reason":"observation bound exceeded"});return false
		private_camera_probe.pending+=1
		private_camera_probe_observe.call_deferred(int(probe.sequence),str(probe.phase),float(view.camera_state.yaw))
	return true

func private_camera_probe_position_equal(a: Variant,b: Variant) -> bool:
	if not a is Array or not b is Array or a.size()!=3 or b.size()!=3:return false
	for i in 3:
		if not is_finite(float(a[i])) or not is_finite(float(b[i])) or absf(float(a[i])-float(b[i]))>0.02:return false
	return true

func private_camera_probe_observe(sequence: int,phase: String,requested_yaw: float) -> void:
	await process_frame
	await process_frame
	if private_camera_probe.is_empty():return
	private_camera_probe.pending-=1
	if closing:return
	if not is_instance_valid(world) or epoch!=int(private_camera_probe.generation) or world.area_id!=int(private_camera_probe.areaId) or session_connection!=int(private_camera_probe.connection):
		send({"kind":"camera-probe-error","reason":"observation scope retired"});return
	var snapshot: Dictionary=world.snapshot(false)
	if not snapshot.get("object_visuals_complete",false) or not world.ready_for_control():
		send({"kind":"camera-probe-error","reason":"world became incomplete"});return
	var actual: Dictionary=observed_camera_snapshot()
	private_camera_probe.observations+=1;report.camera_probe_native.observations=private_camera_probe.observations
	var sample:={"kind":"camera-probe-observed","sequence":sequence,"phase":phase,"requested_yaw":requested_yaw,"generation":epoch,"areaId":world.area_id,"process_frames":Engine.get_process_frames(),"ticks_usec":Time.get_ticks_usec(),"camera":actual,"object_visuals_complete":true,"pending_batches":int(snapshot.get("pending_batches",-1)),"entities":int(snapshot.get("entities",-1))}
	if phase=="measure-start":
		report.camera_probe_native.begin_process_frames=sample.process_frames;report.camera_probe_native.begin_ticks_usec=sample.ticks_usec
	if phase=="measure-end":
		report.camera_probe_native.end_process_frames=sample.process_frames;report.camera_probe_native.end_ticks_usec=sample.ticks_usec
		if report.camera_probe_native.has("begin_process_frames"):
			report.camera_probe_native.frames_delta=int(sample.process_frames)-int(report.camera_probe_native.begin_process_frames)
			report.camera_probe_native.elapsed_usec=int(sample.ticks_usec)-int(report.camera_probe_native.begin_ticks_usec)
			report.camera_probe_native.average_fps=float(report.camera_probe_native.frames_delta)*1000000.0/float(report.camera_probe_native.elapsed_usec) if report.camera_probe_native.elapsed_usec>0 else 0.0
	send(sample)
