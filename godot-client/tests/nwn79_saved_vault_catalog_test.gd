extends SceneTree
const Catalog=preload("res://systems/native_local_character_catalog.gd")
const Vault=preload("res://systems/native_data/native_character_export_vault.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
var folder: String=""
var checks:=0
var failures: Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func bic(marker: int)->PackedByteArray:
	var writer=Writer.new()
	return writer.write("BIC ",Writer.record({"FirstName":Writer.field(12,"Nibs"),"LastName":Writer.field(12,"Druid"),"NativeMarker":Writer.field(4,marker)}))
func ticket(entry: Dictionary)->Dictionary:
	return {"key":"godot-vault:"+str(entry.id),"source":"vault","catalogStem":"","label":str(entry.name),"nativeVaultId":str(entry.id),"nativeFile":{"format":"godot-vault-bic-v1","id":str(entry.id),"sha256":str(entry.sha256),"bytes":int(entry.bytes)}}
func settle(owner: Variant)->bool:
	var deadline:=Time.get_ticks_msec()+5000
	while not owner.ready() and Time.get_ticks_msec()<deadline:await process_frame
	return owner.ready()
func run()->void:
	folder=ProjectSettings.globalize_path("res://.cache/nwn79-vault-catalog-"+Vault._nonce())
	if DirAccess.dir_exists_absolute(folder):fail("Isolated vault path collision");return
	var vault=Vault.new()
	if not vault.configure(folder):fail("Could not create isolated vault");return
	var saved: Dictionary=vault.store({"data":bic(1)})
	if not saved.get("ready",false):fail("Could not create private saved-character fixture");return
	var row: Dictionary=ticket(saved.entry)
	var owner=Catalog.new();root.add_child(owner);owner.configure([]);owner.configure_vault(vault)
	owner.observe(7,[row])
	check(await settle(owner),"Godot vault catalog worker completes")
	check(owner.values.has(row.key) and owner.errors.is_empty() and owner.decoded==1,"Exact vault ID/hash/bytes admits one real BIC projection")
	var forged: Dictionary=row.duplicate(true);forged.nativeFile.sha256="0".repeat(64)
	owner.observe(7,[forged]);check(await settle(owner),"Forged hash check completes")
	check(owner.values.is_empty() and owner.errors.has(row.key),"Forged saved-character hash cannot enter chooser")
	forged=row.duplicate(true);forged.nativeVaultId="wrong-id"
	owner.observe(7,[forged]);check(await settle(owner),"Forged identity check completes")
	check(owner.values.is_empty() and owner.errors.has(row.key),"Forged saved-character ID cannot enter chooser")
	forged=row.duplicate(true);forged.nativeFile.bytes=int(forged.nativeFile.bytes)+1
	owner.observe(7,[forged]);check(await settle(owner),"Forged size check completes")
	check(owner.values.is_empty() and owner.errors.has(row.key),"Forged saved-character byte count cannot enter chooser")
	var revised: Dictionary=vault.store({"data":bic(2)},str(saved.entry.id))
	check(revised.get("ready",false) and int(revised.entry.revision)==2,"Vault publishes a second revision under the same ID")
	row=ticket(revised.entry);owner.observe(7,[row]);check(await settle(owner),"Updated vault ticket check completes")
	check(owner.values.has(row.key) and owner.errors.is_empty() and owner.decoded==2,"New verified revision enters the same chooser identity")
	owner.close();owner.free();cleanup()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Godot worker admission for durable saved BIC tickets, forged ID/hash/size rejection and revision; isolated vault only"}
	print("NWN79_SAVED_VAULT_CATALOG_RESULT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func cleanup()->void:
	if not folder.contains("nwn79-vault-catalog-"):return
	for section in ["blobs","entries"]:
		var path:=folder.path_join(section);var directory:=DirAccess.open(path)
		if directory!=null:
			for name in directory.get_files():DirAccess.remove_absolute(path.path_join(name))
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)
func fail(reason: String)->void:
	printerr("NWN79 saved-vault catalog failed: "+reason);cleanup();quit(1)
