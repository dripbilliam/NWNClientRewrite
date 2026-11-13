extends SceneTree
const Ability=preload("res://systems/native_data/ability_radial.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Feats=preload("res://systems/native_data/feat_radial.gd")
const Desktop=preload("res://systems/native_game_desktop.gd") # Compile the actual integration too.
class Text extends RefCounted:
	var tables: Dictionary={}
	func raw(value: Dictionary) -> String: return str(value.get("strRef",""))
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok and failures.size()<12: failures.append(label); print("FAIL: ",label)
func same(a: Variant,b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for index in a.size():
			if not same(a[index],b[index]): return false
		return true
	return float(a)==float(b) if (a is int or a is float) and (b is int or b is float) else a==b
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("fixture") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); var text:=Text.new(); var rules:=Rules.new(); rules.text=text; var feats:=Feats.new(); feats.rules=rules; var helper:=Ability.new(); helper.rules=rules; helper.feats=feats
	check(fixture.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Reference is pinned to the inspected original")
	for index in fixture.cases.size():
		var sample: Dictionary=fixture.cases[index]; text.tables=sample.tables; var ctx:=feats.context(sample.actor,99)
		check(same(helper.descriptors(ctx),sample.descriptors),"Class branch grouping/normal+bonus ownership "+str(index))
		for page in sample.pages: check(same(helper.class_page(ctx,int(page.index),int(page.start)),page.expected),"Physical class/domain slots, successors, continuation "+str(index)+"/"+str(page.index)+"/"+str(page.start))
		for page in sample.innate: check(same(helper.innate_page(sample.actor,int(page.start)),page.expected),"Innate duplicate cursor, invalid slot holes, counts and continuation "+str(index)+"/"+str(page.start))
	check(helper.errors.is_empty(),"Valid active server tables produce no hierarchy errors")
	var sample: Dictionary=fixture.cases[1]; text.tables=sample.tables; var ctx:=feats.context(sample.actor,99); var original:=helper.class_page(ctx,0)
	var table:=helper.class_table(sample.actor,0); var saved: Array=text.tables[table].orderedRows.duplicate(true); text.tables[table].orderedRows=[]
	check(helper.class_page(ctx,0)!=original,"Replacing an active server class table changes menu structure")
	text.tables[table].orderedRows=saved
	var source: Array=sample.actor.playerState.feats.duplicate(); sample.actor.playerState.feats=[]
	check(helper.class_page(feats.context(sample.actor,99),0).all(func(row):return row.get("domain",false) and row.disabled),"Unowned class feats disappear; castable domain slots retain exhausted state")
	sample.actor.playerState.feats=source
	var desktop:=Desktop.new(); desktop.rules=rules; desktop.actor_id=99; desktop.objects={99:{"id":99,"objectType":5},100:{"id":100,"objectType":5},101:{"id":101,"objectType":10}}
	text.tables.spells={"orderedRows":[{"Name":100,"TargetType":1},{"Name":101,"TargetType":2},{"Name":102,"TargetType":4},{"Name":103,"TargetType":16}]}
	for target in [99,100,-1,101]:
		desktop.radial_target=target
		for spell in 4: check(desktop.radial_spell_allowed(spell)==(spell==[99,100,-1,101].find(target)),"Native self/other/ground/door target bits remain distinct "+str(target)+"/"+str(spell))
	desktop.radial_target=99
	check(desktop.spell_radial({"type":44,"intParam":0},[],0,0).disabled,"Spent innate spell is visible and disabled")
	desktop.pending_shortcuts={"index":0}
	check(not desktop.spell_radial({"type":44,"intParam":1},[],0,0).disabled,"Shortcut assignment permits an exhausted power without casting it")
	desktop.free()
	var output:=FileAccess.open(args.report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Native-binary-derived legacy oracle versus Godot class/domain/innate decisions for custom tables and multiclass ownership. Desktop integration compiled; graphical and authoritative actions require separate tests."},"  ")); output.close(); quit(0 if failures.is_empty() else 1)
func _initialize() -> void: call_deferred("run")
