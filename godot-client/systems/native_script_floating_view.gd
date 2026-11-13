extends Control
# Passive cached shaped runs. Position/colour updates never re-shape text.
# Current Godot/FreeType metrics are explicit; Win32 native glyph pixels and
# nondefault GUI-scale/camera remapping are not claimed by this adapter.
const Markup=preload("res://systems/native_data/script_floating_markup.gd")
const FONT="ttf fnt_maintext 17"
var fonts
var resources
var font_target: RichTextLabel
var model: Dictionary={}
var program: Dictionary={}
var shaped: Array=[]
var run_colors: Dictionary={}
var hook:=Transform2D.IDENTITY
var base_alpha:=1.0
var wanted:=false
var has_frame:=false
var layout_ready:=false
var closed:=false
var layouts:=0
var source_error:=""
func configure(_art,typefaces,source) -> void:
	fonts=typefaces;resources=source;mouse_filter=Control.MOUSE_FILTER_IGNORE;focus_mode=Control.FOCUS_NONE;clip_contents=false
	font_target=RichTextLabel.new();add_child(font_target);font_target.hide();font_target.mouse_filter=Control.MOUSE_FILTER_IGNORE;font_target.focus_mode=Control.FOCUS_NONE;font_target.set_process_internal(false)
	if is_instance_valid(fonts):fonts.loaded.connect(font_loaded)
	if is_instance_valid(resources):resources.loaded.connect(source_loaded)
	hide()
func set_content(value: Dictionary) -> void:
	if closed:return
	model=value;program=value.get("program",{});wanted=true;layout_ready=false;source_error="";shaped.clear();run_colors.clear()
	if is_instance_valid(resources):resources.request()
	if is_instance_valid(fonts):fonts.bind(font_target,FONT)
	relayout()
func font_loaded(name: String) -> void:
	if wanted and not closed and name==FONT:relayout()
func source_loaded() -> void:
	if wanted and not closed:relayout()
func relayout() -> void:
	if closed or not wanted or not program.get("ready",false):return
	if not is_instance_valid(resources) or not resources.plan.get("ready",false):return
	if not font_target.has_meta("native_font_applied") or str(font_target.get_meta("native_font_applied"))!=FONT:return
	var font:=font_target.get_theme_font("normal_font");var height:=font_target.get_theme_font_size("normal_font_size")
	var plain: String=program.plain;var lines:=plain.split("\n",true)
	if plain.ends_with("\n") and lines.size()>1:lines.remove_at(lines.size()-1)
	var widths: Array=[];var max_width:=0.0;var line_height:=font.get_height(height);var ascent:=font.get_ascent(height)
	for line in lines:
		var width: float=font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,height).x;widths.append(width);max_width=maxf(max_width,width)
	var block_height:=line_height*lines.size();var line_index:=0;var cursor:=0.0;shaped=[]
	for index in program.commands.size():
		var command: Dictionary=program.commands[index]
		if command.op!="text":continue
		var pieces: PackedStringArray=str(command.text).split("\n",true)
		for part in pieces.size():
			var content: String=pieces[part]
			if not content.is_empty() and line_index<widths.size():
				var shape:=TextLine.new();shape.direction=TextServer.DIRECTION_LTR;shape.add_string(content,font,height)
				shaped.append({"shape":shape,"command":index,"text":content,"position":Vector2(-float(widths[line_index])*0.5+cursor,-block_height+ascent+line_index*line_height)})
				cursor+=shape.get_size().x
			if part+1<pieces.size():line_index+=1;cursor=0.0
	hook=resources.plan.hooks.foreground.transform;size=Vector2(max_width,block_height);layout_ready=true;layouts+=1
	if wanted and has_frame:show()
	queue_redraw()
func apply_frame(rounded_screen: Vector2,alpha: float) -> void:
	if closed or not wanted:return
	base_alpha=alpha;position=rounded_screen;has_frame=true
	if layout_ready:show()
func prepare_colors() -> void:
	if closed or not wanted or not layout_ready or not is_visible_in_tree():return
	var next:=Markup.colors(program,Markup.shared_ring(),Color(1,1,1,base_alpha))
	if next!=run_colors:run_colors=next;queue_redraw()
func _draw() -> void:
	if closed or not wanted or not layout_ready:return
	draw_set_transform_matrix(hook)
	for run in shaped:
		var color: Color=run_colors.get(int(run.command),Color(1,1,1,base_alpha))
		run.shape.draw(get_canvas_item(),run.position,color)
func release() -> void:
	wanted=false;has_frame=false;base_alpha=1.0;layout_ready=false;model={};program={};shaped.clear();run_colors.clear();hide();queue_redraw()
	if is_instance_valid(fonts):fonts.unbind(font_target)
func close() -> void:
	if closed:return
	release();closed=true
	if is_instance_valid(fonts) and fonts.loaded.is_connected(font_loaded):fonts.loaded.disconnect(font_loaded)
	if is_instance_valid(resources) and resources.loaded.is_connected(source_loaded):resources.loaded.disconnect(source_loaded)
	fonts=null;resources=null
func _exit_tree() -> void:close()
