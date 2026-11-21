extends RefCounted
# Direct client-side item counter and metadata merge from network_item_uses.js.

static func _entry(values: Variant,index: int) -> Variant:
	return values[index] if values is Array and index>=0 and index<values.size() else null

static func apply_client_item_uses(item: Dictionary,entry: Dictionary) -> String:
	var index:=int(entry.get("propertyIndex",0))&255
	var property: Variant=_entry(item.get("properties"),index)
	var count:=int(entry.get("count",0))&65535
	if property==null or int(property.get("costValue",0))==1 or int(property.get("type",0)) in [80,55]:
		item.stackSize=count;item.field454=count
		return "stack"
	return apply_client_property_uses(item,index,count)

static func apply_client_property_uses(item: Dictionary,index: int,count: int) -> String:
	if index>=8:return "ignored"
	if not item.has("propertyUses") or item.propertyUses==null:
		var uses: Array=[]
		for at in 8:
			var value: Variant=_entry(item.get("field351"),at)
			uses.append(value if value!=null else 0)
		item.propertyUses=uses
	var uses: Array=item.propertyUses
	uses[index]=count
	var properties: Array=item.get("properties",[])
	if not item.has("selectedProperty"):
		item.selectedProperty=-1
		for at in properties.size():
			if int(properties[at].get("type",0))==15:item.selectedProperty=at;break
	if index==int(item.selectedProperty) and count==0:
		var next:=-1
		for at in mini(8,properties.size()):
			if int(properties[at].get("type",0))==15 and uses[at]!=0:next=at;break
		item.selectedProperty=255 if next<0 else next
	return "property"

static func merge_network_item(previous: Variant,incoming: Dictionary) -> Dictionary:
	var before: Dictionary=previous if previous is Dictionary else {}
	var item: Dictionary=before.duplicate()
	item.merge(incoming.duplicate(true),true)
	if incoming.has("field454"):item.stackSize=incoming.field454
	if not incoming.has("field351") or incoming.field351==null:return item
	var uses: Array=[]
	for at in 8:
		var value: Variant=_entry(before.get("propertyUses"),at)
		if value==null:value=_entry(before.get("field351"),at)
		uses.append(value if value!=null else 0)
	item.propertyUses=uses
	item.selectedProperty=before.get("selectedProperty") if before.get("selectedProperty")!=null else 255
	var property_value: Variant=item.get("properties",[])
	var properties: Array=property_value if property_value is Array else []
	for at in properties.size():
		var property: Dictionary=properties[at]
		if int(property.get("type",0))==15 and int(item.selectedProperty)==255:item.selectedProperty=at
		property.remaining=1
	for at in 8:
		if (int(incoming.get("reserved",0))&(1<<at))==0:continue
		var count: Variant=_entry(incoming.field351,at)
		apply_client_property_uses(item,at,int(count) if count!=null else 0)
		if at<properties.size():properties[at].remaining=1 if (int(incoming.get("field350",0))&(1<<at))!=0 else 0
	return item
