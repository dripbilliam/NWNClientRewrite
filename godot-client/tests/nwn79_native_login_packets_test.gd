extends SceneTree
const Packets=preload("res://systems/native_data/native_login_packets.gd")
func _initialize()->void:
	var fixture: String=ProjectSettings.globalize_path("res://../backups/animations/native-network-login-packets-observations.json")
	var file:=FileAccess.open(fixture,FileAccess.READ)
	if file==null:fail("fixture unavailable");return
	var rows: Variant=JSON.parse_string(file.get_as_text());file.close()
	if not rows is Dictionary or not rows.get("cases") is Array or rows.cases.size()!=32:fail("fixture shape");return
	var skipped_nul_names:=0
	for row_index in range(rows.cases.size()):
		var row: Dictionary=rows.cases[row_index]
		var sample: Dictionary=row["case"]
		var wire: PackedByteArray=str(row.calls[0][1]).hex_decode()
		var value: Dictionary={}
		match sample.tag:
			"BNCS":
				# Godot's JSON parser replaces escaped NUL in the recorded source
				# name with U+FFFD. Exercise the wire-valid rows without altering
				# the original observation file.
				if str(sample.name).contains("�"):
					skipped_nul_names+=1
					continue
				var input: Dictionary=sample.duplicate(true);input.platformId=2
				value=Packets.connect_request(input)
				if not value.has("bytes"):fail("BNCS encode: "+str(value.get("error","unknown")));return
				if value.bytes!=wire:
					var mismatch: int=-1
					for index in range(mini(value.bytes.size(),wire.size())):
						if value.bytes[index]!=wire[index]:mismatch=index;break
					fail("BNCS size="+str(value.bytes.size())+" expected="+str(wire.size())+" offset="+str(mismatch));return
			"BNVS":
				if str(sample.communityResponse).contains("�"):
					skipped_nul_names+=1
					continue
				value=Packets.validation_response(sample)
				if not value.has("bytes") or value.bytes!=wire:fail("BNVS "+str(value.get("error","wire mismatch")));return
			"BNCR":
				value=Packets.read_connect_response(wire)
				var expected_error: int=1 if int(sample.reason) in [7,255] else int(sample.reason)
				if value.has("error") or (sample.reason and int(value.get("connectionError",0))!=expected_error) or (not sample.reason and (value.get("kind","")!="challenge" or value.keyChallenge!=sample.challenges[1 if sample.passwordRequired else 0])):fail("BNCR row="+str(row_index)+" "+str(value.get("error","value mismatch"))+" kind="+str(value.get("kind"))+" reason="+str(sample.reason)+" observed="+str(value.get("connectionError")));return
			"BNVR":
				value=Packets.read_validation_response(wire)
				if value.has("error") or (sample.reason and value.get("connectionError",0)!=sample.reason) or (not sample.reason and value.get("applicationId",-1)!=sample.applicationId):fail("BNVR");return
	if skipped_nul_names!=3:fail("NUL fixture accounting");return
	if Packets.disconnect_request()!=PackedByteArray([66,78,68,77]):fail("disconnect");return
	print("NWN79 Godot native login packets PASS")
	quit(0)
func fail(stage: String)->void:
	printerr("NWN79 Godot login packet parity failed: "+stage)
	quit(1)
