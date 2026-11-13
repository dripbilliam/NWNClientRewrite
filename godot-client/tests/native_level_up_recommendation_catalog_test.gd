extends "res://tests/native_level_up_recommended_test.gd"
class UiOwner extends Node:
	var catalog
	var closed:=false
class RetiredDesktop extends RefCounted:
	var owner_ui
	var closed:=false
var replacement
var request_capture: Dictionary={}
var replace_on_press:=false
var invalidate_on_press:=false
func change_catalog_on_press() -> void:
	request_capture={"pending":private_owner.recommendation_pending,"wanted":runtime.recommendation_work.wanted,"request":runtime.recommendation_work.serial,"ticket":runtime.recommendation_work.ticket.duplicate(),"scope":runtime.rules_scope.duplicate(),"catalog":runtime.active_catalog}
	if replace_on_press:desktop.owner_ui.catalog=replacement
	if invalidate_on_press:replacement.invalidate()
func new_skills(begin: Dictionary,token: int) -> bool:
	var value:=begin.duplicate(true);value.token=token;panel.reset();panel.open();controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":value}))
	if not await ready("class"):return false
	await click(front.panes["class"].buttons.okbutton)
	if not await ready("attributes"):return false
	await click(front.panes.attributes.buttons.dexupbutton);await click(front.panes.attributes.buttons.okbutton)
	return await ready("skills")
func extra_cases(begin: Dictionary,received: Dictionary,before: Dictionary,tables: Dictionary) -> void:
	cancel_on_press=false;replacement=catalog.fork()
	if not gate(await new_skills(begin,63),"Current catalog guard fixture reopens actual Class/Attributes/Skills"):return
	var pane=front.panes.skills;await click(pane.buttons["up:0"]);var edits: Array=private_owner.skills.changes()
	pane.buttons.recommendbutton.pressed.connect(change_catalog_on_press);replace_on_press=true
	await click(pane.buttons.recommendbutton);replace_on_press=false
	check(request_capture.pending and request_capture.wanted and request_capture.catalog==catalog,"Actual Recommended registers its pending private request before catalog replacement")
	check(await wait_for(func():return panel.visible and not panel.source_active and not runtime.active),"Same actor/token catalog replacement rejects the old worker and uses the existing presentation handoff")
	check(controller.draft.skills==edits and edits[0]==1 and received==before and not tables.has("packages"),"Catalog retirement preserves begun private ranks, received snapshot and canonical tables")
	check(not runtime.publish_recommendation_dependency("late",{"orderedRows":[]},int(request_capture.request),request_capture.scope,catalog).get("ready",false),"Retired catalog dependency cannot publish into the next private map")
	runtime.recommendation_work.completed.emit("skills",{"ready":true,"invoked":true,"loaded":true,"ids":[1]},int(request_capture.request),request_capture.ticket)
	check(controller.draft.skills==edits and not runtime.active,"Late completed result cannot replace the preserved private edits")
	panel.reset()
	if not gate(await new_skills(begin,64),"New token can open against the replacement catalog"):return
	check(runtime.active_catalog==replacement and runtime.recommendation_work.catalog==replacement and runtime.source_owner.active_catalog==replacement,"New draft reconfigures private recommendation and associate job ownership to the current catalog")
	pane=front.panes.skills;await click(pane.buttons["up:0"]);edits=private_owner.skills.changes();invalidate_on_press=true
	var cache_generation: int=replacement.preparation_cache().generation();await click(pane.buttons.recommendbutton);invalidate_on_press=false
	check(replacement.preparation_cache().generation()>cache_generation and request_capture.pending,"Same-object catalog invalidation uses its existing preparation-cache generation")
	check(await wait_for(func():return panel.visible and not panel.source_active and not runtime.active),"Changed catalog generation rejects pending dependency/reset results without a frame poll")
	check(controller.draft.skills==edits and edits[0]==1,"Generation retirement preserves manual ranks before a preference reset can apply")
	panel.reset()
	if not gate(await new_skills(begin,65),"Next draft captures the new generation rather than remaining stuck retired"):return
	pane=front.panes.skills;await click(pane.buttons.recommendbutton)
	check(await wait_for(func():return not private_owner.recommendation_pending) and private_owner.skills.changes()[0]==4 and private_owner.skills.points==0,"Reopened current-generation Recommended completes actual scoped package/preference workers")
	var latest_ticket: Array=front.ticket.duplicate();desktop.owner_ui.catalog=null;runtime.finalize({},latest_ticket)
	check(await wait_for(func():return panel.visible and not panel.source_active and not runtime.active) and desktop.commands.all(func(value):return value.operation!="submit"),"Finalization with a retired catalog cannot emit a proposal or synthetic acknowledgement")
	panel.reset();desktop.owner_ui.catalog=replacement
	var old_desktop=controller.desktop;var retired:=RetiredDesktop.new();var owner:=UiOwner.new();owner.catalog=replacement;retired.owner_ui=owner;controller.desktop=retired
	check(controller.source_catalog()==replacement,"Safe getter reads a live actual Object UI owner")
	owner.closed=true;check(controller.source_catalog()==null,"Closed UI owner returns unavailable catalog")
	owner.free();check(controller.source_catalog()==null,"Freed UI owner returns unavailable catalog without property access")
	retired.owner_ui=null;retired.closed=true;check(controller.source_catalog()==null,"Retired desktop returns unavailable catalog")
	controller.desktop=old_desktop
