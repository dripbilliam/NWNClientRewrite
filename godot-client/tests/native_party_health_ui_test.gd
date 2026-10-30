extends "res://tests/native_party_frame_test.gd"
const Health=preload("res://systems/native_data/party_health.gd")
func variants_checks(ui,output: String,actor: Dictionary,objects: Array,members: Array) -> Dictionary:
	var rail=ui.desktop.party; var own=rail.cards[0].get_node("Box/NativeHealth"); var other=rail.cards[1].get_node("Box/NativeHealth"); var hashes: Array=[]; var variants: Array=[]
	var identity: int=rail.cards[0].get_node("Box/Portrait").get_instance_id(); var hp_before: Dictionary=actor.replicated.hitPoints.duplicate(true); var sent: int=requests.size()
	for flags in [[false,false],[true,false],[false,true],[true,true]]:
		actor.replicated.party={"field8B0":flags[0],"field8B4":flags[1]}; objects[1].replicated.party=actor.replicated.party.duplicate(); var clip:=Health.mode(flags[0],flags[1])
		ui.set_world(1,55,42,objects,{},{"area":{"id":55},"ui":{"party":members}})
		check(await wait_until(func():return own.desired_clip==clip and other.desired_clip==clip and settled_party(ui)),"Received %s flags update both original self/member health variants at unchanged HP"%clip)
		check(own.published_clip==clip and other.published_clip==clip and own.published==25 and other.published==50,"Original %s pose preserves each received health percentage"%clip)
		var hash: String=preload("res://systems/native_data/prepared_cache.gd").digest(own.picture.texture.get_image().get_data()); hashes.append(hash); variants.append({"clip":clip,"own":own.snapshot(),"member":other.snapshot(),"pixel_hash":hash})
		await shot(output,"-health-"+clip)
	var unique: Dictionary={}
	for hash in hashes: unique[hash]=true
	check(unique.size()==4,"All four original health variants render distinct actual pixel data")
	check(requests.size()==sent and actor.replicated.hitPoints==hp_before and rail.cards[0].get_node("Box/Portrait").get_instance_id()==identity,"Health variant presentation sends no gameplay request and preserves authoritative HP/portrait ownership")
	var before: int=own.requests
	for at in 64: own.set_health({"current":25,"maximum":100,"clip":"poison" if at%2==0 else "disease"})
	await wait_until(func():return own.requests>before); check(await wait_until(func():return settled_party(ui)) and own.requests-before==1 and own.published_clip=="disease","A64-change same-HP mode burst coalesces to one final native pose")
	return {"variants":variants,"physicalMouseWarped":false,"fullHealthParity":false}
