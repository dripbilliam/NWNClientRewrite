extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Plan=preload("res://systems/native_data/video_options_layout.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func names(root_node: Dictionary,found: Dictionary) -> void:
	var name:=str(root_node.get("Obj_ResRef","")).to_lower()
	if not name.is_empty(): found[name]=true
	for child in root_node.get("Obj_ChildList",[]): names(child,found)
func bits(value: float) -> int:
	var data:=PackedByteArray(); data.resize(4); data.encode_float(0,value); return data.decode_u32(0)
func double_bits(value: float) -> String:
	var data:=PackedByteArray(); data.resize(8); data.encode_double(0,value); return data.hex_encode()
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var models: Dictionary={}; var hashes: Dictionary={}; var definition: Dictionary={}
	check(catalog.mount_install(install),"Original video resources mount read-only")
	if failures.is_empty():
		var raw: PackedByteArray=catalog.get_resource("options_vidmodes",2047); var parser:=Gff.new(); var document:=parser.parse(raw,"GUI ")
		check(parser.failure.is_empty(),"Original Resolution/UI Scaling GUI parses")
		hashes.options_vidmodes=Cache.digest(raw)
		if parser.failure.is_empty():
			var requested: Dictionary={}; names(document.root,requested)
			for name in requested:
				var source: PackedByteArray=catalog.get_resource(name,2002); var reader:=Actor.new(); var model:=reader.parse(source)
				check(reader.failure.is_empty(),"Original video component model parses: "+str(name))
				models[name]=model; hashes[name]=Cache.digest(source)
			if failures.is_empty():
				var before: Dictionary=document.root.duplicate(true); definition=Plan.parse(document.root,models)
				check(str(definition.error).is_empty(),"Original nested video controls resolve against their source models")
				if str(definition.error).is_empty():
					check(document.root==before and definition.entries.size()==13,"All13 original child controls remain immutable and distinct")
					check(definition.entries.intedit.editable==false and definition.entries.intedit.floating,"Original IntEdit remains a display label rather than an invented editable field")
					check(not definition.entries.videomodelist.initial_enabled and definition.entries.intlabel.runtime_class=="CGuiCharGenLabel","Runtime source distinguishes its initially disabled mode list and display-only scale label from GUI type metadata")
					for tag in Plan.ACTIONS: check(definition.entries[tag].callback==Plan.ACTIONS[tag],"Original video callback metadata is preserved: "+str(tag))
					var expected: Vector2=definition.entries.intlabel.offset+Vector2(308,-30)
					check(definition.entries.intedit.anchor.distance_to(expected)<0.001,"Nested scale display inherits its source parent placement")
					var moved: Dictionary=document.root.duplicate(true)
					for child in moved.Obj_ChildList:
						if str(child.Obj_Tag).to_lower()=="intlabel": child.Obj_X+=0.25
					var changed:=Plan.parse(moved,models)
					check(str(changed.error).is_empty() and changed.entries.intupbutton.rect.position.distance_to(definition.entries.intupbutton.rect.position+Vector2(25,0))<0.001 and changed.entries.intedit.anchor.distance_to(definition.entries.intedit.anchor+Vector2(25,0))<0.001,"Active GUI parent replacement relocates both nested arrows and scale text")
					var missing:=models.duplicate(); missing.erase("ctl_btn_uiscale")
					check(not str(Plan.parse(document.root,missing).error).is_empty(),"A missing original nested scale model fails before exposing a partial page")
					var missing_control: Dictionary=document.root.duplicate(true)
					for child in missing_control.Obj_ChildList:
						if str(child.Obj_Tag).to_lower()=="intlabel": child.Obj_ChildList.pop_front()
					check(not str(Plan.parse(missing_control,models).error).is_empty(),"Missing nested scale text is explicit rather than a guessed widget")
					check(definition.native_data_only and not definition.visible_video_accepted and not definition.display_mode_changes_accepted and not definition.full_video_parity,"Data/float checks do not certify a visible or working resolution page")
	var oracle_path:=ProjectSettings.globalize_path("res://../backups/animations/native-video-scale-observations-v2.json")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Independent scale oracle pins the original binary")
	for row in oracle.desired: check(bits(Plan.desired_scale(int(row.width),int(row.height),row.unconstrained))==int(row.bits),"Desired scale matches unchanged original instructions: "+str([row.width,row.height,row.unconstrained]))
	for row in oracle.steps: check(bits(Plan.scale_step(float(row.value),row.increase,float(row.minimum),float(row.maximum)))==int(row.bits),"Arrow stepping/clamp order matches unchanged original instructions: "+str([row.value,row.minimum,row.maximum,row.increase]))
	for row in oracle.updates:
		var state:=Plan.scale_update(int(row.width),int(row.height),float(row.fixed),float(row.previous),row.unconstrained)
		check(bits(state.maximum)==int(row.bits.maximum) and bits(state.scale)==int(row.bits.scale) and bits(state.gui_to_pixel)==int(row.bits.guiToPixel) and state.refresh_fonts==row.refreshFonts,"Scale update, pixel conversion and font-refresh threshold match original: "+str([row.width,row.height,row.fixed,row.previous,row.unconstrained]))
	var decimal_observations: Array=[]
	for row in oracle.applies:
		# Compare the original captured double bits, not a second JSON decimal
		# conversion: that conversion changes some exact float-promoted doubles.
		var written:=double_bits(Plan.f(float(row.value)))
		check(bits(Plan.fixed_override(float(row.value),float(row.maximum)))==int(row.bits) and written==str(row.writtenDoubleBits),"Apply distinguishes automatic/fixed scale and preserves the original persisted float: "+str([row.value,row.maximum]))
		if double_bits(float(row.writtenValue))!=str(row.writtenDoubleBits): decimal_observations.append({"input":row.value,"original_bits":row.writtenDoubleBits,"parsed_decimal_bits":double_bits(float(row.writtenValue)),"native_bits":written})
	var mode_rows: Array=[{"width":640,"height":480,"refresh":60,"depth":32},{"width":1920,"height":1080,"refresh":60,"depth":32},{"width":1920,"height":1080,"refresh":75,"depth":32},{"width":1920,"height":1080,"refresh":60,"depth":16},{"width":800,"height":600,"refresh":0,"depth":32},{"width":1920,"height":599,"refresh":60,"depth":32}]
	var before_modes:=mode_rows.duplicate(true); var modes:=Plan.display_modes(mode_rows)
	check(modes.size()==3 and modes.all(func(row):return row.width>=800 and row.height>=600),"Original video-mode minimum dimensions and duplicate strings apply")
	check(modes[0].refresh==75 and modes[1].refresh==60 and modes[2].width==800,"Native mode ordering follows original SDL dimensions/depth/refresh priority")
	check(modes[0].label=="1920x1080 75hz" and modes[2].label=="800x600 0hz","Mode captions preserve the original format including unknown refresh values")
	check(mode_rows==before_modes,"Mode presentation leaves native enumeration metadata immutable")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"resourceSha256":hashes,"definition":definition,"oracleSha256":FileAccess.get_sha256(oracle_path),"decimal_roundtrip_observations":decimal_observations,"publicConnections":0,"visibleVideoAccepted":false,"fullVideoParity":false,"scope":"Original installed video page layout/callback data and437 original-instruction float cases only. Actual native video page, monitor-mode enumeration, display changes, scale propagation, Apply/Cancel integration and direct original-window comparison remain unfinished."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
