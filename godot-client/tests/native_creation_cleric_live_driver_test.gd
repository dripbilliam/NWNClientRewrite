extends "res://tests/native_creation_class_controls_test.gd"
const ClericLive=preload("res://tests/native_creation_cleric_live_probe.gd")
func make_driver():return ClericLive.new()
func record_id(document: Dictionary,value: Dictionary) -> int:
	for id in document.records:
		if is_same(document.records[id],value):return int(id)
	return -1
func artifact(suffix: String,value: Variant) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var output: String=arg.trim_prefix("--report=")+suffix
			if FileAccess.file_exists(output):check(false,"Owned Cleric artifact already exists");return
			var file:=FileAccess.open(output,FileAccess.WRITE)
			if value is PackedByteArray:file.store_buffer(value)
			else:file.store_string(JSON.stringify(value,"\t"))
			file.close();return
func observe_bic(bytes: PackedByteArray) -> void:artifact(".source.bic",bytes)
func source_fields(document: Dictionary,rules,expected: Dictionary) -> void:
	artifact(".source.expected.json",expected)
	super.source_fields(document,rules,expected)
	var cls: Dictionary=document.root.ClassList[0]
	var id:=record_id(document,cls)
	check(cls.Class==2 and cls.ClassLevel==1 and document.struct_types[id]==0,"Actual Cleric source class record is first-level struct0")
	check(document.field_types[id].Class==5 and document.field_types[id].ClassLevel==3 and document.field_types[id].Domain1==0 and document.field_types[id].Domain2==0,"Source class/domain values retain original INT/SHORT/BYTE field types")
	check(not cls.has("School") and not cls.has("SpellsPerDayList"),"Cleric omits an invented School or spontaneous daily-use list")
	for level in 10:
		var known: String="KnownList"+str(level);var memo: String="MemorizedList"+str(level)
		check(not cls.has(known),"Unrestricted divine source does not invent a restricted known book "+str(level))
		check(cls.get(memo,[]).size()==int(expected.divineCreation.slots[level]),"Memorized list retains actual divine/domain slot budget "+str(level))
		for row in cls.get(memo,[]):
			var row_id:=record_id(document,row)
			check(document.struct_types[row_id]==0 and row.keys()==["Spell"] and document.field_types[row_id]=={"Spell":2} and int(row.Spell)==65535,"Original unprepared divine slot is struct0/WORDffff without invented Ready/Meta/Domain flags")
	check(not document.root.has("FamiliarType") and not document.root.has("CompanionType"),"Cleric class metadata omits both unused associate namespaces")
