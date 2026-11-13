extends Node
# Front-window coverage removes lower UI, never the world behind source alpha.
# Scope: ordinary controls in one native desktop canvas. Separate overlays and
# custom shader owners retain their own rendering contracts.
const LIMIT:=32
const SOURCE:="""shader_type canvas_item;
uniform int covered_count = 0;
uniform vec4 covered[32];
void fragment() {
    for (int i = 0; i < covered_count; i++) {
        vec4 r = covered[i];
        if (SCREEN_UV.x >= r.x && SCREEN_UV.y >= r.y && SCREEN_UV.x < r.z && SCREEN_UV.y < r.w) { discard; }
    }
}
"""
var host: Control
var shader: Shader
var roots: Dictionary={}
var original: Dictionary={}
var closed:=false
var updates:=0
var overflow:=0
func configure(parent: Control) -> void:
	host=parent; shader=Shader.new(); shader.code=SOURCE
	host.child_entered_tree.connect(added)
	host.child_exiting_tree.connect(removed)
	for child in host.get_children(): added(child)
func added(node: Node) -> void:
	if closed or not node is Control or roots.has(node.get_instance_id()): return
	var id:=node.get_instance_id(); var material:=ShaderMaterial.new(); material.shader=shader
	roots[id]={"owner":weakref(node),"material":material,"signature":[],"supported":node.material==null}
	watch(node,id,true)
func watch(node: Node,id: int,top: bool=false) -> void:
	if node is CanvasLayer or node is SubViewport: return
	var key:=node.get_instance_id()
	if original.has(key): return
	var callback:=descendant_added.bind(id)
	var exit_callback:=restore.bind(key)
	original[key]={"owner":weakref(node),"root":id,"callback":callback,"exit_callback":exit_callback,"canvas":node is CanvasItem}
	node.tree_exiting.connect(exit_callback)
	if node is CanvasItem:
		original[key].material=node.material; original[key].inherit=node.use_parent_material
		# Existing shader subtrees must not inherit a different material.
		if node.material!=null: return
		if roots[id].supported and node.material==null:
			if top: node.material=roots[id].material; node.use_parent_material=false
			else: node.use_parent_material=true
	node.child_entered_tree.connect(callback)
	for child in node.get_children(): watch(child,id)
func descendant_added(child: Node,id: int) -> void:
	if roots.has(id) and not closed: watch(child,id)
func restore(key: int) -> void:
	if not original.has(key): return
	var row: Dictionary=original[key]; var node: Node=row.owner.get_ref()
	if is_instance_valid(node):
		if node.child_entered_tree.is_connected(row.callback): node.child_entered_tree.disconnect(row.callback)
		if node.tree_exiting.is_connected(row.exit_callback): node.tree_exiting.disconnect(row.exit_callback)
		if row.canvas: node.material=row.material; node.use_parent_material=row.inherit
	original.erase(key)
func removed(node: Node) -> void:
	var id:=node.get_instance_id()
	if not roots.has(id): return
	for key in original.keys():
		if original[key].root==id: restore(key)
	roots.erase(id)
func regions(node: Control) -> Array:
	var result: Array=[]
	if not node.is_visible_in_tree() or not node is PanelContainer: return result
	if not node.get_meta("native_window_omit_body",false): result.append(node.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,node.size))
	for ref in node.get_meta("native_window_extras",[]):
		var extra: Control=ref.get_ref() if ref is WeakRef else null
		if is_instance_valid(extra) and extra.is_visible_in_tree(): result.append(extra.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,extra.size))
	return result
func _process(_delta: float) -> void:
	if closed or not is_instance_valid(host): return
	var ordered: Array=[]
	for child in host.get_children():
		if child is Control and roots.has(child.get_instance_id()): ordered.append(child)
	ordered.sort_custom(func(a,b):return a.z_index<b.z_index if a.z_index!=b.z_index else a.get_index()<b.get_index())
	var front: Array=[]; overflow=0
	var viewport: Vector2=host.get_viewport_rect().size
	ordered.reverse()
	for node in ordered:
		var state: Dictionary=roots[node.get_instance_id()]; var masks: Array=[]
		masks=front.duplicate()
		if masks.size()>LIMIT: overflow+=1
		# Never silently discard coverage: excessive simultaneous windows leave
		# this root unmasked and expose a diagnostic for the unsupported layout.
		if masks.size()>LIMIT: masks.clear()
		if state.supported and state.signature!=[viewport,masks]:
			state.signature=[viewport,masks.duplicate()]; updates+=1
			var packed:=PackedVector4Array(); packed.resize(LIMIT)
			for at in masks.size():
				var rect: Rect2=masks[at]; packed[at]=Vector4(rect.position.x/viewport.x,rect.position.y/viewport.y,rect.end.x/viewport.x,rect.end.y/viewport.y)
			state.material.set_shader_parameter("covered",packed); state.material.set_shader_parameter("covered_count",masks.size())
		front.append_array(regions(node))
func snapshot() -> Dictionary:
	return {"roots":roots.size(),"items":original.size(),"updates":updates,"overflow":overflow,"custom_root_materials":roots.values().filter(func(row):return not row.supported).size(),"full_window_parity":false}
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(host) and host.child_entered_tree.is_connected(added): host.child_entered_tree.disconnect(added)
	if is_instance_valid(host) and host.child_exiting_tree.is_connected(removed): host.child_exiting_tree.disconnect(removed)
	for key in original.keys(): restore(key)
	original.clear(); roots.clear()
