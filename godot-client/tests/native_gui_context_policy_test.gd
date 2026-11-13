extends SceneTree
# Authored boundary fixture; actual Desktop pointer input belongs to the
# separately owned world-context test. Canonical access/serial are real.
const Base=preload("res://tests/native_gui_panel_policy_test.gd")
const Adapter=preload("res://systems/native_gui_panel_access.gd")
class ContextDesktop extends Base.Desktop:
	var closed:=false
	var during_command: Callable
	func command(value: Dictionary) -> void:
		super.command(value)
		if during_command.is_valid(): during_command.call()
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func change(sequence: int,panel: int,target: int=2130706432,disabled: bool=true) -> Dictionary: return {"kind":"disabled","sequence":sequence,"retiredThrough":0,"panelId":panel,"targetId":target,"disabled":disabled,"targetSource":"received"}
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var ui=Base.Ui.new()
	for node in [ui.desktop.players,ui.desktop.journal,ui.desktop.book,ui.desktop.sheet]: node.free()
	ui.desktop.free(); ui.desktop=ContextDesktop.new(); root.add_child(ui); ui.add_child(ui.desktop)
	var d=ui.desktop
	for node in [d.players,d.journal,d.book,d.sheet]: ui.add_child(node)
	d.objects[42].areaId=55
	var adapter:=Adapter.new(); ui.add_child(adapter); adapter.configure(ui)
	var targets:={}; var serial:=0; var revision:=0
	for source in Adapter.CONTEXTS:
		var spec: Array=Adapter.CONTEXTS[source]; var id:=2130706432 if source=="ground" else 100+int(spec[0])
		if source!="ground": d.objects[id]={"id":id,"areaId":55,"objectType":spec[1]}
		targets[source]=id
		check(adapter.context_attempt(source,id,Vector3(1.25,-2.5,3.75)),"Known live context is admitted once: "+source); serial+=1
		check(d.sent.back().guiPanelId==spec[0] and d.sent.back().attemptSerial==serial and d.sent.back().position==([1.25,-2.5,3.75] if source=="ground" else [0,0,0]),"Native context maps exact source/serial/NWN coordinates: "+source)
		revision+=1; adapter.receive_event(change(revision,int(spec[0]),id))
		for repeated in 2:
			check(not adapter.context_attempt(source,id,Vector3(2,3,4)),"Each matching blocked context remains suppressed: "+source); serial+=1
		check(d.sent.back().attemptSerial==serial and d.sent.back().accessRevision==revision,"Blocked intents retain shared serial and canonical revision: "+source)
		revision+=1; adapter.receive_event(change(revision,int(spec[0]),id,false))
	var before: int=d.sent.size()
	for source in ["portrait","inventory","constructor","","Ground"]: check(not adapter.context_attempt(source,42,Vector3.ZERO),"Unbound/prototype source does not become a world attempt: "+source)
	check(not adapter.context_attempt("ground",42,Vector3.ZERO) and not adapter.context_attempt("ground",2130706432,Vector3(NAN,0,0)),"Ground requires exact INVALID and finite coordinates")
	var target: Dictionary=d.objects[targets.creature]
	for mutation in [{"areaId":56},{"objectType":6},{"destroyed":true},{"replicationRemoved":true}]:
		var saved:=target.duplicate(true); target.merge(mutation,true); check(not adapter.context_attempt("creature",targets.creature,Vector3.ZERO),"Retired/moved/wrong-type target cannot issue a native attempt"); target.clear(); target.merge(saved)
	check(d.sent.size()==before,"Rejected context attempts emit no intent")
	revision+=1; adapter.receive_event(change(revision,6)); check(not adapter.ordinary("journal") and d.sent.back().attemptSerial==serial+1,"Ordinary bound input shares the exact context serial counter"); serial+=1
	check(adapter.context_attempt("ground",2130706432,Vector3.ZERO) and d.sent.back().attemptSerial==serial+1,"A later context continues the ordinary attempt counter")
	d.during_command=func():d.objects[42]=d.objects[42].duplicate(true)
	check(not adapter.context_attempt("ground",2130706432,Vector3.ZERO),"Reentrant same-ID actor replacement cannot open a new native wheel")
	d.during_command=func():adapter.close()
	check(not adapter.context_attempt("ground",2130706432,Vector3.ZERO) and adapter.closed,"Reentrant connection teardown suppresses a new native wheel")
	ui.free(); await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Real canonical adapter context/serial guards with authored Ui/Desktop/owners; actual native pointer and original-server proofs separate.","gpu":false,"serverConnections":0}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); print("GUI_CONTEXT_POLICY_RESULT ",JSON.stringify(result)); quit(0 if result.success else 1)
