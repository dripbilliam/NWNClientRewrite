extends SceneTree
const Policy=preload("res://systems/native_data/creature_radial.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
class Text extends RefCounted:
	func raw(value: Dictionary) -> String:return str(value.text) if value.has("text") else "Accept" if int(value.get("strRef",0))==6386 else str(int(value.get("strRef",0)))
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report):quit(2);return
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	if not oracle is Dictionary or oracle.get("success")!=true:quit(2);return
	var rules:=Rules.new();rules.text=Text.new();var policy:=Policy.new();policy.rules=rules
	for value in oracle.rows:
		var input: Dictionary=value.input
		var actor:={"id":99,"replicated":{"field908":int(input.get("associateType",0))},"playerState":{"playerFlags":int(input.polymorph)*1024+int(input.locked)*131072}}
		if input.party is Array:
			actor.replicated.party={"player":int(input.party[0]),"field8D4Bit6":int(input.party[1]),"singleton":int(input.party[2]),"leader":int(input.party[3]),"field7DC":int(input.party[4]),"field7D8":100,"firstName":{"text":"SourceInviter"}}
		var result:=policy.self_role(actor,{"partyOwnerPresent":bool(input.get("partyOwnerPresent",true))})
		if value.role4==null:check(result.entry.is_empty(),"Original no role4 "+str(input))
		else:
			var expected: Dictionary=value.role4;var actual: Dictionary=result.entry
			check(not actual.is_empty() and int(actual.slot)==4 and actual.icon==expected.icon,"Original role4 precedence "+str(input))
			if not actual.is_empty():
				check(actual.label==expected.get("label",str(int(expected.get("tooltip",0)))),"Original role4 label/TLK "+str(input))
				check(actual.action==("world-cancel-polymorph" if expected.icon=="IR_SKILLSELF" else "world-associate" if expected.icon=="IFE_UNPOSSESS" else "world-party"),"Original role4 direct action "+str(input))
	var familiar:={"id":99,"replicated":{"field908":3,"party":{"player":true,"field8D4Bit6":true,"singleton":false,"leader":false,"field7DC":false}},"playerState":{"playerFlags":0}}
	check(policy.self_role(familiar,{"partyOwnerPresent":true}).entry.command==-13,"Familiar Unpossess takes precedence over party Leave")
	familiar.playerState.playerFlags=1024
	check(policy.self_role(familiar,{"partyOwnerPresent":true}).entry.action=="world-cancel-polymorph","Source CancelShape overrides familiar role4 too")
	familiar.playerState.playerFlags=131072+1024
	check(policy.self_role(familiar,{"partyOwnerPresent":true}).entry.command==-13,"Received locked-shape bit suppresses only CancelShape override")
	familiar.playerState.erase("playerFlags")
	check(not policy.self_role(familiar,{"partyOwnerPresent":true}).available and policy.self_role(familiar,{"partyOwnerPresent":true}).entry.is_empty(),"Missing received player flags do not invent normal shape state")
	familiar.playerState.playerFlags=0;familiar.replicated.field908=1
	check(policy.self_role(familiar,{"partyOwnerPresent":true}).entry.action=="none","Original997f30 does not send a party Leave packet for captured henchman context")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Normal-player party/familiar/shape role4 vs unchanged original fixtures; DM role not integrated or accepted."},"  "));file.close();quit(0 if failures.is_empty() else 1)
