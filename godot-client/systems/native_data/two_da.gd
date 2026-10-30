extends RefCounted
var failure := ""
func tokens(line: String) -> Array:
	# Most table rows have no quoted fields. Split those in engine code rather
	# than allocating a String for every character and repeatedly concatenating.
	# Quoted/doubled-quote syntax retains the established scanner below.
	if not '"' in line: return Array(line.replace("\t"," ").replace("\r"," ").replace("\n"," ").split(" ",false))
	var result: Array = []; var index := 0
	while index < line.length():
		while index < line.length() and line[index] in [" ", "\t", "\r", "\n"]: index += 1
		if index >= line.length(): break
		var value := ""
		if line[index] == '"':
			index += 1
			while index < line.length():
				if line[index] == '"':
					if index + 1 < line.length() and line[index + 1] == '"': value += '"'; index += 2; continue
					index += 1; break
				value += line[index]; index += 1
		else:
			while index < line.length() and line[index] not in [" ", "\t", "\r", "\n"]: value += line[index]; index += 1
		result.append(value)
	return result
func parse(text: String) -> Dictionary:
	failure = ""
	var lines: Array = []
	for source in text.replace("\r", "").split("\n"):
		var line := source.strip_edges()
		if not line.is_empty() and not line.begins_with(";"): lines.append(line)
	if lines.is_empty() or not str(lines[0]).begins_with("2DA V"): failure = "Unsupported 2DA header"; return {}
	var cursor := 1; var default_value := "****"
	if cursor < lines.size() and str(lines[cursor]).to_upper().begins_with("DEFAULT:"):
		var values := tokens(lines[cursor]); default_value = str(values[1]) if values.size() > 1 else "****"; cursor += 1
	if cursor >= lines.size(): failure = "Missing 2DA columns"; return {}
	var columns := tokens(lines[cursor]); cursor += 1
	var rows := {}; var ordered: Array = []; var cells: Array = []; var labels: Array=[]
	while cursor < lines.size():
		var values := tokens(lines[cursor]); cursor += 1
		if values.is_empty(): continue
		var row := {}; var physical: Array = []
		for index in columns.size():
			var value: String = values[index + 1] if index + 1 < values.size() else default_value
			physical.append(value)
			if not row.has(columns[index]): row[columns[index]] = value
		ordered.append(row); cells.append(physical); labels.append(str(values[0]))
		if str(values[0]).is_valid_int(): rows[int(values[0])] = row
	return {"defaultValue": default_value, "columns": columns, "rows": rows, "orderedRows": ordered, "orderedCells": cells,"rowLabels":labels}
