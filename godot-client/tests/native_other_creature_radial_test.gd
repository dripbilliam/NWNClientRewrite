extends SceneTree
const Policy=preload("res://systems/native_data/other_creature_radial.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
class Text extends RefCounted:
	func raw(value:Dictionary)->String:return str(int(value.strRef))
var checks:=0
var failures:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value and failures.size()<30:failures.append(label)
func _initialize()->void:
	var output:="";var oracle_path:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
		if argument.begins_with("--oracle="):oracle_path=argument.trim_prefix("--oracle=")
	var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	check(oracle.get("success")==true and oracle.get("cases")==2304,"complete original993790 corpus")
	var rules:=Rules.new();rules.text=Text.new();var policy:=Policy.new();policy.rules=rules
	var actor={"id":99,"objectType":5,"replicated":{"field8D4":128},"playerState":{"visibility":{}}}
	var target={"id":100,"objectType":5,"replicated":{"field8D4":1,"field8D6":0,"reaction":0,"stats":{"racialType":8,"field4E8":false}}}
	var context={"dmPermission":false,"playerLookup":{"available":true,"isPlayer":false},"skills":{"0":{"available":true,"value":true},"13":{"available":true,"value":true}}}
	var samples:Array=[]
	for observed in oracle.rows:
		var input:Dictionary=observed.input
		actor.replicated.field8D4=int(input.controlledFlags);actor.playerState.visibility={}
		if input.castVisible!=null:actor.playerState.visibility["100"]=[bool(input.castVisible),false,false]
		target.replicated={"field8D4":int(input.targetFlags),"field8D6":int(input.mode),"field8D8":int(input.related),"reaction":int(input.reaction),"stats":{"racialType":int(input.racialType),"field4E8":bool(input.loot)}}
		context.playerLookup.isPlayer=bool(input.isPlayer)
		for id in [0,13]:context.skills[str(id)].value=(int(input.skills)&(1<<id))!=0
		var start:=Time.get_ticks_usec();var model:=policy.project(actor,target,context);samples.append(Time.get_ticks_usec()-start)
		check(model.entries.size()==observed.entries.size(),"original count "+str(input))
		for i in mini(model.entries.size(),observed.entries.size()):
			var actual:Dictionary=model.entries[i];var expected:Dictionary=observed.entries[i]
			var disabled:Array=observed.disabled.map(func(slot):return int(slot))
			check(int(actual.slot)==int(expected.slot) and actual.icon==expected.icon and actual.label==str(int(expected.tooltip)) and bool(actual.disabled)==disabled.has(int(expected.slot)),"original entry "+str(input)+" #"+str(i))
		check(model.missing.is_empty(),"known fixtures have no unavailable fields "+str(input))
	context.playerLookup={"available":false,"isPlayer":null};var model:=policy.project(actor,target,context)
	check(model.entries.size()==2 and model.missing.has("clicked.selected-character-player-lookup"),"missing player metadata not an NPC")
	context.playerLookup={"available":true,"isPlayer":false};context.skills={};target.replicated.field8D4=1;target.replicated.reaction=0
	model=policy.project(actor,target,context)
	check(not model.entries.any(func(value):return value.get("action")=="world-skill") and model.missing.has("controlled.native-skill-admission.0"),"unknown override/admission never grants a skill")
	context.skills={"0":{"available":true,"value":true}};target.replicated.stats={"race":8}
	model=policy.project(actor,target,context)
	check(model.entries.any(func(value):return value.slot==4 and value.disabled and value.get("availability")=="unavailable"),"legacy race BYTE cannot replace missing racialType WORD")
	actor.playerState.clear();model=policy.project(actor,target,context)
	check(model.entries[1].disabled and model.missing.has("controlled.playerState.visibility"),"missing cast visibility owner unavailable")
	context.dmPermission=true;check(policy.project(actor,target,context).entries.is_empty(),"DM permission cannot use normal policy")
	context.dmPermission=null;check(policy.project(actor,target,context).entries.is_empty(),"unknown DM context cannot use normal policy")
	context.dmPermission=false;actor.playerState={"visibility":{}};var before:=target.duplicate(true);model=policy.project(actor,target,context);model.entries[0].label="mutated";model.missing.clear()
	check(target==before and policy.project(actor,target,context).entries[0].label!="mutated","detached data views cannot mutate current source")
	samples.sort();var result={"success":failures.is_empty(),"checks":checks,"failures":failures,"projectionUsecMedian":samples[samples.size()/2],"projectionUsecP95":samples[int(samples.size()*0.95)],"projectionUsecMax":samples[-1],"scope":"Independent normal993790 policy versus2304 unchanged original fixtures; captured player/skill/DM service results. No Desktop binding, active context selector, server or graphical acceptance."}
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n");file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
