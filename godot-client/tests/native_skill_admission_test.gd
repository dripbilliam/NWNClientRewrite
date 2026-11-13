extends SceneTree
const Skill=preload("res://systems/native_data/skill_admission.gd")
var checks:=0
var failures:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:
	var args:=OS.get_cmdline_user_args()
	var report:=""
	var oracle:=""
	for arg in args:
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
		if arg.begins_with("--oracle="):oracle=arg.trim_prefix("--oracle=")
	var observations:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle))
	check(observations.get("success")==true and observations.get("getterCases")==1320,"original oracle complete")
	for row in observations.get("getter",[]):
		var view={"version":1,"source":Skill.SOURCE,"mask":row.mask,"knownMask":4294967295,"playerUpdateSeen":true,"inventoryUpdateSeen":false}
		var result:Dictionary=Skill.query(view,row.skill,row.count,row.override)
		check(result.available and result.value==(int(row.result)!=0) and result.nativeResult==row.result,"unchanged getter "+str(row))
	var view={"version":1,"source":Skill.SOURCE,"mask":8192,"knownMask":8192,"playerUpdateSeen":false,"inventoryUpdateSeen":true}
	check(Skill.query(view,13,14).value==true and Skill.query(view,13,14).nativeResult==null,"set bit usable with unknown override, numeric return unknown")
	check(not Skill.query(view,0,14,0).available,"unknown bit not false")
	view.mask=0;view.knownMask=4294967295
	check(not Skill.query(view,13,14).available,"clear bit with unknown override unavailable")
	check(Skill.query(view,13,14,0).value==false,"known clear and known no override")
	check(Skill.query({},13,14,-1).nativeResult==1,"signed nonzero native override")
	check(Skill.query({},255,255).nativeResult==0,"out of active count before missing state")
	check(not Skill.query({},13,null,1).available,"missing active count not zero")
	check(not Skill.query(view,13,14,2147483648).available,"override INT32 width")
	check(not Skill.query(view,65536,255,1).available,"skill WORD width")
	check(not Skill.query(view,0,256,1).available,"rules count BYTE width")
	check(not Skill.valid({"version":1,"source":Skill.SOURCE,"mask":2,"knownMask":1,"playerUpdateSeen":false,"inventoryUpdateSeen":true}),"no invented bits outside known mask")
	view.override=0;view.overrideSource=Skill.OVERRIDE_SOURCE
	check(Skill.override_value(view)==0,"validated receivedzero override available")
	view.overrideSource="guess"
	check(Skill.override_value(view)==null,"unverified override provenance unavailable")
	view.overrideSource=Skill.OVERRIDE_SOURCE;view.override=1
	check(Skill.override_value(view)==null,"received true never implies override1")
	view.erase("override");view.erase("overrideSource")
	var start:=Time.get_ticks_usec()
	for i in range(10000):Skill.query(view,i%14,14,0)
	var elapsed:=Time.get_ticks_usec()-start
	var data={"success":failures.is_empty(),"checks":checks,"failures":failures,"query10000Usec":elapsed,"scope":"Isolated native helper only; no World publication, source-owner integration, pixels or server validation."}
	if not report.is_empty():
		var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t")+"\n");file.close()
	print(JSON.stringify(data));quit(0 if failures.is_empty() else 1)
