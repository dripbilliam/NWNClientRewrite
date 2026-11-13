extends RefCounted
# Source-only paired-oracle fixture. No API implementation or pass is claimed.
# A future SceneTree test driver supplies the lease-on/off native adapters.
const CASES=[
	"bind only after final Placement position/rotation and metadata",
	"packed source has no tile metadata; Placement parent tile index 0 does",
	"copied tile metadata alone cannot grant canonical Placement authority",
	"original physical Part owns the direct emitter; nested refs/chunks excluded",
	"unchanged managed endpoint reuses pose while live IDs remain validated",
	"static parameter channels and modulo clocks still sample and advance",
	"revoke before Placement/root/Part transform or hierarchy mutation",
	"ordinary fallback preserves original setters and scale-cache behavior",
	"early SceneTree owner revokes before mutation and native step",
	"late SceneTree owner revokes before second step in same engine frame",
	"opaque random/clock/readiness/fallback callback mutates cached pose",
	"callback throws after mutation; no stale pose survives retry",
	"callback nested read suspends lease then refreshes on return",
	"ancestor hide/show listener runs before leaf signal; live visibility wins",
	"detached but locally visible Node fails live inside-tree check",
	"paused or process-disabled owner retains existing simulation behavior",
	"freed source/pose fails or skips exactly where ordinary path does",
	"idempotent revoke/retire occurs before physical Parts free",
	"old scope/token never binds a new area or reused tile index",
	"source reparent or actor conversion revokes managed coverage",
	"failed or nonfinite bind never publishes a partial lease",
	"arbitrary supported between-frame writer must revoke or stay live",
	"live transform query fallback remains available for every rejected owner"
]

static func topology(parent: Node3D,tile_index: int=0) -> Dictionary:
	# Deliberately mirror Template.Placement -> packed root -> physical Part.
	# The source root carries no metadata and no script.
	var placement:=Node3D.new();placement.name="placement";parent.add_child(placement)
	var packed_root:=Node3D.new();packed_root.name="packed_root";placement.add_child(packed_root)
	var part:=Node3D.new();part.name="part_0";packed_root.add_child(part)
	part.set_meta("native_part_index",0)
	var emitter:=Node3D.new();emitter.name="native_emitter";part.add_child(emitter)
	# An excluded reference subtree is available to the future admission oracle.
	var reference:=Node3D.new();reference.name="native_reference";part.add_child(reference)
	var nested_part:=Node3D.new();nested_part.name="part_0";reference.add_child(nested_part)
	var nested_emitter:=Node3D.new();nested_emitter.name="native_emitter";nested_part.add_child(nested_emitter)
	return {"placement":placement,"source":packed_root,"part":part,"emitter":emitter,"parts":[part],"nested_emitter":nested_emitter,"tile_index":tile_index,"placed":false}

static func final_place(row: Dictionary) -> void:
	# Uses the original setter order. The lease hook belongs AFTER this method.
	row.placement.position=Vector3(20.0,0.0,-30.0)
	row.placement.rotation.y=PI/2
	row.placement.set_meta("native_tile_index",int(row.tile_index))
	row.placed=true

static func ownership_witness(row: Dictionary) -> Dictionary:
	var source: Node3D=row.source;var placement: Node3D=row.placement
	return {"source_has_tile_index":source.has_meta("native_tile_index"),"source_script":source.get_script(),"parent_is_placement":source.get_parent()==placement,"source_parent_tile_index":placement.get_meta("native_tile_index",null),"placed":row.placed}

static func mutate_after_revoke(row: Dictionary,revoke: Callable,which: String) -> void:
	assert(revoke.is_valid(),"A canonical tile writer must revoke before mutation")
	revoke.call(row.placement.get_instance_id(),which)
	match which:
		"placement":row.placement.position+=Vector3(0.125,0.25,-0.5)
		"source":row.source.rotation+=Vector3(0.015625,0.03125,-0.0625)
		"part":row.part.scale=Vector3(-1.0,0.75,1.25)
		"retire":row.placement.free()
		_:assert(false,"Unknown canonical mutation in lease fixture")

static func pending_contract() -> Dictionary:
	return {"status":"source-only; not executed","case_count":CASES.size(),"required_comparisons":["exact private state","geometry bytes","RNG state/draws","clock/channel state","live eligibility","callback observations","error/retry behavior"],"cases":CASES.duplicate()}
