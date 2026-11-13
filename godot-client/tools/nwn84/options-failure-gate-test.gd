extends SceneTree
const Pregame=preload("res://systems/native_pregame_menu.gd")
class Page:
	extends Control
	var layout_ready:=true
	var failure:=""
	var buttons: Dictionary={}
	var admitted:=true
	var reason:=""
	var cohort_scope:="pre_main+okcancelpanel"
	func cohort_snapshot() -> Dictionary:
		return {"scope":cohort_scope,"failures":[] if reason.is_empty() else [reason],"ready":admitted}
	func art_ready() -> bool: return admitted
	func set_context(_scope: Array,_availability: Dictionary,_colors: Dictionary={}) -> void: pass
	func dismiss() -> void: hide()
	func close() -> void: pass
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var pregame:=Pregame.new(); root.add_child(pregame)
	pregame.status=Label.new(); pregame.add_child(pregame.status)
	pregame.main=Page.new(); pregame.add_child(pregame.main)
	pregame.options=Page.new(); pregame.add_child(pregame.options)
	pregame.options.cohort_scope="options_pregame+okcancelpanel"
	pregame.wanted=true; pregame.page="options"; pregame.show()
	pregame.options.admitted=false
	pregame.options.reason="Page image gui:ctl_options:up: corrupt original image"
	pregame.refresh()
	check(pregame.status.visible and pregame.status.text.contains("options_pregame+okcancelpanel") and pregame.status.text.contains("gui:ctl_options:up"),"Active Options image failure displays exact cohort and key")
	check(not pregame.options.visible,"Failed Options page is not admitted")
	pregame.options.reason="Page font fnt_galahad14: Broken font atlas"
	pregame.refresh()
	check(pregame.status.text.contains("fnt_galahad14") and pregame.status.text.contains("Broken font atlas"),"Active Options font failure displays exact key and cause")
	pregame.options.reason=""; pregame.refresh()
	check(pregame.status.text=="Preparing menu resources…" and pregame.status.visible,"Pending Options page retains preparation message")
	pregame.options.admitted=true; pregame.refresh()
	check(pregame.options.visible and not pregame.status.visible,"Ready Options page admits and hides preparation status")
	pregame.page="main"; pregame.main.admitted=false; pregame.main.reason="Page image gui:main:up: corrupt"; pregame.refresh()
	check(pregame.status.visible and pregame.status.text.contains("pre_main+okcancelpanel") and pregame.status.text.contains("gui:main:up"),"Main-page failure still uses its own cohort")
	pregame.close(); pregame.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures},"  ")); file.close()
	quit(0 if failures.is_empty() else 1)
