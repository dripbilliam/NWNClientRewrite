extends SceneTree
const Codec=preload("res://systems/native_data/native_nui_ubjson.gd")

func _initialize()->void:
	var path:=ProjectSettings.globalize_path("res://../backups/animations/native-nui-ubjson-v1.json")
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not oracle is Dictionary or oracle.get("cases",[]).size()!=31:fail("original NUI UBJSON oracle unavailable");return
	for row in oracle.cases:
		var bytes:=str(row.wire).hex_decode()
		var result: Dictionary=Codec.decode(bytes)
		if result.has("error"):fail("original UBJSON was rejected: "+str(result.error));return
		var expected: Variant=int(str(row.value)) if bool(row.integer64) else row.value
		if not same(result.value,expected):fail("original UBJSON value differed for "+str(row.wire)+" actual="+JSON.stringify(result.value)+" expected="+JSON.stringify(expected));return
		if not bool(row.integer64) and bytes[0]!=68:
			var encoded: Dictionary=Codec.encode(expected)
			if encoded.has("error") or encoded.bytes!=bytes:fail("original UBJSON bytes differed for "+str(row.wire));return
	for hex in ["", "53", "5369ff", "5b", "7b", "5b24555d", "5b2369ff", "5a5a", "4340ff", "4869022b31"]:
		if not Codec.decode(str(hex).hex_decode()).has("error"):fail("malformed UBJSON was admitted: "+str(hex));return
	var typed_cases: Array=[
		["5b246923690401020304",[1,2,3,4]],
		["7b23690269016169016901625a",{"a":1,"b":null}],
		["5b2454236903",[true,true,true]],
		["4869143138343436373434303733373039353531363135",{"native64":"18446744073709551615"}],
		["536903e29883","☃"]]
	for row in typed_cases:
		var result: Dictionary=Codec.decode(str(row[0]).hex_decode())
		if result.has("error") or not same(result.value,row[1]):fail("typed NUI UBJSON container differed");return
	print("NWN79 Godot NUI UBJSON PASS: original=31 typed=5 malformed=10")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot NUI UBJSON failed: "+reason)
	quit(1)

func same(left: Variant,right: Variant)->bool:
	if left is Array and right is Array:
		if left.size()!=right.size():return false
		for index in left.size():
			if not same(left[index],right[index]):return false
		return true
	if left is Dictionary and right is Dictionary:
		if left.size()!=right.size():return false
		for key in left:
			if not right.has(key) or not same(left[key],right[key]):return false
		return true
	if (left is int or left is float) and (right is int or right is float):return float(left)==float(right)
	return left==right
