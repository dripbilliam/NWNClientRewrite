extends "res://tests/native_scene_visibility_runtime_test.gd"
# Actual Runtime -> existing World.motion sparse simulation boundary. The
# canonical received DTO deliberately stays fixed between local native steps.
func moving(motion: RefCounted,id: int,point: Vector3) -> Dictionary:
	var state: Dictionary=motion.ensure(id,{"position":point,"animation":2,"walkRate":1000.0,"runRate":1000.0})
	state.path=[point+Vector3(10,0,0)];state.active=true;state.script=1;state.newPath=0
	return state
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var client:=Client.new();root.add_child(client);client.gameplay_ui=Ui.new();client.add_child(client.gameplay_ui);client.render_settings=Settings.new();client.add_child(client.render_settings)
	var runtime:=Runtime.new();runtime.configure(client)
	var first:=world(client);var motion=first.motion
	var controlled:=source(1,"controlled");var remote:=source(2,"remote")
	runtime.lifecycle(birth(1,"controlled"));runtime.lifecycle(birth(2,"remote"));admit(client,controlled);admit(client,remote)
	var state:=moving(motion,2,Vector3(9.95,5,3));state.render=Vector3(9,5,99);state.correction=512
	var retained: Array=[];var action:={"replace":false,"nested":false,"retire":false,"known_reentry":false}
	var early: Callable=func(rows: Array):
		retained.assign(rows.duplicate(true))
		if action.replace:
			action.replace=false;motion.objects.erase(2);moving(motion,2,rows[0].native_position)
		if action.known_reentry:
			action.known_reentry=false
			var fresh:=source(2,"remote-reentry",2);runtime.lifecycle(birth(2,"remote-reentry"));admit(client,fresh)
			motion.objects.erase(2);moving(motion,2,rows[0].native_position)
		if action.nested:action.nested=false;motion.update(.1)
		if action.retire:first.retiring=true
	motion.positions_changed.connect(early)
	check(runtime.receive(tile(1,controlled)) and runtime.accepted_world(data(client,[controlled,remote])).available,"Actual visibility owner binds actual existing World.motion")
	check(motion.positions_changed.get_connections().size()==2,"Runtime adds one immediate sparse listener beside existing listener")
	var events: int=runtime.snapshot().stats.position_events;var scans: int=runtime.snapshot().stats.world_scans
	for index in 3:
		motion.update(.1)
		check(runtime.snapshot().stats.position_events==events+index+1,"Local native path step reaches Runtime without another packet "+str(index))
		check(member(runtime.snapshot(),2).position_native==[state.position.x,state.position.y,state.position.z],"Reveal uses exact native XYZ from actual simulation "+str(index))
	check(state.position.x>10 and member(runtime.snapshot(),2).position_native[0]>10,"Continuous local path crosses native tile boundary")
	check(remote.replicated.position==[5.0,5.0,0.0] and state.render.z!=state.position.z,"Received position remains fixed while render height stays separate")
	check(runtime.snapshot().stats.world_scans==scans,"Sparse local simulation never enumerates canonical world")
	events=runtime.snapshot().stats.position_events;state.active=false;state.render=Vector3(0,0,99);state.correction=512
	var prior_render: Vector3=state.render;motion.update(.1)
	check(state.render!=prior_render and runtime.snapshot().stats.position_events==events,"Idle correction changes render only and emits no reveal position")
	motion.update(0);check(runtime.snapshot().stats.position_events==events,"Unchanged native position is quiet")
	runtime._motion_signal(retained,weakref(motion))
	check(runtime.snapshot().stats.position_events==events,"Retained simulation rows cannot be replayed outside synchronous emission")
	state=moving(motion,2,state.position);state.active=true;action.replace=true;motion.update(.1)
	check(runtime.snapshot().stats.position_events==events,"Earlier listener physical remove/reentry rejects stale in-flight native row")
	state=motion.objects[2];motion.update(.1)
	check(runtime.snapshot().stats.position_events==events+1,"New local physical state publishes its next genuine native step")
	events=runtime.snapshot().stats.position_events;action.nested=true;motion.update(.1)
	check(runtime.snapshot().stats.position_events==events+1 and member(runtime.snapshot(),2).position_native==[state.position.x,state.position.y,state.position.z],"Nested update accepts new revision and rejects superseded outer callback")
	events=runtime.snapshot().stats.position_events;action.known_reentry=true;motion.update(.1)
	check(runtime.snapshot().stats.position_events==events,"Same-ID received lifetime replacement rejects stale reference before accepted-world publication")
	var fresh: Dictionary=client.gameplay_ui.text.objects[2]
	check(runtime.accepted_world(data(client,[fresh])).available,"Canonical fresh lifetime explicitly rebinds at accepted-world boundary")
	motion.update(.1)
	check(runtime.snapshot().stats.position_events==events+1 and member(runtime.snapshot(),2).lifetime==Lifetime.token(fresh),"Reentered entity receives its next actual native step after admission")
	events=runtime.snapshot().stats.position_events;action.retire=true;motion.update(.1)
	check(runtime.snapshot().stats.position_events==events,"Earlier listener retirement fences immediate native motion callback")
	first.retiring=false;action.retire=false
	var next:=world(client,10,4);var transferred:=source(1,"controlled",3,10)
	runtime.lifecycle(birth(1,"controlled","retained",false));admit(client,transferred)
	check(runtime.receive(tile(2,transferred,4,10)) and runtime.accepted_world(data(client,[transferred])).available,"Area successor binds its own actual Motion owner")
	check(motion.positions_changed.get_connections().size()==1 and next.motion.positions_changed.get_connections().size()==1,"World rebind disconnects borrowed old motion callback")
	events=runtime.snapshot().stats.position_events;motion.update(.1)
	check(runtime.snapshot().stats.position_events==events,"Retired world's continuing simulation cannot touch successor visibility")
	runtime.close()
	check(next.motion.positions_changed.get_connections().is_empty(),"Runtime close disconnects current borrowed motion owner")
	motion.positions_changed.disconnect(early);early=Callable();retained.clear()
	release_world(first);release_world(next);client.world=null;client.free();await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual Runtime, World and NetworkMotion sparse native path steps; authored lifecycle, map and fixture native-clock inputs. Packet-free seam crossing, native/render/received separation, idle correction, exact synchronous physical-row guard, nested updates, ID reuse and retirement. No server, GPU, draw collector or full visibility parity claim."}
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("NATIVE_SCENE_VISIBILITY_MOTION ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
