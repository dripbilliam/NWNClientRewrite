extends RefCounted
# Original235000 resource routing and8e5be0 first/last call order. This detached
# worker input owns neither a catalog nor the creator draft/global CRT RNG.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Generator=preload("res://systems/native_data/name_generation.gd")
const Letters=preload("res://systems/native_data/letter_table.gd")
const FALLBACK=["dwarf","elf","gnome","halfling","halfelf","halforc","human"]
static func unavailable(reason:String)->Dictionary:return {"ready":false,"reason":reason}
static func exact(value:Variant,maximum:int)->bool:return value is int and value>=0 and value<=maximum
static func cell(table:Dictionary,race:int,field:String)->String:
	var result:=Tables.cell(table,race,field)
	#1a73a0 stores a literal missing marker as a zero-length native string.
	return "" if str(result.text)=="****" else str(result.text)
static func route(table_result:Dictionary,race:Variant,kind:Variant,sample:Variant=null)->Dictionary:
	if not exact(race,65535) or not exact(kind,255):return unavailable("Native race WORD/name-kind BYTE is unavailable.")
	var first:="";var second:="";var choice:=false
	if race==65534:first="familiar"
	elif race==65535:first="animal"
	else:
		if table_result.get("status")=="ready" and table_result.get("value") is Dictionary:
			if not table_result.value.get("orderedRows") is Array or not table_result.value.get("columns") is Array:return unavailable("The decoded active racialtypes schema is unavailable.")
			first=cell(table_result.value,race,"NameGenTableA");second=cell(table_result.value,race,"NameGenTableB")
		elif table_result.get("status")!="native-load-failed":return unavailable("The active racialtypes name-table read is unavailable.")
		if first.is_empty() and not second.is_empty():first=second;second=""
		choice=not second.is_empty()
		if choice:
			if not exact(sample,32767):return {"ready":false,"choiceRequired":true,"reason":"The original table-choice RNG sample is unavailable."}
			if int(sample)%2==0:first=second
		if first.is_empty() and race<FALLBACK.size():first=FALLBACK[race]
		if not first.is_empty():
			if kind>2:return {"ready":true,"resource":null,"choiceRequired":choice,"reason":"The original ordinary name kind has no suffix path."}
			first+=["m","f","l"][kind]
	if first.is_empty():return {"ready":true,"resource":null,"choiceRequired":choice,"reason":"The original has no name-table route for this race."}
	return {"ready":true,"resource":first.left(16).to_lower(),"rawResource":first,"choiceRequired":choice}
static func plan(table_result:Dictionary,race:Variant,gender:Variant)->Dictionary:
	if not exact(race,65535) or not exact(gender,255):return unavailable("The selected native race/gender is unavailable.")
	var rows:Array=[];var resources:Dictionary={}
	for kind in [1 if gender==1 else 0,2]:
		var odd:=route(table_result,race,kind,1);var even:=route(table_result,race,kind,0)
		if not odd.ready:return odd
		if not even.ready:return even
		if odd.resource==null or even.resource==null:return unavailable("The original cannot load a name table for this selected race.")
		rows.append({"kind":kind,"choiceRequired":bool(odd.choiceRequired),"odd":odd.resource,"even":even.resource})
		resources[odd.resource]=true;resources[even.resource]=true
	return {"ready":true,"raceId":race,"gender":gender,"rows":rows,"resources":resources.keys(),"provenance":"original235000+8e5be0"}
static func generate_pair(prepared:Dictionary,tables:Dictionary,filter_names:Variant,rng:Callable,maximum_draws:int=100000)->Dictionary:
	if prepared.get("ready")!=true or not prepared.get("rows") is Array or prepared.rows.size()!=2 or not rng.is_valid() or maximum_draws<1:return unavailable("The scoped native name plan/RNG is unavailable.")
	var counter:Dictionary={"draws":0,"failure":""};var output:Array=[];var selected:Array=[]
	var draw:=func()->int:
		if int(counter.draws)>=maximum_draws:counter.failure="The native name-pair RNG budget was exhausted.";return -1
		var value:Variant=rng.call();counter.draws=int(counter.draws)+1
		if not exact(value,32767):counter.failure="The native name RNG sample is unavailable.";return -1
		return int(value)
	for row in prepared.rows:
		if not row is Dictionary or not row.get("choiceRequired") is bool or not row.get("odd") is String or not row.get("even") is String:return unavailable("The detached name plan is malformed.")
		var resource:String=row.odd
		if row.choiceRequired:
			var sample:int=draw.call()
			if not str(counter.failure).is_empty():return unavailable(str(counter.failure))
			if sample%2==0:resource=row.even
		if not tables.get(resource) is Dictionary or not Letters.valid(tables[resource]):return unavailable("The active native letter table is unavailable: "+resource)
		var value:=Generator.new().generate(tables[resource],draw,filter_names,maximum_draws-int(counter.draws))
		if not str(counter.failure).is_empty():return unavailable(str(counter.failure))
		if not value.ready:return value
		output.append(str(value.name));selected.append(resource)
	return {"ready":true,"firstName":output[0],"lastName":output[1],"draws":int(counter.draws),"resources":selected}
