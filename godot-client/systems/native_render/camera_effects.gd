extends RefCounted
# Independent camera effects retain their own lifetime. Inserting/removing one
# never reinstalls a stale stack captured before another owner joined.
const BASE=&"native_effect_stack_base"
const OWNERS=&"native_effect_stack_owners"
static func install(camera: Camera3D,effect: CompositorEffect) -> void:
	if not camera.has_meta(BASE):
		camera.set_meta(BASE,{"value":camera.compositor}); camera.set_meta(OWNERS,[])
	var owners: Array=camera.get_meta(OWNERS)
	if owners.has(effect): return
	owners.append(effect)
	var effects: Array[CompositorEffect]=[]
	if camera.compositor!=null: effects.assign(camera.compositor.compositor_effects)
	# Final color transforms must see opaque, transparent AND shared particles.
	var index:=effects.size()
	if not effect.get_meta("native_final_color",false):
		for candidate in effects.size():
			if effects[candidate].get_meta("native_final_color",false): index=candidate; break
	effects.insert(index,effect)
	var next:=Compositor.new(); next.compositor_effects=effects; camera.compositor=next
static func remove(camera: Camera3D,effect: CompositorEffect) -> void:
	if not is_instance_valid(camera) or not camera.has_meta(OWNERS): return
	var owners: Array=camera.get_meta(OWNERS)
	if not owners.has(effect): return
	owners.erase(effect)
	var effects: Array[CompositorEffect]=[]
	if camera.compositor!=null: effects.assign(camera.compositor.compositor_effects)
	effects.erase(effect)
	var base: Compositor=camera.get_meta(BASE).value
	var original: Array[CompositorEffect]=[]
	if base!=null: original.assign(base.compositor_effects)
	if owners.is_empty() and effects==original: camera.compositor=base
	else:
		var next:=Compositor.new(); next.compositor_effects=effects; camera.compositor=next
	if owners.is_empty(): camera.remove_meta(BASE); camera.remove_meta(OWNERS)
