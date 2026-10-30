extends SceneTree
const Ui=preload("res://systems/native_gameplay_ui.gd")
const Examine=preload("res://systems/server_examine.gd")
const Properties=preload("res://systems/native_data/item_property_text.gd")
var failures: Array=[]
var checks:=0
class Inventory extends Node:
	func receive(_message: Dictionary) -> void: pass
	func close() -> void: pass
class Assets extends Node:
	var serial:=0
	var requests: Dictionary={}
	var failure:=""
	func request(name: String,_type: int,_decoder: String) -> int:
		serial+=1; requests[serial]=name; return serial
	func close() -> void: requests.clear()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	var ui:=Ui.new(); root.add_child(ui); ui.set_process(false); ui.controlled_id=1; ui.generation=7
	ui.inventory=Inventory.new(); ui.add_child(ui.inventory)
	ui.examine=Examine.new(); root.add_child(ui.examine); ui.examine.setup("")
	ui.assets=Assets.new(); ui.add_child(ui.assets)
	ui.text.overrides={100:"Custom ability",101:"Strength",102:"+2",103:"Once",104:"Base cost",105:"Base parameter",106:"Container",107:"Other target"}
	var def:={"GameStrRef":"100","SubTypeResRef":"customsub","CostTableResRef":"1","Param1ResRef":"0"}
	ui.text.tables={"itempropdef":{"orderedRows":[def]},"iprp_costtable":{"orderedRows":[{}, {"Name":"basecost"},{"Name":"customcost"}]},"iprp_paramtable":{"orderedRows":[{"TableResRef":"baseparam"},{"TableResRef":"customparam"}]},"baseitems":{"orderedRows":[{"Name":"106"}]}}
	ui.text.objects={20:{"item":{"baseItem":0,"name":{"text":"Test item"}}}}
	var property:={"type":0,"subtype":0,"costValue":2,"uses":3,"usable":true}
	var message: Dictionary=JSON.parse_string(JSON.stringify({"kind":"examine","type":"item","targetId":20,"actorId":1,"identified":true,"canUse":false,"description":{"text":"Server description 1.5"},"charges":4,"weight":15,"value":25,"minimumLevel":9,"properties":[property]}))
	var before:=message.duplicate(true)
	ui.present_examine(message)
	check(ui.examine.state.properties[0].rich.text=="Custom ability" and ui.examine.state.warnings.has("Loading item properties…"),"Item description opens immediately while dependent tables load")
	check(ui.examine.state.facts.any(func(row):return row.name=="Charges" and row.rich.text=="4") and ui.examine.state.facts.any(func(row):return row.name=="Weight" and row.rich.text=="1"),"JSON-float charges and converted tenth-pound weight display as whole game values")
	check(ui.examine.state.facts.any(func(row):return row.name=="Value" and row.rich.text=="25") and ui.examine.state.description.text=="Server description 1.5" and message==before,"Formatting preserves received numbers and server-authored decimal prose")
	check(ui.examine.state.facts.any(func(row):return row.name=="Item type" and row.rich.text=="Container") and ui.examine.state.facts.any(func(row):return row.name=="Use" and row.rich.text=="Cannot use") and ui.examine.state.facts.any(func(row):return row.name=="Required level" and row.rich.text=="9"),"Canonical item type and server use/level gates appear in Examine")
	var rev: int=ui.revision; var position: Vector2=ui.examine.position
	var later:=Control.new(); root.add_child(later); later.move_to_front()
	var resources:={"customsub":{"orderedRows":[{"Name":"101","CostTableResRef":"2","Param1ResRef":"1"}]},"customcost":{"orderedRows":[{}, {},{"Name":"102"}]},"customparam":{"orderedRows":[{}, {},{},{"Name":"103"}]},"basecost":{"orderedRows":[{}, {},{"Name":"104"}]},"baseparam":{"orderedRows":[{}, {},{},{"Name":"105"}]}}
	var delivered:=0
	while not ui.assets.requests.is_empty() and delivered<12:
		var id: int=ui.assets.requests.keys()[0]; var name: String=ui.assets.requests[id]; ui.assets.requests.erase(id)
		ui.prepared(id,{"error":"","value":resources[name]}); delivered+=1
	check(ui.examine.state.properties.size()==1 and ui.examine.state.properties[0].rich.text=="Custom ability Strength +2 Once" and ui.examine.state.properties[0].usable,"Subtype overrides select server-defined cost/parameter tables and TLK text")
	check(ui.examine.state.warnings.is_empty() and ui.examine_jobs.is_empty() and ui.examine_pending.is_empty(),"Dependent tables finish without lingering loading state")
	check(ui.revision==rev and ui.examine.position==position and later.get_index()>ui.examine.get_index(),"Background completion preserves menu revision, position and stacking order")
	ui.text.tables.customsub.orderedRows[0].CostTableResRef="0"; ui.text.tables.customsub.orderedRows[0].erase("Param1ResRef")
	check(Properties.project([property],ui.text,1).properties[0].rich.text=="Custom ability Strength Base cost Base parameter","Zero cost override and absent parameter override preserve definition defaults")
	var bad:=property.duplicate(); bad.type=9999
	var mixed:=Properties.project([bad,property],ui.text,1)
	check(mixed.properties.size()==1 and not mixed.warnings.is_empty(),"Unknown property details do not hide independently valid properties")
	ui.text.tables.basecost.orderedRows[2].Name="****"
	check(not Properties.project([property],ui.text,1).properties[0].rich.text.contains("100") and not Properties.project([property],ui.text,1).warnings.is_empty(),"Missing labels remain explicit rather than being interpreted as TLK zero")
	var hidden:=message.duplicate(true); hidden.identified=false; hidden.erase("canUse"); hidden.erase("value"); hidden.erase("minimumLevel")
	ui.present_examine(hidden)
	check(ui.examine.state.properties.is_empty() and not ui.examine.state.facts.any(func(row):return row.name in ["Charges","Use","Value","Required level"]),"Unidentified items cannot expose property or gated facts from canonical state")
	check(ui.examine.state.facts.any(func(row):return row.name=="Identification" and row.rich.text=="Unidentified"),"Unidentified state is visible")
	ui.text.tables.itempropdef.orderedRows[0].SubTypeResRef="late_table"
	ui.present_examine(message); check(not ui.examine_jobs.is_empty(),"New dependent resource request starts")
	var late: int=ui.examine_jobs.keys()[0]
	ui.present_examine({"kind":"examine","type":"placeable","targetId":30,"name":{"text":"Other target"},"description":{"text":"Different description"}})
	ui.prepared(late,{"error":"","value":{"orderedRows":[{"Name":"101"}]}})
	check(ui.examine.state.targetId==30 and ui.examine.state.description.text=="Different description" and ui.examine.state.properties.is_empty(),"Late item tables cannot replace a different examine target")
	check(not ui.examine.refresh_properties([],[],20,rev),"Closed/stale revision refresh is rejected")
	ui.examine.hide(); ui.refresh_examine_properties(); check(not ui.examine.visible,"Background refresh cannot reopen a closed window")
	ui.close(); ui.examine.free(); later.free(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Headless native Examine controls and actual async table completion path; custom subtype/cost/parameter overrides, disclosure gates, stale target/revision/stacking guards. Real original-server visual acceptance queued."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
