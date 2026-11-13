extends SceneTree
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Special=preload("res://systems/native_render/special_attack_world.gd")
var failures: Array[String]=[]
var checks:=0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
class RigStub extends RefCounted:
	var entities: Dictionary={17:{"context":{"fieldDD":0}}}
class HostStub extends Node:
	var retired:=false
	var rigs:=RigStub.new()
class WorldStub extends RefCounted:
	var controlled_id:=17
	var desired: Dictionary={}
	var installed: Dictionary={17:"one"}
class ManagerStub extends RefCounted:
	var world:=WorldStub.new()
	var tables: Dictionary={}
	var actor: Dictionary={}
	var host_node: Node
	var warmed: Array=[]
	func host(_id: int):return host_node
	func object(_id: int):return actor
	func ensure_models(resources: Dictionary) -> bool:warmed.append(resources.duplicate());return true
class MutatingSpecial extends Special:
	var initialized:=0
	func initialize_record(record: Dictionary) -> bool:
		initialized+=1
		record.source.playerState.feats.append(39)
		record.source.playerState.feats.append(296)
		return true
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var report: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var rules:=Rules.new()
	var actor: Dictionary={"playerState":{"feats":[213,{"id":"0x27"},"bad",-1,39],"bonusFeats":[296,213]},"inventoryStats":{"feats":[{"id":5.9},"6"],"fields118":[6,7],"fields128":[7,8]}}
	var canonical:=var_to_bytes(actor)
	check(Rules.collect_feats(actor)==[213,39,296,5,6,7,8],"Source ordering, number parsing, duplicate admission and filtering remain exact")
	check(var_to_bytes(rules.feats(actor))==var_to_bytes(Rules.collect_feats(actor)),"Existing instance API returns exact static collection bytes")
	var first:=Rules.collect_feats(actor);var second:=Rules.collect_feats(actor);first.append(999)
	check(not second.has(999) and var_to_bytes(actor)==canonical,"Every call owns a fresh result without changing received arrays")
	actor.playerState.feats=[12]
	check(Rules.collect_feats(actor)[0]==12 and not Rules.collect_feats(actor).has(39),"Later calls read current mutable source values")
	check(Rules.collect_feats({}).is_empty(),"Missing source groups retain an empty fresh result")
	rules=null
	var manager:=ManagerStub.new();var host:=HostStub.new();root.add_child(host);manager.host_node=host
	manager.actor={"id":17,"objectType":5,"nativeLifetime":1,"appearance":{"appearance":1},"playerState":{"feats":[213]},"replicated":{"stats":{"classes":[{"id":5,"level":15}]}}}
	manager.world.desired[17]={"key":"one","object":manager.actor}
	var special:=MutatingSpecial.new();special.manager=manager
	special.observe(manager.actor)
	check(special.initialized==1 and special.records.has(17),"Actual special observe initialization branch executes")
	check(special.records[17].initial_signature[1]==[213],"The first fresh collection stays stable across initialization callbacks")
	check(special.warm_signature==[17,1,true,true,true],"The second actual observe collection sees callback-added current feats")
	check(manager.warmed.size()==1 and manager.warmed[0].has("vcm_monkki") and manager.warmed[0].has("vcm_monkstun") and manager.warmed[0].has("vcm_monkquiv"),"Owned ability warmup follows the fresh post-callback collection")
	var providers: Dictionary=special.providers(special.records[17])
	check(providers.gate.call(0)==1,"Actual special provider gate sees received feats")
	manager.actor.playerState.feats=[]
	check(providers.gate.call(0)==0,"Every later provider invocation recollects current feats")
	providers.clear();special.records.clear();special.manager=null;special=null;manager.host_node=null;manager=null;host.free()
	await process_frame;await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Pure collection ordering/alias/current values and actual Special.observe/provider call sites across an initialization mutation boundary; no assets, GPU or server"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
