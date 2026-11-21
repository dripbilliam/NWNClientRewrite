extends RefCounted
const State=preload("res://systems/native_data/nui_state.gd")
const Canvas=preload("res://systems/nui_canvas.gd")
const TYPES=["row","col","group","list","spacer","button","button_image","button_select","check","label","text","image","combo","slider","sliderf","progress","textedit","color_picker","options","tabbar","chart"]
var control_serial:=0
var failure:=""
var text_lookup: Callable
var image_lookup: Callable
var interaction_lookup: Callable
var nodes: Array=[]
var controls: Dictionary={}
var by_path: Dictionary={}
var window: Dictionary={}
var record: Dictionary={}
func label(source: Variant,index: int=-1) -> String:
	var resolved: Variant=State.value(window,source,index)
	if resolved is Dictionary and resolved.has("strref") and text_lookup.is_valid(): return str(text_lookup.call(int(resolved.strref)))
	return State.text(resolved,source if source is Dictionary else {})
static func color(value: Variant) -> Variant:
	if not value is Dictionary: return null
	var result: Dictionary={}
	# nuiColor uses ?? 255 for every channel; an explicit null is white,
	# not Number(null) == 0.
	for key in ["r","g","b"]:
		var channel: Variant=value.get(key,State.UNDEFINED)
		result[key]=255.0 if channel==null or State.missing(channel) else State.number(channel,255)
	var alpha: Variant=value.get("a",State.UNDEFINED)
	result.a=clampf(255.0 if alpha==null or State.missing(alpha) else State.number(alpha,255),0,255)
	return result
static func chart_number(value: Variant) -> Variant:
	# Chart bounds omit invalid Number(...) values, while each original SVG
	# primitive keeps its own invalid point. Do not turn them into zero.
	if State.missing(value):return null
	if value==null:return 0.0
	if value is bool:return 1.0 if value else 0.0
	if value is int or value is float:return float(value) if is_finite(float(value)) else null
	if value is String:
		var source: String=value.strip_edges()
		if source.is_empty():return 0.0
		if source.is_valid_float():return float(source) if is_finite(float(source)) else null
		return null
	if value is Array:
		if value.is_empty():return 0.0
		if value.size()==1:return chart_number(value[0])
	return null
func image(value: Variant,region: Variant) -> int:
	return int(image_lookup.call(value,region)) if image_lookup.is_valid() and value is String and not value.is_empty() and value!="****" else -1
func draws(element: Dictionary,index: int) -> Array:
	var source: Variant=State.at(window,element,"draw_list",index); var result: Array=[]
	if not source is Array: return result
	for item in source:
		if item is Array:
			# JSON arrays are objects in JS, but have no `type` property. They
			# reach the old default/error branch at order 1.
			result.append({"type":-1.0,"source_type":"undefined","order":1})
			continue
		if not item is Dictionary: continue
		var count:=1
		if State.truth(item.get("arrayBinds",false)):
			for key in item:
				var found: Variant=State.value(window,item[key])
				if key!="arrayBinds" and State.is_bind(item[key]) and found is Array: count=maxi(count,found.size())
		if count>20000: failure="Native NUI draw array exceeds bound"; return []
		for draw_index in count:
			var sub:=draw_index if State.truth(item.get("arrayBinds",false)) else index
			if State.strict_false(State.at(window,item,"enabled",sub)): continue
			# The SVG path checks type only after enabled/order/render filtering.
			# Preserve unsupported and fractional types for draw-time admission.
			var type: float=State.number(item.get("type",State.UNDEFINED),-1)
			var row:={"type":type,"source_type":item.get("type","undefined"),"fill":State.truth(State.at(window,item,"fill",sub)),"color":color(State.at(window,item,"color",sub))}
			for key in ["rect","a","b","c","ctrl0","ctrl1","points","radius","amin","amax","line_thickness","order","render","font","image_aspect"]:
				var found: Variant=State.at(window,item,key,sub)
				if not State.missing(found): row[key]=found
			if type==4: row.text=label(item.get("text",State.UNDEFINED),sub)
			if type==5: row.image=image(State.at(window,item,"image",sub),State.at(window,item,"image_region",sub))
			result.append(row)
	return result
func visit(element: Variant,index: int=-1,parent: int=-1,path: String="root",ancestors: Array=[],depth: int=0) -> int:
	if not failure.is_empty(): return -1
	if not element is Dictionary or str(element.get("type","")) not in TYPES or nodes.size()>=20000 or depth>64: failure="Unsupported native NUI element/depth/count"; return -1
	var old: Dictionary=by_path.get(path,{}); var id: int=int(old.id) if old.get("element")==element and int(old.get("index",-2))==index else -1
	if id<0: control_serial+=1; id=control_serial
	var current:={"id":id,"element":element,"index":index,"parent":parent,"path":path,"ancestors":ancestors}
	controls[id]=current
	var enabled:=not State.strict_false(State.at(window,window.layout,"accepts_input")); var visible:=true
	var parents:=ancestors+[{"element":element,"index":index}]
	for owner in parents:
		enabled=enabled and not State.strict_false(State.at(window,owner.element,"enabled",int(owner.index)))
		visible=visible and not State.strict_false(State.at(window,owner.element,"visible",int(owner.index)))
	var values: Dictionary={}
	for key in ["width","height","aspect","margin","padding","scrollbars","text_halign","text_valign","image_aspect","image_halign","image_valign","row_height","direction"]:
		var found: Variant=State.at(window,element,key,index)
		if not State.missing(found): values[key]=State.number(found)
	for key in ["border","encouraged"]: values[key]=State.truth(State.at(window,element,key,index))
	var font: Variant=State.at(window,element,"font",index)
	values.merge({"wordwrap":not State.strict_false(State.at(window,element,"wordwrap",index)),"font":font if font is String else "(default)","enabled":enabled,"visible":visible,"foreground_color":color(State.at(window,element,"foreground_color",index)),"tooltip":label(element.get("tooltip" if enabled else "disabled_tooltip",State.UNDEFINED),index)})
	var kind:=str(element.type); var spec:={"controlId":id,"parent":parent,"type":kind,"index":index,"tag":element.get("id","") if element.get("id") is String else "","children":[],"values":values}; nodes.append(spec)
	if kind in ["button","button_select","check","label","text"]: values.label=label(element.get("value" if kind in ["label","text"] else "label",State.UNDEFINED),index)
	if kind in ["button_select","check"]: values.value=State.truth(State.at(window,element,"value",index))
	if kind in ["image","button_image"]: values.image=image(State.at(window,element,"value" if kind=="image" else "label",index),State.at(window,element,"image_region",index))
	if kind in ["combo","options","tabbar"]:
		var entries: Variant=State.at(window,element,"elements",index)
		if State.missing(entries) or entries==null: entries=[]
		if not entries is Array: failure="Invalid native NUI choices"; return -1
		values.options=[]; values.selected=-1
		for option_index in entries.size():
			var entry: Variant=entries[option_index]; values.options.append(label(entry[0] if entry is Array else entry,index))
			if State.equal(entry[1] if entry is Array and entry.size()>1 else option_index,State.at(window,element,"value",index)) and int(values.selected)<0: values.selected=option_index
	if kind in ["slider","sliderf","progress"]:
		for pair in [["value",0],["min",0],["max",1 if kind=="progress" else 100],["step",1 if kind=="slider" else 0.01]]: values[pair[0]]=State.number(State.at(window,element,pair[0],index),float(pair[1]))
	if kind=="textedit": values.merge({"inputAck":record.acks.get(id,0),"value":State.text(State.at(window,element,"value",index)),"label":label(element.get("label",State.UNDEFINED),index),"multiline":State.truth(element.get("multiline",false)),"max":maxi(0,int(State.number(State.at(window,element,"max",index),1024)))})
	if kind=="color_picker": values.value=color(State.at(window,element,"value",index)); values.value={"r":0,"g":0,"b":0,"a":255} if values.value==null else values.value
	if kind=="chart":
		values.slots=[]; var slots: Variant=State.at(window,element,"value",index)
		if slots is Array:
			for slot in slots:
				if slot==null: failure="Cannot read properties of null (reading 'data')"; return -1
				var chart_slot: Dictionary=slot if slot is Dictionary else {}
				var points: Variant=State.at(window,chart_slot,"data",index); var converted: Array=[]
				if not State.missing(points) and points!=null and not points is Array:
					# Source nuiChart calls data.entries() for every slot. A JSON
					# scalar is a render failure, not an empty chart series.
					failure="data.entries is not a function"; return -1
				if points is Array:
					for point in points: converted.append(chart_number(point))
				values.slots.append({"type":State.number(State.at(window,chart_slot,"type",index)),"color":color(State.at(window,chart_slot,"color",index)),"data":converted})
	values.draw_list=draws(element,index); values.draw_list_scissor=not State.strict_false(State.at(window,element,"draw_list_scissor",index))
	if not failure.is_empty():return -1
	# The old view builds both SVG layers during the synchronous view update.
	# Reject only commands admitted by their current order/hover/button phase,
	# before this projector can publish a replacement window transaction.
	var interaction: Dictionary=interaction_lookup.call(int(record.id),id) if interaction_lookup.is_valid() else {}
	var hovered: bool=bool(interaction.get("hover",false)); var pointer_button: int=int(interaction.get("button",-1))
	for pass_order in [-1,1]:
		for command in values.draw_list:
			if command is Dictionary and Canvas.admitted(command,pass_order,hovered,pointer_button) and not Canvas.supported_type(command.get("type")):
				failure=Canvas.unsupported_command(command)
				return -1
	if kind=="list":
		var count_value: Variant=State.at(window,element,"row_count",index); var count: int=count_value.size() if count_value is Array else maxi(0,int(State.number(count_value)))
		if count>1000000: failure="Native NUI list count exceeds capacity"; return -1
		var active: Dictionary=record.ranges.get(path,{"start":0,"count":32}); var first:=mini(int(active.start),count); var last:=mini(count,first+int(active.count)); values.merge({"row_count":count,"row_height":maxf(1,State.number(State.at(window,element,"row_height",index),25)),"first":first,"last":last})
		for row in range(first,last):
			var template: Array=element.get("row_template",[])
			for cell_index in template.size():
				var cell: Variant=template[cell_index]; var child:=visit(cell[0] if cell is Array else cell,row,id,path+"/%d/%d"%[row,cell_index],parents,depth+1)
				if child<0: return -1
				nodes.back().get("values",{}) # Child spec is selected by its ID below.
				for child_spec in nodes:
					if int(child_spec.controlId)==child: child_spec.cell={"row":row,"width":State.number(cell[1]) if cell is Array and cell.size()>1 else 0.0,"variable":State.truth(cell[2]) if cell is Array and cell.size()>2 else true}; break
				spec.children.append(child)
	else:
		var children: Variant=element.get("children",[])
		if kind=="group" and element.get("id") is String and window.layouts.has(element.id): children=[window.layouts[element.id]]
		if not children is Array: failure="Invalid native NUI children"; return -1
		for child_index in children.size():
			var child:=visit(children[child_index],index,id,path+"/"+str(child_index),parents,depth+1)
			if child<0: return -1
			spec.children.append(child)
	return id
func project(source: Dictionary,target: Dictionary) -> Dictionary:
	failure=""; window=source; record=target; nodes=[]; controls={}; by_path={}
	for control in record.get("controls",{}).values(): by_path[control.path]=control
	var root: Variant=window.layouts.get("_window_",window.layout.get("root")); var root_id:=visit(root) if root!=null else -1
	if not failure.is_empty(): return {}
	var geometry: Variant=State.at(window,window.layout,"geometry"); var collapsed: Variant=State.at(window,window.layout,"collapsed")
	if not record.has("geometry_source") or not State.equal(record.geometry_source,geometry): record.geometry_source=State.copy_value(geometry); record.geometry=geometry if geometry is Dictionary else {}
	if not record.has("collapsed_source") or not State.equal(record.collapsed_source,collapsed): record.collapsed_source=collapsed; record.collapsed=State.truth(collapsed)
	var title_value: Variant=window.layout.get("title","Scripted Window"); var title:=label("" if State.strict_false(State.value(window,title_value)) else title_value)
	var frame:={"kind":"nui-frame","windowId":record.id,"version":window.version,"rootId":root_id,"title":title,"closable":not State.strict_false(State.at(window,window.layout,"closable")),"collapsible":not State.strict_false(window.layout.get("collapsed",State.UNDEFINED)),"collapsed":record.collapsed,"header":not title.is_empty() or not State.strict_false(window.layout.get("collapsed",State.UNDEFINED)) or not State.strict_false(State.at(window,window.layout,"closable")),"transparent":State.truth(State.at(window,window.layout,"transparent")),"border":not State.strict_false(State.at(window,window.layout,"border")),"acceptsInput":not State.strict_false(State.at(window,window.layout,"accepts_input")),"resizable":not State.strict_false(State.at(window,window.layout,"resizable")),"geometry":record.geometry,"sizeConstraint":State.at(window,window.layout,"size_constraint"),"edgeConstraint":State.at(window,window.layout,"edge_constraint"),"font":State.at(window,window.layout,"font")}
	for key in ["sizeConstraint","edgeConstraint"]:
		if not frame[key] is Dictionary: frame[key]={}
	if not frame.font is String: frame.font="(default)"
	record.controls=controls; record.version=window.version; record.structure=[window.layout,window.layouts].duplicate(true)
	return {"frame":frame,"nodes":nodes}
