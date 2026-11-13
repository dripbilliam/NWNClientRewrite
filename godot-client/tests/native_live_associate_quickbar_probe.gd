extends RefCounted
# Original bound39 UI -> native6/27 -> original associate event -> received
# exact henchman inventory. Client layout reflection is not a server ACK.
func rows(inventory) -> Array:
	return inventory.ui.items.values().map(func(row):return {"id":int(row.itemId),"channel":row.channel,"slot":row.slot,"x":row.x,"y":row.y,"baseItem":inventory.objects.get(int(row.itemId),{}).get("item",{}).get("baseItem"),"location":inventory.objects.get(int(row.itemId),{}).get("inventoryLocation")})
func stamp(observations: Array,phase: String) -> void:
	observations.append({"phase":phase,"mono_us":Time.get_ticks_usec(),"wall_ms":Time.get_unix_time_from_system()*1000.0,"process_frame":Engine.get_process_frames()})
func run(probe,controls,index: int) -> bool:
	var desktop=probe.desktop;var actor: int=desktop.actor_id;var epoch: int=desktop.generation;var previous: Dictionary=desktop.quick_bindings[index].duplicate(true);var speaker:=-1
	for id in desktop.objects:
		if int(desktop.objects[id].get("objectType",0))==5 and probe.ui.text.name(null,int(id))=="Native Speaker":speaker=int(id);break
	if not probe.check(speaker>=0,"Original associate fixture target is an actual disclosed creature"):return false
	probe.ui.chat.submit("-native-party-add")
	if not await probe.wait_for(func():return int(desktop.objects.get(speaker,{}).get("replicated",{}).get("master",2130706432))==actor,"Original AddHenchman publishes this specific actor as the associate master"):return false
	var binding:={"type":39,"intParam":-19,"associateType":1,"associateId":speaker};var expected: Dictionary=JSON.parse_string(JSON.stringify(previous.duplicate(true).merged(binding,true)))
	desktop.assign(index,binding)
	var reflected: bool=await probe.wait_for(func():return desktop.quick_bindings[index]==expected,"Client-owned39 layout publishes the exact command/type/associate fields")
	probe.check(reflected,"Original39 setter changes only its owned fields and retains the complete unrelated slot state",{"prior":previous,"current":desktop.quick_bindings[index].duplicate(true),"expected":expected,"ownedFields":binding})
	if not reflected:return false
	if not await controls.open(index):return false
	if not probe.check(desktop.radial_entries.size()==2 and desktop.radial_entries[3].label==probe.ui.text.raw({"strRef":3731}) and desktop.radial_entries[3].icon=="IR_INVENTORY" and desktop.radial_entries[4].action=="quickbar-clear","Actual bound henchman39 exposes original Inventory Use3 and Clear4"):return false
	var windows=probe.ui.inventory_windows;var inventory=windows.alternate
	windows.detailed_timings=true;windows.timing_rows.clear();inventory.detailed_timings=true;inventory.timing_rows.clear()
	var observations: Array=[];stamp(observations,"before-use-input")
	var sequence: int=probe.ui.chat.sequence;var started:=Time.get_ticks_usec();var prior_receipt: int=inventory.window_receipt
	if not await controls.choose(3):return false
	stamp(observations,"after-use-input-three-frames")
	if not await probe.wait_for(func():return probe.ui.chat.rows.any(func(row):return int(row.get("chat_sequence",0))>sequence and str(row.get("text","")).contains("NATIVE_ASSOC_COMMAND:-19:target=")),"Original associate event script observes command -19 on its real SELF/master"):return false
	var pattern:=RegEx.new();pattern.compile("NATIVE_ASSOC_COMMAND:(-?[0-9]+):target=([^:]+):master=([^\\s]+)");var observation: Dictionary={}
	for row in probe.ui.chat.rows:
		if int(row.get("chat_sequence",0))<=sequence:continue
		var match_value:=pattern.search(str(row.get("text","")))
		if match_value:observation={"command":int(match_value.get_string(1)),"targetHex":match_value.get_string(2),"masterHex":match_value.get_string(3)};break
	if not probe.check(not observation.is_empty() and observation.command==-19 and str(observation.targetHex).hex_to_int()==(speaker&2147483647) and str(observation.masterHex).hex_to_int()==(actor&2147483647),"Original event reports the exact requested command and native target/master identity",observation):return false
	if not await probe.wait_for(func():return inventory.window_receipt>prior_receipt and inventory.displayed_owner()==speaker and inventory.ui.wanted and windows.owner_snapshot("alternate").active,"Original13/1 publishes this exact henchman's alternate owner and opens its native view"):return false
	stamp(observations,"window-observed")
	if not await probe.wait_for(func():return inventory.ui.items.values().any(func(row):return row.channel=="I" and int(row.slot)==16 and int(inventory.objects.get(int(row.itemId),{}).get("item",{}).get("baseItem",-1))==0) and inventory.ui.items.values().any(func(row):return row.channel=="R" and int(row.y)==0 and int(inventory.objects.get(int(row.itemId),{}).get("item",{}).get("baseItem",-1))==61),"Original server supplies the authored equipped sword and first-page sling to the actual alternate controls"):
		probe.check(false,"Associate first-page disclosure diagnostic",{"window":windows.owner_snapshot("alternate"),"rows":rows(inventory),"inventories":inventory.inventories,"presented":inventory.ui.state});return false
	var first_rows: Array=rows(inventory)
	stamp(observations,"first-rows-observed")
	if not probe.check(inventory.displayed_owner()==speaker and first_rows.all(func(row):return int(row.location.ownerId)==speaker and row.location.channel in ["r","i"]) and int(probe.ui.inventory.containers.get("C",2130706432))!=speaker,"Canonical and actual alternate inventory retain the received associate owner",{"speakerId":speaker,"actorId":actor,"window":windows.owner_snapshot("alternate"),"rows":first_rows,"elapsedUsec":Time.get_ticks_usec()-started}):return false
	if not probe.check(desktop.actor_id==actor and desktop.generation==epoch,"Bound associate command retains its originating controlled actor and area lifetime"):return false
	stamp(observations,"before-page-input");var page_started:=Time.get_ticks_usec();await controls.click(inventory.ui.pages[1].get_global_rect().get_center());stamp(observations,"after-page-input-three-frames")
	if not await probe.wait_for(func():return inventory.page==1 and inventory.ui.items.values().any(func(row):return row.channel=="R" and int(row.y)==6 and int(inventory.objects.get(int(row.itemId),{}).get("item",{}).get("baseItem",-1))==27),"Physical alternate page sends original self=false and receives the authored second-page bullets"):
		probe.check(false,"Associate second-page disclosure diagnostic",{"window":windows.owner_snapshot("alternate"),"rows":rows(inventory),"page":inventory.page,"view":inventory.ui.state});return false
	if not probe.check(int(inventory.ui.state.page)==1 and inventory.ui.buttons.values().any(func(button):return not button.row.is_empty() and button.row.channel=="R" and int(button.row.y)==6),"Actual original alternate page controls present the current received second-page row",{"speakerId":speaker,"page":inventory.page,"rows":inventory.ui.items.values(),"elapsedUsec":Time.get_ticks_usec()-page_started}):return false
	stamp(observations,"second-rows-observed")
	var close_started:=Time.get_ticks_usec();await controls.click(inventory.ui.close_button.get_global_transform_with_canvas()*Vector2(8,8))
	if not await probe.wait_for(func():return not inventory.ui.wanted and not windows.owner_snapshot("alternate").active,"Physical native alternate X closes its own received-owner view"):return false
	probe.check(inventory.displayed_owner()==speaker,"Alternate local close retains original owner; typed13/1 close is a client notification, not a fabricated server acknowledgment",{"speakerId":speaker,"window":windows.owner_snapshot("alternate"),"elapsedUsec":Time.get_ticks_usec()-close_started})
	probe.check(true,"Alternate inventory timing boundaries retained",{"observations":observations,"windows":windows.timing_rows.duplicate(true),"rows":inventory.timing_rows.duplicate(true),"injected_input_frames":3,"headless_frame_cap":60,"scope":"Local monotonic durations and shared-system UTC wall stamps; control visibility/commit only, not GPU presentation. No polling/timer behavior change."})
	probe.ui.chat.submit("-native-party-remove")
	if not await probe.wait_for(func():return int(desktop.objects.get(speaker,{}).get("replicated",{}).get("master",2130706432))!=actor,"Original RemoveHenchman retires the actual received associate relationship"):return false
	# Original Clear changes only type/INT. Restore the previous associate fields
	# through their actual type39 setter before restoring the prior button type.
	var cleanup: Dictionary=previous.duplicate(true);cleanup.type=39
	var cleanup_expected: Dictionary=JSON.parse_string(JSON.stringify(cleanup))
	desktop.assign(index,cleanup)
	if not await probe.wait_for(func():return desktop.quick_bindings[index]==cleanup_expected,"Original39 setter restores its previous retained association fields"):return false
	desktop.assign(index,previous)
	return await probe.wait_for(func():return desktop.quick_bindings[index]==previous,"Associate39 restores every previous client-owned scratch binding field")
