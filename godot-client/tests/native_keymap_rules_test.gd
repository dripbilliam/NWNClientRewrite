extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Rules=preload("res://systems/native_data/keymap_rules.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var oracle_path:=ProjectSettings.globalize_path("res://../backups/animations/native-key-capture-observations-v1.json")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	check(oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Independent key-capture oracle pins unchanged original instructions")
	for row in oracle.labels: check(Rules.label_ref(int(row.code))==int(row.strRef),"Original key-label lookup: "+str(row.code))
	for row in oracle.remappable: check(Rules.remappable(int(row.code))==bool(row.result),"Original language-default eligibility predicate: "+str(row.code))
	for row in oracle.captures:
		check(Rules.captured_scan_code(int(row.scan),bool(row.enabled))==int(row.captured),"Original captured physical key without synthetic modifier prefix: "+str([row.enabled,row.scan,row.modifiers]))
	check(oracle.special[0].captured==0 and oracle.special[1].captured==0 and oracle.special[2].captured==0 and oracle.special[3].captured==74,"Original release/Alt-Enter/Escape/tilde capture distinctions remain explicit")
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Active installed native catalog mounts without profile or network access")
	var service:=Assets.new(); root.add_child(service)
	var bytes: PackedByteArray=catalog.get_resource("keymap",2017)
	var unused_path:=str(output)+".must-not-create-expanded-table-cache"
	var first:=service.decode(bytes,2017,"2da",unused_path,catalog.decoded_cache())
	check(catalog.failure.is_empty() and str(first.error).is_empty() and first.value.rowLabels.size()==72,"Native decoder preserves all72 installed named Keymap rows")
	check(not first.memory_decode_hit and not first.cache_hit and first.timings.cache_read_ms==0 and first.timings.cache_write_ms==0 and not DirAccess.dir_exists_absolute(unused_path),"Named rows do not reintroduce the expanded disk-cache loading path")
	var table: Dictionary=first.value; var original: Dictionary=table.duplicate(true)
	var next:=service.decode(bytes,2017,"2da",unused_path,catalog.fork().decoded_cache())
	check(next.memory_decode_hit and next.value.rowLabels==table.rowLabels,"Forked resource catalog reuses decoded labels in the session cache")
	next.value.rowLabels[0]="private consumer mutation"; next.value.orderedRows[0].Language0="0"
	var third:=service.decode(bytes,2017,"2da",unused_path,catalog.decoded_cache())
	check(third.memory_decode_hit and third.value==original,"Mutable decoded consumers cannot rewrite shared physical labels or bindings")
	var plan:=Rules.populate(table,0)
	check(plan.errors.is_empty() and plan.rows.size()==51 and plan.language_column=="Language0","Installed keymap populates its51 source-defined action rows")
	check(plan.values[97]==68 and plan.values[108]==0,"Initial load keeps the first Tab action and clears the later duplicate")
	var defaults:=Rules.populate(table,0,{},true)
	check(defaults.values[97]==68 and defaults.values[108]==68,"Defaults preserves the original duplicate Tab rows until another assignment")
	var resolve_text:=Talk.new(); check(resolve_text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original key captions resolve from installed TLK")
	var resolver:=func(ref):return resolve_text.raw({"strRef":ref})
	check(Rules.key_label(101,resolver)=="W" and Rules.key_label(101|(2<<8),resolver)=="Shift + W" and Rules.key_label(101|(3<<8),resolver)=="Ctrl + W","Native key captions preserve original encoded Shift/Ctrl formatting")
	check(Rules.key_label(101|(1<<8),resolver)=="W" and Rules.key_label(0,resolver).is_empty(),"Unknown/unused modifier modes do not invent key captions")
	check(Rules.key_label(41,resolver)=="Right Arrow\n","Original key-caption line break is preserved as resource text")
	var shifted:=Rules.assign(defaults,68,101)
	check(shifted.values[68]==101 and shifted.values[90]==0 and shifted.values[97]==68 and defaults.values[90]==101,"Reassignment clears the other displayed W binding while leaving the source transaction intact")
	check(Rules.assign(shifted,999,101)==shifted and Rules.assign(shifted,68,0)==shifted,"Absent and uncapturable assignments cannot mutate pending bindings")
	var writes:=Rules.writes(shifted)
	check(writes.size()==72 and writes.Action43=="0" and writes.Action68=="101" and writes.Action90=="0" and not writes.has("Action0"),"Commit plan emits all72 original decimal Action entries and leaves quickbar bindings outside that range")
	var synthetic:=Table.new().parse("2DA V2.0\nDEFAULT: ****\nactionstrref Language0 Language1 PAGE Name\naction37 1 79 0 0 first\nAction38 2 80 **** 1 second\nAction39 3 81 **** 2 third\nACTION37 4 82 83 3 duplicate\n")
	check(synthetic.rows.is_empty() and synthetic.rowLabels==["action37","Action38","Action39","ACTION37"],"Named rows preserve physical labels without changing legacy numeric rows")
	check(Rules.integer(synthetic,37,"Page")=={"found":true,"value":0} and Rules.integer(synthetic,37,"Language0").value==79,"Original first case-insensitive row and column matches use physical cells")
	var loaded:=Rules.populate(synthetic,1); var reset:=Rules.populate(synthetic,1,{},true)
	check(loaded.language_column=="Language0" and loaded.rows.size()==3 and loaded.values[38]==80,"Initial language eligibility falls back globally when no remappable default is available")
	check(reset.language_column=="Language1" and reset.rows.size()==1 and reset.values[37]==0,"Defaults retains a zero-only selected language when it produces at least one row")
	var overridden:=Rules.populate(synthetic,0,{"Action38":"79","Action39":"0"})
	check(overridden.values[37]==79 and overridden.values[38]==0 and overridden.values[39]==0,"Stored overrides participate in original ordered duplicate clearing")
	var absent:=Rules.populate(synthetic,5,{},true)
	check(absent.language_column=="Language0" and absent.rows.size()==3,"Defaults uses Language0 only after the requested column adds no rows")
	var numeric:=Table.new().parse("2DA V2.0\nDEFAULT: fallback\nA A B\n7 first shadow\n7 last hidden tail\nname \"quoted value\" \"a\"\"b\"\n")
	check(numeric.rowLabels==["7","7","name"] and numeric.rows[7]=={"A":"last","B":"tail"} and numeric.orderedCells[2]==["quoted value",'a"b',"fallback"],"New labels preserve numeric last-wins rows, duplicate column cells, quotes and defaults")
	check(table==original and plan.native_data_only and not plan.full_key_settings_parity,"Source key table remains immutable and data checks do not accept the unfinished settings UI")
	var population_path:=ProjectSettings.globalize_path("res://../backups/animations/native-key-population-observations-v1.json")
	var population: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(population_path))
	check(population.binarySha256==oracle.binarySha256 and population.installedKeymapSha256==Cache.digest(bytes),"Original population oracle pins the same binary and installed key table")
	for observed in population.rows:
		var fixture: String="2DA V2.0\nActionStrRef Language0 Language1 Page\n"
		for row in observed.case.table:
			fixture+=str(row.row_name)
			for column in ["ActionStrRef","Language0","Language1","Page"]: fixture+=" "+str(row.get(column,"****"))
			fixture+="\n"
		var comparison:=Rules.populate(Table.new().parse(fixture),int(observed.case.language),observed.case.profile,bool(observed.case.defaults))
		var expected_values: Dictionary={}
		for key in observed.values: expected_values[int(key)]=int(observed.values[key])
		var expected_rows: Array=[]
		for row in observed.rows: expected_rows.append({"action":int(row.action),"page":int(row.page),"strRef":int(row.strRef),"binding":int(row.binding)})
		check(comparison.errors.is_empty() and comparison.rows==expected_rows and comparison.values==expected_values,"Initial/default population matches unchanged original caller instructions: "+str([observed.case.name,observed.case.language,observed.case.defaults,observed.case.profile]))
	resolve_text.base.close(); service.close(); service.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"keymapSha256":Cache.digest(bytes),"oracleSha256":FileAccess.get_sha256(oracle_path),"populationOracleSha256":FileAccess.get_sha256(population_path),"initial":plan,"defaults":defaults,"publicConnections":0,"fullKeySettingsParity":false,"scope":"Original-instruction key capture/eligibility/label-table and26 caller population cases, active source row data and pending policy. Does not accept visible key settings, real gameplay remapping, configuration persistence or complete UI parity."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
