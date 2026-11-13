extends SceneTree

class CandidateRig:
	extends "res://systems/model_rigs.gd"
	var refreshes:=0
	func _refresh_processing() -> void:
		refreshes+=1
		super._refresh_processing()

var checks:=0
var failures: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func make_rig():
	var rig=CandidateRig.new()
	root.add_child(rig)
	var player:=AnimationPlayer.new()
	rig.add_child(player)
	for id in 1917:rig.entities[id]={"models":[],"animated_models":[],"manual_poses":{},"attachments":[],"skins":[]}
	rig.entities[1917]={"models":[{"player":player,"dormant_finished":true}],"animated_models":[0],"manual_poses":{},"attachments":[],"skins":[]}
	return {"rig":rig,"player":player}
func exercise() -> Dictionary:
	var pair: Dictionary=make_rig()
	var rig=pair.rig
	var player: AnimationPlayer=pair.player
	check(rig.idle_suspended and not rig.is_processing(),"initial idle")
	var before: int=rig.refreshes
	rig._animation_started(&"sample",player)
	check(not rig.idle_suspended and rig.is_processing(),"external start wakes")
	check(rig.refreshes==before+1,"idle start refreshes once")
	check(not rig.entities[1917].models[0].dormant_finished,"start clears finished state")
	before=rig.refreshes
	var began:=Time.get_ticks_usec()
	for ignored in 64:rig._animation_started(&"sample",player)
	var active_us:=Time.get_ticks_usec()-began
	check(rig.refreshes==before,"active starts do not rescan eligibility")
	check(rig.is_processing(),"active owner remains processing")
	rig._animation_finished(&"sample",player)
	check(rig.idle_suspended and not rig.is_processing(),"finished owner suspends")
	check(rig.entities[1917].models[0].dormant_finished,"finish restores marker")
	var stale_before: int=rig.refreshes
	rig.entities.erase(1917)
	rig._animation_started(&"sample",player)
	check(rig.refreshes==stale_before and rig.idle_suspended,"retired player does not wake")
	rig.queue_free()
	return {"active_starts":64,"other_entities":1917,"active_us":active_us,"refreshes_during_active_starts":0}
func run() -> void:
	var candidate:=exercise()
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"candidate":candidate,"scope":"Current ModelRigs active-start guard; synthetic 1,918-entry SceneTree owner; no FPS claim."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(report,"  ")+"\n")
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
