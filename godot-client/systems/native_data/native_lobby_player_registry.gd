extends RefCounted
# 49/3 is a subscribed lobby view of connected PCs. Its IDs and rows do not
# belong to the 17/2 playable character catalog or the world object registry.
var subscribed:=false
var revision:=0
var rows: Array[Dictionary]=[]

func set_subscribed(open: bool)->void:
	# The original lobby Map survives a 49/2 unsubscribe. Reset is scoped to
	# disconnect/reconnect; reopening does not invent a fresh roster snapshot.
	subscribed=open

func apply(message: Dictionary)->bool:
	if not subscribed or message.get("kind")!="server-character-player" or message.get("major")!=49 or message.get("minor")!=3:return false
	if not message.get("present") is bool or not message.get("character") is Dictionary:return false
	var character: Dictionary=message.character
	if not character.get("id") is int:return false
	var id: int=character.id
	if id<0 or id>4294967295:return false
	var at:=_index(id)
	if message.present:
		if not _valid_present(character):return false
		var owned: Dictionary=character.duplicate(true)
		if at<0:rows.append(owned)
		else:rows[at]=owned
		revision+=1
	elif at>=0:
		rows.remove_at(at)
		revision+=1
	return true

func list()->Array[Dictionary]:
	return rows.duplicate(true)

func lookup(id: int)->Dictionary:
	var at:=_index(id)
	return {"found":true,"character":rows[at].duplicate(true)} if at>=0 else {"found":false}

func reset()->void:
	subscribed=false
	rows.clear()
	revision+=1

func snapshot()->Dictionary:
	return {"subscribed":subscribed,"revision":revision,"players":list()}

static func copy_snapshot(values: Variant)->Variant:
	# The UI receives a full, already admitted registry view. Never alias it to
	# the session map or reinterpret its rows as playable 17/2 choices.
	if not values is Array or values.size()>65535:return null
	var copied: Array[Dictionary]=[]
	var seen: Dictionary={}
	for value in values:
		if not value is Dictionary or not value.get("id") is int or int(value.id)<0 or int(value.id)>4294967295 or not _valid_present(value):return null
		if seen.has(int(value.id)):return null
		seen[int(value.id)]=true
		copied.append(value.duplicate(true))
	return copied

func _index(id: int)->int:
	for at in rows.size():
		if int(rows[at].id)==id:return at
	return -1

static func _valid_present(character: Dictionary)->bool:
	if not character.get("firstName") is Dictionary or not character.get("lastName") is Dictionary:return false
	if not character.get("portrait") is int or int(character.portrait)<0 or int(character.portrait)>65535:return false
	if int(character.portrait)>65533 and not character.get("portraitRef") is String:return false
	if not character.get("classes") is Array or character.classes.size()>255:return false
	for row in character.classes:
		if not row is Dictionary or not row.get("id") is int or not row.get("level") is int:return false
		if int(row.id)<0 or int(row.id)>255 or int(row.level)<0 or int(row.level)>255:return false
	return true
