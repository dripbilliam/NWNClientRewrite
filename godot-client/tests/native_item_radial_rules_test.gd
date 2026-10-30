extends SceneTree
const Policy=preload("res://systems/native_data/item_radial.gd")
class Text:
	extends RefCounted
	func raw(value: Dictionary) -> String: return "#"+str(value.strRef)
class Rules:
	extends RefCounted
	var text:=Text.new()
	var options: Dictionary={}
	func row(table: String,id: int) -> Dictionary:
		match table:
			"baseitems": return {} if options.get("missingBase",false) else {"Stacking":options.get("stacking",1)}
			"iprp_spells": return {"SpellIndex":100+id,"Name":10000+id}
			"spells":
				if options.get("missingSpells",[]).any(func(value):return int(value)==id) or id not in range(100,116) and id not in range(201,209): return {}
				var result:={"Name":id,"IconResRef":"" if "icon"+str(id) in options.get("missingIcons",[]) else "icon"+str(id)}
				if id==100:
					for index in int(options.get("variants",0)): result["SubRadSpell"+str(index+1)]=201+index
				return result
		return {}
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func normalized(entries: Array) -> Array:
	var result: Array=[]
	for value in entries: result.append({"slot":value.slot,"kind":value.action,"icon":str(value.icon).to_upper(),"uses":value.get("uses"),"label":value.label,"payload":value.payload,"disabled":value.disabled})
	return result
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var output:=str(args.get("report","")); var input:=str(args.get("oracle",""))
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(input)); var rules:=Rules.new(); var policy:=Policy.new(); policy.rules=rules
	check(oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Original instruction item-power oracle identity")
	for group in ["root","pages","variants"]:
		for source in oracle[group]:
			var options: Dictionary=source["case"]; rules.options=options; policy.warnings.clear()
			var item:={"baseItem":options.get("baseItem",50),"properties":[],"propertyUses":[]}
			for index in int(options.get("count",1)): item.properties.append({"type":15,"subtype":index,"costValue":options.get("cost",1),"remaining":options.get("remaining",1)})
			if options.has("properties"): item.properties=options.properties.duplicate(true)
			for index in 8: item.propertyUses.append(int(options.get("cachedUses",33))+index)
			var entries: Array=policy.powers(item,bool(options.get("assignment",false)),bool(options.get("actor",true)) and bool(options.get("learn",false))) if group=="root" else policy.page(item,int(options.start),bool(options.get("assignment",false))) if group=="pages" else policy.variants(item,int(options.index),bool(options.get("assignment",false)))
			var expected: Array=source.entries.duplicate(true)
			for value in expected: value.icon=str(value.icon).to_upper()
			check(JSON.parse_string(JSON.stringify(normalized(entries)))==expected,"Original item "+group+" "+str(options)+" got "+str(normalized(entries))+" expected "+str(expected))
			if group=="root": check(policy.warnings==source.warnings,"Original stackable-use warning "+str(options))
	if args.has("context"):
		var contexts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(args.context)))
		check(contexts.target==oracle.binarySha256,"Original context and power observations use the same shipped binary")
		for source in contexts.cases:
			var ctx: Dictionary=source.context; rules.options={}
			var result:=policy.root({"baseItem":50,"canUse":ctx.canUse,"properties":[]},ctx)
			result.sort_custom(func(a,b):return int(a.slot)<int(b.slot))
			var actual: Array=[]; var expected: Array=[]
			for value in result: actual.append({"slot":value.slot,"icon":value.icon,"label":value.label,"action":value.action,"payload":value.payload,"disabled":value.disabled})
			for value in source.entries: expected.append({"slot":value.slot,"icon":value.icon,"label":"#"+str(int(value.ref)),"action":value.action,"payload":value.payload,"disabled":value.disabled})
			check(JSON.parse_string(JSON.stringify(actual))==expected,"Original item context "+str(ctx)+" got "+str(actual)+" expected "+str(expected))
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Native item-use root/page/family projection against unchanged original instruction observations; full context roots, GUI and server actions are checked separately."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
