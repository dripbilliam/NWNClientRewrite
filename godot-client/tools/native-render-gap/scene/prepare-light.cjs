const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const originalPath = path.join(root, 'systems/native_render/model_point_light.gd');
const original = fs.readFileSync(originalPath, 'utf8');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
if (sha(original) !== 'e803135ef951ea13d3d83267f0d671d2072e2df4d676bdf320a98fd9b4d1b9f6') throw new Error('Original changed; inspect before rebasing');
const start = original.indexOf('func configure(properties: Dictionary) -> void:');
const end = original.indexOf('func apply_native_admission(', start);
const originalBody = original.slice(start, end).replace('func configure(', 'func _configure_original(');
const guard = `# Public configure remains one-argument. Opaque synchronous observers, editor
# gizmos, inherited scripts and malformed inputs retain the original body.
func configure(properties: Dictionary) -> void:
\tif get_script().get_base_script()==null and _can_publish_final(properties):
\t\t_configure_final(properties,false)
\telse:
\t\t_configure_original(properties)
func _finite_component(value: Variant) -> bool:
\treturn (value is int or value is float) and is_finite(float(value)) and absf(float(value))<=1000000.0
func _can_publish_final(properties: Dictionary) -> bool:
\tif Engine.is_editor_hint() or get_child_count(true)!=0 or not visibility_changed.get_connections().is_empty(): return false
\tif not _finite_component(native_fade) or native_slot < -1 or native_slot>=Palette.CAPACITY: return false
\tvar source: Variant=properties.get("color",[1.0,1.0,1.0])
\tif not source is Array or source.size()<3: return false
\tfor component in 3:
\t\tif not _finite_component(source[component]): return false
\tfor key in ["radius","multiplier","shadow","ambientonly"]:
\t\tif properties.has(key) and not _finite_component(properties[key]): return false
\treturn true
`;
const final = `# Compute final support once: authored->enhanced->authored range bounces
# trigger renderer dependency/BVH work; equal shadow setters advance versions.
func _configure_final(properties: Dictionary,preserve_selected_shadow: bool) -> void:
\tanimation_cached=false
\tvar selected_shadow:=shadow_enabled if preserve_selected_shadow else false
\tvar color_value: Array=properties.get("color",[1.0,1.0,1.0])
\tvar final_color:=Color(color_value[0],color_value[1],color_value[2])
\tvar radius:=maxf(0,float(properties.get("radius",0))); var multiplier:=maxf(0,float(properties.get("multiplier",1)))
\tvar final_range:=maxf(0.01,radius)
\tvar final_energy:=multiplier
\tvar final_visible:=radius>0 and multiplier>0
\tvar final_attenuation:=1.0
\tvar final_specular:=light_specular
\tif get_meta("native_enhanced_light",false) and (not is_inside_tree() or native_slot>=0):
\t\tnative_state=Policy.point(properties,2.0,0.2,1.5,native_fade)
\t\tvar rgb: Vector3=native_state.color
\t\tfinal_color=Color(rgb.x,rgb.y,rgb.z).linear_to_srgb(); final_energy=1.0
\t\tfinal_range=maxf(0.01,native_state.range); final_attenuation=0.0; final_visible=native_state.enabled
\t\tif native_slot>=0:
\t\t\tfinal_specular=float(native_slot+32)*0.5
\t\t\tPalette.update(native_slot,global_position,native_state)
\telse:
\t\tnative_state.clear(); final_specular=0.5
\tfinal_visible=final_visible and native_admitted
\t# Keep final color/energy/attenuation writes, including signed zero bits.
\t# Positive range is normalized to the engine's float32 property boundary.
\tlight_color=final_color; light_energy=final_energy
\tfinal_range=Vector3(final_range,0,0).x
\tif omni_range!=final_range: omni_range=final_range
\tomni_attenuation=final_attenuation
\tif light_specular!=final_specular: light_specular=final_specular
\tif visible!=final_visible: visible=final_visible
\tvar shadow_requested:=float(properties.get("shadow",0))>0 and float(properties.get("ambientonly",0))==0
\tvar final_shadow:=selected_shadow and shadow_requested
\tif shadow_enabled!=final_shadow: shadow_enabled=final_shadow
\tif native_properties!=properties:
\t\tnative_properties=properties.duplicate(true); native_properties_revision+=1
\t\tset_meta("native_model_light_properties",native_properties)
\tset_meta("native_shadow_requested",shadow_requested)
`;
let result = original.slice(0,start)+guard+originalBody+final+original.slice(end);
const eol = original.includes('\r\n') ? '\r\n' : '\n';
const originalAdmission = ['\tvar had_shadow:=shadow_enabled','\tconfigure(get_meta("native_model_light_properties",{}))','\tshadow_enabled=had_shadow and get_meta("native_shadow_requested",false)'].join(eol);
if (!result.includes(originalAdmission)) throw new Error('Admission seam changed');
result = result.replace(originalAdmission, `\tvar properties: Dictionary=get_meta("native_model_light_properties",{})
\tif get_script().get_base_script()==null and _can_publish_final(properties):
\t\t_configure_final(properties,true)
\telse:
\t\tvar had_shadow:=shadow_enabled
\t\tconfigure(properties)
\t\tshadow_enabled=had_shadow and get_meta("native_shadow_requested",false)`);
const originalAnimation = ['\tvar had_shadow:=shadow_enabled','\tconfigure(properties)','\tshadow_enabled=had_shadow and get_meta("native_shadow_requested",false)'].join(eol);
if (!result.includes(originalAnimation)) throw new Error('Animation seam changed');
result = result.replace(originalAnimation, `\tif get_script().get_base_script()==null and _can_publish_final(properties):
\t\t_configure_final(properties,true)
\telse:
\t\tvar had_shadow:=shadow_enabled
\t\tconfigure(properties)
\t\tshadow_enabled=had_shadow and get_meta("native_shadow_requested",false)`);
const target=path.join(__dirname,'model_point_light_candidate.gd');
if (fs.existsSync(target)) throw new Error('Candidate already exists; preserve it');
fs.writeFileSync(target,result,{flag:'wx'});
fs.writeFileSync(path.join(__dirname,'source-proof.json'),JSON.stringify({createdAtUtc:new Date().toISOString(),original:originalPath,originalSha256:sha(original),candidate:target,candidateSha256:sha(result),originalFallbackBodySha256:sha(originalBody),oneArgumentPublicApi:true,unchangedOriginalFallback:true,sourceOnly:true},null,2),{flag:'wx'});
console.log(JSON.stringify({candidate:target,sha256:sha(result)}));
