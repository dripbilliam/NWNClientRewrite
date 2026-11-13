extends SceneTree
const Plan=preload("res://systems/native_data/level_up_post_recommendation.gd")
const Domains=preload("res://systems/native_data/creation_domains_state.gd")
const School=preload("res://systems/native_data/creation_school_state.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var report:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):report=argument.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var received: Dictionary={"classes":[{"id":0,"level":1}],"fieldD4":2};var original:=received.duplicate(true)
	var tables: Dictionary={"classes":{"orderedRows":[{"Package":"8"},{"Package":"3"}]}}
	for stage in ["domains","school"]:
		var pending: Dictionary=Plan.lookup(stage,received,0,tables)
		check(not pending.ready and pending.pending and pending.dependencies==["packages"],"Real action requests initially absent Packages: "+stage)
		check(pending.resetBeforeLoad==(stage=="domains"),"Original pre-load GUI reset is Domain-only: "+stage)
		tables.packages={};var absent: Dictionary=Plan.lookup(stage,received,0,tables)
		check(absent.ready and not absent.loaded and not absent.apply and absent.resetBeforeLoad==(stage=="domains"),"Load failure does not fabricate a recommendation: "+stage)
		tables.erase("packages")
	var rows: Array=[]
	for index in 9:rows.append({"Domain1":"0","Domain2":"1","School":"0"})
	rows[2]={"Domain1":"5","Domain2":"7","School":"6"};rows[3]={"Domain1":"2","Domain2":"4","School":"1"}
	tables.packages={"orderedRows":rows,"defaultValue":"4tail"}
	var domains: Dictionary=Plan.lookup("domains",received,0,tables);var school: Dictionary=Plan.lookup("school",received,0,tables)
	check(domains.ready and domains.apply and domains.nativeValues==[5,7] and domains.context.source=="received" and domains.context.packageId==2,"Slot0 uses copied package, preserving Domain1/2 order")
	check(school.ready and school.nativeValues==[6],"Slot0 school follows copied package rather than class default")
	domains=Plan.lookup("domains",received,1,tables);school=Plan.lookup("school",received,1,tables)
	check(domains.nativeValues==[2,4] and school.nativeValues==[1] and domains.context.source=="native_class" and domains.context.packageId==3,"Later/new class uses native class Package, never copied slot0")
	tables.classes.orderedRows[1].Package="****";school=Plan.lookup("school",received,1,tables)
	check(school.context.packageId==-1 and school.nativeValues==[4] and not school.reads[0].lookupReturned,"Failed class Package retains native -1; ignored Package INT BOOL consumes table DEFAULT")
	tables.classes.orderedRows[1].Package="3"
	rows[2]={"Domain1":"****","Domain2":"","School":"****"};domains=Plan.lookup("domains",received,0,tables);school=Plan.lookup("school",received,0,tables)
	check(domains.nativeValues==[0,0] and domains.reads.all(func(value):return not value.lookupReturned),"Empty and missing-token Domain INT reads write zero despite BOOL=false")
	check(school.nativeValues==[0] and not school.reads[0].lookupReturned and Plan.selection("school",school.nativeValues).selected==0,"Missing-token School deliberately selects General0 without a fallback default")
	check(not Plan.selection("domains",domains.nativeValues,[0,1,2]).ready,"Duplicate native Domain outputs are explicit unavailable, never filler")
	rows[2]={"Domain1":"0x5","Domain2":"0X7tail","School":"0x8"};domains=Plan.lookup("domains",received,0,tables);school=Plan.lookup("school",received,0,tables)
	check(domains.nativeValues==[5,7] and school.nativeValues==[8],"Reached native hexadecimal INT scans retain exact values and trailing scan semantics")
	rows[2].School="not-a-number";school=Plan.lookup("school",received,0,tables)
	check(school.nativeValues==[0] and school.reads[0].lookupReturned,"Nonempty decimal text uses native atoi0 with BOOL=true")
	var bad_row: Dictionary=received.duplicate(true);bad_row.fieldD4=99;tables.packages.defaultValue="0x8"
	check(Plan.lookup("school",bad_row,0,tables).nativeValues==[0],"Missing-row DEFAULT uses atoi rather than the valid-cell hexadecimal branch")
	rows[2]={"Domain1":"0xG","Domain2":"7","School":"0xG"}
	check(not Plan.lookup("domains",received,0,tables).ready and not Plan.lookup("school",received,0,tables).ready,"Unresolved scan does not borrow a GUI choice or invent a previous native stack value")
	tables.packages={"columns":["School","SCHOOL","Domain1","DOMAIN1","Domain2"],"orderedRows":[{},{},{}],"orderedCells":[[],[],["3","8","4","7","5"]]}
	check(Plan.lookup("school",received,0,tables).nativeValues==[3] and Plan.lookup("domains",received,0,tables).nativeValues==[4,5],"First case-insensitive physical header wins, including duplicate columns")
	tables.packages={"columns":["Other"],"orderedRows":[{},{},{}],"defaultValue":"2after"}
	check(Plan.lookup("school",received,0,tables).nativeValues==[2] and not Plan.lookup("school",received,0,tables).reads[0].lookupReturned,"Missing School header writes atoi(DEFAULT), not retained GUI state")
	for value in [[-1],[9],[300],[null],[1.5],["1"],[],[1,2]]:check(not Plan.selection("school",value).ready,"Unsafe native school is never clamped: "+str(value))
	for value in [[-1,1],[256,1],[1.5,1],["0",1],[1,1],[1,9],[],[1]]:check(not Plan.selection("domains",value,[0,1,2]).ready,"Unsafe/unknown/duplicate domain is never filled: "+str(value))
	check(Plan.selection("domains",[2,0],[0,1,2]).selected==[2,0] and Plan.selection("school",[8]).selected==8,"Valid current physical choice values preserve exact order/index")
	var domain_state:=Domains.new();domain_state.reset({"ready":true,"entries":[{"id":0,"title":100,"description":200},{"id":2,"title":102,"description":202},{"id":5,"title":105,"description":205}]})
	domain_state.select_available(1);var title_before:=domain_state.help_title
	check(not Plan.begin_domains(domain_state) and domain_state.selected_available==1 and domain_state.help_title==title_before,"Recommend with no chosen Domains preserves existing available-row selection/help before load")
	domain_state.add(1);domain_state.add(0);title_before=domain_state.help_title
	check(Plan.begin_domains(domain_state) and domain_state.chosen.is_empty() and domain_state.available_ids==[0,2,5] and domain_state.help_title==title_before,"Begun Domain GUI choices clear and rebuild before Packages with existing help retained")
	var failed_plan: Dictionary={"ready":true,"loaded":false,"apply":false,"nativeValues":[]}
	check(Plan.apply("domains",failed_plan,domain_state).ready and domain_state.chosen.is_empty(),"Package load failure cannot restore cleared Domain choices")
	check(Plan.apply("domains",{"ready":true,"apply":true,"nativeValues":[5,0]},domain_state).ready and domain_state.chosen==[5,0] and domain_state.selected_chosen==0 and domain_state.help_title==105,"Valid Domain callback applies ordered native tabs and first-tab help")
	Plan.begin_domains(domain_state)
	check(not Plan.apply("domains",{"ready":true,"apply":true,"nativeValues":[0,0]},domain_state).ready and domain_state.chosen.is_empty(),"Malformed native pair leaves cleared GUI explicit, without a fabricated second Domain")
	var school_state:=School.new();school_state.reset({"ready":true,"entries":range(9).map(func(id):return {"title":100+id,"description":200+id})});school_state.select_index(6)
	check(Plan.apply("school",failed_plan,school_state).ready and school_state.selected==6 and school_state.help_title==106,"Failed Packages load preserves edited School selection and help")
	check(Plan.apply("school",{"ready":true,"apply":true,"nativeValues":[0]},school_state).ready and school_state.selected==0 and school_state.help_title==100,"Ignored-false INT zero selects actual General tab and help")
	check(not Plan.apply("school",{"ready":true,"apply":true,"nativeValues":[9]},school_state).ready and school_state.selected==0,"Unsafe native School index cannot be clamped or replace current choice")
	check(received==original,"No copied package/class or canonical received field is mutated")
	check(not Plan.lookup("summary",received,0,tables).ready,"Unsupported pane cannot gain a package recommendation callback")
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"runtimeIntegrated":false,"scope":"New pure mode1 Domain/School callback value plan, exact package slot source, ignored INT BOOL/default/empty output, local state reset/preservation/tab/help behavior, native order/index and explicit unsafe-output rejection. No async worker, physical button, server or pixel acceptance."},"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
