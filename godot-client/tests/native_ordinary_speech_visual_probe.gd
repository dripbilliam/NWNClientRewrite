extends Node
# This probe authors no text, input, pose, camera, visibility or clock.
# Inherited admission is automated; session input origin remains unproven.
var client
var scope: Dictionary={}
var started_ms:=0
var next_sample_ms:=0
var hold_seconds:=120
var ended:=false
func run(value,seconds: int)->void:
	client=value;hold_seconds=seconds
	scope={"connection":client.session_connection,"generation":client.epoch,"areaId":client.world.area_id}
	started_ms=Time.get_ticks_msec();next_sample_ms=started_ms+1000
	process_priority=120
	client.send(packet("ordinary-speech-visual-ready"))
	set_process(true)
func current()->bool:
	return is_instance_valid(client) and not client.closing and client.session_connection==scope.connection and client.cancelled_connection!=scope.connection and client.epoch==scope.generation and is_instance_valid(client.world) and client.world.area_id==scope.areaId
func packet(kind: String)->Dictionary:
	var data:={"kind":kind,"scope":scope.duplicate(),"seconds":hold_seconds,"elapsedMs":Time.get_ticks_msec()-started_ms,"probeAutomaticStimulus":false,"automaticAdmission":true,"sessionInputOrigin":"unproven","pixelAcceptance":false,"performanceAcceptance":false}
	if not current():return data
	var ui=client.gameplay_ui
	data.window={"screen":client.root.current_screen,"primary":DisplayServer.get_primary_screen(),"unfocusable":client.root.unfocusable,"focused":client.root.has_focus(),"mouseMode":Input.mouse_mode,"startup":client.report.get("startup_window",{}).duplicate(true)}
	data.areaBorder=client.world.borders.snapshot() if is_instance_valid(client.world.borders) else {"started":false}
	data.popupPreferences=ui.popup_settings().duplicate(true)
	data.speech=[]
	if is_instance_valid(ui.overhead):
		for id in ui.overhead.views:
			if data.speech.size()>=8:break
			var view=ui.overhead.views[id]
			if not is_instance_valid(view):continue
			var slot: Dictionary=ui.overhead_popup_registry.slots.get(id,{})
			var record: Dictionary=slot.get("caption",{})
			data.speech.append({"id":id,"viewInstance":view.get_instance_id(),"visible":view.is_visible_in_tree(),"layoutReady":view.layout_ready,"font":view.font_resource,"position":[view.position.x,view.position.y],"size":[view.size.x,view.size.y],"captionUtf8":Array(view.caption.get_parsed_text().to_utf8_buffer()).slice(0,2048),"mode":record.get("mode"),"remaining":record.get("remaining"),"registered":record.get("guiRegistered"),"registryOrdinal":slot.get("ordinal")})
	data.chatRows=ui.chat.rows.size() if is_instance_valid(ui.chat) else 0
	return data
func _process(_delta: float)->void:
	if ended:return
	if not current():
		ended=true;set_process(false)
		if is_instance_valid(client) and not client.closing:client.fail("Visual inspection scope retired")
		return
	var now:=Time.get_ticks_msec()
	if now-started_ms>=hold_seconds*1000:
		ended=true;set_process(false);client.send(packet("ordinary-speech-visual-finished"));return
	if now>=next_sample_ms:
		next_sample_ms=now+1000
		client.send(packet("ordinary-speech-visual-sample"))
