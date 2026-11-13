extends SceneTree
const Probe=preload("res://tests/native_live_associate_record_probe.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
class Owner extends RefCounted:
	var objects:Dictionary={100:{"inventoryStats":{}}}
	var sheet:Dictionary={"state":{"model":{"abilities":[]}}}
var checks:=0
var failures:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var owner:=Owner.new();var probe=Probe.new();probe.desktop=owner;probe.target_id=100
	var unknown:=Values.abilities([],[],0,{})
	owner.sheet.state.model.abilities=unknown
	check(unknown.size()==6 and unknown.all(func(row):return row.score==null),"Actual projection publishes six explicitly unavailable rows before disclosure")
	check(not probe.received_page_zero_ready(),"Six placeholder rows do not establish NPC page0 readiness")
	owner.objects[100].inventoryStats.fields70=[12,12,12,10,10,10]
	check(not probe.received_page_zero_ready(),"Actual disclosure alone still waits for matching presentation")
	owner.sheet.state.model.abilities=Values.abilities([12,12,12,10,10,10],[],0,{})
	check(probe.received_page_zero_ready(),"Current disclosed scores and matching model become ready")
	owner.sheet.state.model.abilities[0].score=18
	check(not probe.received_page_zero_ready(),"Borrowed or stale other-character score cannot pass readiness")
	owner.objects[100].inventoryStats.fields70=[0,0,0,0,0,0];owner.sheet.state.model.abilities=Values.abilities([0,0,0,0,0,0],[],0,{})
	check(probe.received_page_zero_ready(),"Genuinely received zero remains distinct from unavailable")
	owner.objects[100].inventoryStats.erase("fields70")
	check(not probe.received_page_zero_ready(),"Removing current disclosure cannot borrow the prior numeric model")
	owner.objects[100].inventoryStats.fields70=["0",0,0,0,0,0]
	check(not probe.received_page_zero_ready(),"Malformed text does not become a received numeric score")
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	probe=null;owner=null
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual Values projection plus new test-probe readiness, including missing versus received zero. No server page ACK or production change."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
