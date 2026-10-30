extends SceneTree
const Body=preload("res://systems/native_data/animation_body_type.gd")
const Lookup=preload("res://systems/native_data/animation_lookup.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL ",reason)
func _initialize() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	# Exhaustive recovered native branch outcomes over P/S/F/L presence. W is
	# deliberately unrelated, as in the observed server Gnoll_Warrior row FW.
	var oracle:={"":2,"P":1,"S":2,"PS":1,"F":1,"PF":1,"SF":2,"PSF":1,"L":3,"PL":2,"SL":2,"PSL":2,"FL":3,"PFL":2,"SFL":2,"PSFL":2}
	for flags in oracle:
		check(Body.classify(flags)==int(oracle[flags]),"Original MODELTYPE flag priority: "+str(flags))
		check(Body.classify(str(flags)+"W")==int(oracle[flags]),"Additional server flags preserve original classification: "+str(flags)+"W")
	check(Body.classify("fw")==2,"Native flag search remains case-sensitive")
	var object:={"id":17,"appearance":{"appearance":0,"equipment":[]}}
	var tables:={"appearance":{"orderedRows":[{"MODELTYPE":"FW"}]}}
	var actual:=Lookup.new().context(object,tables)
	check(actual.fieldDE==1 and actual.model_type=="FW","Actual server-table context honors compound FW instead of an exact enum comparison")
	tables.appearance.orderedRows[0].MODELTYPE="SFL"
	check(Lookup.new().context(object,tables).fieldDE==2,"Actual context retains original S-priority for compound flags")
	var lookup:=Lookup.new(); var context:={"fieldDE":Body.classify("FW"),"fieldDD":1,"fieldDF":2,"fieldE0":0,"fieldE8":0,"fieldEC":0}
	check(lookup.name_for(0,context)=="pause1" and lookup.name_for(2,context)=="walk" and lookup.name_for(4,context)=="run","FW requests the original humanoid idle/walk/run clip family")
	context.fieldDE=0
	check(lookup.name_for(0,context)=="cpause1" and lookup.name_for(2,context)=="cwalk" and lookup.name_for(4,context)=="crun","Previous FW classification requests a different creature clip family")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"original_body_refresh":"0x1409795c0","original_setter":"0x14080a2d0","scope":"Exhaustive recovered native MODELTYPE flag branches plus original lookup idle/walk/run names; no live NPC playback or visual acceptance","game_network_connections":0},"  ")); file.close(); quit(0 if failures.is_empty() else 1)
