extends SceneTree
const Patch=preload("res://systems/native_data/gff_root_patch.gd")
const Custom=preload("res://systems/native_data/character_customization_bic.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Reader=preload("res://systems/native_data/gff_document.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func section(bytes: PackedByteArray,index: int) -> PackedByteArray:
	var offset:=bytes.decode_u32(8+index*8); return bytes.slice(offset,offset+bytes.decode_u32(12+index*8)*[12,12,16,1,1,1][index])
func unchanged(source: PackedByteArray,result: PackedByteArray,changed: Array) -> bool:
	if result.is_empty() or source.slice(0,8)!=result.slice(0,8): return false
	var a:=Reader.new(); a.parse(source,"BIC ",true); var b:=Reader.new(); b.parse(result,"BIC ",true)
	if not a.failure.is_empty() or not b.failure.is_empty(): return false
	# Every preexisting ID keeps its record/label. New fields may only append.
	if section(source,0).slice(12)!=section(result,0).slice(12): return false
	for index in [2,3,4]:
		var old:=section(source,index)
		if section(result,index).slice(0,old.size())!=old: return false
	if section(source,5)!=section(result,5): return false
	for index in a.fields.size():
		var label: String=a.labels[int(a.fields[index].label)]
		if changed.has(label): continue
		if section(source,1).slice(index*12,index*12+12)!=section(result,1).slice(index*12,index*12+12): return false
	return true
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var writer:=Writer.new(); var parser:=Reader.new(); var patch:=Patch.new(); var custom:=Custom.new()
	var values: Array=[255,-128,65535,-32768,4294967295,-2147483648,{"unsigned64_low":4294967295,"unsigned64_high":4294967295},-9223372036854775807,-0.0,-0.0,"Café €","server_ref",{"strRef":123,"entries":[{"languageId":0,"text":"old"},{"languageId":2,"text":"préservé"}]},PackedByteArray([0,1,128,255]),Writer.record({"Opaque":Writer.field(13,PackedByteArray([255,0,3]))},17),[Writer.record({"Spell":Writer.field(4,99999)},27)],[0.0,1.0,2.0,3.0],[1.0,2.0,3.0],123]
	var fields: Dictionary={"Age":Writer.field(5,99),"FirstName":Writer.field(12,"Old"),"Equip_ItemList":Writer.field(15,[Writer.record({"UnknownServerVar":Writer.field(13,PackedByteArray([1,2,0,255]))},16)])}
	for type in 19: fields["Opaque"+str(type)]=Writer.field(type,values[type])
	var source:=writer.write("BIC ",Writer.record(fields)); var original:=source.duplicate()
	check(writer.failure.is_empty(),"Owned preservation fixture contains all19 original GFF field kinds, nested equipment and custom data")
	# Preserve noncanonical NaN payload bits even though these are never edited.
	var document:=parser.parse(source,"BIC "); var float_id: int=parser.fields.find_custom(func(row):return parser.labels[int(row.label)]=="Opaque8"); var float_field: int=source.decode_u32(16)+float_id*12
	source.encode_u32(float_field+8,0x7fc00123); original=source.duplicate()
	var result:=custom.apply(source,{"Age":101,"FirstName":"Café €","Description":"New description","Deity":"Authored deity","Appearance_Head":512})
	check(custom.failure.is_empty() and not result.is_empty(),"Native customization patches only original permitted cosmetic/information fields")
	check(source==original,"Preparing a customization leaves its source bytes unchanged")
	check(unchanged(source,result,["Age","FirstName","Description","Deity","Appearance_Head","xAppearance_Head"]),"Every untouched physical field, data byte, struct ID, nested graph/list and opaque NaN bit remains unchanged")
	document=parser.parse(result,"BIC ")
	check(parser.failure.is_empty() and document.root.Age==101 and document.root.FirstName.entries==[{"languageId":0,"text":"Café €"}] and document.field_types[0].Description==12 and document.root.Appearance_Head==0 and document.root.xAppearance_Head==512,"Edited fields retain native widths, English locstring entry and extended appearance compatibility")
	check(custom.apply(source,{})==source,"An unchanged customization returns exactly the original bytes")
	var evidence: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../backups/animations/rea-native-character-customization-v1.json"))
	var writes:=RegEx.new(); writes.compile("CResGFF::WriteField([A-Za-z]+)[\\s\\S]*?\"([A-Za-z0-9_]+)\"[^;]*;")
	var expected_types:={"CExoLocString":12,"CExoString":10,"INT":5,"WORD":2,"CResRef":11,"BYTE":0,"DWORD":4}; var full_changes: Dictionary={}; var extended: Array=[]
	for hit in writes.search_all(str(evidence.rows.customizeSave1.normalized_result.pseudocode)):
		var method: String=hit.get_string(1); var label: String=hit.get_string(2)
		if method=="WORDandBYTE": full_changes[label]=512; extended.append(label)
		else: full_changes[label]="Authored" if method in ["CExoLocString","CExoString","CResRef"] else 11
	check(evidence.binarySha256==observed_binary() and full_changes.size()==36 and extended.size()==19,"Full cosmetic/information field plan derives from all36 original809220 write calls, including19 compatibility pairs")
	var full_result:=custom.apply(source,full_changes); var full_document:=parser.parse(full_result,"BIC ")
	check(custom.failure.is_empty() and parser.failure.is_empty() and not full_result.is_empty(),"Every field saved by original customization is supported together on an existing character BIC")
	var full_ok:=true
	for hit in writes.search_all(str(evidence.rows.customizeSave1.normalized_result.pseudocode)):
		var method: String=hit.get_string(1); var label: String=hit.get_string(2)
		if method=="WORDandBYTE": full_ok=full_ok and full_document.field_types[0].get(label)==0 and full_document.root.get(label)==0 and full_document.field_types[0].get(("x"+label).left(16))==2 and full_document.root.get(("x"+label).left(16))==512
		else: full_ok=full_ok and full_document.field_types[0].get(label)==expected_types[method]
	check(full_ok,"All55 physical edited fields use the widths or paired compatibility labels observed in the original save routine")
	var changed: Array=full_changes.keys()
	for label in extended: changed.append(("x"+label).left(16))
	check(unchanged(source,full_result,changed),"The complete original save field set still preserves all unrelated physical character/equipment data")
	for count in [0,1,3]:
		var old_fields: Dictionary={}
		for at in count: old_fields["Existing"+str(at)]=Writer.field(4,at)
		var input:=writer.write("BIC ",Writer.record(old_fields,77)); var encoded:=patch.apply(input,{"Age":Writer.field(5,55),"FirstName":Writer.field(12,"New")}); var decoded:=parser.parse(encoded,"BIC ")
		check(patch.failure.is_empty() and parser.failure.is_empty() and decoded.struct_types[0]==77 and decoded.root.Age==55 and unchanged(input,encoded,["Age","FirstName"]),"Appending root fields preserves the original zero/one/multiple-field encoding: "+str(count))
	var duplicate:=writer.write("BIC ",Writer.record({"Age":Writer.field(5,1),"DupeA":Writer.field(4,2),"DupeB":Writer.field(4,3)}))
	duplicate.encode_u32(int(duplicate.decode_u32(16))+2*12+4,1)
	var duplicate_result:=patch.apply(duplicate,{"Age":Writer.field(5,2)})
	check(patch.failure.is_empty() and unchanged(duplicate,duplicate_result,["Age"]),"Unrelated duplicate root labels survive without dictionary collapse")
	parser.parse(duplicate,"BIC "); check(not parser.failure.is_empty(),"Ordinary presentation parsing keeps its original strict duplicate-label validation")
	check(patch.apply(duplicate,{"DupeA":Writer.field(4,9)}).is_empty() and not patch.failure.is_empty(),"An ambiguous edited root field is refused rather than changing an arbitrary duplicate")
	var shared:=writer.write("BIC ",Writer.record({"Age":Writer.field(5,1),"Nested":Writer.field(14,Writer.record({"Age":Writer.field(5,2)},12))}))
	shared.encode_u32(int(shared.decode_u32(8))+12+4,0)
	var shared_result:=custom.apply(shared,{"Age":9}); var shared_document:=parser.parse(shared_result,"BIC ")
	check(custom.failure.is_empty() and parser.failure.is_empty() and shared_document.root.Age==9 and shared_document.root.Nested.Age==1 and unchanged(shared,shared_result,["Age"]),"An edited root edge clones a shared physical field rather than mutating the untouched nested character/item value")
	var version3:=source.duplicate(); version3[7]=51; result=custom.apply(version3,{"Age":5})
	check(not result.is_empty() and result.slice(0,8)==version3.slice(0,8),"Original supported V3.3 signature is retained instead of silently converting formats")
	for bad in [{"ClassList":[]},{"Equip_ItemList":[]},{"Experience":0},{"PortraitId":1},{"Age":2.5},{"Color_Skin":256},{"SoundSetFile":-1},{"Appearance_Head":65536},{"Deity":123},{"FirstName":{}},{"Portrait":"longer_than_sixteen"}]:
		check(custom.apply(source,bad).is_empty() and not custom.failure.is_empty() and source==original,"Unsupported field/type/range is refused without source mutation: "+str(bad.keys()[0]))
	check(custom.apply(source.slice(0,40),{"Age":5}).is_empty() and not custom.failure.is_empty(),"Truncated input cannot produce an edited BIC")
	var observed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../backups/animations/native-customization-wordbyte-v1.json")); var compared:=0
	check(observed.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and observed.cases.size()==120,"Compatibility policy pins120 unchanged original instruction observations")
	for row in observed.cases:
		if not row.success: continue
		var input:=writer.write("BIC ",Writer.record({str(row.label):Writer.field(0,0)} if row.mode=="existing" else {}))
		var encoded:=patch.apply(input,Custom.extended_fields(str(row.label),int(row.value))); var decoded:=parser.parse(encoded,"BIC ")
		check(patch.failure.is_empty() and decoded.root[row.label]==row.byte and decoded.root[row.extended]==row.word and decoded.field_types[0][row.extended]==2,"Native legacy-byte/extended-WORD policy matches original case "+str(compared)); compared+=1
	var corpus: Array=[]; var files:=DirAccess.get_files_at(install.path_join("data/lcv"))
	for file_name in files:
		if not file_name.ends_with(".bic"): continue
		var bytes:=FileAccess.get_file_as_bytes(install.path_join("data/lcv").path_join(file_name)); var digest:=HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(bytes)
		var encoded:=custom.apply(bytes,{"FirstName":"Owned customization","Age":33,"Description":"Owned preservation check"}); var decoded:=parser.parse(encoded,"BIC ")
		check(custom.failure.is_empty() and parser.failure.is_empty() and decoded.root.Age==33 and decoded.root.FirstName.entries[0].text=="Owned customization","Native information edits parse on actual installed BIC: "+file_name)
		check(unchanged(bytes,encoded,["FirstName","Age","Description"]),"Actual BIC preserves all unrelated equipment/history/spells/custom sections: "+file_name)
		corpus.append({"file":file_name,"sha256":digest.finish().hex_encode(),"bytes":bytes.size()})
	check(corpus.size()==39,"All39 installed local character BICs were checked read-only")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"fullUiParity":false,"customizeUiImplemented":false,"originalPolicyCasesCompared":compared,"originalAllocationFailureCases":observed.cases.size()-compared,"corpus":corpus,"scope":"Native cosmetic/information BIC preparation preserving untouched physical records and data; no user file writes, UI activation, atomic storage or server admission. Original allocation-failure behavior is recorded separately and not reproduced by the native allocator."}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
func observed_binary() -> String: return "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
