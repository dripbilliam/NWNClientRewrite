extends RefCounted
# Connection-owned original-server transaction. No proposed progression is
# applied locally; only a later authoritative object update changes the actor.
const Sender=preload("res://systems/native_data/native_network_levelup_request.gd")
const Received=preload("res://systems/native_data/level_up_received_context.gd")
var pending: Dictionary={}
var draft: Dictionary={}
var uncertain:=false
var next_token:=0

static func actor_scope(actor: Dictionary,area_id: int)->Array:
	if int(actor.get("id",-1))<0 or int(actor.get("areaId",-1))!=area_id or int(actor.get("objectType",0))!=5 or bool(actor.get("replicationRemoved",false)) or int(actor.get("nativeLifetime",0))<1 or int(actor.get("clientKnownLifetime",0))<1:return []
	return [area_id,int(actor.id),int(actor.nativeLifetime),int(actor.clientKnownLifetime)]

static func build_feature(build: Dictionary)->bool:
	return int(build.get("number",0))>8193 or int(build.get("number",0))==8193 and int(build.get("revision",0))>=35

static func reply(request: Dictionary,accepted: bool,result: Dictionary={},reason: String="")->Dictionary:
	return {"kind":"native-action-result","action":"native-level-up","operation":str(request.get("operation","")),"levelRequest":request.get("levelRequest",{}).duplicate(true),"accepted":accepted,"result":result.duplicate(true),"text":reason}

func request(value: Dictionary,actor: Dictionary,area_id: int,rules: RefCounted,build: Dictionary,now: int)->Dictionary:
	var scope:=actor_scope(actor,area_id)
	if scope.is_empty():return {"error":"Level-up belongs to an old controlled creature"}
	var meta: Variant=value.get("levelRequest")
	if not meta is Dictionary or int(meta.get("areaId",-1))!=area_id or int(meta.get("actorId",-1))!=int(actor.id) or int(meta.get("nativeLifetime",-1))!=int(actor.nativeLifetime) or int(meta.get("knownLifetime",-1))!=int(actor.clientKnownLifetime):return {"error":"Level-up request identity is stale"}
	var operation:=str(value.get("operation",""))
	if operation=="cancel":
		if not draft.is_empty() and draft.get("scope")==scope and pending.is_empty():draft.clear()
		return {"packets":[Sender.cancel(build_feature(build))]}
	if not pending.is_empty() or uncertain:return {"error":"Waiting for the previous server level-up reply"}
	var packets: Array[PackedByteArray]=[]
	if operation=="begin":
		if not bool(actor.get("playerState",{}).get("combat",{}).get("canLevelUp",false)):return {"error":"The server has not made level-up available"}
		draft.clear()
		packets=[Sender.character_sheet(int(actor.id)),Sender.begin()]
	elif operation=="submit":
		var received: Dictionary=Received.snapshot(actor)
		if draft.is_empty() or draft.get("scope")!=scope or int(value.get("token",-1))!=int(draft.get("token",-2)) or not received.get("ready",false) or received.get("value")!=draft.get("snapshot"):
			return {"error":"Character changed; reopen Level Up"}
		var proposal: Variant=value.get("proposal")
		if not proposal is Dictionary or int(proposal.get("classId",-1))<0 or int(proposal.classId)>=draft.available.size() or not bool(draft.available[int(proposal.classId)]):return {"error":"The server has not made this class available"}
		if rules==null:return {"error":"Level-up class rules are unavailable"}
		var schema: Variant=rules.class_info(int(proposal.classId))
		if not schema is Dictionary:return {"error":"Level-up class rules are unavailable"}
		var level:=0
		for row in received.value.classes:level+=int(row.get("level",0))
		var options: Dictionary={"level":level,"skillCount":int(rules.providers().get("skillCount",-1))}
		options.merge(schema,true)
		var encoded: Dictionary=Sender.proposal(proposal,options)
		if encoded.has("error"):return encoded
		packets=[encoded.bytes]
	else:return {"error":"Invalid level-up operation"}
	pending={"operation":operation,"scope":scope,"request":value.duplicate(true),"deadline":now+15000,"timedOut":false,"available":[]}
	return {"packets":packets}

func send_failed()->Dictionary:
	if pending.is_empty():return {}
	var result:=reply(pending.request,false,{},"Native level-up request could not be sent")
	pending.clear()
	return result

func receive(message: Dictionary,actor: Dictionary,area_id: int,build: Dictionary)->Dictionary:
	if not message.get("kind") in ["level-up-classes","level-up-result","level-up-available"]:return {}
	if message.kind=="level-up-available":return {}
	uncertain=false
	if pending.is_empty():return {}
	if pending.scope!=actor_scope(actor,area_id):
		var stale:=reply(pending.request,false,{},"Level-up creature changed")
		pending.clear();draft.clear();return stale
	if message.kind=="level-up-classes":
		if pending.operation!="begin":return {}
		pending.available=message.available.duplicate()
		return observe(actor,area_id,build)
	var request_value: Dictionary=pending.request
	var operation:=str(pending.operation)
	pending.clear();draft.clear()
	if operation=="begin":return reply(request_value,false,{},"The server did not allow leveling up")
	return reply(request_value,true,{"accepted":bool(message.accepted)})

func observe(actor: Dictionary,area_id: int,build: Dictionary)->Dictionary:
	if pending.is_empty() or pending.operation!="begin" or pending.available.is_empty():return {}
	if pending.scope!=actor_scope(actor,area_id):
		var stale:=reply(pending.request,false,{},"Level-up creature changed")
		pending.clear();draft.clear();return stale
	var received: Dictionary=Received.snapshot(actor)
	if not received.get("ready",false):return {}
	next_token+=1
	var snapshot: Dictionary=received.value
	var result: Dictionary={"token":next_token,"snapshot":snapshot.duplicate(true),"available":pending.available.duplicate(),"protocolFeatures":{"multiclassRuleset":build_feature(build)},"draftContext":{"baseFortitude":Received.fortitude(actor)}}
	draft={"token":next_token,"scope":pending.scope.duplicate(),"snapshot":snapshot.duplicate(true),"available":pending.available.duplicate()}
	var answer:=reply(pending.request,true,result)
	pending.clear()
	return answer

func timeout(now: int)->Dictionary:
	if pending.is_empty() or pending.timedOut or now<int(pending.deadline):return {}
	pending.timedOut=true;uncertain=true
	return reply(pending.request,false,{},"The server has not confirmed level-up; waiting for its reply")

func reset()->void:
	pending.clear();draft.clear();uncertain=false
