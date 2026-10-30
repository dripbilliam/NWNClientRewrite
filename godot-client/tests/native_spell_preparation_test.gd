extends SceneTree
const Preparation=preload("res://systems/native_data/spell_preparation.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func cost(meta: int) -> int: return int({0:0,1:2,2:1,4:3,8:4,16:1,32:1}.get(meta,0))
func entry(spell: int,at: int,meta: int=0,domain: bool=false) -> Dictionary: return {"spellId":spell,"classIndex":0,"level":3,"slot":at,"metamagic":meta,"domain":domain}
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var path:=ProjectSettings.globalize_path("res://../backups/animations/native-spell-preparation-drop-observations-v1.json"); var input:=FileAccess.open(path,FileAccess.READ); var oracle: Dictionary=JSON.parse_string(input.get_as_text()); input.close()
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.rows.size()==384,"Oracle executes original occupied/empty drop and source completion policy")
	for row in oracle.rows:
		var source:=entry(5,-1 if int(row.kind)==1 else 0,int(row.metamagic),bool(row.domain)); var destination:=entry(int(row.old),2,int(row.destMetamagic),bool(row.destDomain)); source.classIndex=int(row.classIndex); destination.classIndex=int(row.classIndex)
		var saved:=[source.duplicate(true),destination.duplicate(true)]; var result:=Preparation.plan(source,destination,false,cost); var equal: bool=result.error.is_empty() and result.writes.size()==row.writes.size()
		for at in mini(result.writes.size(),row.writes.size()):
			var actual: Dictionary=result.writes[at]; var expected: Dictionary=row.writes[at]
			for field in ["classIndex","level","slot"]: equal=equal and int(actual[field])==int(expected[field])
			equal=equal and bool(actual.clear)==bool(expected.clear)
			if not actual.clear:
				equal=equal and int(actual.spellId)==int(expected.spellId) and int(actual.metamagic)==int(expected.metamagic) and int(actual.domainLevel)==((3-cost(int(expected.metamagic)))&255 if int(expected.domain)!=0 else 0)
		check(equal and saved==[source,destination],"Original drop ordering/domain/meta matches kind%d old%d domain%d/%d meta%d/%d class%d"%[row.kind,row.old,row.domain,row.destDomain,row.metamagic,row.destMetamagic,row.classIndex])
	var source:=entry(5,0,1,true); var destination:=entry(7,1,4,false)
	check(Preparation.plan(source,source,false,cost).writes.is_empty(),"Dropping a prepared slot on itself sends no writes")
	var other:=destination.duplicate(); other.level=4; check(not Preparation.plan(source,other,false,cost).error.is_empty(),"Different-level preparation destinations are rejected")
	other=destination.duplicate(); other.classIndex=1; check(not Preparation.plan(source,other,false,cost).error.is_empty(),"Different-class preparation destinations are rejected")
	check(not Preparation.plan(entry(5,-1),{},true,cost).error.is_empty(),"Known-list entries cannot be cleared as physical preparations")
	var child:=entry(17,-1,1,true); child.preparationId=5; var prepared:=Preparation.plan(child,destination,false,func(_mask):return 7)
	check(prepared.writes.size()==1 and prepared.writes[0].spellId==5 and prepared.writes[0].domainLevel==252,"Family children prepare their owned parent with active metamagic-cost byte wrapping")
	var actor:={"playerState":{"spellbooks":{"0":{"memorized":{"3":[{"spell":5,"metamagic":1,"domain":true,"ready":true},{"spell":7,"metamagic":4,"domain":false,"ready":false},null]}}}}}; var baseline:=actor.duplicate(true); var scope:=[1,55,42]; var owner:=Preparation.new()
	var plan:=Preparation.plan(source,destination,false,cost); var submitted:=owner.submit(actor,scope,plan.writes,1000)
	check(submitted.error.is_empty() and submitted.requests.size()==2 and owner.pending.size()==2 and actor==baseline,"A swap reserves both actual slots before sending without mutating received data")
	var serial: int=owner.serial; var duplicate:=owner.submit(actor,scope,plan.writes,1001)
	check(not duplicate.error.is_empty() and duplicate.requests.is_empty() and owner.serial==serial and owner.pending.size()==2,"Repeated writes reject atomically while either affected slot is pending")
	var model:={"memory":[source.duplicate(),destination.duplicate(),entry(-1,2)]}; owner.decorate(model)
	check(model.memory[0].pending and model.memory[1].pending and not model.memory[2].pending and actor==baseline,"Pending decoration changes only projected slots")
	check(not owner.observe(actor,scope,1002) and owner.pending.size()==2,"Unchanged received data never confirms a preparation")
	check(not owner.reject(int(submitted.requests[0].requestId),[2,55,42],"old") and owner.pending.size()==2,"A refusal for another world cannot unlock current preparations")
	check(owner.reject(int(submitted.requests[0].requestId),scope,"transport refused") and owner.pending.size()==1 and owner.notice=="transport refused","A correlated transport refusal retires only its affected slot")
	actor.playerState.spellbooks["0"].memorized["3"][1]={"spell":5,"metamagic":1,"domain":true,"ready":false}
	check(owner.observe(actor,scope,1003) and owner.pending.is_empty(),"Only changed authoritative slot data retires the remaining claim")
	owner.reset(); actor=baseline.duplicate(true); var clear:=Preparation.plan(source,{},true,cost); submitted=owner.submit(actor,scope,clear.writes,5000)
	check(not owner.observe(actor,scope,19999) and owner.pending.size()==1,"Preparation remains pending before its confirmation deadline")
	check(owner.observe(actor,scope,20000) and owner.pending.is_empty() and owner.notice.contains("not confirmed") and actor==baseline,"Timeout permits retry with explicit unconfirmed feedback and no invented result")
	owner.submit(actor,scope,clear.writes,20001); check(owner.observe(actor,[2,55,42],20002) and owner.pending.is_empty() and owner.notice.is_empty(),"World retirement clears pending ownership without reporting gameplay success")
	check(not owner.reject(int(submitted.requests[0].requestId),scope,"late"),"Late refusal cannot affect a retired request")
	var invalid: Dictionary=clear.writes[0].duplicate(); invalid.slot=30; submitted=owner.submit(actor,[2,55,42],[clear.writes[0],invalid],20003)
	check(not submitted.error.is_empty() and submitted.requests.is_empty() and owner.pending.is_empty(),"One unavailable cell prevents every write in a planned exchange")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"oracleSha256":FileAccess.get_sha256(path),"publicConnections":0,"fullSpellbookParity":false,"scope":"384 original drop/completion policy observations plus native authoritative pending ownership. Physical pickup, world drop, cancellation and full UI parity remain open."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
