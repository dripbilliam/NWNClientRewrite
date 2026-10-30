extends SceneTree
# Offline data-only worker process; never opens sockets or reads account keys.
const Controller=preload("res://systems/native_asset_prework.gd")
const Exchange=preload("res://systems/native_prework_process.gd")
var directory:=""
var controller
var completing:=false
func _initialize() -> void: call_deferred("run")
func publish(state: Dictionary) -> void:
	if completing: return
	var snapshot:=state.duplicate(true)
	snapshot.diagnostics_path=directory.path_join("model-diagnostics.jsonl")
	snapshot.phase="indexing" if controller.source_loader!=null else "preparing"
	Exchange.write_json(directory.path_join("status.json"),{"done":false,"state":snapshot})
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--job="): directory=arg.substr(6)
	if not directory.is_absolute_path() or not directory.get_file().begins_with("nwn-prework-job-"): quit(2); return
	var request:=Exchange.read_json(directory.path_join("request.json"))
	if request.get("version")!=1 or not request.get("sources") is Dictionary or not str(request.get("cache","")).is_absolute_path(): quit(2); return
	controller=Controller.new(); root.add_child(controller); controller.set_workers(int(request.get("workers",0)))
	var variants: Variant=bytes_to_var(FileAccess.get_file_as_bytes(str(request.get("variants_file",""))))
	controller.extra_variants=variants if variants is Array else []; controller.packet_files=request.get("icons",[]); controller.model_limit=int(request.get("model_limit",0))
	controller.changed.connect(publish)
	var journal:=FileAccess.open(directory.path_join("model-diagnostics.jsonl"),FileAccess.WRITE)
	controller.diagnostic_event.connect(func(event: Dictionary):
		if journal!=null: journal.store_line(JSON.stringify(event)); journal.flush())
	var accepted: bool=controller.start_sources(request.sources,str(request.cache),bool(request.get("all_models",true)))
	var serial:=-1; var checked_at:=0; var cancelled:=false; var last_heartbeat:=Time.get_unix_time_from_system()
	while accepted and controller.state.active:
		if Time.get_ticks_msec()-checked_at>=100:
			checked_at=Time.get_ticks_msec(); var control:=Exchange.read_json(directory.path_join("control.json"))
			if int(control.get("serial",-1))>serial:
				serial=int(control.serial); controller.set_workers(int(control.get("workers",0)))
				if control.get("cancel",false): cancelled=true; controller.cancel()
			var heartbeat:=FileAccess.get_modified_time(directory.path_join("control.json"))
			if heartbeat>0: last_heartbeat=maxf(last_heartbeat,float(heartbeat))
			if Time.get_unix_time_from_system()-last_heartbeat>15: cancelled=true; controller.cancel()
		await process_frame
	completing=true; var state: Dictionary=controller.state.duplicate(true)
	state.diagnostics_path=directory.path_join("model-diagnostics.jsonl")
	controller.close(); controller.queue_free(); await process_frame; await process_frame
	if journal!=null: journal.close()
	Exchange.write_json(directory.path_join("status.json"),{"done":true,"cancelled":cancelled,"state":state})
	quit(0 if accepted else 1)
