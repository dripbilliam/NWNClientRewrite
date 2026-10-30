extends "res://tests/native_spellbook_frame_test.gd"
func cell(book,level: int,at: int) -> Dictionary:
	for row in book.state.memory:
		if int(row.level)==level and int(row.slot)==at: return row
	return {}
func drag_cell(book,from: Dictionary,to: Dictionary) -> void:
	var start: Vector2=book.widgets[int(from.entryId)].get_global_rect().get_center(); var end: Vector2=book.widgets[int(to.entryId)].get_global_rect().get_center()
	await motion(start); await mouse(start,true); await motion(start+Vector2(18,0),Vector2(18,0),true); await motion(end,end-start,true); await mouse(end,false)
func publish(ui,actor: Dictionary,header: Dictionary) -> void:
	ui.set_world(1,55,42,[actor],{},header); await process_frame; await process_frame; await wait_until(func():return book_settled(ui))
func preparation_checks(ui,output: String,actor: Dictionary,header: Dictionary,spells: Dictionary) -> Dictionary:
	var desktop=ui.desktop; var book=desktop.book; var immutable:=actor.duplicate(true); var current:=actor.duplicate(true)
	current.playerState.spellbooks["0"].memorized["3"][2]={"spell":-1,"ready":false,"metamagic":32,"domain":true}; await publish(ui,current,header)
	var before: int=requests.size()
	await drag_cell(book,cell(book,3,0),cell(book,3,2))
	var moved: Array=requests.slice(before)
	check(moved.size()==2 and moved[0].kind=="native-prepare" and moved[0].slot==2 and not moved[0].clear and moved[1].slot==0 and moved[1].clear,"Actual native memory drag writes destination then clears the original source")
	check(desktop.preparation.pending.size()==2 and cell(book,3,0).pending and cell(book,3,2).pending and book.widgets[int(cell(book,3,0).entryId)].payload.is_empty(),"Both transferred cells show pending ownership and cannot start another drag")
	if moved.size()==2:
		desktop.receive({"kind":"native-action-result","action":"native-prepare","accepted":true,"requestId":moved[0].requestId,"generation":1,"areaId":55,"actorId":42,"result":{"sent":true}})
	check(desktop.preparation.pending.size()==2 and actor==immutable,"Transport acceptance neither confirms slots nor mutates received state")
	current.playerState.spellbooks["0"].memorized["3"][0]=null; current.playerState.spellbooks["0"].memorized["3"][2]={"spell":int(spells[3]),"ready":false,"metamagic":0}
	await publish(ui,current,header)
	check(desktop.preparation.pending.is_empty() and cell(book,3,0).spellId<0 and cell(book,3,2).spellId==int(spells[3]) and not cell(book,3,2).ready,"Incoming slot replication alone publishes the moved unready preparation")
	current=actor.duplicate(true); current.playerState.spellbooks["0"].memorized["3"][1]={"spell":int(spells[1]),"ready":false,"metamagic":1}; await publish(ui,current,header)
	before=requests.size(); await drag_cell(book,cell(book,3,0),cell(book,3,1)); var swapped: Array=requests.slice(before)
	check(swapped.size()==2 and swapped[0].slot==0 and swapped[0].spellId==int(spells[1]) and swapped[0].metamagic==1 and swapped[1].slot==1 and swapped[1].spellId==int(spells[3]) and swapped[1].metamagic==0 and not swapped[0].clear and not swapped[1].clear,"Actual occupied-cell drag preserves original displaced-first write order and separate metamagic masks")
	check(current.playerState.spellbooks["0"].memorized["3"][0].spell==int(spells[3]) and desktop.preparation.pending.size()==2,"Exchange leaves the authoritative pool untouched while awaiting both updates")
	if swapped.size()==2:
		desktop.receive({"kind":"native-action-result","action":"native-prepare","accepted":false,"requestId":swapped[0].requestId,"generation":1,"areaId":55,"actorId":42,"text":"The test transport refused this write."})
	check(desktop.preparation.pending.size()==1 and not cell(book,3,0).pending and cell(book,3,1).pending and book.notice.text.contains("refused"),"Correlated refusal unlocks only its failed cell and displays real failure text")
	current.playerState.spellbooks["0"].memorized["3"][1]={"spell":int(spells[3]),"ready":false,"metamagic":0}; await publish(ui,current,header)
	check(desktop.preparation.pending.is_empty() and book.notice.text.contains("refused"),"A partial authoritative outcome is displayed without inventing a rollback or successful exchange")
	var stale: Dictionary=cell(book,3,0); var stale_view: int=book.view_id; before=requests.size(); current.playerState.spellbooks["0"].memorized["3"][0]={"spell":int(spells[1]),"metamagic":1,"ready":false}; ui.set_world(1,55,42,[current],{},header)
	desktop.input_request({"kind":"book-clear","viewId":stale_view,"entryId":stale.entryId})
	check(requests.size()==before and book.notice.text.contains("changed on the server"),"A raw update arriving before UI refresh invalidates a mismatched source slot")
	await process_frame; desktop.preparation.reset([1,55,42]); await publish(ui,actor,header); desktop.book_level=3; desktop.book_meta=0; desktop.family_path.clear(); desktop.refresh_book(); await wait_until(func():return book_settled(ui))
	var used: Dictionary=cell(book,3,1)
	check(is_equal_approx(book.widgets[int(used.entryId)].image.modulate.a,0.4),"Used preparations use the original0.4 icon alpha")
	skin.show_actions(int(used.entryId)); check(book.memorize.disabled and not book.clear.disabled,"Physical-slot utility disables self-preparation while retaining its valid clear action"); skin.action_window.hide()
	await shot(output,"-preparation")
	return {"move_writes":moved,"swap_writes":swapped,"authoritative_fixture_unchanged":actor==immutable,"physicalMouseWarped":false,"full_input_parity":false}
