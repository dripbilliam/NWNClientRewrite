extends "res://systems/lobby_pages_probe.gd"
# Owned local integration only. Uses the running controller/transport, never
# supplies a fabricated lobby acknowledgment or edits state to mimic success.
const TARGETS:=["local:nwn_delete_a.bic","local:nwn_delete_b.bic"]
func current_keys() -> Array:
	var ui=client.character_lobby
	return ui.picker.row_keys if is_instance_valid(ui.picker) else ui.native_chooser.row_keys
func row_button(key: String) -> Button:
	var ui=client.character_lobby
	return ui.picker.shell.rows[key] if is_instance_valid(ui.picker) else ui.native_chooser.rows[ui.native_chooser.row_keys.find(key)]
func delete_button() -> Button:
	var ui=client.character_lobby
	return ui.picker.shell.buttons.delete if is_instance_valid(ui.picker) else ui.native_chooser.buttons.deletecharbutton
func run(tree) -> void:
	client=tree
	var ui=client.character_lobby; var native=ui.native_chooser
	var ready: bool=await wait_until(func():return ui.can_select() and ui.native_selection.is_empty() and ui.confirmation!=null and ui.confirmation.layout_ready and TARGETS.all(func(key):return native.row_keys.has(key)),45)
	check(ready,"Original local server exposes both owned BIC copies to the actual native chooser")
	if ready:
		check(await wait_until(func():return native.frame.art.waiting.is_empty() and native.frame.art.models.pending.is_empty() and not native.frame.art.models.active and native.frame.fonts.pending.is_empty(),120),"Original connected chooser/confirmation artwork and fonts finish before visual review")
		check(not is_instance_valid(client.world) and not client.gameplay_ui.presentation_enabled,"Delete integration starts before character submission or world admission")
		var survivor: Dictionary={}
		for row in ui.state.choices:
			if row.key=="local:nwn_local_ui.bic": survivor=row.duplicate(true)
		check(not survivor.is_empty(),"A separate owned survivor is present for subsequent authoritative admission")
		for key in TARGETS:
			if key==TARGETS[1]:
				ui.enable_picker()
				if not check(await wait_until(func():return ui.picker.visible and ui.picker.shell.visible and not ui.picker.shell.pregen.disabled and ui.native_selection.is_empty(),45),"The production native picker opens on this same live connection without a fabricated state"): break
				if not current_keys().has(key):
					await click(ui.picker.shell.pregen)
				check(await wait_until(func():return current_keys().has(key) and ui.native_selection.is_empty()),"Production picker source filtering exposes the second owned character through actual checkbox input")
			var at: int=current_keys().find(key)
			if not check(at>=0,"Owned target retains its raw catalog identity: "+key): break
			var list: ScrollContainer=ui.picker.shell.list if is_instance_valid(ui.picker) else native.list
			list.ensure_control_visible(row_button(key)); await client.process_frame
			# Active TLK/metadata publication can rebuild the list on that frame.
			# Resolve the current opaque key instead of retaining a retired Control.
			at=current_keys().find(key)
			if not check(at>=0 and is_instance_valid(row_button(key)),"The current row is reacquired after scrolling: "+key): break
			await click(row_button(key))
			if not check(await wait_until(func():return ui.state.get("selected")==key and ui.native_selection.is_empty() and ui.delete_reason().is_empty()),"Native row click receives current selection acknowledgment before Delete: "+key): break
			var selected: Dictionary=ui.selected_local_row(); var file_path: String=str(selected.nativeFile.path); var digest: String=str(selected.nativeFile.sha256)
			check(FileAccess.file_exists(file_path) and FileAccess.get_sha256(file_path)==digest,"Owned file bytes match the raw ticket before confirmation: "+key)
			if key==TARGETS[0]:
				await click(delete_button())
				check(ui.confirmation.visible and not ui.delete_lease.is_empty() and native.buttons.playbutton.disabled,"Source Delete opens its owned original modal and blocks competing Play")
				await RenderingServer.frame_post_draw
				check(client.root.get_texture().get_image().save_png(str(client.args.report).trim_suffix(".json")+".delete-confirmation.png")==OK,"Actual connected native confirmation viewport is retained for visual review")
				await click(ui.confirmation.buttons.cancelbutton)
				check(ui.delete_lease.is_empty() and FileAccess.file_exists(file_path) and ui.state.get("localRefreshAck")==null,"Actual Cancel preserves the file and sends no catalog refresh")
				await click(delete_button())
				for pressed in [true,false]:
					var event:=InputEventKey.new(); event.keycode=KEY_ESCAPE; event.physical_keycode=KEY_ESCAPE; event.pressed=pressed; client.root.push_input(event,true); await client.process_frame
				check(ui.delete_lease.is_empty() and FileAccess.file_exists(file_path) and not ui.confirmation.visible,"Escape cancels the running client's modal without touching the owned file")
			var before: Array=current_keys().duplicate(); var selected_index: int=before.find(key); before.erase(key)
			var expected: String=str(before[mini(selected_index,before.size()-1)]) if not before.is_empty() else ""
			await click(delete_button())
			if not check(ui.confirmation.visible,"A fresh native confirmation is available after cancellation: "+key): break
			await click(ui.confirmation.buttons.okbutton)
			check(not FileAccess.file_exists(file_path),"Accepted native Delete removes exactly the owned loose BIC: "+key)
			var settled: bool=await wait_until(func():return ui.delete_lease.is_empty() and ui.local_catalog.ready() and not current_keys().has(key) and ui.native_selection.is_empty() and ui.state.get("selected")==expected,45)
			if not check(settled,"Real host rescan/acknowledgment and native metadata settle into original row-reselection policy: "+key): break
			var ack: Dictionary=ui.state.get("localRefreshAck",{})
			check(ack.get("connection")==ui.connection and ack.get("key")==key and ack.get("accepted",true) and int(ack.get("requestId",0))>0,"Received raw service acknowledgment retains connection/key/nonce ownership: "+key)
			check(not ui.state.choices.any(func(row):return row.key==key) and not ui.local_catalog.values.has(key),"Deleted row leaves both raw membership and native BIC metadata: "+key)
			check(not ui.confirmation.visible and not is_instance_valid(client.world),"Completed Delete dismisses the original modal without entering the world: "+key)
		if not survivor.is_empty():
			check(FileAccess.file_exists(str(survivor.nativeFile.path)) and FileAccess.get_sha256(str(survivor.nativeFile.path))==str(survivor.nativeFile.sha256),"Both deletions preserve the separate admission character byte-for-byte")
		await RenderingServer.frame_post_draw
		check(client.root.get_texture().get_image().save_png(str(client.args.report).trim_suffix(".json")+".delete-settled.png")==OK,"Refreshed connected chooser viewport is retained after actual IPC")
		if is_instance_valid(ui.picker):
			await click(ui.picker.shell.buttons.details)
			check(await wait_until(func():return native.record.is_visible_in_tree()),"Production Character Details returns to its original native record before independent BIC/action checks")
	var result:={"success":checks.size()>=18 and checks.all(func(row):return row.passed),"checks":checks,"publicConnections":0,"endpoint":"127.0.0.1:5125","scope":"Original local server, actual original-style and production native chooser pointer/key events, native owned-file deletion and real raw-catalog IPC/acknowledgment before normal authoritative admission. Role/scale/sound/Customize and full UI parity remain separate acceptance gaps."}
	client.report.local_delete=result; client.send({"kind":"native-local-delete-proof","success":result.success,"checks":checks}); running=false
