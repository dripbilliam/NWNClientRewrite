extends RefCounted
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const RESOURCES=["pnl_chat","edit_chat_left","edit_chat_right","edit_chat_main","but_chat_bar360","but_chat_bar720","pnl_chat_prompt","edit_chat_prompt","ctl_btn_chatmode","ctl_lst_chatmode","scrollbar_simple","pb_scrl_up","pb_scrl_down","but_chat_reply"]
const FONT="ttf fnt_default 14" # CTlkTable dialog-default14128f1d8 ->140da3638.
static func parse(source: Dictionary) -> Dictionary:
	var models: Dictionary={}
	for name in RESOURCES:
		if not source.has(name): return {"error":"Original chat model missing: "+name}
		models[name]=Geometry.model(source[name])
		if not str(models[name].error).is_empty(): return {"error":str(models[name].error)}
	for name in ["edit_chat_left","edit_chat_right","edit_chat_main"]:
		for hook in ["text0","text1","scrollmin","scrollmax","top","bottom"]:
			if not models[name].hooks.has(hook): return {"error":"Original chat attachment missing: "+name+"."+hook}
	return {"error":"","models":models}
static func pane(plan: Dictionary,secondary: bool,combined: bool,height: float,base: float=56) -> Dictionary:
	var name:="edit_chat_right" if secondary else "edit_chat_main" if combined else "edit_chat_left"
	var model: Dictionary=plan.models[name].duplicate(true)
	# Original879780 updates these hooks from the drag height above the prompt.
	model.hooks.scrollmax.y=height-base-22; model.hooks.text1.y=height-base-14
	var origin: Vector2=plan.models.pnl_chat.hooks.editbox
	var rect:=Rect2(origin+model.hooks.text0,model.hooks.text1-model.hooks.text0)
	var bar:="but_chat_bar720" if combined else "but_chat_bar360"; var handle: Rect2=plan.models[bar].bounds; handle.position+=plan.models.pnl_chat.hooks.dragbar
	return {"resource":name,"model":model,"offset":origin,"rect":rect,"handle":handle,"bar":bar,"width":model.hooks.top.x,"height":height}
