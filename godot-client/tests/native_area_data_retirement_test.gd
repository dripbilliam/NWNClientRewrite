extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
const Effects=preload("res://systems/native_render/effect_world.gd")
const Surface=preload("res://systems/native_render/terrain_surface.gd")
const Drive=preload("res://systems/native_render/drive_collision.gd")
const Disposal=preload("res://systems/native_data/data_retirement.gd")
const Projectiles=preload("res://systems/native_render/projectile_world.gd")
const Voices=preload("res://systems/native_render/creature_voice_world.gd")
class HeldDisposal:
	extends Disposal
	var entered:=Semaphore.new()
	var release:=Semaphore.new()
	var only_data:=false
	func pure(value: Variant) -> bool:
		if value is Object: return false
		if value is Dictionary:
			for key in value:
				if not pure(key) or not pure(value[key]): return false
		if value is Array:
			for row in value:
				if not pure(row): return false
		return true
	func _release(payload: Dictionary) -> void:
		only_data=pure(payload); entered.post(); release.wait(); super._release(payload)
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var disposal:=HeldDisposal.new(); root.add_child(disposal); disposal.set_process(false)
	var world:=World.new(); root.add_child(world); world.set_process(false)
	world.effects=Effects.new(); world.add_child(world.effects); world.effects.set_process(false)
	world.effects.projectiles=Projectiles.new(); world.effects.add_child(world.effects.projectiles); world.effects.projectiles.set_process(false)
	world.effects.creature_voices=Voices.new()
	world.surface=Surface.new(); world.add_child(world.surface); world.surface.set_process(false)
	world.drive_collision=Drive.new(); world.add_child(world.drive_collision); world.drive_collision.set_process(false)
	var rows: Array=[]
	for index in 2000: rows.append({"name":"authored-"+str(index),"coordinates":PackedFloat32Array([1,2,3])})
	var peer:={"orderedRows":rows}
	world.effects.tables={"appearance":peer}; world.effects.bundles={"auth":{"value":{"nodes":rows}}}
	world.effects.projectiles.table=peer; world.effects.projectiles.ranged_tables={"baseitems":peer}
	world.effects.creature_voices.table=peer; world.effects.creature_voices.sets={"auth":{"sounds":["one","two"]}}
	world.surface.table=peer; world.surface.meshes={"auth":{"vertices":PackedFloat32Array([1,2,3])}}
	world.drive_collision.tables={"appearance":peer}; world.drive_collision.models={"auth":{"states":rows}}
	var controller_alias: Dictionary=world.effects.tables
	world.begin_retirement()
	check(world.retirement_step(),"Retirement detaches every decoded owner without waiting for disposal")
	check(not world.retired_data.is_empty() and disposal.tasks.is_empty(),"Detached data remains retained through physical-owner close")
	controller_alias.clear()
	check(world.retired_data.effects.tables.has("appearance") and world.retired_data.effects.tables.appearance.orderedRows.size()==2000,"A closing controller cannot clear the retained source container through an alias")
	check(world.retired_data.effects.projectiles.table.orderedRows.size()==2000 and world.retired_data.effects.creature_voices.sets.auth.sounds==["one","two"],"Projectile tables and voice source data share the same bounded retirement packet")
	check(world.effects.projectiles.table.is_empty() and world.effects.projectiles.ranged_tables.is_empty() and world.effects.creature_voices.sets.is_empty(),"Effect subowners release pure source bindings before their main-thread close")
	check(world.effects.tables.is_empty() and world.effects.bundles.is_empty() and world.surface.table.is_empty() and world.surface.meshes.is_empty() and world.drive_collision.models.is_empty() and world.drive_collision.tables.is_empty(),"Old frame owners release bindings before their final close")
	world.close(); world.queue_free()
	check(disposal.deferred.size()==1 and disposal.tasks.is_empty(),"One grouped CPU packet survives queued scene destruction until the frame fence")
	var deadline:=Time.get_ticks_msec()+10000
	while not disposal.entered.try_wait() and Time.get_ticks_msec()<deadline: disposal.poll(); await process_frame
	check(disposal.only_data,"Worker payload contains no scene nodes, GPU resources or other Objects")
	check(disposal.stats.submitted==1 and disposal.tasks.size()==1,"Owner data is grouped into one bounded world-disposal job")
	await process_frame; await process_frame
	check(peer.orderedRows.size()==2000 and peer.orderedRows[1999].name=="authored-1999","Closing the old world does not mutate data retained by another owner")
	check(disposal.tasks.any(func(task):return not WorkerThreadPool.is_task_completed(task)),"Presentation frames continue while pure-data disposal is deliberately parked")
	disposal.release.post()
	while disposal.tasks.any(func(task):return not WorkerThreadPool.is_task_completed(task)): await process_frame
	disposal.poll()
	check(disposal.stats.completed==1 and disposal.stats.threads.size()==1 and disposal.stats.threads[0]!=OS.get_main_thread_id(),"Actual decoded graph release runs on a joined background worker")
	var stats:=disposal.snapshot(); disposal.close(); disposal.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"disposal":stats,"publicConnections":0})); file.close()
	quit(0 if failures.is_empty() else 1)
