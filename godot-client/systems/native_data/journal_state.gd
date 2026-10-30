extends RefCounted
const Order=preload("res://systems/native_data/journal_order.gd")
var records: Dictionary={}
var lists: Array=[[],[]]
var modes: Array[int]=[0,0]
var context:=""
var revision:=0
func reset(identity: String) -> void:
	if identity==context: return
	context=identity; records.clear(); lists=[[],[]]; modes=[0,0]; revision+=1
func observe(data: Dictionary) -> bool:
	var next: Dictionary={}; var changed:=false
	for value in data.get("entries",[]):
		var source: Dictionary=value[1] if value is Array else value
		var key:=str(value[0]) if value is Array else str(source.get("tag",""))
		next[key]=source
	for key in records.keys():
		if not next.has(key):
			for list in lists: list.erase(key)
			records.erase(key); changed=true
	for key in next:
		var source: Dictionary=next[key]; var page:=1 if bool(source.get("completed",false)) else 0
		if not records.has(key):
			# The transport's historical isQuest name carries native record4c:
			# the encouraged/unread flag, not a Personal Notes category.
			records[key]={"source":source.duplicate(true),"expanded":false,"unread":bool(source.get("isQuest",true))}; lists[page].append(key); changed=true
		elif records[key].source!=source:
			var previous: Dictionary=records[key].source
			if bool(previous.get("completed",false))!=bool(source.get("completed",false)):
				lists[1-page].erase(key); lists[page].append(key)
			if previous.get("description")!=source.get("description") or previous.get("date")!=source.get("date") or previous.get("time")!=source.get("time") or previous.get("isQuest")!=source.get("isQuest"): records[key].unread=bool(source.get("isQuest",true))
			records[key].source=source.duplicate(true); changed=true
	if changed: revision+=1
	return changed
func rows(page: int,text,actor_id: int,day_length: int) -> Array:
	var projected: Array=[]
	if page<0 or page>1: return projected
	for key in lists[page]:
		var record: Dictionary=records[key]; var source: Dictionary=record.source; var row:=source.duplicate(true)
		row.key=key; row.expanded=record.expanded; row.unread=record.unread
		row.sortTitle=text.resolve(source.get("title",{"text":str(source.get("tag",""))}),actor_id)
		row.title=text.Rich.parse(row.sortTitle); row.description=text.rich(source.get("description",{"strRef":source.get("strRef",-1)}),actor_id)
		projected.append(row)
	var sorted: Array=[]
	for index in Order.indices(projected,modes[page],day_length): sorted.append(projected[index])
	return sorted
func expand(key: String) -> bool:
	if not records.has(key): return false
	records[key].expanded=not records[key].expanded; records[key].unread=false; revision+=1; return true
func sort_by(page: int,mode: int) -> bool:
	if page<0 or page>1 or mode<0 or mode>2 or modes[page]==mode: return false
	modes[page]=mode; revision+=1; return true
