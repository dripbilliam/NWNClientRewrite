extends SceneTree
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const InventoryStats=preload("res://systems/native_data/native_inventory_stats.gd")

func _initialize()->void:
	var path:=ProjectSettings.globalize_path("res://../backups/animations/native-network-inventory-stats-observations.json")
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not fixture is Dictionary or fixture.get("cases",[]).size()!=160:fail("Original inventory observations unavailable");return
	for index in range(fixture.cases.size()):
		var row: Dictionary=fixture.cases[index];var scenario: Dictionary=row.case
		var packet:=str(row.packet).hex_decode()
		var reader:=Requirements.Reader.new()
		if not reader.configure(packet.slice(3),int(scenario.format)) or reader.signed_byte()!=71 or reader.signed_byte()!=83:fail("Case "+str(index)+" header");return
		var build: Dictionary={"number":8193,"revision":scenario.revision,"postfix":scenario.postfix}
		var record: Dictionary=InventoryStats.decode(reader,build,{"skillCount":int(scenario.skillCount)})
		if record.has("error") or int(record.id)!=0xffffffff or int(record.mask)!=int(scenario.mask):fail("Case "+str(index)+" record "+str(record)+" reader="+str(reader.error));return
		var state: Dictionary=record.state;var cells: Dictionary=row.cells
		if (int(record.mask) & 1)!=0:
			for field in [["fields70",0x70],["fields7d",0x7d],["fields76",0x76]]:
				var values: Array=state[field[0]]
				for offset in range(values.size()):
					if int(values[offset])!=int(cells["0x%x" % (int(field[1])+offset)]):fail("Case "+str(index)+" "+str(field[0])+"["+str(offset)+"]");return
		for bit_and_field in [[2,"field98",0x98],[4,"field99",0x99],[8,"field9a",0x9a],[16,"field94",0x94],[0x2000,"field9c",0x9c],[0x4000,"field9d",0x9d],[0x8000,"field9e",0x9e],[0x400,"field8c",0x8c],[0x800,"field88",0x88],[0x800,"field8a",0x8a]]:
			if (int(record.mask) & int(bit_and_field[0]))!=0 and int(state[bit_and_field[1]])!=int(cells["0x%x" % int(bit_and_field[2])]):fail("Case "+str(index)+" "+str(bit_and_field[1]));return
		if (int(record.mask) & 32)!=0 and (int(state.field9b)!=int(cells["0x9b"]) or int(state.fielda0)!=int(cells["0xa0"])):fail("Case "+str(index)+" flags");return
		if (int(record.mask) & 64)!=0:
			var combat: Dictionary=state.combatInformation;var observed: Array=row.combat[0]
			for offset in [0,1,2,5,6,7,8,9,0x13,0x14]:
				if (int(combat["field%x" % offset]) & 255)!=int(observed[offset]):fail("Case "+str(index)+" combat field "+str(offset));return
			if int(combat.field18)!=int(observed[0x18]):fail("Case "+str(index)+" combat optional flag");return
			var nodes: Array=combat.group0+combat.group1
			if nodes.size()!=row.nodes.size():fail("Case "+str(index)+" combat node count");return
			for node_index in range(nodes.size()):
				var node: Dictionary=nodes[node_index];var source: Array=row.nodes[node_index]
				var values: Array=[int(node.field0)&255,int(node.get("field1",0)),int(node.field2),int(node.field3),int(node.field4),int(node.field5)]
				for component in range(values.size()):
					if int(values[component])!=int(source[component]):fail("Case "+str(index)+" combat node "+str(node_index)+" component "+str(component));return
		if (int(record.mask) & 128)!=0:
			for skill in state.skills:
				if (int(skill.value) & 255)!=int(row.skills[int(skill.index)]):fail("Case "+str(index)+" skill "+str(skill)+" expected="+str(row.skills[int(skill.index)])+" reader="+str(reader.error));return
		if reader.byte_cursor!=int(row.reader.byteCursor) or reader.bit_cursor!=int(row.reader.curBit) or reader.byte()!=90 or not reader.error.is_empty():fail("Case "+str(index)+" record boundary");return
	print("NWN79 Godot native inventory-stats fixture PASS (160 original observations)")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot inventory stats failed: "+reason)
	quit(1)
