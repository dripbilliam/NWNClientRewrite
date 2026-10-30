extends SceneTree
const Owner=preload("res://systems/native_character_preview.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Digest=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
var folder:=""
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func wait_until(predicate: Callable) -> bool:
	var end:=Time.get_ticks_msec()+15000
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return predicate.call()
func source(bytes: PackedByteArray) -> Dictionary:
	var digest:=Digest.digest(bytes); var path:=folder.path_join(digest+".bic"); var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(bytes); file.close()
	return {"format":"native-bic-file-v1","path":path,"sha256":digest,"bytes":bytes.size()}
func bic(name: String,padding: int=0) -> PackedByteArray:
	var fields:={"FirstName":Writer.field(12,{"strRef":4294967295,"entries":[{"languageId":0,"text":name},{"languageId":2,"text":"Nom français"}]}),"LastName":Writer.field(12,{"strRef":4294967295,"entries":[{"languageId":0,"text":"€ Preview"}]}),"Description":Writer.field(12,{"strRef":16777217,"entries":[]}),"Str":Writer.field(0,14),"Dex":Writer.field(0,12),"HitPoints":Writer.field(3,18),"CurrentHitPoints":Writer.field(3,13),"Experience":Writer.field(4,6000),"PortraitId":Writer.field(2,65534),"Portrait":Writer.field(11,"po_clsbard_"),"Gender":Writer.field(0,0),"Race":Writer.field(0,6),"ClassList":Writer.field(15,[Writer.record({"Class":Writer.field(5,10),"ClassLevel":Writer.field(3,4),"KnownList0":Writer.field(15,[Writer.record({"Spell":Writer.field(2,24)})]),"KnownList1":Writer.field(15,[Writer.record({"Spell":Writer.field(2,35)})])})]),"SkillList":Writer.field(15,[Writer.record({"Rank":Writer.field(0,7)}),Writer.record({"Rank":Writer.field(0,0)})]),"FeatList":Writer.field(15,[Writer.record({"Feat":Writer.field(2,12)}),Writer.record({"Feat":Writer.field(2,65535)})]),"EffectList":Writer.field(15,[Writer.record({"Type":Writer.field(4,9999)})]),"ScriptHeartbeat":Writer.field(11,"nw_bad_script"),"ObjectId":Writer.field(4,123)}
	if padding>0: var bytes:=PackedByteArray(); bytes.resize(padding); fields.Padding=Writer.field(13,bytes)
	var writer:=Writer.new(); var bytes:=writer.write("BIC ",Writer.record(fields)); check(writer.failure.is_empty(),"Authored original-width BIC fixture encodes"); return bytes
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	folder=output.trim_suffix(".json")+"-sources"; DirAccess.make_dir_recursive_absolute(folder)
	var owner:=Owner.new(); root.add_child(owner); owner.configure(folder)
	var first:=source(bic("Café",1200000)); owner.observe(1,"first",first,true)
	check(await wait_until(func():return not owner.value.is_empty() or not owner.error.is_empty()),"Real native BIC worker finishes beyond the bridge JSON size limit")
	check(owner.error.is_empty() and owner.value.native_only,"Decoded preview has a native owner and no fabricated decode error")
	check(owner.value.firstName.text=="Café" and owner.value.lastName.text=="€ Preview","Native CP1252/localized name bytes survive worker decoding")
	check(owner.value.description=={"strRef":16777217},"Unexpanded custom TLK references remain native rendering inputs")
	check(owner.value.abilities=={"Str":14,"Dex":12} and not owner.value.abilities.has("Con"),"Only present raw ability fields are extracted")
	check(owner.value.hitPoints==18 and owner.value.currentHitPoints==13 and owner.value.experience==6000,"Raw serialized HP and experience survive without a JS stats model")
	check(owner.value.classes==[{"id":10,"level":4}] and owner.value.skills==[{"id":0,"rank":7},{"id":1,"rank":0}],"Physical class and skill-rank data retain their source identities")
	check(owner.value.feats==[12,65535] and owner.value.spells==[{"classId":10,"level":0,"id":24},{"classId":10,"level":1,"id":35}],"Raw feat IDs and class/level spell lists remain available for native pages")
	check(not owner.value.has("EffectList") and not owner.value.has("ScriptHeartbeat") and not owner.value.has("ObjectId") and not owner.value.has("Padding"),"Display extraction imports no saved effects, scripts, world IDs or unused blob data")
	check(not owner.value.derived_combat_ready and not owner.value.has("armorClass"),"Unported derived combat values are explicit gaps rather than invented statistics")
	owner.language=1; owner.observe(1,"first",first,true); check(await wait_until(func():return owner.value.get("firstName",{}).get("text","")=="Nom français"),"Changing native language invalidates the localized preview projection")
	owner.language=0; var second:=source(bic("Beta")); owner.set_process(false); owner.observe(2,"old",first,true); var task: int=owner.task; owner.observe(2,"latest",second,true)
	check(await wait_until(func():return WorkerThreadPool.is_task_completed(task)),"The superseded owned decoder reaches completion")
	owner._process(0); check(owner.value.is_empty() and owner.stats.stale>=1,"A completed older selection cannot populate the latest record")
	owner.set_process(true); check(await wait_until(func():return owner.value.get("firstName",{}).get("text","")=="Beta"),"The latest pending selection is dispatched after stale work retires")
	var invalid:=second.duplicate(); invalid.path=folder.get_base_dir().path_join(str(second.sha256)+".bic"); owner.observe(3,"outside",invalid,true)
	check(owner.value.is_empty() and owner.error=="Character preview byte ticket is invalid.","A byte ticket cannot read outside the owned preview directory")
	invalid=second.duplicate(); invalid.bytes=55; owner.observe(3,"short",invalid,true); check(not owner.error.is_empty() and owner.task<0,"Invalid byte counts cannot start a worker")
	owner.observe(3,"restored",second,true); check(await wait_until(func():return not owner.value.is_empty()),"A valid owned selection recovers after a rejected ticket")
	var corrupt:=FileAccess.open(str(second.path),FileAccess.WRITE); corrupt.store_buffer(PackedByteArray([1,2,3])); corrupt.close(); owner.observe(4,"changed",second,true)
	check(await wait_until(func():return not owner.error.is_empty()) and owner.value.is_empty(),"Changed owned bytes are refused instead of displaying stale character data")
	var malformed:=source(PackedByteArray()); malformed=source(bic("Malformed")); var raw:=FileAccess.get_file_as_bytes(str(malformed.path)); raw[0]=0; malformed=source(raw); owner.observe(5,"malformed",malformed,true)
	check(await wait_until(func():return not owner.error.is_empty()) and owner.value.is_empty(),"Invalid BIC headers fail natively without importing a partial record")
	first=source(bic("After reset")); owner.set_process(false); owner.observe(6,"late",first,true); owner.observe(7,null,null,false); owner.close()
	check(owner.snapshot().closed and not owner.snapshot().worker_running and not owner.snapshot().pending and owner.value.is_empty(),"Disconnect/close invalidates pending selection and joins the owned worker")
	owner.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"fullUiParity":false,"derivedCombatParity":false,"scope":"Actual native worker BIC decoding, raw field projection, language/presence, bounded source tickets, integrity failures, selection supersession and close/join. Gameplay derived statistics and source record pages remain separate."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
