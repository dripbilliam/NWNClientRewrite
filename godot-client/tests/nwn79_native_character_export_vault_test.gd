extends SceneTree
const Vault=preload("res://systems/native_data/native_character_export_vault.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
class FaultVault extends Vault:
	var stop_at: String=""
	func _allow_commit(stage: String)->bool:return stage!=stop_at

var folder: String=""

func _initialize()->void:
	call_deferred("run")

func run()->void:
	folder=ProjectSettings.globalize_path("res://.cache/nwn79-vault-isolated-"+Vault._nonce())
	if not folder.contains("nwn79-vault-isolated-") or DirAccess.dir_exists_absolute(folder):fail("Isolated test path collision");return
	var vault=FaultVault.new()
	if not vault.configure(folder):fail("Could not configure isolated vault");return
	var first:=bic("../unsafe","Druid",1)
	var second:=bic("../unsafe","Druid",2)
	var third:=bic("../unsafe","Druid",3)
	if first.is_empty() or second.is_empty() or third.is_empty():fail("Could not produce BIC fixtures");return
	var saved: Dictionary=vault.store({"kind":"character-export","firstName":{"text":"../../wrong"},"lastName":{"text":"wrong"},"data":first})
	if not saved.get("ready",false):fail("First durable save failed: "+str(saved));return
	var id:=str(saved.entry.id)
	if not Vault._valid_id(id) or int(saved.entry.revision)!=1 or str(saved.entry.name)!="../unsafe Druid":fail("Vault identity/name source differs");return
	if not exact(vault.export_character(id),first):fail("First opaque export changed bytes");return
	if not only_revision(vault,1,id):fail("First list differs");return
	var next: Dictionary=vault.store({"data":second},id)
	if not next.get("ready",false) or int(next.entry.revision)!=2 or str(next.entry.id)!=id or str(next.entry.sha256)==str(saved.entry.sha256):fail("Stable ID revision failed");return
	if not only_revision(vault,2,id) or not exact(vault.export_character(id),second):fail("Latest revision not exported");return
	if not FileAccess.file_exists(folder.path_join("blobs").path_join(str(saved.entry.sha256)+".bic")):fail("Prior immutable BIC disappeared");return
	vault.stop_at="before-entry-commit"
	var failed: Dictionary=vault.store({"data":third},id)
	if not failed.has("error") or not only_revision(vault,2,id) or not exact(vault.export_character(id),second):fail("Failed entry commit replaced last good save");return
	vault.stop_at="after-blob"
	failed=vault.store({"data":third},id)
	if not failed.has("error") or not only_revision(vault,2,id):fail("Interrupted post-blob save replaced entry");return
	vault.stop_at=""
	var reopened=Vault.new()
	if not reopened.configure(folder) or not exact(reopened.export_character(id),second):fail("Reopened vault lost last good save");return
	var recovered: Dictionary=reopened.store({"data":third},id)
	if not recovered.get("ready",false) or int(recovered.entry.revision)!=3 or not exact(reopened.export_character(id),third):fail("Save did not recover after write failure");return
	if not only_revision(reopened,3,id):fail("Recovered list is not a single current entry");return
	var duplicate: Dictionary=reopened.store({"data":third},id)
	if not duplicate.get("ready",false) or int(duplicate.entry.revision)!=4 or str(duplicate.entry.sha256)!=str(recovered.entry.sha256):fail("Duplicate save did not retain identity and reuse exact blob");return
	var another: Dictionary=reopened.store({"data":third})
	if not another.get("ready",false) or str(another.entry.id)==id or str(another.entry.sha256)!=str(recovered.entry.sha256):fail("Distinct character identity did not share duplicate content blob");return
	var pair: Dictionary=reopened.list()
	if not pair.get("ready",false) or pair.entries.size()!=2:fail("Duplicate content identities were lost");return
	var fourth:=bic("../unsafe","Druid",4)
	var stopped=FaultVault.new()
	if not stopped.configure(folder):fail("Could not reopen for blob failure");return
	stopped.stop_at="before-blob-commit"
	if not stopped.store({"data":fourth},id).has("error") or not exact(stopped.export_character(id),third):fail("Failed blob commit damaged current export");return
	if not reopened.export_character("../escape").has("error") or not reopened.store({"data":first},"../escape").has("error"):
		fail("Unsafe local ID was accepted");return
	if not reopened.store({"data":PackedByteArray([66,73,67,32])}).has("error"):
		fail("Truncated BIC was accepted");return
	if not FileAccess.file_exists(folder.path_join("blobs").path_join(str(recovered.entry.sha256)+".bic")):
		fail("Content-addressed blob missing");return
	cleanup()
	print("NWN79 Godot character-export vault PASS: opaque_bytes=true atomic_revisions=4 duplicate_content=true failure_recovery=true identity_safe=true isolated_test=true")
	quit(0)

func bic(first_name: String,last_name: String,marker: int)->PackedByteArray:
	var writer=Writer.new()
	var bytes: PackedByteArray=writer.write("BIC ",Writer.record({"FirstName":Writer.field(12,first_name),"LastName":Writer.field(12,last_name),"NativeMarker":Writer.field(4,marker),"NativeRaw":Writer.field(13,PackedByteArray([0,255,0,marker]))}))
	if not writer.failure.is_empty():return PackedByteArray()
	var parser=Gff.new();parser.parse(bytes,"BIC ")
	return bytes if parser.failure.is_empty() else PackedByteArray()

func exact(result: Dictionary,bytes: PackedByteArray)->bool:
	return result.get("ready",false) and result.get("data") is PackedByteArray and result.data==bytes

func only_revision(vault,revision: int,id: String)->bool:
	var found: Dictionary=vault.list()
	return found.get("ready",false) and found.entries.size()==1 and str(found.entries[0].id)==id and int(found.entries[0].revision)==revision and int(found.invalidEntries)==0

func cleanup()->void:
	for subfolder in ["blobs","entries"]:
		var path:=folder.path_join(subfolder);var directory:=DirAccess.open(path)
		if directory!=null:
			for filename in directory.get_files():DirAccess.remove_absolute(path.path_join(filename))
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)

func fail(reason: String)->void:
	printerr("NWN79 Godot character-export vault failed: "+reason)
	if not folder.is_empty() and folder.contains("nwn79-vault-isolated-"):cleanup()
	quit(1)
