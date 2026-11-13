extends SceneTree
const Policy=preload("res://systems/native_data/gui_panel_access.gd")
const Adapter=preload("res://systems/native_gui_panel_access.gd")
class View extends Control:
	var wanted:=false
	var opens:=0
	var closes:=0
	func open() -> void: wanted=true; opens+=1; show()
	func close_players() -> void: wanted=false; closes+=1; hide()
	func close_journal() -> void: wanted=false; closes+=1; hide()
	func close_sheet() -> void: wanted=false; closes+=1; hide()
class Desktop extends Node:
	var players=View.new()
	var journal=View.new()
	var book=View.new()
	var sheet=View.new()
	var objects={42:{"id":42,"objectType":5}}
	var actor_id:=42
	var area_id:=55
	var generation:=1
	var sent: Array=[]
	func command(value: Dictionary) -> void: sent.append(value.duplicate(true))
class Ui extends Node:
	var desktop=Desktop.new()
	var generation:=1
	var controlled_id:=42
	var area_id:=55
	var dependencies_ready:=true
	func panel_ready(_id: String) -> bool: return dependencies_ready
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func scope(lifetime: int=1) -> Dictionary: return {"actorId":42,"areaId":55,"areaGeneration":1,"controlLifetime":lifetime,"source":"client_receive_context"}
func event(sequence: int,kind: String="disabled",change: Dictionary={}) -> Dictionary:
	var value:={"sequence":sequence,"panelId":6,"kind":kind,"retiredThrough":0}
	if kind=="disabled": value.merge({"disabled":true,"targetId":Policy.INVALID,"targetSource":"received"})
	else: value.scope=scope()
	value.merge(change,true); return value
func header(revision: int,events: Array,disabled: Array=[],control: Dictionary=scope()) -> Dictionary:
	return {"revision":revision,"retiredThrough":maxi(0,revision-Policy.LIMIT),"disabled":disabled,"events":events,"control":control}
func run() -> void:
	var output:=""; var oracle:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--oracle="): oracle=arg.substr(9)
	if output.is_empty() or oracle.is_empty() or FileAccess.file_exists(output): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle))
	check(original.success and original.checks==3043 and original.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Original gate corpus is the pinned unchanged-machine-code observation")
	for row in original.rows:
		var members: Array=row.members.map(func(v):return int(v))
		var value:=Policy.original_gate(int(row.panel),int(row.target),members,{"bypass":bool(row.rawBypass540),"ownerPresent":row.owner!="absent","visible":row.owner=="visible","containerMode":row.owner=="inventory-alternate"})
		check(value.get("available",false) and value.blocked==row.blocked,"Original6f7870 case%s"%checks)
	check(not Policy.original_gate(4,42,[42],{"bypass":false,"ownerPresent":true,"visible":false}).available,"Unavailable container role is not coerced to primary0")
	var ui:=Ui.new(); root.add_child(ui); ui.add_child(ui.desktop)
	for node in [ui.desktop.players,ui.desktop.journal,ui.desktop.book,ui.desktop.sheet]: ui.add_child(node)
	var access:=Adapter.new(); ui.add_child(access); access.configure(ui)
	var disabled:=[{"panelId":6,"targetId":Policy.INVALID,"targetSource":"received"}]
	var seed:=header(2,[event(1),event(2,"popup")],disabled)
	access.observe_header(JSON.parse_string(JSON.stringify(seed)))
	check(ui.desktop.journal.wanted and ui.desktop.journal.opens==1,"Header seed replays ordered disable then forced popup once")
	access.observe_header(seed); check(ui.desktop.journal.opens==1,"Repeated header never replays an accepted popup")
	check(access.ordinary("journal") and ui.desktop.sent.is_empty(),"An existing disabled journal may close without GUI14")
	ui.desktop.journal.close_journal(); check(not access.ordinary("journal") and not access.ordinary("journal") and ui.desktop.sent.size()==2,"Repeated physical blocked attempts emit separate GUI14 intents")
	check(ui.desktop.sent[0].targetId==Policy.INVALID and ui.desktop.sent[1].attemptSerial==2,"Journal attempts retain INVALID target and distinct private intent serials")
	access.receive_event(event(3,"popup")); check(ui.desktop.journal.wanted and ui.desktop.journal.opens==2,"Forced popup bypasses retained disabled membership")
	access.receive_event(event(4)); check(not ui.desktop.journal.wanted and ui.desktop.journal.closes==2,"A duplicate server disable still closes a forced-open owner")
	access.receive_event(event(4)); check(ui.desktop.journal.closes==2,"Duplicate delivery does not close twice")
	var detached:=access.snapshot(); detached.policy.disabled.clear(); detached.control.actorId=99; seed.disabled.clear()
	check(access.policy.matches(6,Policy.INVALID) and access.control.actorId==42,"Header and returned views are detached recursively")
	access.receive_event(event(5,"disabled",{"disabled":false})); check(access.ordinary("journal"),"Exact global enable removes its membership")
	ui.desktop.journal.open(); access.receive_event(event(6,"disabled",{"targetId":42})); check(not ui.desktop.journal.wanted and access.ordinary("journal"),"Journal receive-close ignores target but later ordinary gate still uses INVALID")
	access.observe_header(header(7,[event(7,"popup",{"scope":scope(1)})],[],scope(2))); check(not ui.desktop.journal.wanted,"Same-ID retired control lifetime cannot force a replacement owner")
	access.receive_event(event(8,"popup",{"scope":null})); check(not ui.desktop.journal.wanted,"Unavailable popup identity does not invent a character")
	var before:=access.snapshot(); access.receive_event({"kind":"disabled","panelId":"6","sequence":9}); check(access.snapshot().policy==before.policy,"Malformed scalar event does not mutate canonical native policy")
	# Out-of-order delivery repairs canonical state only from a matching/newer
	# header; effects remain receive-sequenced and never replay.
	access.receive_event(event(10,"popup",{"scope":scope(2)})); check(not access.policy.complete and not ui.desktop.journal.wanted,"A serial gap suppresses ordinary admission and waits for ordered effects")
	access.receive_event(event(9,"popup",{"scope":scope(2)})); check(ui.desktop.journal.wanted and access.effects_seen==10,"Late predecessor drains both one-shot effects in order")
	access.observe_header(header(10,[event(9,"popup"),event(10,"popup")],[],scope(2))); check(access.policy.complete,"Canonical same-revision header repairs a scalar-state gap")
	var opens: int=ui.desktop.journal.opens
	ui.dependencies_ready=false; access.receive_event(event(11,"popup",{"scope":scope(2)})); check(access.effects_seen==11 and ui.desktop.journal.opens==opens,"Wanted owner is an idempotent no-op even when dependencies become unavailable")
	ui.desktop.journal.close_journal(); access.receive_event(event(12,"popup",{"scope":scope(2)})); access.receive_event(event(13,"disabled",{"disabled":false}))
	check(access.pending.size()==2 and not ui.desktop.journal.wanted,"Unready popup retains later enable until completion")
	ui.dependencies_ready=true; access.drain(); check(ui.desktop.journal.wanted and access.pending.is_empty(),"Explicit readiness boundary drains ordered effects once")
	access.close(); check(not access.ordinary("journal") and access.pending.is_empty(),"Closed connection rejects bound input and clears queued commands"); ui.free(); await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Original3043 gate corpus versus native scalar policy plus isolated adapter ordering/detachment/lifecycle with authored owners. No real input/server/renderer acceptance.","gpu":false,"serverConnections":0}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); print("GUI_ACCESS_POLICY_RESULT ",JSON.stringify(result)); quit(0 if result.success else 1)
