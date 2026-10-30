extends "res://tests/native_particle_schedule_test.gd"
const Selection=preload("res://systems/native_data/script_sound.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var path:="res://../backups/animations/native-network-audio-observations.json"
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(corpus.target==BINARY_SHA,"Retained original script-sound branch uses the expected unchanged nwmain")
	var compared:=0
	for row in corpus.cases:
		if row.kind!="client-branch": continue
		var raw: PackedByteArray=str(row.textHex).hex_decode()
		var cue:=Selection.cue_bytes(raw,row.positional,row.position); var call: Dictionary=row.calls[0]
		var expected: PackedByteArray=str(call.resRefHex).hex_decode()
		check(cue.error.is_empty() and cue.resRef==Binary.new(expected).text(0,expected.size()) and same(cue.position,call.position).is_empty() and cue.priority==int(call.priority) and cue.delay==int(call.delay) and cue.volume==int(call.volume),"Original77e330 ResRef/position/profile case "+str(compared)); compared+=1
	check(compared==20,"All20 original bounded client sound branch observations compared")
	var cast_path:="res://../backups/animations/native-script-sound-class-casts-current.json"
	var casts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(cast_path))
	check(casts.target==BINARY_SHA,"Current read-only positional-class evidence has matching original hash")
	var types:={"CNWCModule":3,"CNWCArea":4,"CNWCCreature":5,"CNWCItem":6,"CNWCTrigger":7,"CNWCProjectile":8,"CNWCPlaceable":9,"CNWCDoor":10,"CNWCAreaOfEffectObject":11,"CNWCMapPin":12,"CNWCStore":14,"CNWCSoundObject":16}
	var covered: Dictionary={}
	for row in casts.cases:
		var name:=str(row.name).trim_prefix(".?AV").trim_suffix("@@")
		# Area/item's primary interfaces are not their registered CGameObject
		# base. Their RTTI offsets identify the actual base table explicitly.
		if not types.has(name) or name=="CNWCArea" and int(row.baseOffset)!=272 or name=="CNWCItem" and int(row.baseOffset)!=72: continue
		check(Selection.positional_type(int(types[name]))==(str(row.slot18)=="0x140762820"),"Original registered source cast "+name); covered[name]=true
	check(covered.size()==types.size(),"Every supported positional/nonpositional source type is independently covered by original virtual-slot evidence")
	check(Selection.positional_type(99)==null and not Selection.cue("tone",true,null).error.is_empty(),"Unknown source casts and missing 3D poses cannot invent centered fallback audio")
	check(Selection.cue("tone",false,null).position==null and Selection.cue_bytes(PackedByteArray([97,0,98]),false,null).resRef=="a","Nonpositional and embedded-null names preserve native one-shot semantics")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalBranchCases":compared,"originalAudioSha256":FileAccess.get_sha256(path),"originalClassSha256":FileAccess.get_sha256(cast_path),"scope":"Original bounded77e330 branch and read-only RTTI source casts. Not a full original chat-handler, server/device or mixer acceptance."},"\t")); file.close(); print("NATIVE_SCRIPT_SOUND_DATA ",checks," checks"); quit(0 if failures.is_empty() else 1)
