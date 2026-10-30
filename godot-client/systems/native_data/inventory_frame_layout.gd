extends RefCounted
const Model=preload("res://systems/native_data/inventory_equipment_layout.gd")
const M=preload("res://systems/native_render/particle_math.gd")
# Original RepositionModel140882b70 uses33-pixel cells and integer half sizes.
const CELL:=33
static func icon_center(x: int,y: int,width: int,height: int) -> Vector2:
	return Vector2((width*CELL)/2+x*CELL+width/2,(height*CELL)/2+y*CELL+height/2)
static func original_position(x: int,y: int,width: int,height: int) -> Array:
	var center:=icon_center(x,y,width,height)
	return [M.f(M.f(center.x)*M.f(0.01)),M.f(M.f(center.y)*M.f(0.01)),0.0]
static func elements(root: Dictionary,models: Dictionary,offset: Vector2) -> Dictionary:
	var result: Dictionary={}
	for child in root.get("Obj_ChildList",[]):
		var tag:=str(child.get("Obj_Tag","")).to_lower()
		if result.has(tag): return {"error":"Ambiguous original inventory frame tag"}
		var caption: Dictionary=child.get("Obj_Caption",{})
		if int(child.get("Obj_Type",-1))==5:
			var point:=Vector2(float(child.get("Obj_Label_X",0)),-float(child.get("Obj_Label_Y",0)))*100.0
			var size:=Vector2(float(child.get("Obj_Label_Width",0)),float(child.get("Obj_Label_Height",0)))*100.0
			if not point.is_finite() or not size.is_finite() or size.x<=0 or size.y<=0: return {"error":"Invalid original inventory label geometry"}
			result[tag]={"rect":Rect2(offset+point,size),"caption":caption}; continue
		var resource:=str(child.get("Obj_ResRef","")).to_lower()
		if not models.has(resource): return {"error":"Missing original inventory component model: "+resource}
		var data:=Model.model(models[resource])
		if not str(data.error).is_empty(): return data
		var point:=Vector2(float(child.get("Obj_X",0)),-float(child.get("Obj_Y",0)))*100.0+offset
		if not point.is_finite(): return {"error":"Invalid original inventory component placement"}
		var rect: Rect2=data.bounds
		if not data.drawn:
			if int(child.get("Obj_Type",-1))!=8 or not data.hooks.has("text0") or not data.hooks.has("text1"): return {"error":"Original inventory component has no mesh or edit-text hooks: "+tag}
			rect=Rect2(data.hooks.text0,data.hooks.text1-data.hooks.text0).abs()
			if rect.size.x<=0 or rect.size.y<=0: return {"error":"Invalid original edit-text hook rectangle"}
		rect.position+=point
		result[tag]={"resource":resource,"rect":rect,"offset":point,"model":data,"caption":caption}
	return {"error":"","entries":result}
static func grid(data: Dictionary,offset: Vector2,columns: int,rows: int) -> Dictionary:
	if not data.hooks.has("icon"): return {"error":"Original inventory grid icon hook is missing"}
	var rect: Rect2=data.bounds; rect.position+=offset
	var base: Vector2=offset+data.hooks.icon
	return {"error":"","art":rect,"rect":Rect2(base-Vector2(0,rows*CELL),Vector2(columns*CELL,rows*CELL)),"base":base,"columns":columns,"rows":rows}
static func parse(layouts: Dictionary,models: Dictionary) -> Dictionary:
	for name in ["inv_panel","inv_container"]:
		if not layouts.has(name): return {"error":"Original inventory GUI is missing: "+name}
	var main: Dictionary=layouts.inv_panel; var resource:=str(main.get("Obj_ResRef","")).to_lower()
	if not models.has(resource): return {"error":"Original inventory panel model is missing"}
	var panel:=Model.model(models[resource])
	if not str(panel.error).is_empty() or not panel.drawn: return {"error":"Original inventory panel bounds are unavailable"}
	var origin: Vector2=-panel.bounds.position
	for hook in ["equip","container","repository","tabs"]:
		if not panel.hooks.has(hook): return {"error":"Original inventory panel attachment missing: "+hook}
	var entries:=elements(main,models,origin)
	if not str(entries.error).is_empty(): return entries
	for tag in ["xbutton","inspectbutton","goldbutton","gplabel","weightlabel","maxweightlabel"]:
		if not entries.entries.has(tag): return {"error":"Original inventory control missing: "+tag}
	for name in ["inv_box_10x6","ctl_inv_btn_tab"]:
		if not models.has(name): return {"error":"Original inventory grid/tab model missing: "+name}
	var repo_model:=Model.model(models.inv_box_10x6); var tab:=Model.model(models.ctl_inv_btn_tab)
	if not str(repo_model.error).is_empty() or not str(tab.error).is_empty() or not tab.hooks.has("next"): return {"error":"Invalid original inventory grid/tab hierarchy"}
	var repository:=grid(repo_model,origin+panel.hooks.repository,10,6)
	if not str(repository.error).is_empty(): return repository
	var tabs: Array=[]; var point: Vector2=origin+panel.hooks.tabs
	for index in 6:
		var rect: Rect2=tab.bounds; rect.position+=point; tabs.append(rect); point+=tab.hooks.next
	var container: Dictionary=layouts.inv_container; var container_name:=str(container.get("Obj_ResRef","")).to_lower()
	if not models.has(container_name): return {"error":"Original container panel model is missing"}
	var container_model:=Model.model(models[container_name]); var container_origin: Vector2=origin+panel.hooks.container
	if not str(container_model.error).is_empty(): return container_model
	var controls:=elements(container,models,container_origin)
	if not str(controls.error).is_empty(): return controls
	for tag in ["itemgrid","label","title","xbutton","closebutton","leftbutton","rightbutton"]:
		if not controls.entries.has(tag): return {"error":"Original container control is missing: "+tag}
	var cell: Dictionary=controls.entries.itemgrid
	var container_grid:=grid(cell.model,cell.offset,7,5)
	if not str(container_grid.error).is_empty(): return container_grid
	var container_rect: Rect2=container_model.bounds; container_rect.position+=container_origin
	return {"error":"","resource":resource,"size":panel.bounds.size,"origin":origin,"equipment":origin+panel.hooks.equip,"entries":entries.entries,"repository":repository,"tabs":tabs,"split":origin.y+panel.hooks.equip.y,"container":{"resource":container_name,"rect":container_rect,"entries":controls.entries,"grid":container_grid}}
