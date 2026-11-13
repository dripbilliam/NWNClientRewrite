extends SceneTree
# Read a sealed local recording, never connect to its server. Validate actual
# captured row shapes through the real worker and current/frozen World owners.
const Metadata=preload("res://systems/native_data/world_snapshot_metadata.gd")
const Preparation=preload("res://systems/native_data/world_snapshot_preparation.gd")
const Current=preload("res://systems/native_render/live_world.gd")
const Before=preload("res://tests/fixtures/native_world_snapshot_before_world.gd")
const Oracle=preload("res://tests/fixtures/native_world_snapshot_metadata_oracle.gd")
const WorldFixture=preload("res://tests/native_world_snapshot_sidecar_test.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String)->void:
	checks+=1
	if not value and failures.size()<20:failures.append(label)
func state(world)->PackedByteArray:
	var motion: Dictionary={}
	for id in world.motion.objects:
		var value: Dictionary=world.motion.objects[id]
		motion[id]={"position":value.position,"orientation":value.orientation,"animation":value.animation}
	return var_to_bytes([world.desired,world.base_scenery_omitted,world.base_scenery_progress_counts,world.base_scenery_population_revision,motion])
func _initialize()->void:call_deferred("run")
func run()->void:
	var report:="";var capture:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		if arg.begins_with("--capture="):capture=arg.substr(10)
	if report.is_empty() or capture.is_empty() or FileAccess.file_exists(report):quit(2);return
	var timeline:=capture.path_join("timeline.jsonl")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(capture.path_join("recording.json")))
	check(manifest.complete==true and FileAccess.get_sha256(timeline)==manifest.timelineSha256,"Sealed original recording bytes match manifest")
	var input:=FileAccess.open(timeline,FileAccess.READ);var header: Dictionary={};var rows: Array=[]
	while not input.eof_reached():
		var line:=input.get_line()
		if line.is_empty():continue
		var entry: Dictionary=JSON.parse_string(line)
		if entry.get("kind")!="frame":continue
		var message: Dictionary=entry.value
		if header.is_empty() and message.kind=="raw-world-begin" and int(message.get("generation",-1))==2 and message.data.get("bridgeMode")!="delta":header=message
		elif not header.is_empty() and message.get("serial")==header.serial:
			if message.kind=="raw-world-chunk":rows.append_array(message.objects)
			elif message.kind=="raw-world-end":break
	input.close()
	check(not header.is_empty() and rows.size()==int(header.get("count",-1)),"Actual first full captured world is complete")
	var errors: Dictionary={};var missing_area:=0
	for row in rows:
		var reason:=Metadata.validation_error(row)
		if not reason.is_empty():errors[reason]=int(errors.get(reason,0))+1
		if not row.has("areaId"):missing_area+=1
	check(errors.is_empty() and missing_area==2,"All captured rows, including two non-world rows without areaId, are worker-safe")
	var diagnostic: Dictionary={};var prepared_rows:=0;var desired_rows:=0
	if errors.is_empty() and not header.is_empty():
		var area:=int(header.data.area.id);var generation:=int(header.generation)
		var scope: Array=[int(header.connection),generation,int(header.serial),area]
		var owner:=Preparation.new();check(owner.begin(scope,area,rows.size()),"Real preparation scope opens")
		for offset in range(0,rows.size(),64):check(owner.submit(rows.slice(offset,mini(offset+64,rows.size()))),"Captured chunk submitted without row normalization")
		check(owner.seal(),"Captured full boundary seals")
		var packet: Dictionary={};var deadline:=Time.get_ticks_msec()+10000
		while packet.is_empty() and Time.get_ticks_msec()<deadline:
			packet=owner.take(scope)
			if packet.is_empty():await process_frame
		check(not packet.is_empty() and packet.get("error","").is_empty() and packet.get("rows",[]).size()==rows.size(),"Actual worker prepares the entire captured boundary without fallback")
		diagnostic=owner.snapshot()
		check(diagnostic.stats.completed>0 and not diagnostic.stats.threads.has(OS.get_main_thread_id()),"Captured metadata preparation runs off main")
		if not packet.is_empty() and packet.get("error","").is_empty():
			var oracle:=Oracle.new()
			for index in rows.size():
				var row: Dictionary=rows[index];var value: Dictionary=packet.rows[index]
				if value.accepted:
					check(value.key==oracle.signature(row) and var_to_bytes(value.pose)==var_to_bytes(oracle.object_pose(row)),"Captured metadata exactly matches pre-worker signature and pose")
			var current:=Current.new();var before:=Before.new()
			for world in [current,before]:world.generation=generation;world.area_id=area;world.combat=WorldFixture.Combat.new();world.continuous_base_stream=true
			check(current.stage_received_metadata(rows,packet),"Actual World accepts completed captured metadata")
			before.receive(rows,int(header.data.controlledId));current.receive(rows,int(header.data.controlledId))
			check(state(current)==state(before),"Current prepared World equals frozen synchronous desired/progress/motion state")
			prepared_rows=int(current.received_metadata_stats.prepared_rows)
			desired_rows=current.desired.size()
			check(prepared_rows==rows.size() and current.received_metadata_stats.rejected==0 and desired_rows>0 and desired_rows==before.desired.size(),"Actual initial World consumes all metadata slots and preserves the frozen initial population before later captured removals")
			before.close();current.close();before.free();current.free();oracle=null
		owner.close();owner=null
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"captured_rows":rows.size(),"missing_area_rows":missing_area,"validation_errors":errors,"prepared_rows":prepared_rows,"initial_desired_rows":desired_rows,"worker":diagnostic,"scope":"Sealed captured row-shape regression with actual worker and current/frozen World state. No assets admitted, server connection, rendering or FPS measurement."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print(JSON.stringify({"success":result.success,"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
