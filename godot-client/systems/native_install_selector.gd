extends CanvasLayer
# First-run installation chooser. Uses the same native Godot FileDialog pattern
# as ClientSetup's mods picker. Startup saves the choice through the settings
# owner after any one-time legacy settings import has completed.
signal chosen(path: String)

var notice: Label
var picker: FileDialog

static func valid_install(path: String)->bool:
	return not path.is_empty() and path.is_absolute_path() and path.length()<=4096 and not path.to_utf8_buffer().has(0) and DirAccess.dir_exists_absolute(path) and FileAccess.file_exists(path.path_join("data/nwn_base.key"))

static func candidate(explicit: String,remembered: String,fallback: String)->String:
	if not explicit.is_empty():return explicit if valid_install(explicit) else ""
	if valid_install(remembered):return remembered
	return fallback if valid_install(fallback) else ""

func begin()->void:
	layer=100
	var cover:=Control.new();cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(cover)
	var panel:=PanelContainer.new();panel.set_anchors_preset(Control.PRESET_CENTER);panel.offset_left=-260;panel.offset_top=-90;panel.offset_right=260;panel.offset_bottom=90;cover.add_child(panel)
	var column:=VBoxContainer.new();panel.add_child(column)
	var heading:=Label.new();heading.text="Choose your Neverwinter Nights installation";column.add_child(heading)
	var help:=Label.new();help.text="Select the folder containing data/nwn_base.key.";column.add_child(help)
	var browse:=Button.new();browse.text="Choose folder…";browse.pressed.connect(func():picker.popup_centered_ratio(0.7));column.add_child(browse)
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(notice)
	picker=FileDialog.new();picker.title="Neverwinter Nights installation";picker.access=FileDialog.ACCESS_FILESYSTEM;picker.file_mode=FileDialog.FILE_MODE_OPEN_DIR;picker.use_native_dialog=true;picker.dir_selected.connect(select);cover.add_child(picker)

func select(path: String)->void:
	if not valid_install(path):notice.text="That folder does not contain the NWN game data. Choose the installation folder.";return
	var absolute:=path.simplify_path()
	chosen.emit(absolute)
