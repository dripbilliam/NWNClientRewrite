extends SceneTree
const Models=preload("res://systems/native_data/level_up_child_models.gd")
const Domains=preload("res://systems/native_data/creation_domains_state.gd")
const School=preload("res://systems/native_data/creation_school_state.gd")
const Associate=preload("res://systems/native_data/creation_associate_state.gd")
class Text extends RefCounted:
	func raw(value: Dictionary) -> String:return "Server "+str(int(value.strRef))
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var text:=Text.new();var tables:={"domains":{"orderedRows":[{"Name":"101","Description":"201","GrantedFeat":"43","Icon":"server_domain0"},{"Name":"0"},{"Name":"102","Description":"202","GrantedFeat":"77","Icon":"server_domain2"}]},"packages":{"orderedRows":[{"Domain1":"2","Domain2":"0","School":"5"}]},"spellschools":{"orderedRows":range(9).map(func(id):return {"StringRef":str(400+id),"Description":str(500+id)})},"classes":{"orderedRows":[{"Arcane":"2"}]},"hen_companion":{"orderedRows":[{"STRREF":"600","BASERESREF":"serverwolf","DESCRIPTION":"700"},{"STRREF":"601","BASERESREF":"serverbear","DESCRIPTION":"701"}]}}
	var received:={"classes":[{"id":0,"level":20}],"fieldD4":0,"fieldE34":1,"fieldE48":"Copied familiar","fieldE30":0,"fieldE38":"Copied companion"}
	var before:=received.duplicate(true);var active_before:=tables.duplicate(true)
	var model:=Models.domains(received,tables,text,0);check(model.ready and model.entries.map(func(row):return int(row.id))==[0,2] and model.recommended==[2,0],"Mode1 slot0 domain rows/grants/recommendation use active physical IDs and copied Package")
	var state:=Domains.new();state.reset(model);check(state.recommend() and state.chosen==[2,0] and state.entry(2).grantedFeat==77,"Shared original domain list policy consumes mode1 model without first-level draft")
	check(state.entry(2).name=="Server 102" and state.entry(2).icon=="server_domain2","Active custom domain names/icons remain owned by the server tables/TLK")
	var missing:=received.duplicate(true);missing.erase("fieldD4");model=Models.domains(missing,tables,text,0)
	check(model.ready and not model.recommendationReady and model.recommended.is_empty(),"Unknown copied Package disables domain Recommended without selecting stock/default row0")
	model=Models.school(received,tables,0);var school:=School.new();school.reset(model)
	check(model.ready and model.entries.size()==9 and model.recommended==5 and school.recommend() and school.selected==5,"Original nine school tabs use active metadata and copied mode1 Package recommendation")
	model=Models.school(missing,tables,0);check(model.ready and not model.recommendationReady and model.recommended==null,"Unknown Package does not invent a General recommendation")
	missing.fieldD4=4294967295;check(not Models.school(missing,tables,0).recommendationReady,"Out-of-range modern DWORD Package does not alias physical row0")
	model=Models.associate(received,0,tables,text);var associate:=Associate.new();var view:=associate.configure(model.choices,model.storedType,model.name)
	check(model.ready and model.classLevel==21 and model.table=="hen_companion" and model.field=="familiar" and model.storedType==1 and model.name=="Copied familiar","Mode1 associate preserves exact Arcane==1 table versus nonzero storage distinction and new current-class level")
	check(view.ready and view.physicalId==1 and view.preview.resource=="serverbear21" and associate.commit().name=="Copied familiar","Original associate state uses copied type/name and current-level UTC reference without generating an actor")
	missing=received.duplicate(true);missing.erase("fieldE48");check(not Models.associate(missing,0,tables,text).ready,"Missing copied associate name remains pending")
	var replaced:=tables.duplicate(true);replaced.classes.orderedRows[0].Arcane="0";model=Models.associate(received,0,replaced,text)
	check(model.ready and model.field=="companion" and model.storedType==0 and model.name=="Copied companion","Active nonarcane class selects its exact received companion fields")
	check(received==before and tables==active_before,"Mode1 child adapters never write canonical received state or shared active tables")
	var multiclass:=tables.duplicate(true);multiclass.classes.orderedRows.append({"Package":"1"});multiclass.packages.orderedRows.append({"Domain1":"0","Domain2":"2","School":"7"})
	model=Models.domains(received,multiclass,text,1);check(model.ready and model.recommended==[0,2] and Models.school(received,multiclass,1).recommended==7,"A newly appended mode1 class uses its active classes.Package rather than received slot0 Package")
	multiclass.classes.orderedRows[1].erase("Package");check(not Models.school(received,multiclass,1).recommendationReady,"Missing later-class Package never borrows copied slot0/first-level recommendation")
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"scope":"Staged mode1 Domain/School/Associate active-table models and existing original list policies; no actual child controls/UTC/name workers, level-up entry/commit or server/pixel acceptance."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
