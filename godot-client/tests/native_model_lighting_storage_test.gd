extends "res://tests/native_model_storage_test.gd"
const NativeLightingMaterial=preload("res://systems/native_render/native_model_material.gd")
func material_owner(style: int,direct: bool) -> Dictionary:
	var node:=TransformProbe.new(); root.add_child(node); var mesh:=MeshInstance3D.new(); node.add_child(mesh); mesh.mesh=BoxMesh.new()
	var source:=StandardMaterial3D.new(); source.albedo_color=Color(.13,.52,.91,.61)
	source.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if style>=2 else BaseMaterial3D.TRANSPARENCY_DISABLED
	var material:=NativeLightingMaterial.new(); material.configure(source,[.8,.6,.4],[0.0,0.0,0.0])
	if style%2==0: mesh.material_override=material
	else: mesh.set_surface_override_material(0,material)
	var control:=source_node()
	var metadata:={"root":0,"emitterFields":{},"parts":[{"type":"trimesh","node":control,"properties":{},"children":[],"transparencyHint":style==3}]}
	var pose:=CountedPose.new(); pose.compiled_controls=true; pose.direct_flush=direct; pose.bulk_evaluation=true; pose.prepared_plan=true; pose.native_storage=direct; pose.configure(metadata,{"parts":[0]},[node])
	if direct: expect(pose.native_context!=null and pose.native_failures==0,true,"Compiled storage configures native shader material safely"); native_material_cases+=1
	return {"pose":pose,"node":node,"material":mesh.get_active_material(0),"base":material}
