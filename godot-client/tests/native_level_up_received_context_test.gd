extends SceneTree
const Gate=preload("res://systems/native_data/level_up_received_context.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","fixture"]) or FileAccess.file_exists(args.report):quit(2);return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	for row in fixture.rows:
		var before: Dictionary=row.actor.duplicate(true);var projected:=Gate.snapshot(row.actor)
		check(projected.ready==row.ready and (not projected.ready or projected.value==row.snapshot),"Exact JSON-visible networkLevelUpSnapshot shape, including missing/null keys: "+str(row.name))
		if projected.ready:
			projected.value.classes[0].level=99
			check(row.actor==before,"Projection is detached from the actual opaque received source: "+str(row.name))
	var actor: Dictionary=fixture.rows[0].actor;var original:=actor.duplicate(true);var scope: Array=[5,7,42]
	var begin:={"token":11,"snapshot":fixture.rows[0].snapshot,"available":[true,false],"protocolFeatures":{"multiclassRuleset":true},"draftContext":{"baseFortitude":null,"other":"preserved"}};var baseline:=begin.duplicate(true)
	var late:=actor.duplicate(true);late.inventoryStats={"field9c":0}
	var gate:=Gate.new();check(gate.capture(begin,scope,3,actor).armed,"Missing context captures only the current token/menu/native disclosure lifetime")
	var offered:=gate.observe(scope,11,3,late,false,false,false)
	check(offered.ready and offered.action=="Reload choices" and offered.sends==0 and not offered.serverAcknowledged,"Late received zero enables an explicit local action without packet/ACK")
	var selected:=gate.retry(scope,11,3,late,false,false,false)
	check(selected.ready and selected.result.token==11 and selected.result.snapshot==begin.snapshot and selected.result.available==begin.available and selected.result.protocolFeatures==begin.protocolFeatures and selected.result.draftContext=={"baseFortitude":0,"other":"preserved"},"Explicit retry changes only detached draftContext, preserving transaction and comparison")
	check(not gate.retry(scope,11,3,late,false,false,false).ready and not gate.armed,"A consumed retry cannot replay")
	check(actor==original and begin==baseline,"Received actor and original begin result remain unchanged")
	for value in [-128,-1,0,127,false,true,-129,128,0.5,"0",null]:
		gate.capture(begin,scope,3,actor);var current:=actor.duplicate(true);current.inventoryStats={"field9c":value}
		var valid: bool=(value is float or value is int) and value>=-128 and value<=127 and float(value)==floor(float(value))
		check(gate.observe(scope,11,3,current,false,false,false).ready==valid and (not gate.ready or Gate.fortitude(current)==value),"Strict received signed CHAR eligibility: "+str(value))
		gate.close()
	var known:=begin.duplicate(true);known.draftContext.baseFortitude=0
	check(not gate.capture(known,scope,3,actor).ready and not gate.armed,"A valid known begin zero is never replaced by a later value")
	check(not gate.capture(begin,scope,3,late).ready and not gate.armed,"Ambiguous already-present native context is excluded from the initial proposal")
	for kind in ["generation","area","actor","serial","token","nativeLifetime","clientKnownLifetime","removed","type","actorArea"]:
		gate.capture(begin,scope,3,actor);var current:=late.duplicate(true);var now:=scope.duplicate();var serial:=3;var token:=11
		match kind:
			"generation":now[0]=6
			"area":now[1]=8
			"actor":now[2]=43
			"serial":serial=4
			"token":token=12
			"nativeLifetime":current.nativeLifetime+=1
			"clientKnownLifetime":current.clientKnownLifetime+=1
			"removed":current.replicationRemoved=true
			"type":current.objectType=6
			"actorArea":current.areaId=8
		check(not gate.observe(now,token,serial,current,false,false,false).ready and not gate.armed,"Stale/foreign retry retires without changing draft: "+kind)
	for kind in ["class","skill","ability","feat","book","null","missing","notLevelable"]:
		gate.capture(begin,scope,3,actor);var current:=late.duplicate(true)
		match kind:
			"class":current.replicated.stats.classes[0].level+=1
			"skill":current.playerState.levelUp.skills[0]+=1
			"ability":current.playerState.abilities.base[0]+=1
			"feat":current.playerState.feats.append(99)
			"book":current.playerState.spellbooks["0"].known.append(99)
			"null":current.replicated.stats.fieldDE4=null
			"missing":current.replicated.stats.erase("fieldDE4")
			"notLevelable":current.playerState.combat.canLevelUp=false
		check(not gate.observe(scope,11,3,current,false,false,false).ready and not gate.armed,"Exact comparison retirement includes absent versus null: "+kind)
	gate.capture(begin,scope,3,actor)
	check(not gate.observe(scope,11,3,late,true,false,false).ready and not gate.observe(scope,11,3,late,false,false,false).ready,"A user edit, including uncommitted text, permanently fences this candidate even after undo")
	gate.close();gate.capture(begin,scope,3,actor)
	check(not gate.observe(scope,11,3,late,false,true,false).ready and gate.observe(scope,11,3,late,false,false,false).ready,"Waiting UI remains masked without inventing a context result")
	gate.close();gate.capture(begin,scope,3,actor)
	check(not gate.observe(scope,11,3,late,false,false,true).ready and not gate.armed and not gate.observe(scope,11,3,late,false,false,false).ready,"Once a proposal was sent, later submitting=false cannot revive the retry")
	gate.capture(begin,scope,3,actor);var moved:=late.duplicate(true);moved.replicated.position=[9,8,7]
	check(gate.observe(scope,11,3,moved,false,false,false).ready,"Unrelated received motion is opaque and does not alter the level-up snapshot")
	gate.close();check(not gate.armed and not gate.ready and gate.original.is_empty(),"Close/reset retires retained private context")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"productionApplied":false,"sends":0,"serverConnections":0,"gpu":false,"scope":"NEW unimported late-S9c gate and actual JavaScript networkLevelUpSnapshot schema comparison on authored received-object JSON, with missing/null distinctions, explicit pristine retry and lifecycle/edit/sent fences. No UI hook, network packet, actual received server transcript or admission."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
