import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2];
if(!/^material-init-[a-z0-9-]+$/.test(label??''))throw Error('Fresh material initialization label required');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const sourceManifest=path.join(project,'.cache/native-render-trials/native-manual-light-input-movement-1793869228225/overlay.json'),parentBytes=fs.readFileSync(sourceManifest),parent=JSON.parse(parentBytes);
const stage=path.join(project,'.cache/native-140fps/loading-agent',label);if(fs.existsSync(stage))throw Error('Existing evidence preserved');
const baseline=path.join(stage,'baseline'),candidate=path.join(stage,'candidate'),pins=[];
for(const target of [baseline,candidate]){
 fs.mkdirSync(target,{recursive:true});for(const pin of parent.trialPins){const bytes=fs.readFileSync(path.join(parent.rendererProject,pin.relative));if(hash(bytes)!==pin.sha256)throw Error('Frozen source changed: '+pin.relative);const file=path.join(target,pin.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);if(target===baseline)pins.push({...pin});}
}
const once=(s,a,b)=>{if(s.split(a).length!==2)throw Error('Batched material boundary changed: '+a);return s.replace(a,b);};
const materialRelative='systems/native_render/native_model_material.gd',poolRelative='systems/native_render/resource_pool.gd';
const originalMaterial=fs.readFileSync(path.join(baseline,materialRelative)),originalPool=fs.readFileSync(path.join(baseline,poolRelative));
let material=originalMaterial.toString().replaceAll('\r\n','\n'),pool=originalPool.toString().replaceAll('\r\n','\n');
material=once(material,'static var shaders: Dictionary={}','static var shaders: Dictionary={}\nvar _configuring_shader:=false');
material=once(material,'func configure(source: StandardMaterial3D,ambient_value: Array,raw_emission: Array,standard: bool=false,quality: int=2) -> void:\n\tstandard_specular=standard; standard_quality=quality',
 'func configure(source: StandardMaterial3D,ambient_value: Array,raw_emission: Array,standard: bool=false,quality: int=2,surface_policy: Variant=null) -> void:\n\t_configuring_shader=true\n\tstandard_specular=standard; standard_quality=quality');
material=once(material,'\ttransparency=source.transparency; refresh_shader()',
 '\ttransparency=source.transparency\n\t# A missing optional policy retains the legacy reconfiguration behavior.\n\tif surface_policy is bool:native_surface_output=surface_policy\n\t_configuring_shader=false; refresh_shader()');
material=once(material,'func refresh_shader() -> void:\n\tif native_surface_output:',
 'func refresh_shader() -> void:\n\tif _configuring_shader:return\n\tif native_surface_output:');
pool=once(pool,'corrected.configure(result,ambient,emission,native_standard,2); published=corrected',
 'corrected.configure(result,ambient,emission,native_standard,2,native_surface_output); published=corrected');
pool=once(pool,'\t\tcorrected.native_surface_output=native_surface_output; corrected.native_world_fog=native_surface_output',
 '\t\tcorrected.native_world_fog=native_surface_output');
fs.writeFileSync(path.join(candidate,materialRelative),material);fs.writeFileSync(path.join(candidate,poolRelative),pool);
const fixture='tests/fixtures/native_perf140_loading_model_material_before.gd';for(const target of [baseline,candidate])fs.writeFileSync(path.join(target,fixture),originalMaterial);
const changed=[{relative:materialRelative,before:hash(originalMaterial),after:hash(Buffer.from(material))},{relative:poolRelative,before:hash(originalPool),after:hash(Buffer.from(pool))}];
const manifest={version:1,label,stage,baseline,candidate,parent:{file:sourceManifest,sha256:hash(parentBytes),rendererProject:parent.rendererProject},pins,fixture:{relative:fixture,sha256:hash(originalMaterial)},changed,backup:changed.map(p=>({file:path.join(baseline,p.relative),sha256:p.before,verified:hash(fs.readFileSync(path.join(baseline,p.relative)))===p.before})),serverConnections:0,sharedNativeBuilds:0,scope:'New material configuration defers intermediate shader refreshes and selects its final surface-output policy before one refresh. Later setters, final shader code, uniforms and primary resource-cache policy are unchanged.'};
const file=path.join(stage,'manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({success:true,file,baseline,candidate,changed,backupVerified:manifest.backup.every(p=>p.verified)}));
