extends RefCounted
# Client collectors98f550 / class page98fbf0 / innate traversal9a3e80.
# Pure decisions over received ownership and the selected catalog's tables.
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Feats=preload("res://systems/native_data/feat_radial.gd")
const INNATE_SLOTS=[2,6,0,4,1,5,3]
var rules
var feats
var errors: Array=[]
var always_subradial:=false
func player_flags(actor: Dictionary) -> int:
	return int(actor.get("playerState",{}).get("playerFlags",0))
func activity(actor: Dictionary,id: int) -> Dictionary:
	# Original player reader7b4f70 publishes Search/Stealth/Defensive Casting
	# from bits0/1/15; constructors994d10/9a37a0 choose their active labels.
	var flags:=player_flags(actor)
	match id:
		0: return {"labelRef":4849 if flags&1 else 4848,"icon":"isk_search"}
		1: return {"labelRef":4851 if flags&2 else 4850,"icon":"isk_movsilent"}
		5: return {"labelRef":8118 if flags&512 else 693,"icon":"IR_CNTRSPELL"}
		10: return {"labelRef":1765 if flags&32768 else 1762,"icon":"ir_defcast"}
	return {}
func classes(actor: Dictionary) -> Array:
	return actor.get("replicated",{}).get("stats",{}).get("classes",[])
func class_row(actor: Dictionary,index: int) -> Dictionary:
	var rows:=classes(actor)
	return rules.row("classes",int(rows[index].id)&255) if index>=0 and index<rows.size() else {}
func class_table(actor: Dictionary,index: int) -> String:
	var name:=str(Rules.cell(class_row(actor,index),"FeatsTable","")).to_lower()
	return "" if name=="****" else name
func grouped(actor: Dictionary) -> bool:
	return always_subradial or classes(actor).size()>3
func class_records(actor: Dictionary,index: int) -> Array:
	var rows: Array=rules.text.tables.get(class_table(actor,index),{}).get("orderedRows",[])
	var count:=rows.size()&65535; var storage: Array=[]; var cursor:=0
	# Native loader shrinks its loop bound on invalid feats. Do not fabricate
	# untouched destination records if a malformed table exposes a storage hole.
	while cursor<count:
		var row: Dictionary=rows[cursor]; var id:=Rules.number(Rules.cell(row,"FeatIndex"),0)&65535
		if feats.feat(id).is_empty(): count-=1
		else: storage.append({"id":id,"onMenu":Rules.number(Rules.cell(row,"OnMenu"),0)})
		cursor+=1
	if storage.size()<count:
		var reason:="Class ability table has undefined native loader storage: "+class_table(actor,index)
		if not errors.has(reason): errors.append(reason)
		return []
	return storage.slice(0,count)
func domains(actor: Dictionary,index: int) -> Array:
	var rows:=classes(actor); var result: Array=[]
	if index<0 or index>=rows.size() or (int(rows[index].id)&255)!=2: return result
	for id in rows[index].get("domains",[]).slice(0,2):
		var row: Dictionary=rules.row("domains",int(id)&255)
		if not row.is_empty(): result.append({"featId":Rules.number(Rules.cell(row,"GrantedFeat"),65535)&65535,"castable":Rules.number(Rules.cell(row,"CastableFeat"),0)})
	return result
func descriptors(ctx: Dictionary) -> Array:
	var result: Array=[]; var actor: Dictionary=ctx.actor
	for index in classes(actor).size()&255:
		var group:=domains(actor,index).any(func(row):return int(row.castable)!=0); var first:=65535
		for record in class_records(actor,index):
			if group: break
			var id:=int(record.id)
			if int(record.onMenu)!=1 or not ctx.owned.has(id) or grouped(actor) and id==1089: continue
			if first==65535: first=id
			else: group=true
		if group or first!=65535: result.append({"group":group,"classIndex":index,"firstFeat":first})
	return result
func class_page(ctx: Dictionary,index: int,start: int=0) -> Array:
	index&=7; start&=65535
	var result: Array=[]; var reserved:=0
	if start==0:
		for domain in domains(ctx.actor,index):
			var id:=int(domain.featId)
			if id==65535 or int(domain.castable)==0 or feats.feat(id).is_empty(): continue
			result.append({"slot":reserved,"featId":id,"domain":true,"uses":feats.remaining(ctx,id),"disabled":not ctx.assignment and feats.remaining(ctx,id)<1}); reserved+=1
	var ids: Array=[]
	for record in class_records(ctx.actor,index):
		var id:=int(record.id)
		if int(record.onMenu)!=1 or grouped(ctx.actor) and id==1089: continue
		var selected:=65535; var visited: Dictionary={}
		while id!=0:
			if visited.has(id):
				if not errors.has("Class ability successor cycle"): errors.append("Class ability successor cycle")
				return []
			visited[id]=true
			if not ctx.owned.has(id): break
			selected=id; var info: Dictionary=feats.feat(id)
			if info.is_empty(): break
			id=int(info.successor)&65535
		if selected!=65535 and not ids.has(selected): ids.append(selected)
	var remaining:=reserved+ids.size()-start; var limit:=8 if remaining==8 else 7
	for offset in maxi(0,mini(ids.size()-start,limit-reserved)):
		result.append({"slot":reserved+offset,"featId":ids[start+offset]})
	if remaining>8: result.append({"slot":7,"next":(limit-reserved+start)&65535,"classIndex":index})
	return result
func innate_page(actor: Dictionary,start: int=0) -> Array:
	var pool: Array=actor.get("playerState",{}).get("specialAbilities",[])
	var result: Array=[]; var seen: Dictionary={}; var at:=maxi(0,start); var index:=0
	while at<pool.size() and index<7:
		var source: Dictionary=pool[at]; var id:=int(source.get("spell",-1))
		if seen.has(id): at+=2; continue # Original duplicate branch advances twice.
		seen[id]=true; var slot: int=INNATE_SLOTS[index]; index+=1; at+=1
		if rules.row("spells",id).is_empty(): continue # Invalid physical slot stays empty.
		var level:=int(source.get("level",0))&255; var uses:=0
		for value in pool:
			if int(value.get("spell",-1))==id and (int(value.get("level",0))&255)==level and Rules.flag(value.get("state",false)): uses=(uses+1)&255
		result.append({"slot":slot,"spellId":id,"domainLevel":level,"uses":uses})
	if at<pool.size(): result.append({"slot":7,"next":at})
	return result
