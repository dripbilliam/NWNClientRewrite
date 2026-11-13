extends SceneTree
const Skill=preload("res://systems/native_data/skill_admission.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const TwoDA=preload("res://systems/native_data/two_da.gd")
var checks:=0
var failures:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func table(size:int)->Dictionary:
	var rows:Array=[]
	for i in size:rows.append({"Label":"physical"+str(i)})
	return {"orderedRows":rows,"rowLabels":["9999","-500","not-a-number"]}
func _initialize()->void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	var rules:=Rules.new()
	check(not rules.skill_admission({"objectType":5},0).available,"missing Talk owner unavailable")
	var talk:=Talk.new();rules.text=talk
	check(not rules.skill_admission({"objectType":5},0).available,"missing active Skills not base fallback")
	var cache={"version":1,"source":Skill.SOURCE,"mask":8193,"knownMask":4294967295,"playerUpdateSeen":true,"inventoryUpdateSeen":false}
	var actor={"objectType":5,"clientSkillAdmission":cache}
	var first:=table(14);talk.publish_table("skills",first)
	var revision:int=talk.revision
	var admitted:=rules.skill_admission(actor,13)
	check(admitted.available and admitted.value and admitted.nativeResult==null,"received setbit usable, unknown override exact result unavailable")
	check(admitted.rules.count==14 and admitted.rules.revision==revision,"current publication count/revision")
	check(not rules.skill_admission(actor,1).available,"clearbit plus unknown override unavailable")
	cache.override=0;cache.overrideSource=Skill.OVERRIDE_SOURCE
	check(rules.skill_admission(actor,1).available and rules.skill_admission(actor,1).value==false,"received31/22 zero makes known clearbit reject")
	check(rules.skill_admission(actor,13).nativeResult==8192,"receivedzero preserves exact native setbit result")
	cache.overrideSource="unverified"
	check(not rules.skill_admission(actor,13).available,"unverified override provenance cannot grant even retained mask")
	cache.override=1;cache.overrideSource=Skill.OVERRIDE_SOURCE
	check(not rules.skill_admission(actor,1).available,"permission true cannot become fabricated override1")
	cache.erase("override");cache.erase("overrideSource")
	var parsed:=TwoDA.new().parse_reference("2DA V2.0\n\nLabel\n9999 One\n-500 Two\nbanana Three\n")
	talk.publish_table("skills",parsed)
	check(not is_same(first,talk.tables.skills),"replacement table source identity")
	check(rules.skill_admission(actor,13).nativeResult==0 and rules.skill_admission(actor,13).reason=="outside_active_rules","physical count3 despite labels9999 and negative and text")
	check(rules.skill_admission(actor,0).rules.revision==revision+1,"replacement publication revision observed")
	check(admitted.rules.count==14,"detached previous result remains original count")
	admitted.rules.count=999
	check(rules.skill_admission(actor,0).rules.count==3,"consumer result mutation does not mutate live table")
	var unchanged_revision:int=talk.revision
	talk.tables.skills.orderedRows.append({"Label":"extra"})
	check(rules.skill_admission(actor,0).rules.count==4 and talk.revision==unchanged_revision,"same-source inplace row append has no stale count cache")
	talk.publish_table("skills",{"error":"failed active publication"})
	check(not rules.skill_admission(actor,0).available,"error publication unavailable")
	talk.publish_table("skills",table(256))
	check(rules.skill_admission(actor,0).nativeResult==0 and rules.skill_admission(actor,0).rules.count==0,"physical256 lowBYTE0 native behavior")
	talk.publish_table("skills",table(257))
	check(rules.skill_admission(actor,0).value==true and rules.skill_admission(actor,0).rules.count==1,"physical257 lowBYTE1")
	check(not rules.skill_admission({"objectType":5,"replicationRemoved":true,"clientSkillAdmission":cache},0).available,"removed creature unavailable")
	check(not rules.skill_admission({"objectType":9,"clientSkillAdmission":cache},0).available,"noncreature not interpreted as stats")
	check(not rules.skill_admission({"objectType":5},0).available,"missing disclosure not zero")
	talk.close()
	check(not rules.skill_admission(actor,0).available,"owner close clears active count even unchanged revision")
	var next:=Talk.new();rules.text=next;next.publish_table("skills",table(2))
	check(rules.skill_admission(actor,0).rules.count==2 and rules.skill_admission(actor,0).rules.revision==1,"reconnected Talk owner same revision uses new publication")
	var before:=Time.get_ticks_usec()
	for i in 10000:rules.skill_admission(actor,0)
	var usec:=Time.get_ticks_usec()-before
	next.close();rules.text=null;talk=null;next=null;rules=null
	var result={"success":failures.is_empty(),"checks":checks,"failures":failures,"facade10000Usec":usec,"scope":"Actual Talk.publish_table/close and GameUiRules read-only facade; source-faithful physical count. No menu enable, stats110 inference, server or graphical acceptance."}
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n");file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
