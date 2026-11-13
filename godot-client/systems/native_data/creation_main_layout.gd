extends RefCounted
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const BUTTONS={"alignbutton":"0x1408e0d20","abilitiesbutton":"0x1408e0cc0","cancelbutton":"0x1408e1100","classbutton":"0x1408e1ae0","playbutton":"0x1408e3f90","packagesbutton":"0x1408e5770","portraitbutton":"0x1408e58c0","racebutton":"0x1408e5ab0","customizebutton":"0x1408e25c0","resetbutton":"0x1408e6780","genderbutton":"0x1408e71d0"}
const FLOW_TAGS={"alignbutton":"align","abilitiesbutton":"abilities","classbutton":"class","playbutton":"play","packagesbutton":"packages","portraitbutton":"portrait","racebutton":"race","customizebutton":"customize","genderbutton":"gender"}
static func parse(root: Dictionary,models: Dictionary) -> Dictionary:
	var result:=Dialog.panel(root,models,["titlelabel"],[],BUTTONS,["ctl_cg_goldbar"])
	if not str(result.error).is_empty(): return result
	# Original CG_MAIN binder8ec740 sets TitleLabel's bounds flag4 before
	# importing it. Center within the authored bar, not around its left corner.
	result.entries.titlelabel.erase("floating");result.entries.titlelabel.erase("anchor")
	var main:=Geometry.model(models[result.resource])
	if not main.hooks.has("charactersheet"): return {"error":"Original creator's character-sheet attachment is missing"}
	result.summary_origin=result.origin+main.hooks.charactersheet
	return result
