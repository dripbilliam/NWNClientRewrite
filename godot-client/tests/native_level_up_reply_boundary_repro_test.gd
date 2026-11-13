extends SceneTree
# Defect reproduction at the actual transaction/presentation result boundary.
# Rendering is overridden, not the production receive_result/begin behavior.
const NativeOwner=preload("res://systems/native_level_up.gd")
class View extends RefCounted:
	signal presentation_reset
	signal source_reopen
	var wanted:=false
	var request_serial:=0
	var source_active:=false
	var status:={"text":""}
	func open() -> void:wanted=true;request_serial+=1
	func reset() -> void:wanted=false;source_active=false;request_serial+=1;presentation_reset.emit()
class Desktop extends RefCounted:
	var generation:=1
	var area_id:=7
	var actor_id:=42
	var rules:=RefCounted.new()
	var commands: Array=[]
	func command(value: Dictionary) -> void:commands.append(value.duplicate(true))
class Controller extends NativeOwner:
	func select_class(id: int) -> void:draft={"classId":id}
	func render() -> void:pass
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
	var desktop:=Desktop.new();var view:=View.new();var controller:=Controller.new();controller.configure(desktop,view)
	var one:={"token":11,"snapshot":{"actorId":42,"classes":[{"id":0,"level":3}],"skills":[]},"available":[true],"draftContext":{"baseFortitude":0},"protocolFeatures":{"multiclassRuleset":true}}
	var two:=one.duplicate(true);two.token=12
	view.open();controller.input({"kind":"level-open"});var first_serial:=view.request_serial
	controller.receive_result({"accepted":true,"operation":"begin","result":one})
	check(view.wanted and controller.token==11,"Actual initial begin result is presented")
	view.reset();view.open();controller.input({"kind":"level-open"});var second_serial:=view.request_serial
	controller.receive_result({"accepted":true,"operation":"begin","result":two})
	check(second_serial>first_serial and controller.token==12 and desktop.commands.size()==2,"New same-actor UI entry has its own begin and token")
	controller.receive_result({"accepted":true,"operation":"begin","result":one})
	check(controller.token==11,"REPRO: an older begin result replaces the newer current same-actor token")
	controller.receive_result({"accepted":true,"operation":"begin","result":two})
	check(controller.token==12 and view.wanted,"Newer entry can be re-established independently of the old reply")
	controller.receive_result({"accepted":true,"operation":"submit","token":11,"result":{"accepted":true}})
	check(not view.wanted and controller.token==-1,"REPRO: an older successful submission result resets a newer same-actor entry despite its supplied old token")
	controller.close();view.presentation_reset.disconnect(controller.retire_source);view.source_reopen.disconnect(controller.reopen_source)
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"defectsExpected":2,"productionFixed":false,"scope":"Actual NativeLevelUp receive_result/begin/reset with render-only subclass and authored out-of-order local envelopes. Reproduction of missing per-request/view correlation; no assertion that the real server reorders packets, no source UI pixels/server acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
