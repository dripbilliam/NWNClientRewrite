extends SceneTree
const Policy=preload("res://systems/native_data/associate_creature_radial.gd")
class Text extends RefCounted:
	func raw(value:Dictionary)->String:return str(int(value.strRef))
class Rules extends RefCounted:
	var text:=Text.new()
var checks:=0
var failures:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value and failures.size()<30:failures.append(label)
static func signed32(value:int)->int:
	value&=4294967295
	return value-4294967296 if value&2147483648 else value
func compare_rows(actual:Array,observed:Array,label:String)->void:
	check(actual.size()==observed.size(),label+" count")
	for index in mini(actual.size(),observed.size()):
		var a:Dictionary=actual[index];var e:Dictionary=observed[index]
		check(int(a.slot)==int(e.slot) and a.icon==e.icon and a.label==str(int(e.tooltip)) and not a.disabled,label+" exactsector/icon/TLK #"+str(index))
		var callback:=str(e.callback)
		if callback=="0x140995f10":
			check(a.action=="world-associate" and a.command==int(e.argument32) and a.binding=={"type":39,"intParam":int(e.argument32),"associateType":1,"associateId":101} and a.canDrag,label+" command/assignment #"+str(index))
		elif callback=="0x140997f30":check(a.action=="world-associate" and a.command==-17 and not a.has("binding") and not a.canDrag,label+" Kick has source activation/no invented assignment")
		elif callback=="0x140996190":check(a.action=="interact" and a.interaction=="conversation.start" and a.binding=={"type":6},label+" Talk/direct target+assignment")
		elif callback=="0x1409980c0":check(a.action=="power" and a.binding=={"type":38},label+" Possess currentfamiliar source route")
		elif callback=="0x1409904b0":check(a.menu.kind=="spell-root",label+" controlled Cast targetmenu")
		elif callback=="0x140992730":check(a.menu.kind=="abilities",label+" controlled abilities")
		elif callback=="0x14098f8e0":check(a.menu.kind=="associate-actions" and a.menu.associateType==int(e.argument) and a.menu.targetId==101,label+" source actions type+target")
		elif callback=="0x140997e00":check(a.binding=={"type":40},label+" Examine assignment")
		else:check(false,label+" unclassified original callback "+callback)
func _initialize()->void:
	var output:="";var oracle_path:="";var callbacks_path:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
		if argument.begins_with("--oracle="):oracle_path=argument.trim_prefix("--oracle=")
		if argument.begins_with("--callbacks="):callbacks_path=argument.trim_prefix("--callbacks=")
	var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	var callbacks:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(callbacks_path))
	check(oracle.get("success")==true and oracle.get("rootCases")==48 and oracle.get("actionCases")==8 and oracle.get("callbackCases")==68,"complete original root/actions/command corpus124")
	check(oracle.get("transportView",{}).get("sourceSha256")=="1ca1340b018c41615d3175bc049501384a87674f9db598408ee3de9f401a85b2" and oracle.transportView.entries==365,"exact Python-int lowDWORD transport view; raw qword oracle preserved")
	check(callbacks.get("success")==true and callbacks.get("cases")==44,"complete original Examine/Talk/Possess/Kick44")
	var policy:=Policy.new();policy.rules=Rules.new()
	for observed in oracle.roots:
		var input:Dictionary=observed.input
		compare_rows(policy.root_rows(int(input.associateType),bool(input.actorPresent) and int(input.polymorph)==0,101),observed.entries,"original root "+str(input))
	for observed in oracle.actions:
		var type:=int(observed.input.associateType);var actual:=policy.action_rows(type,101)
		compare_rows(actual,observed.entries,"original actions "+str(type))
		check(actual[0].action==("associate-record" if type in [1,2,3,4] else "examine"),"source normal owned Examine destination "+str(type))
	for observed in oracle.callbacks:
		var input:Dictionary=observed.input;var command:=int(input.rawArgument)
		var actual:=policy.command_row([0,"IR_GUARD",0,command],101)
		if bool(input.partyPresent):
			var event:Dictionary=observed.observations[0]
			check(actual.targetId==int(event.target) and (actual.binding.type==39 and (((command&65535)<<16)|1)==int(event.packed) if bool(input.assignment) else actual.command==int(event.command)),"source callback exact wireDWORD / type39 packedSHORT "+str(input))
		else:check(observed.observations.is_empty(),"original absent party callback is inert; no runtime owner availability invented")
	for observed in callbacks.rows:
		var input:Dictionary=observed.input
		if input.kind=="examine" and not bool(input.assignment) and int(input.master)==99:
			var actual:Array=policy.action_rows(int(input.associateType),101)
			check(actual[0].action==("associate-record" if observed.observations[0].kind=="record" else "examine"),"original Examine callback destination "+str(input))
		elif input.kind=="kick" and int(input.associateType)==1:
			check(policy.action_rows(1,101)[1].command==int(observed.observations[0].command) and observed.observations.size()==1,"source henchman Kick suppresses party operation")
	var actor:={"id":99,"objectType":5,"playerState":{"playerFlags":0}}
	var target:={"id":101,"objectType":5,"replicated":{"master":99,"field908":1}}
	var context:={"dmPermission":false}
	var samples:Array=[]
	for type in [0,1,2,3,4,5,6,65535]:
		target.replicated.field908=type
		for flags in [0,1024,131072,132096,4294967295]:
			actor.playerState.playerFlags=flags
			var model:=policy.project(actor,target,context)
			check(model.available and model.missing.is_empty() and model.entries.any(func(value):return value.slot==1)==((flags&1024)==0),"known received flags select Cast exactly type"+str(type)+" flags"+str(flags))
			var actions:=policy.project(actor,target,context,true)
			check(actions.available and actions.entries[0].action==("associate-record" if type in [1,2,3,4] else "examine"),"known action destination "+str(type))
	target.replicated.field908=1;actor.playerState.playerFlags=0
	for key in ["master","field908"]:
		var changed:=target.duplicate(true);changed.replicated.erase(key)
		var model:=policy.project(actor,changed,context)
		check(not model.available and model.entries.is_empty() and model.missing.has("clicked.replicated."+key),"missing "+key+" cannot become a default")
	var missing_flags:=actor.duplicate(true);missing_flags.playerState.clear()
	check(not policy.project(missing_flags,target,context).available,"missing playerFlags cannot mean unpolymorphed")
	for value in [null,-1,65536,"1",true]:
		var changed:=target.duplicate(true);changed.replicated.field908=value
		check(not policy.project(actor,changed,context).available,"malformed type remains unavailable "+str(value))
	for value in [null,true,0,1]:
		check(not policy.project(actor,target,{"dmPermission":value}).available,"no unknown/DM permission normal fallback "+str(value))
	var other_master:=target.duplicate(true);other_master.replicated.master=100
	check(not policy.project(actor,other_master,context).available,"unowned target is not an associate")
	var self_target:=target.duplicate(true);self_target.id=99
	check(not policy.project(actor,self_target,context).available,"self stays separate even malformed master points at self")
	var before_actor:=actor.duplicate(true);var before_target:=target.duplicate(true)
	var detached:=policy.project(actor,target,context);detached.entries[0].binding.intParam=777;detached.missing.append("changed")
	check(actor==before_actor and target==before_target and policy.project(actor,target,context).entries[0].binding.intParam==-7,"detached views cannot mutate received owners or later views")
	for _index in 500:
		var start:=Time.get_ticks_usec();policy.project(actor,target,context);policy.project(actor,target,context,true);samples.append(Time.get_ticks_usec()-start)
	samples.sort()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"originalCases":168,"projectionPairUsecMedian":samples[samples.size()/2],"projectionPairUsecP95":samples[int(samples.size()*0.95)],"projectionPairUsecMax":samples[-1],"scope":"New unimported detached associate policy vs124+44 unchanged-original captured-boundary cases; received-owner unknown/mutation tests. Pair timing is synchronous authored-text CPU work, not actual input, server outcome, pixels, font/art preparation or FPS."}
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n");file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
