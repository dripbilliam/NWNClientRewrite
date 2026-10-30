extends RefCounted
# CSpellBox drop1409c21d0 / completion1409c2340 / SetSpell1409c2630.
# Plans and pending claims only. Never changes received creature spellbooks.
var context: Array=[]
var pending: Dictionary={}
var serial:=0
var notice:=""
var timeout_ms:=15000
static func key(row: Dictionary) -> String: return "%d:%d:%d"%[int(row.classIndex),int(row.level),int(row.slot)]
static func command(row: Dictionary,id: int,meta: int,domain: bool,cost: Callable) -> Dictionary:
	var base: int=(int(row.level)-(int(cost.call(meta)) if meta!=0 else 0))&255 if domain else 0
	return {"kind":"native-prepare","clear":false,"classIndex":int(row.classIndex),"level":int(row.level),"slot":int(row.slot),"spellId":id,"metamagic":meta,"domainLevel":base}
static func plan(source: Dictionary,destination: Dictionary,clear: bool,cost: Callable) -> Dictionary:
	var result:={"writes":[],"error":""}
	if int(source.get("spellId",-1))<0: result.error="Choose a spell to prepare."; return result
	var source_slot:=int(source.get("slot",-1))
	if clear:
		if source_slot<0: result.error="Choose a prepared slot to clear."; return result
		var write:=command(source,int(source.spellId),int(source.metamagic),bool(source.domain),cost); write.clear=true; result.writes.append(write); return result
	if destination.is_empty() or int(destination.get("slot",-1))<0 or int(source.classIndex)!=int(destination.classIndex) or int(source.level)!=int(destination.level): result.error="No compatible preparation slot at this spell level."; return result
	if source_slot>=0 and key(source)==key(destination): return result
	var domain:=bool(source.domain); var source_id:=int(source.get("preparationId",source.spellId)); var old:=int(destination.spellId)
	# Original exchange deliberately takes the source domain flag for both
	# writes, including the displaced record; preserve that native rule.
	if old>=0 and source_slot>=0: result.writes.append(command(source,old,int(destination.metamagic),domain,cost))
	result.writes.append(command(destination,source_id,int(source.metamagic),domain,cost))
	# Empty-target moves clear only after the destination write. Known-list
	# sources copy and never erase a preparation. Occupied targets swap above.
	if old<0 and source_slot>=0:
		var write:=command(source,int(source.spellId),int(source.metamagic),domain,cost); write.clear=true; result.writes.append(write)
	return result
static func slot(actor: Dictionary,row: Dictionary) -> Array:
	var entries: Array=actor.get("playerState",{}).get("spellbooks",{}).get(str(int(row.classIndex)),{}).get("memorized",{}).get(str(int(row.level)),[])
	var at:=int(row.slot)
	if at<0 or at>=entries.size(): return []
	var value: Variant=entries[at]
	if not value is Dictionary or int(value.get("spell",-1))<0: return [-1,0,false,false]
	return [int(value.spell),int(value.get("metamagic",0)),bool(value.get("domain",false)),bool(value.get("ready",false))]
func reset(scope: Array=[]) -> void: pending.clear(); context=scope.duplicate(); notice=""
func observe(actor: Dictionary,scope: Array,now_ms: int) -> bool:
	if scope!=context:
		var had:=not pending.is_empty(); reset(scope); return had
	var changed:=false
	for name in pending.keys():
		var claim: Dictionary=pending[name]; var actual:=slot(actor,claim.write)
		if actual!=claim.before:
			pending.erase(name); changed=true
		elif now_ms-int(claim.at)>=timeout_ms:
			pending.erase(name); changed=true; notice="The server has not confirmed that spell preparation. Check the current slots before retrying."
	if changed and pending.is_empty() and notice=="Waiting for the server to update spell preparations…": notice=""
	return changed
func submit(actor: Dictionary,scope: Array,writes: Array,now_ms: int) -> Dictionary:
	observe(actor,scope,now_ms)
	var names: Dictionary={}
	for write in writes:
		var name:=key(write)
		if names.has(name) or pending.has(name): return {"requests":[],"error":"That preparation slot is waiting for the server."}
		if slot(actor,write).is_empty(): return {"requests":[],"error":"That preparation slot is no longer available."}
		names[name]=true
	var requests: Array=[]
	for write in writes:
		serial+=1; var request: Dictionary=write.duplicate(true); request.requestId=serial
		pending[key(write)]={"requestId":serial,"write":write.duplicate(true),"before":slot(actor,write),"at":now_ms}; requests.append(request)
	if not requests.is_empty(): notice="Waiting for the server to update spell preparations…"
	return {"requests":requests,"error":""}
func reject(request_id: int,scope: Array,message: String) -> bool:
	if scope!=context: return false
	for name in pending:
		if int(pending[name].requestId)==request_id:
			pending.erase(name); notice=message; return true
	return false
func decorate(model: Dictionary) -> void:
	for row in model.get("memory",[]): row.pending=pending.has(key(row))
