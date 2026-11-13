extends "res://tests/native_creation_ui_test.gd"
# Actual shipping creator/input and first-level BIC builder, without a rendered
# preview or network. Original CPU evidence is independently pinned below.
const ORIGINAL="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
const ORACLE="a5abe6c710fd231733a15b698890661d085e960eaa2649a66d932c5303fc0820"
var surface: SubViewport
func check(value: bool,label: String,details: Variant=null) -> bool:
	checks+=1
	if not value: failures.append({"label":label,"details":details}); print("CREATION CHECK FAILED: "+label+" "+JSON.stringify(details))
	return value
func frames(count: int=3) -> void:
	for index in count: await process_frame
func key(code: Key) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed; surface.push_input(event,true); await frames()
func click(control: Control) -> void:
	var point:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; surface.push_input(motion,true); await frames()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0; surface.push_input(event,true); await frames()
func page(creator,index: int) -> void:
	await click(creator.view.tabs[index]); await frames()
	check(creator.step==index,"Physical sidebar input selects creator page "+str(index),creator.step)
func control_for(creator,operation: String,choice: Variant=null) -> Control:
	for id in creator.controls:
		var entry: Dictionary=creator.controls[id]
		if entry.operation==operation and (choice==null or entry.value==choice):
			var target: Control=creator.view.controls.get(id)
			if is_instance_valid(target):
				creator.view.scroll.ensure_control_visible(target); await frames(); return target
	return null
func choose(creator,operation: String,choice: Variant=null) -> bool:
	var target: Control=await control_for(creator,operation,choice)
	if not check(target!=null and target is BaseButton and not target.disabled,"Live input control exists: "+operation,choice): return false
	await click(target); return true
func recommend(creator) -> void:
	await click(creator.view.recommend)
	check(await wait_for(func():return creator.phase=="editing"),"Package recommendations finish in the native draft owner",creator.status)
func pick_domain(creator,index: int,second: bool) -> void:
	var target: Control=await control_for(creator,"domain-"+str(index))
	if not check(target is OptionButton,"Actual domain selector exists",index): return
	var desired:=1 if second else 0
	var option: OptionButton=target; var popup:=option.get_popup(); await click(option)
	if not check(popup.visible,"Physical click opens the domain popup",index): return
	# The embedding viewport forwards these through Window::_window_input;
	# pushing directly to PopupMenu bypasses its internal menu navigation.
	for attempt in popup.item_count+1:
		if popup.get_focused_item()==desired: break
		for pressed in [true,false]:
			var event:=InputEventKey.new(); event.keycode=KEY_DOWN; event.physical_keycode=KEY_DOWN; event.pressed=pressed; surface.push_input(event,true); await frames()
	for pressed in [true,false]:
		var event:=InputEventKey.new(); event.keycode=KEY_ENTER; event.physical_keycode=KEY_ENTER; event.pressed=pressed; surface.push_input(event,true); await frames()
func oracle(path: String) -> void:
	check(FileAccess.get_sha256(path)==ORACLE,"Original reset corpus is unchanged")
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(data is Dictionary and data.binarySha256==ORIGINAL and data.entry=="0x1407edcc0","Complete original reset and pinned binary identify the corpus"): return
	for row in data.rows:
		var out: Dictionary=row.output; var input: Dictionary=row.input; var valid:=int(out.points)==0 and int(out.budget)==int(input.budget)
		valid=valid and int(out.granted)==0 and int(out.pending)==0 and int(out.resources)==0
		for n in 9:
			var expected: Array=[255,255] if n<mini(8,int(input.classes)) else [n+10,n+30]
			valid=valid and out.domains[n].map(func(value):return int(value))==expected
		for n in 255: valid=valid and int(out.ranks[n])==0 and int(out.additions[n])==0
		valid=valid and int(out.ranks[255])==17 and int(out.additions[255])==18
		for count in out.known: valid=valid and int(count)==0
		for values in out.memorized: valid=valid and values.all(func(value):return int(value)==0)
		var expected_feats: Array=[]
		if int(input.featCount)>0:
			var racial: bool=int(input.firstLevel)==1 and int(input.racialAdjustment)==0
			if racial: expected_feats.append(1)
			if racial or int(input.level)==1: expected_feats.append(2)
			if int(input.level)==2: expected_feats.append(3)
			if int(input.level)==1: expected_feats.append(4)
		valid=valid and out.feats.map(func(value):return int(value))==expected_feats
		check(valid,"Executed original reset clears chosen state and domains, classes="+str(int(input.classes)),input)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("install") or not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report): quit(2); return
	oracle(args.oracle)
	surface=SubViewport.new(); surface.size=Vector2i(1600,1000); surface.disable_3d=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; surface.gui_embed_subwindows=true; root.add_child(surface)
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original install mounts read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg"); ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator; creator.open(41)
	if check(await wait_for(func():return creator.phase=="editing",90),"Actual shipping native creator loads original active rules",creator.resource_errors):
		await frames()
		var cleric:=-1; var fighter:=-1
		for id in creator.rules.rows("classes").size():
			var label:=str(creator.rules.cell(creator.rules.row("classes",id),"Label","")).to_lower()
			if label=="cleric": cleric=id
			if label=="fighter": fighter=id
		check(cleric>=0 and fighter>=0,"Actual classes table supplies Cleric and Fighter")
		for operation in ["ability","alignment","race","class"]:
			await page(creator,3); await choose(creator,"class",cleric); await recommend(creator)
			await page(creator,7); await pick_domain(creator,0,false); await pick_domain(creator,1,true)
			check(creator.rules.draft.domains==[0,1],"Physical domain popup keyboard input commits both choices",creator.rules.draft.domains)
			# Preserve unrelated draft input while source-derived choices retire.
			creator.rules.draft.firstName="Reset"; creator.rules.draft.lastName="Proof"; creator.rules.draft.biography="Keep this text"
			creator.rules.draft.familiarName="Keep familiar"; creator.rules.draft.companionName="Keep companion"
			var preserved: Dictionary=creator.rules.draft.duplicate(true)
			match operation:
				"ability": await page(creator,6); await choose(creator,"ability",["Str",-1])
				"alignment": await page(creator,4); await choose(creator,"alignment",4)
				"race": await page(creator,1); await choose(creator,"race",int(creator.rules.draft.raceId))
				"class": await page(creator,3); await choose(creator,"class",fighter)
			var d: Dictionary=creator.rules.draft
			check(d.domains.is_empty() and d.skills.is_empty() and d.feats.is_empty() and d.memorized.is_empty() and d.known.get(1,[]).is_empty(),"Actual "+operation+" input retires domains and derived selections",d.domains)
			# The independently verified original Race OK resets Biography even
			# when accepting the same race; CG_MAIN's derived-choice reset alone
			# does not. Other choice actions preserve the authored biography.
			var biography: String=ui.text.raw({"strRef":creator.rules.num(creator.rules.race(),"Biography",4294967295)}) if operation=="race" else preserved.biography
			check(d.firstName==preserved.firstName and d.lastName==preserved.lastName and d.biography==biography and d.familiarName==preserved.familiarName and d.companionName==preserved.companionName and d.school==preserved.school and d.soundset==preserved.soundset and d.portrait==preserved.portrait,"Derived "+operation+" reset preserves unrelated authored fields and original Race biography policy")
			if operation!="class": check(creator.rules.errors().has("Choose two different domains."),"Invalidated Cleric choices require fresh domains before Play")
		await recommend(creator)
		var builder:=Builder.new(); var bytes:=builder.build(creator.rules); var parser:=Gff.new(); var document:=parser.parse(bytes,"BIC ")
		if check(not bytes.is_empty() and builder.failure.is_empty() and parser.failure.is_empty(),"Real first-level BIC builds after switching from Cleric to Fighter",[builder.failure,parser.failure]):
			var selected: Dictionary=document.root.ClassList[0]
			check(selected.Class==fighter and selected.ClassLevel==1 and not selected.has("Domain1") and not selected.has("Domain2") and not selected.has("School"),"Serialized replacement class omits original inactive school/domain fields",selected)
			var class_record:=-1
			for id in document.records:
				if is_same(document.records[id],selected): class_record=int(id)
			check(class_record>=0 and int(document.struct_types[class_record])==0,"First-level ClassList record uses original client struct type0")
			check(document.root.FirstName.get("entries",[]).any(func(entry):return entry.text=="Reset") and document.root.Description.get("entries",[]).any(func(entry):return entry.text=="Keep this text"),"Actual serialized BIC retains the unrelated text fields")
		for label in ["cleric","wizard"]:
			var class_id:=-1
			for id in creator.rules.rows("classes").size():
				if str(creator.rules.cell(creator.rules.row("classes",id),"Label","")).to_lower()==label: class_id=id
			await page(creator,3); await choose(creator,"class",class_id); await recommend(creator)
			builder=Builder.new(); bytes=builder.build(creator.rules); parser=Gff.new(); document=parser.parse(bytes,"BIC ")
			if check(not bytes.is_empty() and builder.failure.is_empty() and parser.failure.is_empty(),"Real "+label+" first-level BIC still validates after draft replacement",[builder.failure,parser.failure]):
				var selected: Dictionary=document.root.ClassList[0]; var draft: Dictionary=creator.rules.draft
				if label=="cleric": check(selected.Domain1==draft.domains[0] and selected.Domain2==draft.domains[1] and not selected.has("School"),"Active domain-picking class serializes its newly recommended domains only",selected)
				else: check(selected.School==draft.school and not selected.has("Domain1") and not selected.has("Domain2"),"Active school-picking class serializes School without stale domains",selected)
		var stale_view: int=creator.serial
		creator.cancel(); creator.open(42); await wait_for(func():return creator.phase=="editing",90)
		var before: Dictionary=creator.rules.draft.duplicate(true)
		creator.input({"operation":"control","viewId":stale_view,"controlId":0})
		check(creator.rules.draft==before and creator.connection==42,"Retired draft controls cannot reset the replacement connection's choices")
	check(not sent.any(func(message):return message.kind=="native-creation-submit"),"Input and BIC verification do not connect or upload any character")
	ui.close(); ui.free(); surface.queue_free(); await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Complete original CPU reset observations, actual shipping native creator mouse/keyboard draft actions and first-level BIC serialization. No original-window pixels, public connection, existing-character editing or server admission acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
