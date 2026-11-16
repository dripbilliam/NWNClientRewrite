extends SceneTree
const Transaction=preload("res://systems/native_data/native_levelup_transaction.gd")
class Rules:
	extends RefCounted
	func class_info(id: int)->Variant:return {"pickDomains":false,"pickSchool":false} if id==2 else null
	func providers()->Dictionary:return {"skillCount":0}

func _initialize()->void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_native_levelup_sender_fixture.json"))
	var proposal: Dictionary=fixture.cases[0].case
	var area:=0x80000009;var actor_id:=0xffffffff
	var actor: Dictionary={"id":actor_id,"areaId":area,"objectType":5,"replicationRemoved":false,"nativeLifetime":7,"clientKnownLifetime":8,"replicated":{"stats":{"classes":[{"id":2,"level":1}],"racialType":6,"fieldDE4":50,"fieldDE6":50}},"playerState":{"combat":{"canLevelUp":true},"abilities":{"base":[10,10,10,10,10,10]},"feats":[],"spellbooks":{}}}
	var request_meta: Dictionary={"areaId":area,"actorId":actor_id,"nativeLifetime":7,"knownLifetime":8}
	var tx=Transaction.new();var rules=Rules.new();var build: Dictionary={"number":8193,"revision":36,"postfix":0}
	var begin_request: Dictionary={"operation":"begin","levelRequest":request_meta}
	var first: Dictionary=tx.request(begin_request,actor,area,rules,build,1000)
	if first.has("error") or first.packets.size()!=2 or first.packets[0].hex_encode()!="7015010c00000000ffffffff60" or first.packets[1]!=PackedByteArray([112,29,4]):fail("Original pre-begin request order");return
	if not tx.receive({"kind":"level-up-classes","available":[false,false,true]},actor,area,build).is_empty() or tx.pending.is_empty():fail("Classes did not wait for authoritative actor details");return
	actor.playerState.levelUp={"skills":[],"fieldE34":255,"fieldE48":"Familiar","fieldE30":2,"fieldE38":"Animal"}
	actor.inventoryStats={"field9c":6}
	var ready: Dictionary=tx.observe(actor,area,build)
	if not ready.get("accepted",false) or ready.result.available!=[false,false,true] or ready.result.snapshot.actorId!=actor_id or ready.result.draftContext.baseFortitude!=6 or tx.pending.size()!=0:fail("Authoritative begin result unavailable");return
	var submit_request: Dictionary={"operation":"submit","levelRequest":request_meta,"token":ready.result.token,"proposal":proposal}
	var submit: Dictionary=tx.request(submit_request,actor,area,rules,build,2000)
	if submit.has("error") or submit.packets.size()!=1 or submit.packets[0].slice(0,3)!=PackedByteArray([112,29,0]):fail("Original proposal was not admitted");return
	var accepted: Dictionary=tx.receive({"kind":"level-up-result","accepted":true},actor,area,build)
	if not accepted.get("accepted",false) or not accepted.result.get("accepted",false) or not tx.draft.is_empty():fail("Server result did not retire proposal");return
	var second: Dictionary=tx.request(begin_request,actor,area,rules,build,3000)
	if second.has("error"):fail("Second begin was blocked");return
	var timeout: Dictionary=tx.timeout(18000)
	if timeout.get("accepted",true) or not tx.uncertain or not tx.request(begin_request,actor,area,rules,build,18001).has("error"):fail("Uncertain timeout did not fence next request");return
	var refused: Dictionary=tx.receive({"kind":"level-up-result","accepted":false},actor,area,build)
	if refused.get("accepted",true) or tx.uncertain or not tx.pending.is_empty():fail("Late server rejection did not settle uncertainty");return
	var third: Dictionary=tx.request(begin_request,actor,area,rules,build,19000)
	if third.has("error"):fail("Third begin was blocked");return
	actor.nativeLifetime=9;actor.clientKnownLifetime=10
	var stale: Dictionary=tx.receive({"kind":"level-up-classes","available":[false,false,true]},actor,area,build)
	if stale.get("accepted",true) or not tx.pending.is_empty() or not tx.draft.is_empty():fail("Replaced actor kept level-up transaction");return
	request_meta.nativeLifetime=9;request_meta.knownLifetime=10
	var cancel: Dictionary=tx.request({"operation":"cancel","levelRequest":request_meta},actor,area,rules,build,20000)
	if cancel.has("error") or cancel.packets[0].hex_encode()!="7035011b000000100000000000007f00000000000000000000000060":fail("Original cancellation packet differs");return
	print("NWN79 Godot level-up transaction PASS: ordered begin, authoritative snapshot, proposal, result, timeout, replacement and cancel")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot level-up transaction failed: "+reason)
	quit(1)
