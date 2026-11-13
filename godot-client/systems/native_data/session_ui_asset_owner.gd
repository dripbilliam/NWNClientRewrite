extends RefCounted
# Strong, catalog-scoped ownership of completed UI images. The catalog's ordered
# bindings, not a resource name alone, determine which source supplied an image.
var binding_identities: Array=[]
var images: Dictionary={}
var failures: Dictionary={}
var closed:=false

func configure(identities: Array) -> void:
	binding_identities=identities.duplicate()

func lookup(kind: String,key: String) -> Dictionary:
	if closed: return {}
	return images.get(kind,{}).get(key,{})

func retain(kind: String,key: String,texture: Texture2D,bounds: Dictionary={}) -> void:
	if closed or kind.is_empty() or key.is_empty() or texture==null: return
	if not images.has(kind): images[kind]={}
	images[kind][key]={"texture":texture,"bounds":bounds.duplicate(true)}
	if failures.has(kind): failures[kind].erase(key)

func note_failure(kind: String,key: String,reason: String) -> void:
	if closed or kind.is_empty() or key.is_empty(): return
	if not failures.has(kind): failures[kind]={}
	failures[kind][key]=reason

func failure(kind: String,key: String) -> String:
	return str(failures.get(kind,{}).get(key,""))

func snapshot() -> Dictionary:
	var counts: Dictionary={}
	for kind in images: counts[kind]=images[kind].size()
	var failed_counts: Dictionary={}
	for kind in failures: failed_counts[kind]=failures[kind].size()
	return {"binding_identities":binding_identities.duplicate(),"images":counts,"failures":failed_counts,"closed":closed}

func close() -> void:
	closed=true
	images.clear(); failures.clear(); binding_identities.clear()
