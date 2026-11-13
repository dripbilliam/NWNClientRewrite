extends SceneTree
const Desktop=preload("res://systems/native_game_desktop.gd")
class View extends RefCounted:
	var resets:=0
	func reset() -> void: resets+=1
class Wheel extends View:
	var active:=true
	var request_id:=10
	var menu_id:=20
	func reset() -> void:
		super.reset(); active=false; request_id+=1; menu_id=-1
class Text extends RefCounted:
	func raw(value: Dictionary) -> String: return str(value.strRef)
class Chat extends RefCounted:
	var messages: Array=[]
	func append_message(value: Dictionary) -> void: messages.append(value)
class Owner extends RefCounted:
	var text:=Text.new()
	var chat:=Chat.new()
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var desktop:=Desktop.new(); var wheel:=Wheel.new(); var view:=View.new(); var sent: Array=[]
	for field in ["party","quickbar","sheet","book","journal","area_map","players","buffs","level_up","action_queue"]: desktop.set(field,view)
	desktop.radial=wheel; desktop.actor_id=99; desktop.generation=1; desktop.area_id=10; desktop.objects={99:{"id":99,"objectType":5}}; desktop.request.connect(func(message):sent.append(message))
	var select:={"requestId":10,"menuId":20,"slot":0}
	desktop.radial_entries={0:{"action":"activity","activityId":0}}; desktop.radial_stack=[{"kind":"abilities"}]
	desktop.radial_select(select.merged({"menuId":19},true)); check(sent.is_empty() and wheel.active,"An earlier menu page cannot dispatch into the current wheel")
	desktop.radial_entries[0].disabled=true; desktop.radial_select(select); check(sent.is_empty() and wheel.active,"A disabled action is rejected by the owning desktop too")
	desktop.radial_entries[0].disabled=false; desktop.radial_select(select)
	check(sent.size()==1 and int(sent[0].actorId)==99 and int(sent[0].areaId)==10 and int(sent[0].generation)==1,"A valid current radial action carries its actor, area and generation")
	desktop.radial_select(select); check(sent.size()==1,"A closed wheel rejects a duplicate selection")
	var owner:=Owner.new(); desktop.owner_ui=owner
	for field in ["feats","bonusFeats"]:
		desktop.objects[99].playerState={field:[240]}
		desktop.command({"kind":"native-activity","activityId":0})
		check(sent.size()==1 and owner.chat.messages[-1]=={"system":true,"text":"66728"},"Original Keen Senses Search feedback stays local for "+field)
	for change in ["area","generation","actor"]:
		wheel.active=true; wheel.menu_id=21; desktop.radial_entries={0:{"action":"activity","activityId":1}}; desktop.radial_stack=[{"kind":"abilities"}]; desktop.pending_shortcuts={"index":5}
		var old:={"requestId":wheel.request_id,"menuId":21,"slot":0}
		var epoch:=desktop.generation+int(change=="generation"); var area:=desktop.area_id+int(change=="area"); var actor:=desktop.actor_id+int(change=="actor")
		desktop.set_world(epoch,area,actor,{actor:{"id":actor,"objectType":5}},{}); desktop.radial_select(old)
		check(not wheel.active and desktop.radial_stack.is_empty() and desktop.radial_entries.is_empty() and desktop.pending_shortcuts.is_empty() and sent.size()==1,"A changed "+change+" retires menu history, pending assignment and old action handles")
	desktop.objects.clear(); desktop.command({"kind":"native-activity","activityId":0}); check(sent.size()==1,"A removed controlled actor cannot submit an activity")
	desktop.free()
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Actual desktop selection and set_world retirement across actor/area/generation; request capture only, no server outcome."},"  ")); file.close(); quit(0 if failures.is_empty() else 1)
func _initialize() -> void: call_deferred("run")
