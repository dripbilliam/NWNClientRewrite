extends "res://tests/native_projectile_lifetime_test.gd"
const Stream=preload("res://systems/native_render/object_stream.gd")
const LiveWorld=preload("res://systems/native_render/live_world.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
func door_row(index: int,animation: int,state: int) -> Dictionary:
	return {"id":77,"objectType":10,"areaId":42,"nativeLifetime":1,"replicated":{"doorType":0,"genericType":index,"animation":animation,"doorOpenState":state,"position":[2,3,0],"orientation":[0,1,0],"hasTransition":true}}
func transforms(door) -> Array:
	return door.rigs.entities[77].nodes.map(func(node):return node.transform)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original door assets mount read-only")
	var bytes: PackedByteArray=catalog.get_resource("genericdoors",2017)
	var parser:=Table.new(); var table:=parser.parse(Binary.new(bytes).text(0,bytes.size())); var index:=-1; var name:=""
	for row_index in table.get("orderedRows",[]).size():
		var row: Dictionary=table.orderedRows[row_index]; var candidate:=str(row.get("ModelName",row.get("Model","")))
		if candidate not in ["","****"] and str(row.get("VisibleModel","1"))!="0" and catalog.has_resource(candidate,2002): index=row_index; name=candidate; break
	check(index>=0,"Active genericdoors table selects an installed original visible door")
	if index<0: quit(1); return
	var world:=LiveWorld.new(); root.add_child(world); world.set_process(false); world.catalog=catalog; world.area_id=42; world.receive([door_row(index,22,0)],-1)
	var owner:=Stream.new(); world.add_child(owner); owner.configure(catalog,world.pool,[door_row(index,22,0)],42,"")
	check(await wait_for(func():return owner.done),"Actual native door stream completes")
	check(owner.stats.errors.is_empty() and owner.instances.has(77),"Original door publishes as an animated native instance rather than a static template")
	if owner.instances.has(77):
		var door=owner.instances[77]; owner.instances.erase(77); world.instances[77]=door; world.installed[77]=world.desired[77].key; door.set_process(false); door.rigs.set_process(false)
		door.rigs._update(0); var closed_pose:=transforms(door)
		check(door.received_state==0 and door.rigs.entities[77].models[0].clip=="closed","Initial received closed state selects original closed clip")
		world.receive_delta([door_row(index,50,1)],[],-1)
		check(door.rigs.entities[77].models[0].clip=="opening1" and door.door_stats.transitions==1,"Authoritative open update starts original side1 opening clip")
		var length: float=door.rigs.clip_length(77,300); door.rigs._update(length*0.5); door._process(length*0.5)
		check(transforms(door)!=closed_pose,"Actual original door Parts move during the opening animation")
		var serial: int=door.rigs.entities[77].models[0].play_serial; world.receive_delta([door_row(index,50,1)],[],-1)
		check(door.rigs.entities[77].models[0].play_serial==serial,"Repeated server state does not restart opening")
		door.rigs._update(length*0.5+0.01); door._process(length*0.5+0.01)
		check(door.pending_rest<0 and door.rigs.entities[77].models[0].clip=="opened1","Opening settles into original opened1 pose")
		world.receive_delta([door_row(index,22,0)],[],-1)
		check(door.rigs.entities[77].models[0].clip=="closing1","Authoritative close uses side1 closing clip")
		door._process(door.rigs.clip_length(77,302)+0.01); door.rigs._update(0)
		check(door.rigs.entities[77].models[0].clip=="closed","Closing settles back to the closed pose")
		world.receive_delta([door_row(index,51,2)],[],-1)
		check(door.rigs.entities[77].models[0].clip=="opening2","Side2 server state selects opening2")
		door._process(door.rigs.clip_length(77,301)+0.01); world.receive_delta([door_row(index,22,0)],[],-1)
		check(door.rigs.entities[77].models[0].clip=="closing2","Side2 closes using closing2")
		check(world.desired[77].object.replicated.doorOpenState==0 and world.desired[77].object.replicated.animation==22,"Presentation never changes the server's received door state")
		check(door.door_stats.missing_clips.is_empty(),"Original door defines every requested open/close/rest clip")
	var stats: Dictionary=owner.stats.duplicate(true); world.close(); world.queue_free(); await settle_retirement(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"model":name,"genericType":index,"stream":stats,"scope":"Actual installed original door/table through native model worker, real physical-Part animations and live_world.receive_delta. No original server outcome or graphical pixel acceptance."},"\t")); file.close(); print("NATIVE_DOOR_PRESENTATION ",checks," checks"); quit(0 if failures.is_empty() else 1)
