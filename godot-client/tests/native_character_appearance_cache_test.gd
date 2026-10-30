extends SceneTree
const Saved=preload("res://systems/native_data/character_appearance_cache.gd")
const Visual=preload("res://systems/native_data/bic_visual.gd")
const Hash=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var folder:=output.trim_suffix(".json")+"-owned"; var saved:=Saved.new(); saved.directory=folder
	var state:={"previewAccountScope":"a".repeat(64),"endpoint":{"host":"LOCALHOST.","port":5126},"selected":"server:17:owned"}; var scope:=Saved.identity(state)
	check(scope==["a".repeat(64),"localhost",5126,"server:17:owned"] and saved.read_seen(scope).is_empty(),"Cache identity is private-account digest, normalized endpoint and exact advertised server character")
	for field in ["previewAccountScope","endpoint","selected"]:
		var invalid:=state.duplicate(true); invalid.erase(field); check(Saved.identity(invalid).is_empty(),"Missing identity component refuses cached appearance: "+field)
	var armor_parts: Array=[]
	for index in 19: armor_parts.append(index+1)
	var actor:={"id":987654,"areaId":42,"objectType":5,"replicated":{"position":[4,8,0],"stats":{"racialType":63},"script":"NEVER_IMPORT"},"appearance":{"appearance":1,"head":1,"gender":0,"phenotype":0,"skin":28,"hair":17,"tattoo1":0,"tattoo2":0,"bodyParts":[{"index":7,"value":1}],"equipment":[{"slot":2,"id":876543,"item":{"baseItem":0,"modelType":3,"parts":armor_parts,"colors":[1,2,3,4,5,6],"partColors":[[255,2,255,4,255,6]],"ownerId":987654,"script":"NEVER_IMPORT"}}]}}
	check(saved.save_seen(scope,actor),"A complete observed controlled appearance is saved to persistent native storage")
	var cold:=Saved.new(); cold.directory=folder; var first:=cold.read_seen(scope)
	check(not first.is_empty() and first.source.equipmentComplete and first.source.appearance.skin==28 and first.source.equipment[0].item.armorParts==armor_parts,"A fresh cache owner restores the actual skin and armor without a local BIC")
	var encoded:=JSON.stringify(first); check(not encoded.contains("987654") and not encoded.contains("876543") and not encoded.contains("NEVER_IMPORT") and not encoded.contains("position"),"Snapshots exclude server object IDs, ownership, location and scripts")
	var tables:={"orderedRows":[{"ModelType":"3"}]}; var preview:=Visual.actor(first.source,tables)
	check(not preview.has("error") and preview.id==1 and preview.appearance.equipment[0].item.parts==armor_parts and preview.replicated.stats.racialType==63,"Saved appearance becomes a private preview actor under active server item rules")
	check(Visual.actor(first.source,{"orderedRows":[{"ModelType":"1"}]}).has("error"),"Changed active model-type rules refuse incompatible saved equipment rather than inventing parts")
	for field in ["previewAccountScope","endpoint","selected"]:
		var other:=state.duplicate(true)
		if field=="previewAccountScope": other[field]="b".repeat(64)
		elif field=="endpoint": other.endpoint.port=5127
		else: other.selected="server:17:other"
		check(saved.read_seen(Saved.identity(other)).is_empty(),"Another identity cannot use this appearance: "+field)
	var invalid_actor:=actor.duplicate(true); invalid_actor.appearance.erase("equipment")
	check(not saved.save_seen(scope,invalid_actor) and not saved.error.is_empty() and saved.read_seen(scope).digest==first.digest,"Incomplete disconnect data preserves the last valid appearance")
	actor.appearance.equipment=[]; actor.appearance.skin=7
	check(saved.save_seen(scope,actor),"Later observations replace the old snapshot atomically")
	cold=Saved.new(); cold.directory=folder; var second:=cold.read_seen(scope)
	check(second.source.appearance.skin==7 and second.source.equipment.is_empty() and second.digest!=first.digest,"Explicitly observed unequipping is retained rather than resurrecting old armor")
	var path:=saved.filename(scope); var file:=FileAccess.open(path,FileAccess.WRITE); var damaged:=second.duplicate(true); damaged.source.appearance.skin=99; file.store_buffer(var_to_bytes(damaged)); file.close(); cold=Saved.new(); cold.directory=folder
	check(cold.read_seen(scope).is_empty(),"Changed bytes with a stale digest are ignored")
	file=FileAccess.open(path,FileAccess.WRITE); var oversized:=PackedByteArray(); oversized.resize(Saved.MAX_BYTES+1); file.store_buffer(oversized); file.close(); cold=Saved.new(); cold.directory=folder
	check(cold.read_seen(scope).is_empty(),"Oversized cache data is refused before decoding")
	check(DirAccess.remove_absolute(path)==OK and DirAccess.remove_absolute(folder)==OK,"Only the owned test snapshot and its empty folder are removed")
	var report:=FileAccess.open(output,FileAccess.WRITE); report.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"fullUiParity":false,"scope":"Native last-seen appearance persistence, cold read, server/account/character isolation, original-compatible preview projection, active-rule changes, incomplete observations, unequipping, corruption and owned cleanup. Native disconnect wiring and original local-server observation require separate checks."},"  ")+"\n"); report.close(); quit(0 if failures.is_empty() else 1)
