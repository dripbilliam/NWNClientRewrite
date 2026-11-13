extends SceneTree
const Talk=preload("res://systems/native_data/talk_text.gd")
class VirtualTalk extends "res://systems/native_data/talk_text.gd":
	var calls: Array=[]
	func fetch_reference(ref: int,gender: int=0)->Dictionary:
		calls.append([ref,gender]);return {"found":true,"text":"Virtual hook", "flags":0}
var checks:=0
var failures: Array=[]
var observations: Array=[]
func _initialize()->void:run.call_deferred()
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func tlk(values: Array,duration: float=0.0)->PackedByteArray:
	var strings:=PackedByteArray();var result:=PackedByteArray();result.resize(20+values.size()*40)
	for index in 8:result[index]="TLK V3.0".to_ascii_buffer()[index]
	result.encode_u32(12,values.size());result.encode_u32(16,result.size())
	for index in values.size():
		var encoded:=str(values[index]).to_ascii_buffer();var at:=20+index*40
		result.encode_u32(at,5 if duration!=0.0 else 1);result.encode_u32(at+28,strings.size());result.encode_u32(at+32,encoded.size());result.encode_float(at+36,duration)
		strings.append_array(encoded)
	result.append_array(strings);return result
func absent()->Dictionary:return {"known":true,"present":false}
func run()->void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var talk:=Talk.new()
	check(talk.base.open_bytes(tlk(["Base0","<CUSTOM12> base raw","Male2"],3.25)),"Real TLK parser accepts a complete primary table and sound-duration flags")
	check(talk.publish_native_family(false,true),"Actual missing-female publication aliases its native primary without table copies")
	var base_bytes: PackedByteArray=talk.base.bytes.duplicate()
	var selection:=absent();var selection_before:=selection.duplicate(true)
	talk.overrides[0]="Later live override";talk.custom_tokens[12]="Later token"
	var map_before: Dictionary=talk.overrides.duplicate(true)
	var result: Dictionary=talk.fetch_native_reference_snapshot(0,0,selection)
	check(result.found and result.lookupComplete and result.text=="Base0" and not result.override and result.duration==3.25,"Captured absence bypasses a later live override and reads actual primary TLK record")
	check(selection==selection_before and talk.overrides==map_before and talk.base.bytes==base_bytes,"Snapshot fetch changes neither selection, live override map nor original TLK bytes")
	result=talk.fetch_native_reference(0,0)
	check(result.found and result.text=="Later live override" and result.override and not result.has("lookupComplete"),"Default native API keeps its original live override and return-shape contract")
	result=talk.fetch_native_reference_snapshot(1,0,absent())
	check(result.found and result.lookupComplete and result.text=="<CUSTOM12> base raw" and not result.override,"Native parse0 base text remains raw, never generic-resolved by snapshot fetch")
	selection={"known":true,"present":true,"text":"<CUSTOM12> captured raw"};selection_before=selection.duplicate(true)
	talk.overrides[1]="Different future override";map_before=talk.overrides.duplicate(true)
	result=talk.fetch_native_reference_snapshot(1,1,selection)
	check(result.found and result.lookupComplete and result.text=="<CUSTOM12> captured raw" and result.override and result.gender==1 and result.duration==0.0,"Captured present override is returned raw with original gender and no TLK sound duration")
	check(selection==selection_before and talk.overrides==map_before,"Present snapshot does not temporarily replace or mutate the shared live map")
	result.text="Caller mutation";result=talk.fetch_native_reference_snapshot(1,1,selection)
	check(result.text=="<CUSTOM12> captured raw" and selection==selection_before,"Returned result mutation cannot change the retained input descriptor")
	result=talk.fetch_native_reference_snapshot(0xffffffff,1,{"known":false})
	check(result.found and result.lookupComplete and result.text.is_empty() and result.gender==1 and not result.override,"INVALID DWORD precedes unknown override selection")
	result=talk.fetch_native_reference_snapshot(-1,0,{"present":"malformed"})
	check(result.found and result.lookupComplete and result.text.is_empty() and result.gender==0,"Signed INVALID also precedes malformed selected-override fields")
	result=talk.fetch_native_reference_snapshot(0,2,{"known":false})
	check(result.found and result.lookupComplete and result.text.is_empty() and result.gender==2 and not result.override,"Native invalid gender guard precedes selected-override lookup")
	for invalid in [{},{"known":false},{"known":true},{"known":1,"present":false},{"known":true,"present":1},{"known":true,"present":true,"text":5}]:
		result=talk.fetch_native_reference_snapshot(0,0,invalid)
		check(not result.found and not result.lookupComplete and result.has("reason"),"Uncertified/malformed selected override stays explicitly unavailable")
	for invalid in [null,"0",0.5,-2147483649,4294967296]:
		result=talk.fetch_native_reference_snapshot(invalid,0,absent())
		check(not result.found and not result.lookupComplete,"Malformed snapshot reference never becomes a completed native lookup")
	result=talk.fetch_native_reference_snapshot(0,1,absent())
	check(result.found and result.lookupComplete and result.text=="Base0" and result.gender==1 and result.duration==3.25,"Explicit absent-female alias retains gender1 while reading the primary table")
	check(talk.female.open_bytes(tlk(["Female0"])) and talk.publish_native_family(false,false),"Actual separate short female TLK replaces the alias by current load publication")
	result=talk.fetch_native_reference_snapshot(0,1,absent())
	check(result.found and result.lookupComplete and result.text=="Female0" and result.gender==1 and result.duration==0.0,"In-range female record is selected independently of the live override map")
	result=talk.fetch_native_reference_snapshot(2.0,1.0,absent())
	check(result.found and result.lookupComplete and result.text=="Male2" and result.gender==0 and result.duration==3.25,"Short female row-bounds fallback mutates gender before native primary lookup")
	result=talk.fetch_native_reference_snapshot(99,0,absent())
	check(not result.found and result.lookupComplete and result.text.is_empty(),"Existing primary out-of-range is a completed native false result, not unresolved resource readiness")
	var malformed:=tlk(["In-range corrupt string"]);malformed.encode_u32(20+28,999999)
	check(talk.female.open_bytes(malformed) and talk.publish_native_family(false,false),"Corrupt string bounds retain a valid header/count for the in-range-failure test")
	result=talk.fetch_native_reference_snapshot(0,1,absent())
	check(not result.found and result.lookupComplete and result.gender==1 and not talk.female.failure.is_empty(),"In-range corrupt entry is a completed false lookup and never a guessed male row fallback")
	talk.retire_native_family(false)
	result=talk.fetch_native_reference_snapshot(0,0,absent())
	check(not result.found and not result.lookupComplete,"Retired/unpublished primary family remains pending despite still-open old TLK bytes")
	result=talk.fetch_native_reference_snapshot(0,1,{"known":true,"present":true,"text":"Captured before family"})
	check(result.found and result.lookupComplete and result.text=="Captured before family" and result.override,"Certified captured override precedes unavailable TLK family")
	var missing:=Talk.new();result=missing.fetch_native_reference_snapshot(0x01000001,1,absent())
	check(result.found and result.lookupComplete and result.text=="BadStrRef(16777217)" and result.gender==1,"Native missing custom-file branch returns its completed BadStrRef result")
	missing.retire_native_family(true);result=missing.fetch_native_reference_snapshot(0x01000001,1,absent())
	check(not result.found and not result.lookupComplete,"Explicit pending custom load is distinct from the native completed no-file branch")
	check(missing.custom.open_bytes(tlk(["Custom0","Custom1"],4.5)) and missing.publish_native_family(true,true),"Actual custom native pair publishes certified absent-female alias")
	missing.overrides[0x01000001]="Later custom override"
	result=missing.fetch_native_reference_snapshot(0x01000001,1,absent())
	check(result.found and result.lookupComplete and result.text=="Custom1" and result.gender==1 and result.duration==4.5,"Snapshot uses native custom mask/family alias without borrowing future override")
	check(missing.custom_female.open_bytes(tlk(["CustomFemale0"])) and missing.publish_native_family(true,false),"Separate short custom female file publishes only after its actual load")
	result=missing.fetch_native_reference_snapshot(0x01000001,1,absent())
	check(result.found and result.lookupComplete and result.text=="Custom1" and result.gender==0,"Custom short-female fallback uses the original full STRREF and changes gender0")
	var old_custom=missing.custom;missing.custom=Talk.Tlk.new()
	result=missing.fetch_native_reference_snapshot(0x01000001,0,absent())
	check(not result.found and not result.lookupComplete,"Replaced table owner cannot reuse a formerly ready native family publication")
	missing.custom=old_custom
	var virtual:=VirtualTalk.new()
	check(virtual.base.open_bytes(tlk(["Actual base behind virtual hook"])) and virtual.publish_native_family(false,true),"Default-hook fixture uses a real published TLK pair")
	result=virtual.fetch_native_reference(0,0)
	check(result.found and result.text=="Virtual hook" and virtual.calls==[[0,0]],"Default native fetch still invokes an authored subclass's existing virtual fetch_reference exactly once")
	result=virtual.fetch_native_reference_snapshot(0,0,absent())
	check(result.found and result.lookupComplete and result.text=="Actual base behind virtual hook" and virtual.calls==[[0,0]],"Snapshot bypasses virtual live override lookup through the exact selected actual TLK owner")
	result=virtual.fetch_native_reference_snapshot(0,0,{"known":true,"present":true,"text":"Receipt raw"})
	check(result.text=="Receipt raw" and result.override and virtual.calls==[[0,0]],"Captured present snapshot also leaves default virtual hook untouched")
	observations.append({"femaleFailureComplete":true,"snapshotDefaultSplit":virtual.calls.duplicate(true),"liveMap":talk.overrides.duplicate(true),"customMap":missing.overrides.duplicate(true)})
	check(talk.base.bytes==base_bytes and talk.overrides[0]=="Later live override" and talk.overrides[1]=="Different future override" and missing.overrides[0x01000001]=="Later custom override","All test branches preserve underlying original byte table and current live override maps")
	talk.close();missing.close();virtual.close()
	check(talk.native_families.is_empty() and missing.native_families.is_empty() and virtual.native_families.is_empty(),"Normal text-owner close retires native family publications and table resources")
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scope":"Actual TalkText snapshot/default APIs and actual TLK byte decoder/family publication, receipt-time override isolation, invalid priority, female/custom fallback, completed false vs unpublished pending, map/result mutation and legacy virtual hook. Synthetic valid/corrupt TLK records only; no original new execution/server/keys/profiles/GPU/native build/user process or parser pixel parity."})+"\n");file.close();print("NATIVE_TALK_SNAPSHOT_FETCH ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
