extends SceneTree
const Sender=preload("res://systems/native_data/native_network_levelup_request.gd")

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_native_levelup_sender_fixture.json"))
	if not fixture is Dictionary or not fixture.get("cases") is Array or fixture.cases.size()!=48:fail("Original 48-case level-up writer fixture unavailable");return
	if Sender.begin()!=PackedByteArray([112,29,4]):fail("Original level-up begin packet differs");return
	if Sender.character_sheet(0xffffffff).hex_encode()!="7015010c00000000ffffffff60":fail("Original pre-begin sheet packet differs");return
	if Sender.cancel(false).hex_encode()!="7035010f000000100000000000007f60" or Sender.cancel(true).hex_encode()!="7035011b000000100000000000007f00000000000000000000000060":fail("Original level-up cancel packet differs");return
	for index in fixture.cases.size():
		var row: Dictionary=fixture.cases[index]
		var actual: Dictionary=Sender.proposal(row.case,row.case)
		var expected: PackedByteArray=str(row.packet).hex_decode()
		if actual.has("error") or actual.bytes.size()!=expected.size() or actual.bytes.slice(0,actual.bytes.size()-1)!=expected.slice(0,expected.size()-1) or int(actual.bytes[-1])&0xe0!=int(expected[-1])&0xe0:
			fail("Original level-up proposal differs at case "+str(index)+": "+str(actual.get("error","defined bytes")));return
		if actual.bytes.decode_u32(3)!=actual.bytes.size()-1:fail("Original level-up declared length differs at case "+str(index));return
	var row: Dictionary=fixture.cases[0]
	var invalid: Dictionary=row.case.duplicate(true);invalid.skillPoints=-1
	if not Sender.proposal(invalid,row.case).has("error"):fail("Negative skill points accepted");return
	invalid=row.case.duplicate(true);invalid.skills=[128]
	if not Sender.proposal(invalid,row.case).has("error"):fail("Invalid skill rank accepted");return
	invalid=row.case.duplicate(true);invalid.fieldE48="Name".repeat(80)
	if not Sender.proposal(invalid,row.case).has("error"):fail("Oversized associate name accepted");return
	invalid=row.case.duplicate(true);invalid.ability=1
	if not Sender.proposal(invalid,row.case).has("error"):fail("Early ability increase accepted");return
	print("NWN79 Godot level-up sender PASS: 48 original native proposals, begin packet, defined residual bits, strict invalid input")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot level-up sender failed: "+reason)
	quit(1)
