extends SceneTree
const Health=preload("res://systems/native_data/party_health.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func bits(value: float) -> int:
	var bytes:=PackedByteArray(); bytes.resize(4); bytes.encode_float(0,value); return bytes.decode_u32(0)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var path:=ProjectSettings.globalize_path("res://../backups/animations/native-party-health-observations-v1.json"); var input:=FileAccess.open(path,FileAccess.READ); var oracle: Dictionary=JSON.parse_string(input.get_as_text()); input.close()
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.rows.size()==144,"Health oracle executes pinned original mode, clamp and animation time instructions")
	for row in oracle.rows:
		var clip:=Health.mode(int(row.poison),int(row.disease)); var result:=Health.sample(float(row.percent),clip)
		check(result.error.is_empty() and clip==row.publication.clip and bits(result.percent)==int(row.clampedBits) and bits(result.time)==int(row.publication.timeBits),"Original health mode/clamp/time bits match poison%d disease%d percent%s"%[row.poison,row.disease,row.percent])
	check(Health.from_party({"field8B4":true,"field8B0":false})=="disease" and Health.from_party({"field8B4":false,"field8B0":true})=="poison","Received wire field order maps disease first and poison second")
	check(Health.from_party({"poisoned":true,"diseased":true,"effectIcons":{"1":true}})=="percentage","Unrelated names/effects cannot invent received party health flags")
	check(Health.from_player_icons({"20":false})=="poison" and Health.from_player_icons({21:0})=="disease","Controlled health flags use source icon presence rather than the flashing bit")
	check(Health.from_player_icons({20:0,"21":false})=="diseasepoison" and Health.from_player_icons({})=="percentage","Controlled health combines original icons20/21 and clears on received removal")
	check(Health.from_player_icons({1:true,22:true})=="percentage","Other server effect IDs cannot tint controlled health")
	check(not Health.sample(50,"missing").error.is_empty() and not Health.sample(NAN).error.is_empty(),"Invalid private clip/nonfinite input fails before native artwork work")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"oracleSha256":FileAccess.get_sha256(path),"scope":"Original finite-input mode/clamp/time instruction oracle and wire field mapping; nonfinite source/runtime and full HUD parity not accepted."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
