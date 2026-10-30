extends RefCounted
# Original local row70cd20 imports CNWCCreatureStats7f7e20. Pregen membership
# comes from column1 of the active Pregen.2DA in705f10, not an installed-file flag.
const Stats=preload("res://systems/native_data/pregame_skills.gd")
static func project(document: Dictionary) -> Dictionary:
	var root: Dictionary=document.root; var types: Dictionary=document.field_types.get(0,{})
	var result:={"native_only":true,"firstName":{},"lastName":{},"classes":Stats.source(document).classes,"portrait":65535,"portraitRef":""}
	result.isDM=types.get("IsDM")==0 and int(root.get("IsDM",0))!=0
	for pair in [["FirstName","firstName"],["LastName","lastName"]]:
		if types.get(pair[0])==12: result[pair[1]]=root[pair[0]].duplicate(true)
	if types.get("PortraitId")==2: result.portrait=int(root.PortraitId)&65535
	if int(result.portrait)>=65534 and types.get("Portrait")==11: result.portraitRef=str(root.Portrait).to_lower()
	return result
static func pregenerated(stem: String,table: Dictionary) -> bool:
	if not str(table.get("error","")).is_empty(): return false
	for row in table.get("orderedCells",[]):
		if row.size()>1 and str(row[1])==stem: return true
	return false
static func ordinal(stem: String) -> int:
	var start:=stem.length()
	while start>0 and stem.unicode_at(start-1)>=48 and stem.unicode_at(start-1)<=57: start-=1
	return int(stem.substr(start)) if start<stem.length() else 0
