extends RefCounted
# View-only scoped binding for the six source-proven mode1 title callers.
# It never resolves names, changes a draft, resizes a source box or adds a font.
const Context=preload("res://systems/native_data/level_up_title_context.gd")
const CALLERS={"domains":"0x1409cc0f0","associate":"0x1409cc4f0","feats":"0x1409cc890","school":"0x1409ccb40","skills":"0x1409cce50","spells":"0x1409cd040"}
var target: WeakRef
var owner: WeakRef
var identity: Array=[]
var original_caption:=""
var first_line:=""
var applied_text:=""
var key:=""
static func pending(reason: String) -> Dictionary:return {"ready":false,"reason":reason}
static func locate(pane: Control,stage: String,source_caption: String) -> Dictionary:
	if not CALLERS.has(stage):return pending("This pane has no verified mode1 title-prefix caller.")
	if not is_instance_valid(pane) or not pane.layout_ready:return pending("Original title controls are still being prepared.")
	var parent: Control=pane.content if stage in ["associate","spells"] else pane
	if not is_instance_valid(parent):return pending("Original title container is unavailable.")
	var entry: Dictionary=pane.plan.entries.title
	var found: Array=[]
	for child in parent.get_children():
		if child is Label and child.text==source_caption:
			var expected_font: String=str(entry.get("caption",{}).get("AurString_Font",""))
			if str(child.get_meta("native_font_resource",""))==expected_font:found.append(child)
	if found.size()!=1:return pending("Original source title identity is missing or ambiguous.")
	return {"ready":true,"label":found[0],"entry":entry,"caller":CALLERS[stage]}
static func actual_first_line(label: Label) -> Dictionary:
	if not is_instance_valid(label):return pending("Original title label is unavailable.")
	if str(label.get_meta("native_font_applied","")).is_empty():return pending("Original title font is still being prepared.")
	# Current source title controls are unwrapped. Do not guess a wrapped first
	# line or replace it with a string split when the real rendered line differs.
	if label.autowrap_mode!=TextServer.AUTOWRAP_OFF or label.get_line_count()>1 or "\n" in label.text or "\r" in label.text or label.text.to_utf8_buffer().has(0):return pending("Actual single source-caption line is unavailable.")
	return {"ready":true,"text":label.text}
func begin(pane: Control,stage: String,source_caption: String,scope: Array) -> Dictionary:
	# An old prepared/font callback must not retire or relabel a newer menu.
	if scope.is_empty() or not is_instance_valid(pane) or not pane.wanted or pane.scope!=scope:return pending("Exact current level-up title identity is unavailable.")
	retire()
	var located:=locate(pane,stage,source_caption)
	if not located.ready:return located
	var line:=actual_first_line(located.label)
	if not line.ready:return line
	target=weakref(located.label);owner=weakref(pane);identity=scope.duplicate();key=stage;original_caption=source_caption;first_line=line.text
	return {"ready":true,"caption":first_line,"caller":CALLERS[stage]}
func current(scope: Array) -> bool:
	return not identity.is_empty() and identity==scope and target!=null and is_instance_valid(target.get_ref()) and owner!=null and is_instance_valid(owner.get_ref()) and owner.get_ref().wanted and owner.get_ref().scope==scope
func present(parts: Variant,classes: Variant,tables: Dictionary,text,scope: Array) -> Dictionary:
	if not current(scope):return pending("Level-up title scope is stale.")
	var label: Label=target.get_ref()
	if label.text!=original_caption and (applied_text.is_empty() or label.text!=applied_text):return pending("Another owner replaced the title caption.")
	var value:=Context.compose(parts,classes,first_line,tables,text)
	if not value.ready:
		if not applied_text.is_empty() and label.text==applied_text:label.text=original_caption
		applied_text=""
		return value
	if label.text!=value.text:label.text=value.text
	applied_text=value.text
	return {"ready":true,"text":applied_text,"caller":CALLERS[key],"scope":identity.duplicate(),"runtimeIntegrated":false,"geometryChangedByHelper":false}
func retire() -> void:
	if target!=null and is_instance_valid(target.get_ref()):
		var label: Label=target.get_ref()
		if not applied_text.is_empty() and label.text==applied_text:label.text=original_caption
	target=null;owner=null;identity=[];original_caption="";first_line="";applied_text="";key=""
