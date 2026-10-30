extends RefCounted
# Original item Examine140899040 ordering and TLK/2DA presentation only.
# Never computes identification, cost, charges, properties or use permission.
const Rich=preload("res://systems/native_data/rich_text.gd")
const Item=preload("res://systems/native_data/item_icon.gd")
const Numbers=preload("res://systems/native_data/game_numbers.gd")
static func string_ref(value: Variant) -> int: return Item.number(value,4294967295)
static func cell(row: Dictionary,column: String) -> Variant:
	for key in row:
		if str(key).to_lower()==column.to_lower(): return row[key]
	return null
static func localized(text,ref: int,target: int) -> String:
	return text.resolve({"strRef":ref},target) if ref>=0 and ref!=4294967295 else ""
static func item(message: Dictionary,text,target: int) -> Dictionary:
	var object_item: Dictionary=text.objects.get(target,{}).get("item",{})
	var base:=int(object_item.get("baseItem",-1)); var definition:=Item.row(text.tables,"baseitems",base)
	var description: String=text.resolve(message.get("description",{}),target)
	var description_ref:=string_ref(cell(definition,"Description")); var stat_ref:=string_ref(cell(definition,"BaseItemStatRef"))
	if base==16:
		# Active item properties disclose the original cached armor category as
		# field35c. Appearance parts may differ; the server's category wins.
		var armor_row:=Item.row(text.tables,"armor",Item.number(object_item.get("field35c"),-1))
		description_ref=string_ref(cell(armor_row,"DESCRIPTIONS")); stat_ref=string_ref(cell(armor_row,"BASEITEMSTATREF"))
	if description.is_empty(): description=localized(text,description_ref,target)
	var lines: Array[String]=[description,"",localized(text,stat_ref,target)]
	var name_ref:=string_ref(cell(definition,"Name"))
	if name_ref!=4294967295 and name_ref not in [0x5f3,0x5f8,0x619,0x61d,0xc0,0x8f6]:
		lines.append(localized(text,0xd036,target)+" "+localized(text,name_ref,target))
	var identified:=bool(message.get("identified",false))
	if identified and int(message.get("charges",0))>0: lines.append(localized(text,0x15bd,target)+" "+str(int(message.charges)))
	if message.has("weight"):
		lines.append(localized(text,0x15bf,target)+" "+Numbers.tenths(message.weight))
	if message.has("value") and int(message.value)!=4294967295: lines.append("%s %s %d"%[localized(text,0xbe8,target),localized(text,0x1907,target),int(message.value)])
	lines.append("")
	if identified and int(message.get("minimumLevel",0))>0:
		lines.append(localized(text,0x1a97,target)+" "+str(int(message.minimumLevel))); lines.append("")
	return {"rich":Rich.parse("\n".join(lines)),"property_heading":Rich.parse(localized(text,0x1a96,target))}
