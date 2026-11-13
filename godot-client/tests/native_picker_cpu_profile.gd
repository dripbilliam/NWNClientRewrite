extends SceneTree
# CPU-only picker stages. This does not admit a character or prepare a world.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Preview=preload("res://systems/native_character_preview.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Spells=preload("res://systems/native_data/pregame_spells.gd")
const Record=preload("res://systems/native_data/pregame_record.gd")
var report:={"success":false,"publicConnections":0,"gpuBenchmark":false,"rows":[],"tables":{},"failures":[]}
var catalog
var tables: Dictionary={}
func _initialize() -> void: call_deferred("run")
func load_table(name: String) -> void:
	if tables.has(name): return
	var began:=Time.get_ticks_usec(); var bytes: PackedByteArray=catalog.get_resource(name,2017); var read_us:=Time.get_ticks_usec()-began
	var parser:=Table.new(); var value: Dictionary=parser.parse(preload("res://systems/native_data/binary_data.gd").new(bytes).text(0,bytes.size()))
	tables[name]=value
	report.tables[name]={"read_ms":read_us/1000.0,"decode_ms":(Time.get_ticks_usec()-began-read_us)/1000.0,"bytes":bytes.size(),"rows":value.get("orderedRows",[]).size(),"error":parser.failure}
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("install") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	catalog=Catalog.new(); var began:=Time.get_ticks_usec()
	if not catalog.mount_install(args.install): report.failures.append(catalog.failure)
	report.mount_ms=(Time.get_ticks_usec()-began)/1000.0
	if args.has("resource-directory"):
		if not catalog.mount_directory(args["resource-directory"],50000000): report.failures.append(catalog.failure)
	var files: Array=[]
	if args.has("bic-directory"):
		for file in DirAccess.get_files_at(args["bic-directory"]):
			if file.ends_with(".bic"): files.append(str(args["bic-directory"]).path_join(file))
	else:
		for name in ["wizard","fighter","druid"]: files.append(str(args.install).path_join("data/lcv/"+name+".bic"))
	for file in files:
		var row:={"file":file.get_file(),"stages":{},"projection_passes":[]}; report.rows.append(row)
		began=Time.get_ticks_usec(); var bytes:=FileAccess.get_file_as_bytes(file); row.bytes=bytes.size(); row.stages.read_ms=(Time.get_ticks_usec()-began)/1000.0
		began=Time.get_ticks_usec(); var parser:=Gff.new(); var doc:=parser.parse(bytes,"BIC "); row.stages.parse_ms=(Time.get_ticks_usec()-began)/1000.0
		if not parser.failure.is_empty(): report.failures.append(parser.failure); continue
		row.records=doc.records.size(); began=Time.get_ticks_usec()
		var value: Dictionary=preload("res://systems/native_data/character_preview.gd").project(doc.root,0)
		row.stages.basic_ms=(Time.get_ticks_usec()-began)/1000.0; began=Time.get_ticks_usec()
		value.visualSource=preload("res://systems/native_data/bic_visual.gd").source(doc); row.stages.visual_ms=(Time.get_ticks_usec()-began)/1000.0; began=Time.get_ticks_usec()
		value.skillSource=Skills.source(doc); row.stages.skill_source_ms=(Time.get_ticks_usec()-began)/1000.0; began=Time.get_ticks_usec()
		value.spellSource=Spells.source(doc,value.skillSource); row.stages.spell_source_ms=(Time.get_ticks_usec()-began)/1000.0; began=Time.get_ticks_usec()
		value.recordSource=Record.source(doc,value.skillSource); row.stages.record_source_ms=(Time.get_ticks_usec()-began)/1000.0; began=Time.get_ticks_usec()
		row.signature_bytes=JSON.stringify([value,tables.size(),0]).length(); row.stages.full_signature_ms=(Time.get_ticks_usec()-began)/1000.0
		for pass_index in 20:
			var pass_row:={"index":pass_index}; var pending: Array=[]
			for pair in [["record",Record,value.recordSource],["skills",Skills,value.skillSource],["spells",Spells,value.spellSource]]:
				began=Time.get_ticks_usec(); var projection: Dictionary=pair[1].compute(pair[2],tables); pass_row[pair[0]+"_ms"]=(Time.get_ticks_usec()-began)/1000.0; pass_row[pair[0]+"_ready"]=projection.get("ready",false)
				for name in projection.get("dependencies",[]): if not pending.has(name): pending.append(name)
			pass_row.dependencies=pending.duplicate(); row.projection_passes.append(pass_row)
			if pending.is_empty(): break
			for name in pending: load_table(str(name))
	report.success=report.failures.is_empty(); var output:=FileAccess.open(args.report,FileAccess.WRITE)
	if output==null: print("PICKER_REPORT_ERROR ",args.report," code=",FileAccess.get_open_error()); quit(3); return
	output.store_string(JSON.stringify(report,"  ")+"\n"); output.close(); quit(0 if report.success else 1)
