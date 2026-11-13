extends "res://tests/native_creation_spells_state_test.gd"
const Recommendations=preload("res://systems/native_data/creation_spell_recommendations.gd")
const Plan=preload("res://systems/native_data/creation_spell_recommendation_plan.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
class RulesFixture extends RefCounted:
	var tables: Dictionary={}
	var draft: Dictionary={"classId":0,"packageId":0}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var state:=State.new();var source:=fixture();var plan:={"ready":true,"helperInvoked":true,"loaded":true,"restricted":true,"preferences":[3],"opposition":null}
	state.configure(source);state.add(1);var result:=Recommendations.apply(state,plan)
	check(result.ready and state.known[0]==[0] and state.known[1]==[3,2,1] and state.remaining==2 and state.selected_level==1 and state.can_accept(),"Recommended restores the original baseline, applies ordered preferences then fills the available list in source order",state.view())
	check(result.preferenceCalls==[["learn",3]] and result.greedyCalls==[["learn",2],["learn",1]],"Preference-book order is distinct from the descending-level GUI fallback mutation order",result)
	result.view.known.clear();check(state.known[1]==[3,2,1],"Recommended returns a detached native view")
	plan.loaded=false;result=Recommendations.apply(state,plan)
	check(result.ready and state.known[0]==[0] and state.known[1].is_empty() and state.remaining==0 and state.selected_level==0 and state.can_accept(),"An actual failed preference table returns native zero helper budget, without inventing fallback selections")
	result=Recommendations.apply(state,{"ready":true,"helperInvoked":false})
	check(result.ready and state.known[1]==[2,1,3] and state.remaining==2 and state.can_accept(),"A failed package preference lookup preserves reset budget and uses original ordered fallback")
	state.configure(fixture(false));plan.loaded=true;result=Recommendations.apply(state,plan)
	check(result.ready and state.known[0]==[0] and state.known[1]==[3] and state.selected_level==1 and state.remaining==0 and state.can_accept(),"Non-memorizing recommendation combines per-level preference capacity with the missing cantrip fallback",state.view())
	var before:=state.known.duplicate(true);check(not Recommendations.apply(state,{"ready":false}).ready and state.known==before,"An unavailable recommendation plan does not fabricate decisions or erase choices")
	var rules:=RulesFixture.new();result=Plan.compose(rules,source)
	check(not result.ready and result.dependencies==["packages"],"Unloaded active Packages remain an explicit dependency")
	rules.tables.packages={};result=Plan.compose(rules,source);check(result.ready and not result.helperInvoked,"A published failed Package load takes the original lookup-failure branch")
	rules.tables.packages={"orderedRows":[{}]};result=Plan.compose(rules,source);check(result.ready and not result.helperInvoked,"Missing SpellPref2DA does not invent a default preference resource")
	rules.tables.packages.orderedRows[0].SpellPref2DA="SERVER_SPELL_PLAN_LONG";result=Plan.compose(rules,source)
	var name:="server_spell_pla";check(not result.ready and result.dependencies==[name],"Preference resource identity preserves original16-byte case-normalized width",result)
	rules.tables[name]={"orderedRows":[{"SpellIndex":"3"},{"SpellIndex":"****"},{"SpellIndex":"-1"}]};rules.tables.classes={"orderedRows":[{"SpellbookRestricted":"1"}]};result=Plan.compose(rules,source)
	check(result.ready and result.helperInvoked and result.loaded and result.preferences==[3,null,-1] and result.restricted,"Active physical preference conversions preserve successful integers and failed-cell nulls",result)
	var parser:=Parser.new();rules.tables[name]=parser.parse_reference("2DA V2.0\nSpellIndex spellindex\n99 2 3\n");result=Plan.compose(rules,source)
	check(result.ready and result.preferences==[2],"Case-insensitive duplicate preference columns use the first physical column")
	rules.tables[name]={};result=Plan.compose(rules,source);check(result.ready and result.helperInvoked and not result.loaded and result.preferences.is_empty(),"Missing resource content remains an actual failed load rather than an unloaded or zero-row success")
	rules.tables[name]={"orderedRows":[]};result=Plan.compose(rules,source);check(result.ready and result.loaded and result.preferences.is_empty(),"A parsed zero-row preference table remains a successful native load")
	source.school=1;result=Plan.compose(rules,source);check(not result.ready and result.dependencies==["spellschools"],"Memorizing preference opposition requires its current active table")
	rules.tables.spellschools={"orderedRows":[{}, {"Opposition":"2"}]};result=Plan.compose(rules,source);check(result.ready and result.opposition==2,"Original helper opposition lookup uses current school even when the view's PickSchool flag is false")
	rules.tables.spellschools.orderedRows[1].Opposition="****";result=Plan.compose(rules,source);check(result.ready and result.opposition==null,"Failed opposition lookup remains explicit rather than inventing school zero")
	rules.tables[name]={"orderedRows":[{"SpellIndex":"0xZZ"}]};result=Plan.compose(rules,source);check(not result.ready,"Unresolved original hexadecimal conversion remains unavailable")
	check(not Plan.compose(rules,{}).ready,"Missing native source flags and school never become default zero values")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Native9c9df0 coordinator composition from static original control flow, existing independently tested State and480-executed7eb630 preference helper, active Package/preference/opposition metadata. No complete original9c9df0 execution, actual creator/controller/view, server or pixel acceptance; copied helper corpus unused by this fixture.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
