extends SceneTree
const State=preload("res://systems/native_data/creation_domains_state.gd")
const Fixtures=preload("res://tests/native_creation_feat_adapter_test.gd")
const ORACLE_SHA256="050d99f54cd76972b7950d2464ac30fb8e417c2be86470d537f496b9af96fbfe"
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String,detail: Variant=null) -> void:
	checks+=1
	if not value:failures.append({"label":label,"detail":detail})
func ids(value: Array) -> Array:return value.map(func(id):return int(id))
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	check(FileAccess.get_sha256(args.oracle)==ORACLE_SHA256,"Pinned immutable original domain callback corpus")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.rows.size()==288,"Original domain288 cases identify exact binary and declared GUI service boundaries")
	var supplied:={"ready":true,"entries":[],"recommended":[3,0]}
	for id in [0,2,3,5]:supplied.entries.append({"id":id,"title":1000+id,"description":2000+id})
	for at in oracle.rows.size():
		var row: Dictionary=oracle.rows[at];var state:=State.new();state.reset(supplied)
		for step in row.sequence.size():
			var action: Array=row.sequence[step];var id:=int(action[1]);var expected: Dictionary=row.observations[step]
			match action[0]:
				"list":state.select_available(state.available_ids.find(id))
				"add":state.add(state.available_ids.find(id))
				"remove":state.remove(id)
				"chosen":state.select_chosen(id)
			check(state.available_ids==ids(expected.available) and state.chosen==ids(expected.chosen) and state.help_title==int(expected.help["0x228"]) and state.help_description==int(expected.help["0x2d0"]) and state.can_accept()==expected.enabled,"Original physical domain order/selection/help/count "+str([at,step]),{"expected":expected,"available":state.available_ids,"chosen":state.chosen,"help":[state.help_title,state.help_description]})
		if row.finish=="ok" and row.present:check(state.chosen==ids(row.domains),"Original SetDomain1/2 commit physical bytes "+str(at))
		if row.finish=="cancel":check(row.calls.has(["deactivate",3.0 if int(row.mode)==0 else 2.0]) if row.present else row.calls.has(["deactivate",0.0]),"Original domain Cancel branch and return code "+str(at))
	var state:=State.new();state.reset(supplied);check(state.help_title==6011 and state.help_description==5985 and not state.can_accept(),"Fresh original domain owner uses introductory help and disabled OK")
	check(state.recommend() and state.chosen==[3,0] and state.selected_chosen==0 and state.help_title==1003,"Recommended preserves active package slot order and focuses the first choice")
	var snapshot:=JSON.stringify(state.chosen);supplied.recommended[0]=99;supplied.entries.clear();check(state.chosen==[3,0] and state.entry(3).title==1003 and JSON.stringify(state.chosen)==snapshot,"Borrowed model mutation cannot alter the temporary domain owner")
	check(not state.add(-1) and not state.remove(9) and state.chosen==[3,0],"Invalid or third choices do not alter the temporary selection")
	var absent:=State.new();absent.reset({"ready":true,"entries":state.model.entries,"recommended":[0,0]});check(not absent.can_recommend() and not absent.recommend(),"An invalid duplicate package recommendation is unavailable rather than a fabricated pair")
	absent.reset({"ready":true,"entries":state.model.entries,"recommended":[99,0]});check(not absent.can_recommend() and not absent.recommend(),"Unknown recommended domains remain unavailable")
	var rules=Fixtures.fixture();rules.tables.domains={"orderedRows":[{"Name":"100","Description":"200","GrantedFeat":"7","Icon":"SERVER_DOMAIN"},{"Name":"0","Label":"NotAChoice"},{"Name":"****","Label":"NotAChoice"},{"Name":"103"}]};rules.tables.packages={"orderedRows":[{"Domain1":"3","Domain2":"0"}]}
	var model:=State.choices(rules,null)
	check(model.ready and model.entries.map(func(item):return item.id)==[0,3] and model.entries[0].icon=="server_domain" and model.entries[1].description==4294967295 and model.entries[1].grantedFeat==65535,"Active loader Name validity, source order, constructor sentinels and icon resref conversion; Label is not a filter",model)
	check(model.recommended==[3,0],"Package recommendations use current physical Domain1/2 cells")
	rules.tables.domains.orderedRows[0].Name="0xGG";check(not State.choices(rules,null).ready,"Undefined native integer conversion stays unavailable")
	rules.tables.erase("domains");check(not State.choices(rules,null).ready,"Missing active domain data is explicit")
	rules.tables.domains={"orderedRows":[]}
	for id in 260:rules.tables.domains.orderedRows.append({"Name":str(100+id)})
	check(State.choices(rules,null).entries.size()==4,"Original domain row count is a byte, not an unlimited row list")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalCases":288,"scope":"Native temporary domain policy vs unchanged original add/remove/help/OK/Cancel callbacks with explicit GUI/list service boundaries; active metadata/constructor sentinel and detached model tests. No source-control, graphical, draft/controller, server or full table-loader acceptance.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
