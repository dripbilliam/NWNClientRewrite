extends Node
# Owned localhost only: activate real native controls, submit their native BIC,
# and leave admission/movement/export verification to the original server.
var failures: Array=[]
var checks:=0
var owner_world
var expected: Dictionary={}
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label)
	return value
func wait_for(predicate: Callable,seconds: float=30.0) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	return predicate.call()
func proof() -> void:
	owner_world.send({"kind":"creation-proof","success":failures.is_empty(),"checks":checks,"failures":failures,"expected":expected})
func run(world) -> void:
	owner_world=world
	world.character_lobby.create_button.pressed.emit()
	if not check(await wait_for(func():return is_instance_valid(world.gameplay_ui) and world.gameplay_ui.creator.phase=="editing",90),"New Character loads the active catalog"): proof(); return
	var creator=world.gameplay_ui.creator
	creator.view.navigate(3); var selected:=false
	for id in creator.controls:
		var control: Dictionary=creator.controls[id]
		if str(control.operation)=="class" and str(creator.rules.cell(creator.rules.row("classes",int(control.value)),"Label","")).to_lower()==str(world.args.get("creation-class","fighter")):
			creator.view.change(int(id),null,creator.serial); selected=true; break
	if not check(selected,"Actual class control is selected from the active classes table"): proof(); return
	creator.view.recommend.pressed.emit()
	if not check(await wait_for(func():return creator.phase=="editing"),"Package recommendations finish in Godot"): proof(); return
	creator.view.navigate(13)
	for id in creator.controls:
		var control: Dictionary=creator.controls[id]
		if str(control.operation)=="field" and str(control.value) in ["firstName","lastName"]:
			creator.view.inputs[id].text="Native" if control.value=="firstName" else "Prelude"+str(Time.get_ticks_msec())
	creator.view.navigate(14)
	check(creator.rules.errors().is_empty(),"Native recommendation and text controls produce a valid first-level draft")
	check(not creator.view.finish.disabled,"Play becomes available only after native validation")
	if not failures.is_empty(): proof(); return
	expected={"classId":int(creator.rules.draft.classId),"known":[],"feats":creator.rules.granted_feats().duplicate()}
	for known in creator.rules.draft.known.values(): expected.known.append_array(known)
	for feat in creator.rules.draft.feats: expected.feats.append(int(feat.id))
	creator.view.finish.pressed.emit()
	check(await wait_for(func():return creator.phase in ["waiting","closed"] or creator.phase=="editing"),"Native worker finishes the character file")
	check(creator.phase in ["waiting","closed"],"Completed native BIC is submitted to the protocol owner")
	proof()
