extends SceneTree
const Actor=preload("res://systems/native_data/combat_actor.gd")
const Selector=preload("res://systems/attack_animation.gd")
const ClassState=preload("res://systems/native_data/combat_class_state.gd")
const Presentation=preload("res://systems/native_render/combat_presentation.gd")
class PrivateRig extends Node:
	signal animation_event(id: int,name: String,serial: int)
	var entities: Dictionary={21:{}}
class PrivateActor extends Node3D:
	var rigs
	func configure(object: Dictionary) -> void:
		rigs=PrivateRig.new();add_child(rigs)
		set_meta("native_combat_actor",Actor.project(object,{}))
var checks:=0
var failures: Array=[]
var projection_cpu: Dictionary={}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func source() -> Dictionary: return {"id":21,"objectType":5,"nativeLifetime":3,"replicated":{}}
func owners() -> void:
	var object:=source();var before:=object.duplicate(true);var initial:=ClassState.project(object)
	check(initial.known and not initial.monk and initial.source=="native-constructor-7ea230","Valid private creature starts with the original non-monk constructor flag")
	check(object==before,"Private class construction creates no canonical stat/class fields")
	object.replicated.stats={"classes":[{"id":5,"level":0}]};var received:=ClassState.project(object,initial)
	check(received.known and received.monk and received.source=="received-creature-classes","Actual received class slot5 replaces constructor state even at level0")
	object.replicated.erase("stats");check(ClassState.project(object,received)==received,"Same logical creature retains received projection across absent disclosure/model change")
	object.replicated.stats={"classes":[]};var empty:=ClassState.project(object,received)
	check(empty.known and not empty.monk and empty.source=="received-creature-classes","Explicit received empty class array replaces the previous monk projection")
	for malformed in [null,{},[{"id":"5"}],[{"id":5.5}],[{"id":-1}],[{"id":256}],[{}],[null],range(9)]:
		object.replicated.stats={"classes":malformed};var rejected:=ClassState.project(object,received)
		check(not rejected.known and rejected.monk==null,"Malformed class disclosure remains unknown: "+str(malformed))
	object.replicated.stats={"classes":null};var unknown:=ClassState.project(object,received);object.replicated.erase("stats")
	check(ClassState.project(object,unknown)==unknown,"Unavailable projection cannot silently recover through an absent update")
	object.nativeLifetime=4;var next:=ClassState.project(object,received)
	check(next.known and not next.monk and next.lifetime==4,"New logical lifetime retires the previous received class projection")
	object.nativeLifetime=2;check(not ClassState.project(object,received).monk,"A previous projection from another lifetime cannot alias an older supplied owner")
	object=source();var foreign:=received.duplicate(true);foreign.id=22
	check(not ClassState.project(object,foreign).monk,"Foreign actor class state cannot be retained")
	for value in [null,0,-1,1.5]:
		object=source();object.nativeLifetime=value;check(not ClassState.project(object,received).known,"Missing or malformed disclosure identity never receives a constructor default: "+str(value))
	for patch in [{"id":0x7f000000},{"id":null},{"objectType":9},{"replicated":null}]:
		object=source();object.merge(patch,true);check(not ClassState.project(object,received).known,"Invalid owner/type/replication cannot acquire a known class projection")
	object=source();object.replicated.stats={"classes":[{"id":5}]};before=object.duplicate(true)
	var first:=PrivateActor.new();root.add_child(first);first.configure(object)
	var presentation:=Presentation.new();root.add_child(presentation);presentation.sync(21,object,first)
	check(presentation.engine.actors[21].monk,"Actual combat sync accepts a received private class flag")
	var absent:=source();var replacement:=PrivateActor.new();root.add_child(replacement);replacement.configure(absent)
	check(not replacement.get_meta("native_combat_actor").monk,"Replacement model starts with its independent private constructor metadata")
	presentation.sync(21,absent,replacement)
	check(presentation.engine.actors[21].monk and presentation.engine.actors[21].classState.source=="received-creature-classes","Actual model replacement retains engine-owned class projection for the same logical lifetime")
	absent.nativeLifetime=4;presentation.sync(21,absent,replacement)
	check(not presentation.engine.actors[21].monk and presentation.engine.actors[21].lifetime==4,"Actual sync retires class projection when the logical lifetime changes")
	check(object==before and not absent.replicated.has("stats"),"Actual sync never publishes invented canonical classes or stats")
	presentation.close();presentation.sync(21,object,first);check(presentation.engine.actors.is_empty(),"Closed presentation ignores late class/model data")
	presentation.free();first.free();replacement.free()
	var sample:=source();sample.replicated.stats={"classes":[{"id":4},{"id":5}]};var metadata: Dictionary={};var elapsed: Array=[]
	for index in 200:
		var began:=Time.get_ticks_usec();Actor.refresh(metadata,sample);elapsed.append(Time.get_ticks_usec()-began)
	elapsed.sort();projection_cpu={"count":elapsed.size(),"medianUs":elapsed[int(elapsed.size()/2)],"p95Us":elapsed[int(ceil(elapsed.size()*0.95))-1],"maximumUs":elapsed[-1],"scope":"Synchronous private Actor.refresh calls only; no resource read, frame, GPU, server or FPS acceptance"}
	check(metadata.monk and metadata.classState.source=="received-creature-classes","Repeated metadata refresh retains the actual received class projection")
func selected(row: Dictionary,received: bool) -> Dictionary:
	var c: Dictionary=row.case
	var object:={"id":21,"objectType":5,"nativeLifetime":3,"replicated":{"animation":0,"animationSpeed":1.0}}
	if received: object.replicated.stats={"classes":c.classes.map(func(id):return {"id":int(id),"level":1})}
	var context:={"fieldDE":1,"fieldDD":1,"fieldE0":int(c.side)}
	var actor:={"id":21,"objectType":5,"lifetime":3,"position":Vector3(1,0,0),"orientation":Vector3.RIGHT,"preferredDistance":1.0,"weaponScale":1.0,"equipment":{},"context":context}
	if c.weapon: actor.equipment["16"]={"baseItem":22,"slashLeft":50,"slashRight":50,"preferredDistance":1.0}
	Actor.refresh(actor,object)
	var target:={"id":22,"objectType":5,"position":Vector3.ZERO,"orientation":Vector3.RIGHT,"facingTarget":21,"hitDistance":0.0,"base":0}
	var selector:=Selector.new(); selector.random_state=int(c.seed)
	selector.actors={21:actor,22:target};selector.state={21:{"side":int(c.side),"base":0,"context":context},22:{"base":0}}
	var record:={"targetId":22,"ranged":0,"weaponAttackType":1,"attackType":0,"reaction":1,"reactionDuration":1000,"duration":1000}
	var code:=selector.select(actor,record)
	return {"animation":code,"side":selector.state[21].side,"contextSide":selector.state[21].context.fieldE0,"reaction":record.reaction,"draws":selector.draws,"monk":actor.monk}
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(oracle.success and oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Original constructor/near-selector corpus identity")
	var missing: Array=[]
	for row in oracle.selectorCases:
		var actual:=selected(row,true)
		check(int(actual.animation)==int(row.animation) and int(actual.side)==int(row.side) and int(actual.contextSide)==int(row.contextSide) and int(actual.reaction)==int(row.reaction) and int(actual.draws)==int(row.draws),"Received physical class slots match original near-selector: "+str(row.case))
		if row.case.classes.size()==1 and int(row.case.classes[0])==4:
			var absent:=selected(row,false); missing.append({"case":row.case,"actual":absent,"expected":row})
			check(absent.monk is bool and not absent.monk and int(absent.animation)==int(row.animation) and int(absent.side)==int(row.side) and int(absent.draws)==int(row.draws),"Undisclosed classes preserve the original private non-monk constructor near attack: "+str(row.case))
	owners();await process_frame
	var output:={"success":failures.is_empty(),"checks":checks,"failures":failures,"missingCases":missing,"projectionCpu":projection_cpu,"originalSelectorCases":oracle.selectorCases.size(),"originalConstructorCases":oracle.constructorCases.size(),"serverConnections":0,"gpu":false,"scope":"Actual combat metadata refresh and near-selector against complete original constructor/GetClass/selector cases. Missing-class source-owner repro only; no canonical stats write, server/pixel/NPC outcome claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(output,"  ")+"\n");file.close();quit(0 if failures.is_empty() else 1)
