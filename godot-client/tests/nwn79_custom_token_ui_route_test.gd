extends SceneTree
const Decoder=preload("res://systems/native_data/native_network_custom_token.gd")
const Ui=preload("res://systems/native_gameplay_ui.gd")

class Connection extends RefCounted:
	var value:=7
	func current()->int:return value

var checks:=0
var failures: Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func packet(rows: Array,name: String)->Dictionary:
	for row in rows:
		if row.name==name:return Decoder.decode_packet(str(row.packet).hex_decode())
	return {"error":"Missing original token fixture: "+name}
func run()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_custom_token_fixture.json"))
	if not fixture is Dictionary or not fixture.get("cases") is Array:printerr("NWN79 token UI oracle missing");quit(1);return
	var scope=Connection.new();var ui=Ui.new();ui.native_connection_query=Callable(scope,"current")
	var positive:=packet(fixture.cases,"native-sender-936")
	var negative:=packet(fixture.cases,"native-sender-912")
	var embedded:=packet(fixture.cases,"native-sender-948")
	check(not positive.has("error") and positive.id==10 and positive.textBytes=="value".to_ascii_buffer(),"Original 50/1 writer and Godot decoder supply exact positive token bytes")
	ui.receive(positive,1,scope.value)
	check(ui.custom_token_snapshot().connection==7 and ui.custom_token_snapshot().records.size()==1 and ui.text.custom_tokens.get(10)=="value","GameplayUI owns one connection-scoped raw token and safe text projection")
	check(ui.text.resolve({"text":"<CUSTOM10>"},0)=="value" and ui.text.rich({"text":"<CUSTOM10>"},0).text=="value","Actual TalkText and tooltip rich-text edge display the accepted token")
	var prior: int=ui.text.server_tokens.revision
	ui.receive(negative,1,scope.value)
	check(ui.text.server_tokens.revision==prior and ui.custom_token_snapshot().records.size()==1,"Original signed-negative token ID leaves active text and order unchanged")
	ui.receive(embedded,1,scope.value)
	var exact: Dictionary=ui.text.server_tokens.lookup_bytes(10)
	check(exact.get("found",false) and exact.bytes==PackedByteArray([97,0,98]) and not ui.text.custom_tokens.has(10),"Embedded NUL remains byte-exact and cannot enter captured UI text")
	check(ui.text.resolve({"text":"<CUSTOM10>"},0)=="<UNAVAILABLE TOKEN>" and ui.text.rich({"text":"<CUSTOM10>"},0).text=="<UNAVAILABLE TOKEN>","Speech and tooltip text refuse lossy embedded-NUL projection")
	ui.receive({"kind":"custom-token","id":11,"text":"wrong"},1,scope.value)
	check(not ui.text.server_tokens.lookup_bytes(11).found,"Admitted wire event cannot fall back to a String or fabricate bytes")
	check(ui.sync_custom_token_connection(7) and ui.text.server_tokens.lookup_bytes(10).found,"Area publication within one connection retains native custom-token table")
	scope.value=8
	check(ui.sync_custom_token_connection(8) and ui.custom_token_snapshot().records.is_empty() and ui.text.custom_tokens.is_empty(),"New connection clears raw and display token state")
	ui.receive(positive,2,7)
	check(ui.custom_token_snapshot().records.is_empty() and ui.stats.stale_messages==1,"Late prior-connection 50/1 cannot restore stale text")
	ui.receive(positive,2,8)
	check(ui.text.resolve({"text":"<CUSTOM10>"},0)=="value","Current connection rebuilds the same native token through actual UI ingress")
	ui.receive({"kind":"custom-token","id":20,"textBytes":PackedByteArray([0x80,0xe9])},2,8)
	check(ui.text.resolve({"text":"<CUSTOM20>"},0)=="€é" and ui.text.server_tokens.lookup_bytes(20).bytes==PackedByteArray([0x80,0xe9]),"Native CP1252 bytes render without changing stored payload")
	ui.receive({"kind":"custom-token","id":3,"textBytes":PackedByteArray([0,65])},2,8)
	check(ui.text.server_tokens.lookup_bytes(3).bytes.is_empty() and ui.text.resolve({"text":"<CUSTOM3>"},0)=="","Leading NUL is an empty native assignment")
	check(ui.custom_token_snapshot().records.map(func(row):return int(row.id))==[3,10,20],"Connection token records remain in native ID order")
	ui.text.close();ui.free()
	print("NWN79_CUSTOM_TOKEN_UI_ROUTE_RESULT ",JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"provenance":"Original native sender scalar observation and original-format authored writer fixture; no captured native server packet"}))
	quit(0 if failures.is_empty() else 1)
