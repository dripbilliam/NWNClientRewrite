extends SceneTree
const Witness=preload("res://systems/native_data/level_up_finalization_witness.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var scope: Array=[1,7,42,3];var ticket: Array=scope+[1,"summary"]
	var private:={"ready":true,"vitals":{"raw":[14,14,14,14,14,14],"racial":[0,0,0,0,0,0],"gains":[0,0,0,0,0,0],"scores":[14,14,14,14,14,14],"modifiers":[2,2,2,2,2,2]},"source":{"classes":[{"id":10,"level":16,"secret":"PRIVATE_SENTINEL"}],"current":0,"owned":[40.0],"definitions":[RefCounted.new()],"text":"PRIVATE_SENTINEL"}}
	var application:={"forceMaximum":false,"hideHitPointGain":false,"secret":"PRIVATE_SENTINEL"}
	var review:={"ready":true,"hitDie":3,"displayHitPointGain":6,"hiddenHitPointGain":false,"summary":"PRIVATE_SENTINEL"}
	var value:=Witness.capture(scope,ticket,private,[40],application,review,1)
	check(value.get("ready",false) and value.scope==scope and value.ticket==ticket,"Actual scalar source scope and Summary ticket are preserved")
	check(value.ownedTypes==[TYPE_FLOAT] and value.primaryTypes==[TYPE_INT] and not value.literalInt40Membership.owned and value.literalInt40Membership.primary,"Numeric ID representation and literal membership remain observable")
	check(not JSON.stringify(value).contains("PRIVATE_SENTINEL") and not value.has("source") and value.classes[0].keys().size()==2 and value.moduleFlags.keys().size()==2,"Allowlist excludes private strings/definitions/Objects and unknown fields")
	private.vitals.raw[0]=99;private.source.owned[0]=12.0
	check(value.vitals.raw[0]==14 and value.ownedFeats[0]==40.0,"Vectors and IDs are detached from mutable callers")
	check(not Witness.capture(scope,[1,7,42,4,1,"summary"],private,[40],application,review,1).ready,"Changed token cannot reuse a witness")
	var large: Array=[];large.resize(4097);large.fill(40)
	check(not Witness.capture(scope,ticket,private,large,application,review,1).ready,"Oversize primary feat list is refused")
	private.vitals.raw[0]=NAN
	check(not Witness.capture(scope,ticket,private,[40],application,review,1).ready,"Non-finite data is refused")
	private.vitals.raw[0]=14;application.forceMaximum=0
	check(not Witness.capture(scope,ticket,private,[40],application,review,1).ready,"Unprojected module bits cannot masquerade as composed flags")
	check(JSON.stringify(value).to_utf8_buffer().size()<=128*1024 and value.serverAcknowledged==false,"Bounded private witness does not invent server authority")
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Pure allowlisted finalization witness shape/type/bounds/redaction only. No actor, packet, server or RNG operation."}));file.close();quit(0 if failures.is_empty() else 1)
