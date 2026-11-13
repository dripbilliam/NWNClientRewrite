extends SceneTree
const Text=preload("res://systems/native_data/nameplate_text.gd")
const Plate=preload("res://systems/native_nameplate.gd")
const ORIGINAL:="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
const CORPUS:="af16c4ae9ca9f94df07d4486fe91cee319eef64ce8d44a854804ef3e727d8e81"
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label_text: String,detail: Variant=null) -> void:
	checks+=1
	if not value and failures.size()<24:failures.append({"label":label_text,"detail":detail})
func word(value: float) -> String:return PackedFloat32Array([value]).to_byte_array().hex_encode()
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report):quit(2);return
	check(FileAccess.get_sha256(args.oracle)==CORPUS,"Original text observation corpus is immutable")
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(corpus.target==ORIGINAL and corpus.rows.size()==459,"Pinned original plain-text width/wrap instructions execute for459 authored atlas cases")
	for row in corpus.rows:
		var source: Dictionary=row.input;var before:=JSON.stringify(source)
		var metrics:={"glyphs":source.glyphs,"default":source.default,"spacing":source.spacing}
		for expected in row.measures:
			var actual:=Text.measure(source.text,float(source.width),metrics,bool(expected.wrapping))
			check(actual.overflow==expected.overflow and actual.visible==int(expected.visible) and word(actual.width)==word(expected.width),"Complete original visible-width observation",{"source":source,"expected":expected,"actual":actual})
		var wrapped:=Text.wrap_lines(source.text,float(source.width),metrics)
		check(wrapped.lines==row.lines and wrapped.wrap_result==int(row.wrap_result),"Complete original word-wrap observation",{"source":source,"expected":row.lines,"actual":wrapped})
		check(JSON.stringify(source)==before,"Text fitting does not mutate font/source data")
	check(corpus.policies.size()==272,"Complete original fixed-bubble selection observations")
	for row in corpus.policies:
		var source: Dictionary=row.input;var metrics:={"glyphs":source.glyphs,"default":source.default,"spacing":source.spacing}
		var actual:=Text.choose(source.text,metrics,float(source.line_height),int(source.minimum_lines),float(source.indent))
		check(actual.bubble_index==int(row.bubble_index) and [float(actual.bubble[0]),float(actual.bubble[1])]==row.dimensions,"Original fixed-bubble policy with separately executed original text providers",{"source":source,"expected":row.bubble_index,"actual":actual.bubble_index})
	var colored:={"text":"ABCDE FGHIJ\n","spans":[{"text":"AB","color":"#ff0000"},{"text":"CDE ","color":"#00ff00"},{"text":"FGHIJ\n","color":"#0000ff"}]}
	var before:=colored.duplicate(true);var metrics:={"default":0.06,"glyphs":{" ":0.03,"\n":0.0}}
	var displayed:=Text.display(colored,Text.wrap_lines(colored.text,0.18,metrics),0.18,metrics)
	check(displayed.text=="ABC\nDE \nFGH\nIJ" and displayed.spans[0]=={"text":"AB","color":"#ff0000"} and displayed.spans[1]=={"text":"C","color":"#00ff00"},"Explicit source lines preserve color spans and retained whitespace across cuts and omit the terminal newline",displayed)
	check(colored==before and Text.plain(displayed)==displayed.text,"Fitted rich text is detached from received caption data")
	var plate:=Plate.new();root.add_child(plate);plate.configure()
	var value:={"available":true,"name":{"text":"Nibs"},"caption":{"text":"Nibs\nUninjured\n","spans":[{"text":"Nibs\n","color":"#8080ff"},{"text":"Uninjured\n","color":"#80ff80"}]},"color":Color.WHITE,"caption_color":Color.WHITE,"portrait":"","creature":true}
	var source_before:=value.duplicate(true);plate.set_content(value)
	check(plate.caption.autowrap_mode==TextServer.AUTOWRAP_OFF and plate.caption.get_parsed_text()=="Nibs\nUninjured","Actual native plate renders source lines and does not add a final blank Godot line")
	check(plate.caption.clip_contents and not plate.caption.scroll_active and plate.caption.size.y<=plate.size.y,"Actual caption stays clipped to the selected original bubble without scrolling")
	var control_id:=plate.caption.get_instance_id();var layouts:=plate.layouts
	for index in 60:plate.place(Vector2(200+index,200),Rect2(0,0,1000,700))
	check(plate.caption.get_instance_id()==control_id and plate.layouts==layouts and value==source_before,"Position-only updates preserve fitted text, font work, widget identity and received data")
	var prop:=value.duplicate(true);prop.creature=false;prop.caption={"text":"Chest"};plate.set_content(prop)
	check(plate.size.y>=plate.caption.get_theme_font("normal_font").get_height(plate.caption.get_theme_font_size("normal_font_size"))*2,"Shared original item/placeable popup reserves two lines even without a portrait")
	value=value.duplicate(true);value.caption={"text":"LongCaption".repeat(70)};plate.set_content(value)
	check(plate.size==Vector2(300,454) and plate.caption.size.y<=454 and plate.caption.get_parsed_text().contains("\n"),"Unbreakable long captions use original fallback capacity and explicit line cuts")
	value.available=false;plate.set_content(value);check(not plate.visible,"Withdrawn caption hides without exposing stale text")
	plate.close();plate.queue_free();await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"gpu":false,"scope":"Original plain-text CalculateVisibleStringLengthAndWidth/GetSymbolCoords/AlignGUIToPixel/WrapLines and fixed-bubble policy observations with authored atlas metrics; actual native caption control line/clipping/retention binding. Original font raster metrics, renderer pixels and full live HUD acceptance remain open."}
	var output:=FileAccess.open(args.report,FileAccess.WRITE);output.store_string(JSON.stringify(result,"  ")+"\n");output.close()
	print("NATIVE_NAMEPLATE_TEXT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
