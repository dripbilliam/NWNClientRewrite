extends SceneTree
const Actor=preload("res://systems/native_data/combat_actor.gd")
var failures: Array=[]
var checks:=0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var object:={"id":1,"nativeLifetime":1,"objectType":5,"appearance":{"appearance":0,"equipment":[]},"replicated":{}}
	var tables:={"appearance":{"orderedRows":[{"HITDIST":"0.3","PREFATCKDIST":"1.7"}]},"baseitems":{"orderedRows":[{"WeaponType":"3","WeaponWield":"2","WeaponSize":"1","%AnimSlashL":"25","%AnimSlashR":"75","PrefAttackDist":"1.2"}]}}
	object.appearance.equipment=[{"slot":2,"item":{"modelType":3,"parts":[0,1],"colors":[2,3]}}]
	var projected:=Actor.project(object,tables)
	check(projected.equipment.is_empty(),"Visual-only clothing does not invent combat base item zero")
	check(projected.preferredDistance!=null and projected.hitDistance!=null,"Missing equipment metadata does not abort the rest of the actor projection")
	check(not object.appearance.equipment[0].item.has("baseItem"),"Projection leaves source equipment unmodified")
	for unknown in [null,"0",0.5,NAN,INF]:
		object.appearance.equipment[0].item.baseItem=unknown
		check(Actor.project(object,tables).equipment.is_empty(),"Unavailable/malformed item type remains absent: "+str(unknown))
	for known in [0,0.0]:
		object.appearance.equipment[0].item.baseItem=known;projected=Actor.project(object,tables)
		check(projected.equipment.has("2") and projected.equipment["2"].baseItem==0 and projected.equipment["2"].weaponType==3 and projected.equipment["2"].slashRight==75,"Explicit base item zero retains actual active-table projections")
	object.appearance.equipment=[{"slot":2,"item":{"modelType":3}},{"slot":16,"item":{"baseItem":0}}];projected=Actor.project(object,tables)
	check(not projected.equipment.has("2") and projected.equipment.has("16"),"An unknown visual entry does not suppress another fully known equipped item")
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Native CombatActor equipment omission/admission and remaining actor projections for visual-only preview payloads and actual whole base-item IDs. No rendering/server/complete combat acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
