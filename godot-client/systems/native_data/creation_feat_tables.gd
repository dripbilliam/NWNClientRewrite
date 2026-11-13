extends RefCounted
# CNWFeat2a1180 + LoadFeatInfo2a8800. Keep constructor defaults separate
# from failed C2DA1a7010 output: conditional writes retain the former, while
# unconditional writes consume the latter. These are physical, active rows.
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const Integers=preload("res://systems/native_data/ruleset_cache.gd")
const BYTE_FIELDS=["MinAttackBonus","MinSTR","MinDEX","MinINT","MinWIS","MinCON","MinCHA","MinSpellLvl"]
const CONDITIONAL={"PreReqFeat1":65535,"PreReqFeat2":65535,"REQSKILL":65535,"ReqSkillMinRanks":0,"REQSKILL2":65535,"ReqSkillMinRanks2":0,"SUCCESSOR":-1,"SpellId":-1,"UsesPerDay":0,"TargetSelf":0,"MinLevel":0,"MinLevelClass":255,"MaxLevel":0,"MinFortSave":0,"PreReqEpic":0,"ReqAction":1}
const WORD_FIELDS=["PreReqFeat1","PreReqFeat2","REQSKILL","ReqSkillMinRanks","REQSKILL2","ReqSkillMinRanks2"]
const CONDITIONAL_BYTES=["UsesPerDay","MinLevel","MinLevelClass","MaxLevel","MinFortSave"]
static func columns(table: Dictionary) -> Dictionary:
	var result:={"_prepared":true}
	for at in table.get("columns",[]).size():
		var key:=str(table.columns[at]).to_lower()
		if not result.has(key):result[key]=at
	return result
static func cell(table: Dictionary,index: int,key: String,lookup: Dictionary={}) -> Dictionary:
	var rows: Array=table.get("orderedRows",[])
	var headers: Array=table.get("columns",[]);var column:=-1
	if lookup.has("_prepared"):column=int(lookup.get(key.to_lower(),-1))
	else:
		for at in headers.size():
			if str(headers[at]).to_lower()==key.to_lower():column=at;break
	if index<0 or index>=rows.size() or not headers.is_empty() and column<0:
		return {"found":false,"text":str(table.get("defaultValue",""))}
	var physical: Array=table.get("orderedCells",[])
	if column>=0 and index<physical.size() and column<physical[index].size():return {"found":true,"text":str(physical[index][column])}
	var raw: Variant=Game.cell(rows[index],key)
	return {"found":raw!=null,"text":str(raw) if raw!=null else str(table.get("defaultValue",""))}
static func integer(table: Dictionary,index: int,key: String,lookup: Dictionary={}) -> Dictionary:
	var source:=cell(table,index,key,lookup);var value: String=source.text
	if not source.found:return {"ready":true,"ok":false,"value":Integers.atoi(value)}
	if value in ["","****"]:return {"ready":true,"ok":false,"value":0}
	if value.length()>2 and value.left(2).to_lower()=="0x":
		# A failed sscanf leaves the caller's previous stack value in place.
		# Do not turn malformed hex/CRT overflow into an invented feat rule.
		var digits:="";var at:=2
		while at<value.length() and value[at].to_lower() in "0123456789abcdef":digits+=value[at];at+=1
		if digits.is_empty() or digits.length()>8:return {"ready":false,"ok":false,"reason":"Unresolved original hexadecimal conversion."}
		var hex_value:=digits.hex_to_int()&0xffffffff
		return {"ready":true,"ok":true,"value":hex_value-4294967296 if hex_value&0x80000000 else hex_value}
	return {"ready":true,"ok":true,"value":Integers.atoi(value)}
static func definition(table: Dictionary,index: int,lookup: Dictionary={}) -> Dictionary:
	var name:=integer(table,index,"Feat",lookup)
	if not name.ready:return name
	if not name.ok:return {"ready":true,"id":index,"valid":false}
	var result:={"ready":true,"id":index,"valid":true,"FEAT":int(name.value),"OrReqFeats":[65535,65535,65535,65535,65535]}
	for key in ["Description","Category","MaxCR","AllClassesCanUse","HostileFeat","GainMultiple"]+BYTE_FIELDS:
		var read:=integer(table,index,key,lookup)
		if not read.ready:return read
		result[key]=int(read.value)&255 if key in BYTE_FIELDS else int(read.value)
		if key=="GainMultiple":result[key]=int(int(read.value)==1)
	for key in CONDITIONAL:
		var read:=integer(table,index,str(key),lookup)
		if not read.ready:return read
		var value: int=int(read.value) if read.ok else int(CONDITIONAL[key])
		if key in WORD_FIELDS:value&=65535
		elif key in CONDITIONAL_BYTES:value&=255
		elif key in ["PreReqEpic","ReqAction"]:value=int(value!=0)
		result[key]=value
	for at in 5:
		var read:=integer(table,index,"OrReqFeat"+str(at),lookup)
		if not read.ready:return read
		if read.ok:result.OrReqFeats[at]=int(read.value)&65535
	var master:=integer(table,index,"MASTERFEAT",lookup)
	if not master.ready:return master
	result.MASTERFEAT=int(master.value)&255 if master.ok and int(master.value)>=0 else 255
	var icon:=cell(table,index,"Icon",lookup);result.Icon=str(icon.text).to_lower() if icon.found and str(icon.text)!="****" else ""
	return result
static func decode(table: Dictionary) -> Dictionary:
	var result: Array=[];var lookup:=columns(table)
	for id in (table.get("orderedRows",[]).size()&65535):
		var feat:=definition(table,id,lookup)
		if not feat.ready:return {"ready":false,"reason":str(feat.get("reason","Native feat metadata is unresolved.")),"featId":id,"definitions":[]}
		result.append(feat)
	return {"ready":true,"definitions":result}
static func class_records(table: Dictionary,definitions: Array) -> Dictionary:
	var rows: Array=table.get("orderedRows",[]);var count:=rows.size()&65535;var result: Array=[];var cursor:=0;var lookup:=columns(table)
	while cursor<count:
		var record: Dictionary={}
		for pair in [["FeatIndex","id",65535],["GrantedOnLevel","level",255],["List","List",255]]:
			var read:=integer(table,cursor,str(pair[0]),lookup)
			if not read.ready:return {"ready":false,"reason":str(read.reason),"records":[]}
			record[pair[1]]=int(read.value)&int(pair[2])
		var id: int=record.id
		if id>=definitions.size() or not definitions[id].valid:count-=1
		else:
			if int(record.List) not in [0,1,2,3]:return {"ready":false,"reason":"Class feat List leaves original classification flags undefined.","records":[]}
			result.append(record)
		cursor+=1
	# The original shrinks its loop bound without compacting all storage. Never
	# manufacture a record from an uninitialized destination slot.
	if result.size()<count:return {"ready":false,"reason":"Class feat table exposes undefined original loader storage.","records":[]}
	return {"ready":true,"records":result.slice(0,count)}
