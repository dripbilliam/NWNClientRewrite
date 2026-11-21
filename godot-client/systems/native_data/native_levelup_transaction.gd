extends RefCounted
# Connection-owned original-server transaction. No proposed progression is
# applied locally; only a later authoritative object update changes the actor.
const Sender=preload("res://systems/native_data/native_network_levelup_request.gd")
const Received=preload("res://systems/native_data/level_up_received_context.gd")
const ReplyScope=preload("res://systems/native_data/level_up_reply_scope.gd")
var pending: Dictionary={}
var draft: Dictionary={}
var uncertain:=false
var next_token:=0

static func actor_scope(actor: Dictionary,area_id: int)->Array:
	if int(actor.get("id",-1))<0 or int(actor.get("areaId",-1))!=area_id or int(actor.get("objectType",0))!=5 or bool(actor.get("replicationRemoved",false)) or int(actor.get("nativeLifetime",0))<1 or int(actor.get("clientKnownLifetime",0))<1:return []
	return [area_id,int(actor.id),int(actor.nativeLifetime),int(actor.clientKnownLifetime)]

static func build_feature(build: Dictionary)->bool:
	if not build.has("number") or not build.has("revision") or not build.has("postfix"):return false
	return int(build.number)>=8193 and (int(build.revision)>35 or int(build.revision)==35 and int(build.postfix)>=0)

static func reply(request: Dictionary,accepted: bool,result: Dictionary={},reason: String="")->Dictionary:
	var answer: Dictionary={"kind":"native-action-result","action":"native-level-up","operation":str(request.get("operation","")),"accepted":accepted,"result":result.duplicate(true),"text":reason}
	if request.get("levelRequest") is Dictionary:answer.levelRequest=request.levelRequest.duplicate(true)
	return answer

func request(value: Dictionary,actor: Dictionary,area_id: int,rules: RefCounted,build: Dictionary,now: int)->Dictionary:
	var captured: Dictionary=ReplyScope.capture(value)
	if captured.has("error"):return {"error":captured.error}
	var scope:=actor_scope(actor,area_id)
	if scope.is_empty():return {"error":"Level-up belongs to an old controlled creature"}
	var meta: Variant=captured.value
	if meta is Dictionary and (int(meta.areaId)!=area_id or int(meta.actorId)!=int(actor.id) or int(meta.nativeLifetime)!=int(actor.nativeLifetime) or int(meta.knownLifetime)!=int(actor.clientKnownLifetime)):return {"error":"Level-up request identity is stale"}
	var operation:=str(value.get("operation",""))
	if operation=="cancel":
		var cancel_draft_token:=int(draft.get("token",-1)) if draft.get("scope")==scope and pending.is_empty() else -1
		return {"packets":[Sender.cancel(build_feature(build))],"cancelDraftToken":cancel_draft_token,"cancelScope":scope}
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
	var stored_request: Dictionary=value.duplicate(true)
	if meta is Dictionary:stored_request.levelRequest=meta.duplicate(true)
	pending={"operation":operation,"scope":scope,"request":stored_request,"deadline":now+15000,"timedOut":false,"available":[],"classes_received":false}
	return {"packets":packets}

func complete_cancel(token: int,scope: Array)->void:
	# The original session retired its draft only after the cancel packet sent
	# and only if the same draft still belonged to the controlled creature.
	if token>=0 and pending.is_empty() and int(draft.get("token",-1))==token and draft.get("scope")==scope:draft.clear()

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
		pending.available=message.available.duplicate();pending.classes_received=true
		return observe(actor,area_id,build)
	var request_value: Dictionary=pending.request
	var operation:=str(pending.operation)
	pending.clear();draft.clear()
	if operation=="begin":return reply(request_value,false,{},"The server did not allow leveling up")
	return reply(request_value,true,{"accepted":bool(message.accepted)})

func observe(actor: Dictionary,area_id: int,build: Dictionary)->Dictionary:
	if pending.is_empty() or pending.operation!="begin" or not pending.get("classes_received",false):return {}
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
