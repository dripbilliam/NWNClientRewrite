extends SceneTree
const Identity=preload("res://systems/native_data/player_identity.gd")
var checks:=0
var failures:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:
	var fixture:="";var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture="):fixture=argument.trim_prefix("--fixture=")
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	check(data.get("success")==true and data.get("stages",[]).size()==19,"actual Session World host fixture complete")
	for stage in data.stages:
		var expected:Dictionary=stage.expected;var header:Dictionary=stage.header
		var lookup:=Identity.selected_lookup(header.players,header.playerRosterKnown,stage.target)
		var role:=Identity.permission(header.gameMasterPermission)
		var context:=Identity.normal_context(header,stage.target)
		check(lookup.available==expected.lookupAvailable and lookup.isPlayer==expected.isPlayer,"typed selected lookup "+str(stage.label))
		check(role.available==expected.roleAvailable and role.permission==expected.dmPermission,"typed connection permission "+str(stage.label))
		check(context.available==expected.normalAdmission,"native normal-context admission "+str(stage.label))
	var source:Dictionary=data.stages[3].header
	var detached:=Identity.selected_lookup(source.players,true,2147483650);detached.selectedId=0
	check(Identity.selected_lookup(source.players,true,2147483650).selectedId==2147483650,"consumer data detached")
	check(not Identity.permission({"permission":0,"source":"guess","field114":null,"parameter":null}).available,"guessed normal permission unavailable")
	check(not Identity.selected_lookup([],false,1).available,"initial empty roster is not NPC evidence")
	check(not Identity.selected_lookup([],true,Identity.INVALID).available,"invalid target not a player lookup")
	var result={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual in-memory Session/typed decoder/World/same host producer into native metadata selector admission. Desktop world dispatch, server outcomes and graphical acceptance remain separate."}
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n");file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
