extends "res://tests/native_quickbar_frame_test.gd"
const Lobby=preload("res://systems/character_lobby.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Mutation=preload("res://systems/native_data/local_character_mutation.gd")
const Hash=preload("res://systems/native_data/prepared_cache.gd")
var ui
var lobby_state: Dictionary={}
func present(connection: int=1) -> void:
	ui.apply_state({"connection":connection,"state":lobby_state.duplicate(true)}); await process_frame; await process_frame
func acknowledge() -> void:
	if ui.native_selection.is_empty(): return
	var pending: Dictionary=ui.native_selection.duplicate(); lobby_state.selected=pending.key; lobby_state.selectionAck={"key":pending.key,"requestId":pending.requestId}; await present(ui.connection)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../backups/animations/native-character-delete-results-v1.json"))
	check(original.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and original.cases.size()==55,"Confirmation result and row-reselection evidence pins55 unchanged original instruction executions")
	for row in original.cases:
		if row.kind=="button": check(int(row.result)==(1 if row.button=="ok" else 2),"Original modal result: "+str(row.button))
		else: check(Mutation.accepted(int(row.result))==(int(row.result)==1) and (row.next==null or Mutation.next_selection(int(row.selected),int(row.after))==int(row.next)),"Native destructive-result/row policy matches original populated-list case "+str(row))
	root.size=Vector2i(1280,800); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original chooser/confirmation resources mount read-only")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original confirmation text resolves from installed TLK")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	ui=Lobby.new(); surface.add_child(ui); ui.preferences.open_file(""); ui.enable_picker(); ui.request.connect(func(value):requests.append(value.duplicate(true))); ui.configure_confirmation(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	check(await wait_until(func():return ui.confirmation.layout_ready or not ui.confirmation.failure.is_empty()),"Original confirmation preparation terminates")
	check(ui.confirmation.failure.is_empty() and ui.confirmation.layout_ready,"All original OKCANCELPANEL controls and artwork geometry prepare: "+ui.confirmation.failure)
	if not ui.confirmation.layout_ready: ui.free(); painter.close(); painter.free(); text.close(); quit(1); return
	var dialog=ui.confirmation; check(dialog.definition.entries.size()==3 and dialog.buttons.size()==2 and dialog.definition.entries.okbutton.callback=="0x140201ef0" and dialog.definition.entries.cancelbutton.callback=="0x140201e30","Original message label and both source callback identities are retained")
	check(dialog.message.clip_text and dialog.message.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART and dialog.message.get_rect().is_equal_approx(dialog.definition.entries.messagelabel.rect) and Rect2(Vector2.ZERO,dialog.panel.size).encloses(dialog.message.get_rect()),"The explicitly imported original message label wraps inside its authored rectangle rather than floating outside the panel")
	var folder:=output.trim_suffix(".json")+"-owned"; DirAccess.make_dir_recursive_absolute(folder); var paths: Array=[]; var rows: Array=[]
	var bytes:=FileAccess.get_file_as_bytes(install.path_join("data/lcv/wizard.bic"))
	var gff:=preload("res://systems/native_data/gff_document.gd").new(); var dm_document:=gff.parse(bytes,"BIC "); dm_document.root.IsDM=1
	check(preload("res://systems/native_data/local_character_metadata.gd").project(dm_document).isDM,"Native role metadata recognizes an actual typed BIC IsDM byte")
	dm_document.field_types[0].IsDM=2; check(not preload("res://systems/native_data/local_character_metadata.gd").project(dm_document).isDM,"An incorrectly typed DM field does not fabricate a DM alias role")
	for at in 4:
		var path:=folder.path_join("owned"+str(at)+".bic"); var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(bytes); file.close(); paths.append(path)
		rows.append({"key":"local:owned"+str(at),"label":"Owned "+str(at),"source":"local","catalogStem":"owned"+str(at),"nativeFile":{"format":"native-local-bic-v1","path":path,"bytes":bytes.size(),"sha256":Hash.digest(bytes),"storageSource":"local"}})
	# Native metadata still decodes the actual BIC; labels are replaced below by
	# original source names, so select by opaque key rather than fixture captions.
	text.publish_table("pregen",{"orderedCells":[]}); ui.picker.configure_source(text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	lobby_state={"phase":"character-selection","connected":true,"canSelect":true,"canCreate":true,"localAllowed":true,"selected":null,"choices":rows}; ui.apply_state({"connection":1,"localCharacterRoots":[folder],"state":lobby_state.duplicate(true)})
	check(await wait_until(func():return ui.can_select() and ui.picker.row_keys.size()==4 and not ui.native_selection.is_empty()),"Real local BIC metadata becomes ready before destructive input is offered")
	await acknowledge(); ui.choose_native("local:owned1"); await acknowledge()
	check(ui.delete_reason().is_empty() and not ui.picker.shell.buttons.delete.disabled,"A selected profile-vault byte ticket enables native Delete")
	await click(ui.picker.shell.buttons.delete.get_global_rect().get_center())
	check(dialog.visible and dialog.message.text==text.raw({"strRef":0x2910}) and dialog.captions.okbutton.text==text.raw({"strRef":0x42}) and dialog.captions.cancelbutton.text==text.raw({"strRef":0x43}),"Delete opens the original localized question and Yes/No controls")
	check(not ui.delete_lease.is_empty() and ui.picker.shell.play.disabled,"The scoped confirmation holds destructive selection and Play")
	if DisplayServer.get_name()!="headless":
		check(await wait_until(func():return painter.art.waiting.is_empty() and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.fonts.pending.is_empty()),"Original confirmation artwork and fonts finish before visual review")
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+".confirmation.png")==OK,"Actual native original-resource Delete confirmation screenshot captured")
	await click(dialog.buttons.cancelbutton.get_global_rect().get_center())
	check(ui.delete_lease.is_empty() and FileAccess.file_exists(paths[1]) and not dialog.visible,"No dismisses the confirmation without deleting any character")
	await click(ui.picker.shell.buttons.delete.get_global_rect().get_center()); ui.picker.shell.grab_focus(); await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	check(ui.delete_lease.is_empty() and FileAccess.file_exists(paths[1]) and not dialog.visible,"Escape returns original cancel result2 even when another control owns GUI focus")
	await click(ui.picker.shell.buttons.delete.get_global_rect().get_center()); var changed:=bytes.duplicate(); changed[changed.size()-1]^=1; var file:=FileAccess.open(paths[1],FileAccess.WRITE); file.store_buffer(changed); file.close(); await click(dialog.buttons.okbutton.get_global_rect().get_center())
	check(FileAccess.file_exists(paths[1]) and not ui.local_notice.is_empty() and ui.picker.shell.status.text==ui.local_notice and ui.delete_lease.is_empty() and requests.back().kind!="lobby-local-refresh","A character changed during confirmation is preserved with visible refusal feedback")
	file=FileAccess.open(paths[1],FileAccess.WRITE); file.store_buffer(bytes); file.close(); await click(ui.picker.shell.buttons.delete.get_global_rect().get_center()); await click(dialog.buttons.okbutton.get_global_rect().get_center())
	check(not FileAccess.file_exists(paths[1]) and FileAccess.file_exists(paths[0]) and FileAccess.file_exists(paths[2]),"Yes deletes exactly the captured owned local BIC")
	check(requests.back().kind=="lobby-local-refresh" and requests.back().key=="local:owned1" and requests.back().sha256==Hash.digest(bytes) and not requests.back().has("path"),"Successful mutation requests a scoped raw-catalog refresh without sending a filesystem path or gameplay outcome")
	var refresh: Dictionary=requests.back(); lobby_state.choices=[rows[0],rows[2],rows[3]]; lobby_state.selected=null; lobby_state.preview=null; lobby_state.selectionAck=null; lobby_state.localRefreshAck={"connection":1,"key":refresh.key,"requestId":refresh.requestId}; await present()
	check(await wait_until(func():return ui.local_catalog.ready() and ui.delete_lease.is_empty() and not ui.native_selection.is_empty()),"Matching catalog refresh settles only after native metadata is ready")
	check(requests.back().kind=="lobby-choose" and requests.back().key=="local:owned2","Original post-delete policy selects the same visual row, now occupied by the next character")
	await acknowledge()
	var installed_row: Dictionary=rows[2].duplicate(true); installed_row.source="installed"; installed_row.nativeFile.storageSource="installed"; lobby_state.choices=[rows[0],installed_row,rows[3]]; await present(); check(await wait_until(func():return ui.can_select()),"An installed alias role is revalidated through actual native BIC metadata")
	check(FileAccess.set_read_only_attribute(paths[2],true)==OK,"Owned installed-role fixture is read-only before alias dismissal")
	await click(ui.picker.shell.buttons.delete.get_global_rect().get_center()); await click(dialog.buttons.okbutton.get_global_rect().get_center()); refresh=requests.back()
	check(FileAccess.file_exists(paths[2]) and FileAccess.get_read_only_attribute(paths[2]) and refresh.kind=="lobby-local-refresh" and refresh.dismissInstalled,"Installed-row acceptance preserves its bytes/attributes and requests session-only dismissal")
	lobby_state.choices=[rows[0],rows[3]]; lobby_state.selected=null; lobby_state.preview=null; lobby_state.selectionAck=null; lobby_state.localRefreshAck={"connection":1,"key":refresh.key,"requestId":refresh.requestId}; await present(); check(await wait_until(func():return ui.local_catalog.ready() and not ui.native_selection.is_empty()),"Installed dismissal waits for the matching authoritative catalog refresh")
	await acknowledge(); check(ui.state.selected=="local:owned3" and ui.picker.shell.status.text.contains("original game files were not deleted"),"Installed-only deletion selects the next row and explicitly reports that original files were preserved")
	ui.choose_native("local:owned0"); await acknowledge(); check(FileAccess.set_read_only_attribute(paths[0],true)==OK,"Owned profile-role fixture is read-only before original-compatible deletion"); await click(ui.picker.shell.buttons.delete.get_global_rect().get_center()); await click(dialog.buttons.okbutton.get_global_rect().get_center()); refresh=requests.back()
	check(not FileAccess.file_exists(paths[0]),"Confirmed profile deletion follows original chmod/unlink behavior for a read-only BIC")
	lobby_state.error="The local character list could not be refreshed."; lobby_state.localRefreshAck={"connection":1,"key":refresh.key,"requestId":refresh.requestId,"accepted":false}; await present()
	check(ui.delete_lease.is_empty() and ui.post_delete_index<0 and ui.picker.shell.status.text==lobby_state.error and not ui.picker.shell.buttons.back.disabled,"A refused catalog refresh releases destructive ownership and shows the failure instead of leaving the picker stuck")
	ui.choose_native("local:owned3"); lobby_state.error=""; await acknowledge()
	var server: Dictionary=rows[0].duplicate(true); server.source="server"; check(not Mutation.reason(server,ui.local_catalog.roots).is_empty(),"Server-vault rows cannot acquire local file mutation authority")
	var installed: Dictionary=rows[2].duplicate(true); installed.source="installed"; installed.nativeFile.storageSource="installed"; var dismissal:=Mutation.remove(installed,ui.local_catalog.roots)
	check(dismissal.success and not dismissal.fileRemoved and dismissal.dismissInstalled and FileAccess.file_exists(paths[2]),"Original installed-row deletion dismisses the row without removing installed content outside LOCALVAULT")
	var dm: Dictionary=rows[2].duplicate(true); dm.isDM=true; check(not Mutation.reason(dm,ui.local_catalog.roots).is_empty(),"Unmigrated DM-vault ownership cannot accidentally delete a LOCALVAULT file")
	var outside: Dictionary=rows[0].duplicate(true); outside.nativeFile.path=install.path_join("data/lcv/wizard.bic"); check(not Mutation.reason(outside,ui.local_catalog.roots).is_empty(),"An out-of-root ticket is refused even when its bytes match")
	await click(ui.picker.shell.buttons.delete.get_global_rect().get_center()); var before:=requests.size(); lobby_state.choices=[]; lobby_state.selected=null; lobby_state.localRefreshAck=null; await present(2); dialog.buttons.okbutton.pressed.emit()
	check(FileAccess.file_exists(paths[3]) and requests.size()==before and ui.delete_lease.is_empty(),"A stale confirmation cannot delete a character after connection replacement")
	ui.close_native(); ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	for path in paths:
		if FileAccess.file_exists(path):
			check(FileAccess.get_sha256(path)==Hash.digest(bytes),"Only an unchanged owned BIC fixture is eligible for cleanup")
			if FileAccess.get_sha256(path)==Hash.digest(bytes): FileAccess.set_read_only_attribute(path,false); check(DirAccess.remove_absolute(path)==OK,"Only an unchanged owned BIC fixture is removed during cleanup")
	check(DirAccess.remove_absolute(folder)==OK,"The owned mutation fixture directory is empty and removed")
	var report:=FileAccess.open(output,FileAccess.WRITE); report.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"fullUiParity":false,"scope":"Original-resource native confirmation and actual pointer/No/Escape/Yes mutation of owned local BICs, changed-byte refusal, selection/connection ownership, raw refresh request and same-row reselection. Original installed/DM alias edge cases, sound, Customize and full visual/local-server admission remain open."},"  ")+"\n"); report.close(); quit(0 if failures.is_empty() else 1)
