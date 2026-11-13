extends SceneTree
const Preview=preload("res://systems/native_creation_preview.gd")
const RealAssets=preload("res://systems/native_data/asset_service.gd")
const RealStream=preload("res://systems/native_render/creature_stream.gd")
class Work extends RefCounted:
	var completed:=false
	func run() -> void:OS.delay_msec(40);completed=true
class PrivateAssets extends RefCounted:
	var running: Dictionary={}
	var cancelled:=0
	var premature:=false
	var work:=Work.new()
	func start() -> void:running[1]=WorkerThreadPool.add_task(work.run,false,"Owned preview retirement stress")
	func retire_scope() -> void:cancelled+=1
	func close() -> void:
		for task in running.values():
			if not WorkerThreadPool.is_task_completed(int(task)):premature=true
			WorkerThreadPool.wait_for_task_completion(int(task))
		running.clear()
class PrivateStream extends Node3D:
	var assets:=PrivateAssets.new()
	var done:=false
	var closed:=false
	func close() -> void:
		if closed:return
		closed=true;assets.close()
	func _exit_tree() -> void:close()
class TestPreview extends Preview:
	var installs: Array=[]
	func install_pending() -> void:
		if pending_model.is_empty() or not retiring.is_empty():return
		var value:=pending_model;pending_model={}
		if dead or not view.active or value.signature!=signature:return
		diagnostics=value.diagnostics;stream=PrivateStream.new();view.pivot.add_child(stream);view.model=stream;stream.assets.start();installs.append(value.object.appearance.head)
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var view=preload("res://systems/creation_preview.gd").new();root.add_child(view);view.set_active(true)
	var preview:=TestPreview.new();root.add_child(preview);preview.view=view
	var parts: Array=[];parts.resize(19);parts.fill(1);var colors: Array=[];colors.resize(6);colors.fill(0)
	var value:={"head":1,"phenotype":0,"gender":0,"skin":0,"hair":0,"tattoo1":0,"tattoo2":0,"bodyParts":parts.duplicate(),"skinParts":parts.duplicate(),"materialColors":colors,"clothes":0,"clothingResRef":"owned"}
	preview.refresh_source(0,0,value,{},[1]);var old=preview.stream;var old_assets=old.assets;var initial_parent=view.surface.get_parent()
	var began:=Time.get_ticks_usec()
	for index in range(2,102):
		value.head=index;preview.refresh_source(0,0,value,{},[1])
		check(preview.retiring.size()==1 and preview.stream==null and view.model==null and preview.pending_model.size()==3,"Rapid request keeps one retired stream and one latest snapshot")
	var rapid_us:=Time.get_ticks_usec()-began
	check(preview.installs==[1] and int(preview.pending_model.object.appearance.head)==101,"No replacement stream starts while original private task drains")
	check(old_assets.cancelled==1 and not old_assets.premature,"Epoch retirement cancels exactly the old owner without synchronous close")
	check(not is_instance_valid(view.model),"Generic view.reset cannot synchronously close the retired stream")
	view.reset();var started:=Time.get_ticks_msec()
	while preview.installs.size()<2 and Time.get_ticks_msec()-started<3000:await process_frame
	check(preview.installs==[1,101] and not old_assets.premature and preview.retiring.is_empty(),"Drain installs only latest request, after worker completion")
	check(view.surface.get_parent()==initial_parent,"Retirement does not move an active viewport surface")
	value.head=102;preview.refresh_source(0,0,value,{},[1]);var cancelled=preview.retiring[0].stream.assets;preview.stop();view.active=false
	started=Time.get_ticks_msec()
	while not preview.retiring.is_empty() and Time.get_ticks_msec()-started<3000:await process_frame
	check(preview.pending_model.is_empty() and preview.installs==[1,101] and not cancelled.premature,"Cancel discards pending snapshot and prevents stale installation")
	check(preview.retirement_stats.maximumRetired==1 and preview.retirement_stats.maximumPending==1 and preview.retirement_stats.coalesced==99 and preview.retirement_stats.pendingDiscarded==1,"Queue/coalescing/cancel bounds describe actual work")
	var statistics: Dictionary=preview.retirement_stats.duplicate(true);preview.close();preview.free()
	# The real service owns the task IDs; unlike the async path this closes
	# before completion. An external Preview wait used to join each ID twice.
	for cycle in 2:
		var closing:=Preview.new();root.add_child(closing);closing.view=view;view.active=true
		var actual:=RealStream.new();view.pivot.add_child(actual)
		var actual_assets:=RealAssets.new();actual.add_child(actual_assets);actual.assets=actual_assets
		var work:=Work.new();actual_assets.running[1]=WorkerThreadPool.add_task(work.run,false,"Owned immediate Preview close")
		closing.stream=actual;view.model=actual;closing.close()
		check(work.completed and actual.closed and actual_assets.running.is_empty() and closing.retiring.is_empty() and view.model==null,"Immediate close/reopen cycle joins each real Stream/AssetService worker exactly once: "+str(cycle))
		closing.close();closing.free();await process_frame
	view.free();await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"rapidInputUsec":rapid_us,"retirement":statistics,"scope":"Real Preview coordinator with one owned data-worker/stream double; rapid latest coalescing, model pointer clearance, no premature exit/join, cancel and complete cleanup. Actual installed native stream admission remains in composed Tail test."},"  "));file.close();quit(0 if failures.is_empty() else 1)
