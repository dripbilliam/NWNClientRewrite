extends SceneTree
const Creator=preload("res://systems/native_creation.gd")
const CreationRules=preload("res://systems/native_data/creation_rules.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Reader=preload("res://systems/native_data/gff_document.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var writer:=Writer.new(); var reader:=Reader.new(); var fields: Dictionary={}
	var values: Array=[255,-128,65535,-32768,4294967295,-2147483648,{"unsigned64_low":4294967295,"unsigned64_high":4294967295},-9223372036854775807,1.25,2.5,"Café €","authored",{"strRef":4294967295,"entries":[{"languageId":0,"text":"Authored name"}]},PackedByteArray([0,127,255]),Writer.record({"Nested":Writer.field(5,-1)},17),[Writer.record({"Entry":Writer.field(2,55)},3)],[0.0,1.0,2.0,3.0],[1.0,2.0,3.0],123]
	for type in 19: fields["Type"+str(type)]=Writer.field(type,values[type])
	var bytes:=writer.write("BIC ",Writer.record(fields)); var decoded:=reader.parse(bytes,"BIC ")
	check(writer.failure.is_empty() and reader.failure.is_empty(),"All original GFF field kinds serialize and parse")
	for type in 19:
		check(int(decoded.field_types[0]["Type"+str(type)])==type,"Field width retained for type "+str(type))
	check(decoded.root.Type5==-2147483648 and decoded.root.Type6.unsigned64_high==4294967295,"Signed INT and full unsigned 64-bit values survive")
	check(decoded.root.Type10=="Café €" and decoded.root.Type12.entries[0].text=="Authored name","Original byte text and localized strings survive")
	var copied:=writer.typed(decoded,decoded.root); var encoded:=writer.write("BIC ",copied)
	check(encoded==bytes,"Typed native resources retain original struct IDs and field ordering")
	writer.write("BIC ",Writer.record({"Bad":Writer.field(0,256)})); check(not writer.failure.is_empty(),"Narrow integer overflow is rejected")
	writer.write("BIC ",Writer.record({"Class":Writer.field(5,4),"ClassLevel":Writer.field(3,1)})); check(writer.failure.is_empty(),"Original class INT and class-level SHORT widths are supported")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
