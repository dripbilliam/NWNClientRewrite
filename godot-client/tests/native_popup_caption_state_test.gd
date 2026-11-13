extends SceneTree
const CaptionState=preload("res://systems/native_data/popup_caption_state.gd")
const ORIGINAL="6205e86e750e7dc4ef092fed2f557464a6d21c4f003b13dd86d1b1efd166d46c"
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label)
static func float_bits(value: float)->int:
	var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_float(0,value);return bytes.decode_u32(0)
static func from_bits(value: int)->float:
	var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_u32(0,value);return bytes.decode_float(0)
static func snapshot(record: Dictionary)->Dictionary:
	# `elapsedBits` is the immutable oracle's OLD mechanical field label.
	# Fresh source identifies that DWORD+128 as forceVisible, never elapsed.
	return {"activeBits":record.activeBits,"sizeChoice":int(record.sizeChoice)&4294967295,"full":int(record.mode==2),"elapsedBits":record.forceVisible,"durationBits":float_bits(record.remaining),"timed":record.timedFlag,"off":int(record.mode==0),"minimumLines":record.minimumLines,"indentBits":float_bits(record.indent)}
static func fields_match(actual: Dictionary,expected: Dictionary)->bool:
	# JSON integers arrive as FLOAT variants; all these fields are exact UINT32
	# bit patterns, not numeric tolerances or glyph/timer approximations.
	return actual.size()==expected.size() and actual.keys().all(func(key):return expected.has(key) and int(actual[key])==int(expected[key]))
func _initialize()->void:run.call_deferred()
func run()->void:
	var output:="";var oracle:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		if arg.begins_with("--oracle="):oracle=arg.trim_prefix("--oracle=")
	if output.is_empty() or oracle.is_empty() or FileAccess.file_exists(output):quit(2);return
	check(FileAccess.get_sha256(oracle)==ORIGINAL,"Exact unchanged original92-case receipt is retained")
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle));check(source.success and source.cases.size()==80 and source.fontCases.size()==12,"Original mode/font scope has80+12 finite source cases")
	for case in source.cases:
		for index in case.rows.size():
			var input: Dictionary=case.rows[index];var before: Dictionary=case.before[index];var bytes:=PackedByteArray()
			for line in input.lines:
				if line!=null:bytes.append_array(CaptionState.encoded(str(line).hex_decode()).bytes)
			var record:=CaptionState.create(int(case.oldMode),false)
			record.currentRaw=bytes;record.activeBits=before.activeBits;record.sizeChoice=before.sizeChoice;record.forceVisible=before.elapsedBits;record.remaining=from_bits(int(before.durationBits));record.timedFlag=before.timed;record.minimumLines=before.minimumLines;record.indent=from_bits(int(before.indentBits));record.portrait="fixture" if input.portrait else "";record.sceneActive=input.active;record.hidden=(int(before.activeBits)&4)!=0
			var old_raw: PackedByteArray=record.currentRaw.duplicate();var result:=CaptionState.mode_changed(record,int(case.newMode))
			check(result.ready and fields_match(snapshot(record),case.after[index]),"Original mode fields match: "+str(case.name)+":"+str(case.oldMode)+">"+str(case.newMode)+":"+str(index))
			check(record.currentRaw==old_raw and record.sceneActive==(bool(input.active) and int(case.newMode)!=0 if case.oldMode!=case.newMode else bool(input.active)),"Refit retains exact current bytes and cannot immediately activate inactive popup: "+str(case.name)+":"+str(index))
	for case in source.fontCases:
		for index in case.before.size():
			var before: Dictionary=case.before[index];var record:=CaptionState.create(int(case.mode),false)
			record.activeBits=before.activeBits;record.sizeChoice=before.sizeChoice;record.forceVisible=before.elapsedBits;record.remaining=from_bits(int(before.durationBits));record.timedFlag=before.timed;record.minimumLines=before.minimumLines;record.indent=from_bits(int(before.indentBits));record.currentRaw=PackedByteArray([60,99,255,1,2,62,88,10])
			var retained: PackedByteArray=record.currentRaw.duplicate()
			if int(case.guiInitialized)!=0:CaptionState.font_changed(record,str(case.remappedFont).hex_decode().get_string_from_ascii().contains("_hr"))
			check(fields_match(snapshot(record),case.after[index]) and record.currentRaw==retained,"Font refresh preserves raw/choice/timer/flags: "+str(case.mode)+":"+str(case.guiInitialized)+":"+str(index))
	var record:=CaptionState.create(2,true);var raw:="A"+String.chr(233)+" "+String.chr(8211)+"\n<c"+String.chr(255)+String.chr(1)+String.chr(2)+">B</c>"
	var terminated: PackedByteArray=CaptionState.encoded(raw).bytes;terminated.append(0);terminated.append_array("discard".to_ascii_buffer())
	var stream:=CaptionState.encoded(terminated);check(stream.ready and CaptionState.decoded(stream.bytes)==raw,"Current caption CP1252, native color bytes, whitespace and first-NUL stream roundtrip without UTF8 substitution")
	check(CaptionState.cache_name(record,"current hover",{"text":"current hover","spans":[]}).ready and record.currentRaw.is_empty() and record.remaining==from_bits(float_bits(0.0001)),"Cache-only writer does not replace current caption or clock")
	CaptionState.write(record,stream.bytes,{"text":"visible","spans":[]},"speech","",4.0,1);CaptionState.advance(record,1.0);var remaining: float=record.remaining;var choice: int=record.sizeChoice;CaptionState.font_changed(record,false)
	check(record.remaining==remaining and record.sizeChoice==choice and record.currentRaw==stream.bytes,"Font-only helper cannot restart time, rewrap or invalidate shape")
	CaptionState.mode_changed(record,0);var stopped: float=record.remaining;CaptionState.advance(record,10.0);check(not record.sceneActive and record.timedFlag==1 and record.remaining==stopped,"Off preserves timed source flag while unregistering its clock")
	CaptionState.mode_changed(record,2);check(not record.sceneActive and not record.guiRegistered,"Enabling does not activate an inactive record inside the setting callback")
	CaptionState.project_active(record,true);check(record.sceneActive and record.guiRegistered,"A later eligible normal owner projection may activate when Off and panel gates permit")
	check(not CaptionState.advance(record,4.0) and record.remaining==0.0 and record.guiRegistered,"Exactly zero waits until a later positive GUI delta")
	check(CaptionState.advance(record,0.01) and record.timedFlag==0 and record.remaining==0.0 and CaptionState.decoded(record.currentRaw)=="current hover" and not record.guiRegistered,"Strict-negative expiry restores latest cache, clears timed flag and stops the single clock")
	check(not record.hidden,"Unknown global ToggleOff flag does not invent a universal hidden/deactivated state")
	var toggled:=CaptionState.create(2,true);toggled.remaining=0.0;toggled.guiRegistered=true;CaptionState.advance(toggled,0.01,true);check(toggled.hidden,"Explicit admitted true ToggleOff flag may hide the popup")
	CaptionState.cache_name(record,"new cached hover",{});CaptionState.write(record,"new current hover",{},"hover","",4.0,0);CaptionState.mode_changed(record,1)
	check(CaptionState.decoded(record.currentRaw)=="new current hover" and record.timedFlag==0,"Mode refit uses the actual later hover writer instead of older speech/cache")
	CaptionState.advance(record,1.0);check(record.timedFlag==0 and record.remaining==3.0,"Zero source marker is not a timer-enable Boolean: active hover countdown still ticks")
	var retained: Dictionary=record.duplicate(true);CaptionState.mode_changed(record,1);check(record==retained,"Same mode is a complete no-op")
	var negative:=CaptionState.create(2,true);negative.remaining=-1.0;negative.guiRegistered=true;negative.currentRaw="unrestored".to_ascii_buffer();CaptionState.advance(negative,1.0)
	check(CaptionState.decoded(negative.currentRaw)=="unrestored" and negative.remaining==-1.0 and not negative.guiRegistered,"Pre-existing negative timer unregisters without running restoration")
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalModeCases":80,"originalFontCases":12,"scope":"Pure presentation-record mode/font field parity against unchanged original92 cases plus current/cache/raw byte and single-clock lifecycle. Oracle elapsedBits is mechanical128 forceVisible, not elapsed. No view/font shaping/activation lower effects, world/profile/server/GPU."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
