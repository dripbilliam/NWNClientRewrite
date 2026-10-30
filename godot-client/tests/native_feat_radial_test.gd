extends SceneTree
const Feats=preload("res://systems/native_data/feat_radial.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
class ProviderRules extends RefCounted:
	var sample: Dictionary
	func feats(_actor: Dictionary) -> Array: return sample.get("owned",[257])+sample.get("bonus",[])
	func row(table: String,id: int) -> Dictionary:
		if id<0: return {}
		if table=="feat":
			if sample.get("missingFeats",[]).any(func(value):return int(value)==id): return {}
			var source: Dictionary=sample.get("feats",{}).get(str(id),{})
			return {"FEAT":source.get("nameRef",id+1000),"ICON":source.get("icon",""),"SUCCESSOR":source.get("successor",-1),"SpellId":source.get("spellId",sample.get("spellId",10)),"TargetSelf":source.get("targetSelf",sample.get("targetSelf",0)),"UsesPerDay":1}
		if table=="spells":
			if sample.get("missingSpells",[]).any(func(value):return int(value)==id): return {}
			var value: Dictionary={"Name":id+2000,"IconResRef":"spell"+str(id),"FeatID":int(sample.get("childFeats",{}).get(str(id),id))<<16}
			var children: Array=sample.get("children",[]) if id==10 else []
			for n in children.size(): value["SubRadSpell"+str(n+1)]=children[n]
			return value
		return {}
class Text extends RefCounted:
	var tables: Dictionary={}
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String,details: Dictionary={}) -> void:
	checks+=1
	if not value and failures.size()<8: failures.append({"label":label,"details":details})
func same(a: Variant,b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for n in a.size():
			if not same(a[n],b[n]): return false
		return true
	if (a is int or a is float) and (b is int or b is float): return float(a)==float(b)
	return a==b
func context(helper,sample: Dictionary) -> Dictionary:
	var provider:=ProviderRules.new(); provider.sample=sample; helper.rules=provider
	var uses: Dictionary={}
	for id in provider.feats({}): uses[str(int(id)&65535)]=sample.get("remaining",5)
	var actor: Dictionary={"id":99,"objectType":5,"replicationRemoved":not sample.get("controlled",true),"playerState":{"feats":sample.get("owned",[257]),"bonusFeats":sample.get("bonus",[]),"featUses":uses}}
	var ctx: Dictionary=helper.context(actor,99 if sample.get("self",true) else int(sample.get("targetId",100)),bool(sample.get("assignment",false)))
	ctx.familiar=sample.get("familiar",{}) if sample.get("familiar")!=null else {}; ctx.defensiveStance=sample.get("defensiveStance",0)
	return ctx
func table_checks(helper) -> void:
	var rules:=Rules.new(); var text:=Text.new(); rules.text=text; helper.rules=rules
	text.tables={"feat":{"orderedRows":[{"FEAT":9999,"Icon":"server_icon","TargetSelf":1,"UsesPerDay":1,"SpellId":0,"SUCCESSOR":-1}]},"spells":{"orderedRows":[{"Name":101,"SubRadSpell1":99,"SubRadSpell2":1},{"Name":102,"IconResRef":"server_variant","FeatID":Feats.signed32((65001<<16)|25),"TargetType":1}]}}
	var actor: Dictionary={"id":7,"objectType":5,"playerState":{"feats":[0],"featUses":{"0":2}}}; var ctx: Dictionary=helper.context(actor,8)
	check(helper.leaf(ctx,0).featId==0,"Feat cell validates a physical row without remapping its ID")
	var children: Array=helper.variants(ctx,0)
	check(children.size()==1 and int(children[0].slot)==1 and int(children[0].featId)==0 and int(children[0].auxiliary)==65001,"Invalid physical spell children leave holes; variants retain parent feat and high WORD")
	check(children[0].disabled and children[0].uses==2,"Parent target-self restriction and received remaining uses gate variants")
	var packed: Dictionary=Feats.binding(int(children[0].featId),int(children[0].auxiliary))
	check(int(packed.intParam)<0 and (int(packed.intParam)&65535)==0 and ((int(packed.intParam)>>16)&65535)==65001,"Variant shortcut serializes one signed INT with the complete auxiliary WORD")
	text.tables.spells.orderedRows[1].FeatID=123<<16
	check(int(helper.variants(ctx,0)[0].auxiliary)==123,"Changing the active server's physical spell table changes the selected variant")
	text.tables.feat.orderedRows[0].TargetSelf=0
	check(not helper.variants(ctx,0)[0].disabled,"Active feat-table target changes are consulted without a base-game cache")
	actor.playerState.featUses["0"]=0
	check(helper.variants(ctx,0)[0].disabled,"A newly received exhausted parent disables its children")
	check(not helper.variants(helper.context(actor,8,true),0)[0].disabled,"Shortcut assignment remains available without current charges")
	text.tables.feat.orderedRows[0].UsesPerDay=256; actor.playerState.featUses.clear()
	check(helper.remaining(ctx,0)==100,"Original UsesPerDay byte truncation preserves the unlimited sentinel")
	text.tables.feat.orderedRows.append({"FEAT":5,"SUCCESSOR":0,"SpellId":-1}); actor.playerState.feats=[0,1]; text.tables.feat.orderedRows[0].SUCCESSOR=1
	check(helper.leaf(helper.context(actor,7),0).featId==1,"Client successor traversal stops at zero rather than visiting feat zero again")
	text.tables.feat.orderedRows[1].SUCCESSOR=1
	check(helper.leaf(helper.context(actor,7),0).is_empty() and helper.errors.size()==1,"Malformed server successor cycles are rejected without hanging the UI")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("fixture") or FileAccess.file_exists(args.report): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); var helper:=Feats.new()
	check(oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Retained feat observations pin the original native binary")
	for kind in ["leaf","variants","selection"]:
		var cases: Array=oracle[kind]
		for n in cases.size():
			var sample: Dictionary=cases[n].case; var ctx:=context(helper,sample); var expected: Variant; var got: Variant
			if kind=="leaf":
				got=helper.leaf(ctx,int(sample.get("packed",257))); expected=cases[n].entries[0].duplicate() if not cases[n].entries.is_empty() else {}; expected.erase("slot")
			elif kind=="variants": got=helper.variants(ctx,257); expected=cases[n].entries
			else: got=helper.select(ctx,int(sample.get("packed",257))); expected=cases[n].calls[0] if not cases[n].calls.is_empty() else {"mode":"none"}
			check(same(got,expected),"Native original feat "+kind+" case "+str(n),{"input":sample,"expected":expected,"actual":got})
	table_checks(helper)
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"cases":{"leaf":oracle.leaf.size(),"variants":oracle.variants.size(),"selection":oracle.selection.size()},"scope":"Retained original native feat leaf, variants and callback observations; active physical table/ownership/use and signed shortcut tests. No original process, server outcome or graphical acceptance."},"  ")); file.close(); quit(0 if failures.is_empty() else 1)
