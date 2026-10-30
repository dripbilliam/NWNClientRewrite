extends SceneTree
const Desktop=preload("res://systems/native_game_desktop.gd")
const Disposal=preload("res://systems/native_data/data_retirement.gd")
class View:
	extends Control
	var resets:=0
	func reset() -> void: resets+=1
class HeldDisposal:
	extends Disposal
	var entered:=Semaphore.new()
	var release:=Semaphore.new()
	var packet: Dictionary={}
	static func data_only(value: Variant) -> bool:
		if typeof(value)==TYPE_OBJECT or typeof(value)==TYPE_CALLABLE or typeof(value)==TYPE_SIGNAL: return false
		if value is Dictionary:
			for key in value:
				if not data_only(key) or not data_only(value[key]): return false
		elif value is Array:
			for row in value:
				if not data_only(row): return false
		return true
	func _release(payload: Dictionary) -> void:
		mutex.lock(); packet={"keys":payload.keys(),"data_only":data_only(payload),"objects":payload.get("ui_objects",{}).size()}; mutex.unlock()
		entered.post(); release.wait(); super._release(payload)
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func desktop(parent: Node):
	var result:=Desktop.new(); parent.add_child(result); result.set_process(false)
	for field in ["party","quickbar","sheet","book","journal","area_map","players","buffs","radial","level_up","action_queue"]:
		var view:=View.new(); result.add_child(view); result.set(field,view)
	return result
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var host:=Node.new(); root.add_child(host)
	var disposal:=HeldDisposal.new(); host.add_child(disposal); disposal.set_process(false)
	var ui=desktop(host)
	check(ui.raw_data_retirement_enabled,"Worker retirement is the default")
	var old:={1:{"id":1,"replicated":{"position":[1,2,3]},"playerState":{"spellbooks":{"0":[{"spellId":4}]}}}}
	var old_header:={"journal":{"entries":[{"text":"authored old state"}]}}
	ui.set_world(1,10,1,old,old_header)
	check(ui.raw_data_retirements==0 and disposal.deferred.is_empty(),"Initial empty desktop needs no disposal packet")
	check(is_same(ui.objects,old) and is_same(ui.state,old_header),"Initial authoritative map/header identities remain exact")
	var current:={2:{"id":2,"replicated":{"position":[4,5,6]}}}; var current_header:={"journal":{"entries":[{"text":"authored new state"}]}}
	ui.set_world(2,11,2,current,current_header)
	check(is_same(ui.objects,current) and is_same(ui.state,current_header) and ui.actor_id==2 and ui.area_id==11 and ui.generation==2,"New authoritative state is available immediately without waiting for disposal")
	check(ui.party.resets==2 and ui.book.resets==2,"World changes still reset actual desktop-owned view interfaces")
	check(ui.raw_data_retirements==1 and disposal.deferred.size()==1,"One replaced nonempty raw map schedules exactly one fenced packet")
	check(old.size()==1 and old_header.journal.entries[0].text=="authored old state","Retention never clears or mutates another holder's old protocol graph")
	disposal.poll()
	check(disposal.tasks.is_empty() and not disposal.entered.try_wait(),"Old raw graph is not released before the frame fence")
	ui.set_world(2,11,2,current,{"journal":{}})
	check(ui.raw_data_retirements==1 and disposal.deferred.size()==1,"Same-map incremental update never disposes live state")
	check(ui.party.resets==2,"Same-generation/control update preserves menu reset behavior")
	var deadline:=Time.get_ticks_msec()+5000; var parked:=false
	while not parked and Time.get_ticks_msec()<deadline:
		disposal.poll(); parked=disposal.entered.try_wait()
		if not parked: await process_frame
	check(parked and disposal.tasks.size()==1,"Detached raw data reaches an actual worker, held independently of the UI")
	disposal.mutex.lock(); var observed: Dictionary=disposal.packet.duplicate(true); disposal.mutex.unlock()
	check(observed.get("data_only",false) and observed.get("objects",0)==1 and observed.get("keys",[]).size()==2,"Worker packet contains only raw Variant data, never controls/resources/callables")
	for frame in 3: await process_frame
	check(is_same(ui.objects,current) and ui.objects[2].replicated.position==[4,5,6] and is_instance_valid(ui.party),"Current UI state and controls survive continuing frames while old release is held")
	ui.raw_data_retirement_enabled=false; var next:={3:{"id":3}}
	ui.set_world(3,12,3,next,{})
	check(is_same(ui.objects,next) and ui.raw_data_retirements==1,"Explicit main-thread reference path performs the same authoritative handoff")
	var separate:=Node.new(); root.add_child(separate); var standalone=desktop(separate)
	standalone.set_world(1,10,1,old,old_header); standalone.set_world(2,11,2,current,current_header)
	check(is_same(standalone.objects,current) and standalone.raw_data_retirements==0,"Desktop without a session disposal owner safely retains ordinary behavior")
	disposal.release.post(); deadline=Time.get_ticks_msec()+5000
	while not disposal.tasks.is_empty() and Time.get_ticks_msec()<deadline: disposal.poll(); await process_frame
	check(disposal.stats.completed==1 and disposal.tasks.is_empty(),"Worker releases its packet and completes without a UI wait")
	check(old.size()==1 and old_header.journal.entries[0].text=="authored old state","A retained external old-state reader remains intact after worker completion")
	check(disposal.stats.threads.all(func(id):return id!=OS.get_main_thread_id()),"Final data-release callback runs away from the presentation thread")
	disposal.close(); ui.raw_data_retirement_enabled=true; ui.set_world(4,13,4,{4:{"id":4}},{})
	check(ui.actor_id==4 and ui.raw_data_retirements==1 and disposal.snapshot().pending==0,"Closed disposal owner has a safe synchronous fallback with no retained packet")
	var metrics: Dictionary=disposal.snapshot(); host.queue_free(); separate.queue_free(); await process_frame; await process_frame
	check(not is_instance_valid(ui) and not is_instance_valid(standalone) and metrics.pending==0,"Shutdown releases all controls and drains detached protocol data")
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"disposal":metrics,"public_connections":0,"scope":"Real native desktop set_world with reset interfaces, actual held worker/fence, same-map incremental updates, canonical raw identities, no mutation of retained graphs, missing/closed owner fallback and shutdown. No GPU/FPS or complete menu visual acceptance."},"\t")); file.close(); print("NATIVE_UI_DATA_RETIREMENT ",checks," checks"); quit(0 if failures.is_empty() else 1)
