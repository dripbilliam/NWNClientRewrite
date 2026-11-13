extends SceneTree
# Deferred focused native UI/state fixture, no server/assets/native library.
# SOURCE ONLY: Root/user has not approved running tests yet.
const Fit=preload("res://tools/native_parity/ui/conversation_viewport.gd")
const Conversation=preload("res://systems/server_conversation.gd")
class Art extends RefCounted:
	var textures: Dictionary={}
	var bound_portrait:=""
	func bind_portrait(_control,resource: String) -> void:bound_portrait=resource
class Frame extends RefCounted:
	var art=Art.new()
	func font_style(_control,_caption) -> void:pass
class TextOwner extends RefCounted:
	var objects: Dictionary={}
	func name(_source,_speaker) -> String:return "Speaker"
	func raw(_source) -> String:return "Speaker"
	func rich(source: Dictionary,_speaker) -> Dictionary:return source
class Ui extends RefCounted:
	var text=TextOwner.new()
class DialogSkin:
	extends "res://systems/native_conversation_frame.gd"
	var measured: Array=[]
	func reflow(entry_height: float,reply_height: float,clearance: float) -> void:
		# Asset-free fixture records the real frame's measurement path. Native
		# Plan.layout/art/rail publication remains the existing separate UI gate.
		measured=[entry_height,reply_height,clearance]
var checks:=0
var failures: Array=[]
var sent: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for scale_value in [1.0,1.25,2.0,3.0]:
		var canvas:=Transform2D(0,Vector2.ZERO).scaled(Vector2.ONE*scale_value)
		var viewport:=Rect2(Vector2.ZERO,Vector2(1200,900))
		var available:=Fit.space(viewport,canvas)
		check(not available.is_empty() and available.bounds.size.y<900/scale_value,"Logical viewport respects parent UI scale")
		var size:=Vector2(360,404)
		var location:=Fit.clamp_position(available,Vector2(1100,850),size)
		var global_rect: Rect2=canvas*Rect2(location,size*float(available.scale))
		check(viewport.encloses(global_rect),"Clamped dialog remains wholly inside physical viewport")
		check(scale_value<3 or float(available.scale)<1,"Tiny logical viewport uses uniform constrained-only fit")
	check(Fit.reply_width(331)=={"total":331.0,"indent":20.0,"text":311.0,"number":16.0},"Native number/text column widths remain unchanged")
	check(Fit.reply_width(150).text==130 and Fit.reply_width(150).total==150,"Wrapped labels use actual reply viewport width")
	check(Fit.space(Rect2(Vector2.ZERO,Vector2.ZERO),Transform2D.IDENTITY).is_empty(),"Unavailable viewport cannot publish invalid geometry")
	root.size=Vector2i(1200,900)
	var canvas:=Control.new();root.add_child(canvas);canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dialog:=Conversation.new();canvas.add_child(dialog);dialog.setup("");dialog.request.connect(func(message):sent.append(message.duplicate(true)))
	var skin:=DialogSkin.new();root.add_child(skin);skin.set_process(false);skin.ui=Ui.new();skin.frame=Frame.new();skin.view=dialog;dialog.native_skin=skin;dialog.rendered.connect(skin.changed)
	dialog.present({"kind":"dialog-entry","speakerId":3,"rich":{"text":"A long speaker entry ".repeat(12)}})
	dialog.present({"kind":"dialog-replies","entryId":17,"replies":[{"id":44,"available":true,"rich":{"text":"A long received reply ".repeat(15)}},{"id":55,"available":false,"rich":{"text":"Read-only"}}]})
	skin.activate()
	skin.geometry={"entry":Rect2(85,25,261,100),"replies":Rect2(12,150,331,180)}
	skin.entry_scroll.size=Vector2(261,100);skin.reply_scroll.size=Vector2(331,180)
	skin.sync_text_widths();await process_frame;await process_frame;skin._process(0)
	var button: Button=dialog.replies.get_child(0);var label: RichTextLabel=button.get_child(0)
	check(label.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART and label.size.x==311,"Native reply wraps at its measured content viewport")
	check(button.custom_minimum_size.y>=label.get_content_height() and label.get_content_height()>20,"Wrapped reply click height includes every rendered line")
	skin.reply_scroll.size.x=180;skin.sync_text_widths();await process_frame;await process_frame;skin._process(0)
	check(label.size.x==160 and button.custom_minimum_size.x==180 and button.custom_minimum_size.y>=label.get_content_height(),"Narrow viewport cannot retain stale331px/311px hit and label widths")
	dialog.position=Vector2(60,70);canvas.scale=Vector2.ONE*1.25;skin._process(0)
	check(not skin.measured.is_empty() and skin.measured[2]<700,"Scaled frame measures logical clearance instead of physical900px")
	check(skin.portrait.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"Speaker portrait keeps its aspect convention")
	var before:=sent.size();dialog.replies.get_child(1).pressed.emit();check(sent.size()==before,"Disabled reply remains nonselectable")
	dialog.replies.get_child(0).pressed.emit();check(sent.size()==before+1 and sent.back()=={"kind":"reply","entryId":17,"replyId":44,"abort":false},"Layout preserves authoritative reply IDs and pending behavior")
	dialog.present({"kind":"dialog-entry","speakerId":3,"rich":{"text":"Replacement entry"}})
	dialog.present({"kind":"dialog-replies","entryId":18,"replies":[{"id":77,"available":true,"rich":{"text":"Replacement ".repeat(20)}}]})
	skin.reply_scroll.size.x=180;skin.sync_text_widths();await process_frame;await process_frame;skin._process(0)
	check(dialog.replies.get_child_count()==1 and dialog.replies.get_child(0).custom_minimum_size.y>=dialog.replies.get_child(0).get_child(0).get_content_height(),"Replacement rows recalculate height under a new serial")
	# Manual teardown avoids invoking the full skin owner's real art/font API in
	# this deliberately asset-free fixture. The real native UI gate still owns it.
	skin.closed=true;skin.free();dialog.free();canvas.free()
	print("NATIVE_PARITY_CONVERSATION_VIEWPORT ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
