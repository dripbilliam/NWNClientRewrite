import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const label=process.argv[2];if(!/^weak-residency-[a-z0-9-]+$/.test(label??''))throw Error('Fresh weak residency label required');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const sourceManifest=path.join(project,'.cache/native-render-trials/native-manual-light-input-movement-1793869228225/overlay.json');
const parentBytes=fs.readFileSync(sourceManifest),parent=JSON.parse(parentBytes);
const stage=path.join(project,'.cache/native-140fps/loading-agent',label);if(fs.existsSync(stage))throw Error('Existing candidate/evidence preserved');
const baseline=path.join(stage,'baseline'),candidate=path.join(stage,'candidate');
const pins=[];
for(const target of [baseline,candidate]){
 fs.mkdirSync(target,{recursive:true});
 for(const pin of parent.trialPins){const bytes=fs.readFileSync(path.join(parent.rendererProject,pin.relative));if(hash(bytes)!==pin.sha256)throw Error('Frozen source differs: '+pin.relative);const file=path.join(target,pin.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);if(target===baseline)pins.push({...pin});}
}
const relative='systems/native_render/resource_pool.gd';const original=fs.readFileSync(path.join(baseline,relative));
const once=(s,a,b)=>{if(s.split(a).length!==2)throw Error('ResourcePool boundary changed: '+a);return s.replace(a,b);};
let text=original.toString().replaceAll('\r\n','\n');
text=once(text,'var resource_order:={"mesh":[],"texture":[],"material":[]}',
 'var resource_order:={"mesh":[],"texture":[],"material":[]}\nvar weak_residency=preload("res://systems/native_render/weak_resource_residency.gd").new()');
text=once(text,'\t\tentries.erase(oldest); stats[kind+"_evictions"]+=1',
 '\t\tif kind in ["mesh","texture","material"]:weak_residency.remember(kind,oldest,entries.get(oldest))\n\t\tentries.erase(oldest); stats[kind+"_evictions"]+=1');
text=once(text,'\tentries[key]=value; touch(kind,key)',
 '\tentries[key]=value; touch(kind,key)\n\tif kind in ["mesh","texture","material"]:weak_residency.forget(kind,key)');
text=once(text,'\tif textures.has(key): stats.texture_hits += 1; touch("texture",key); return textures[key]',
 '\tif textures.has(key): stats.texture_hits += 1; touch("texture",key); return textures[key]\n\tif maximum_textures>0:\n\t\tvar resident: Texture2D=weak_residency.take("texture",key) as Texture2D\n\t\tif resident!=null:\n\t\t\tstats.texture_hits+=1;stats.texture_resident_hits=int(stats.get("texture_resident_hits",0))+1\n\t\t\tretain("texture",textures,key,resident,maximum_textures);return resident');
text=once(text,'\tif meshes.has(key): stats.mesh_hits += 1; touch("mesh",key); return meshes[key]',
 '\tif meshes.has(key): stats.mesh_hits += 1; touch("mesh",key); return meshes[key]\n\tif maximum_meshes>0:\n\t\tvar resident: ArrayMesh=weak_residency.take("mesh",key) as ArrayMesh\n\t\tif resident!=null:\n\t\t\tstats.mesh_hits+=1;stats.mesh_resident_hits=int(stats.get("mesh_resident_hits",0))+1\n\t\t\tretain("mesh",meshes,key,resident,maximum_meshes);return resident');
text=once(text,'\tif materials.has(key): stats.material_hits += 1; touch("material",key); return materials[key]',
 '\tif materials.has(key): stats.material_hits += 1; touch("material",key); return materials[key]\n\tif maximum_materials>0:\n\t\tvar resident: Material=weak_residency.take("material",key) as Material\n\t\tif resident!=null:\n\t\t\tstats.material_hits+=1;stats.material_resident_hits=int(stats.get("material_resident_hits",0))+1\n\t\t\tretain("material",materials,key,resident,maximum_materials);return resident');
text=once(text,'\tstate.template_preparation_peaks=template_preparation_peaks.duplicate(true)',
 '\tstate.template_preparation_peaks=template_preparation_peaks.duplicate(true)\n\tstate.weak_residency=weak_residency.snapshot()');
text=once(text,'\tfor order in resource_order.values(): order.clear()',
 '\tfor order in resource_order.values(): order.clear()\n\tweak_residency.clear()');
fs.writeFileSync(path.join(candidate,relative),text);
const helperSource=path.join(project,'tools/perf140/loading/weak_resource_residency.gd'),helperBytes=fs.readFileSync(helperSource),helper='systems/native_render/weak_resource_residency.gd';
for(const target of [baseline,candidate])fs.writeFileSync(path.join(target,helper),helperBytes);
const changed=[{relative,before:hash(original),after:hash(Buffer.from(text))},{relative:helper,before:null,after:hash(helperBytes)}];
const manifest={version:1,label,stage,baseline,candidate,parent:{file:sourceManifest,sha256:hash(parentBytes),rendererProject:parent.rendererProject},pins,changed,backup:{file:path.join(baseline,relative),sha256:hash(original),verified:hash(fs.readFileSync(path.join(baseline,relative)))===hash(original)},sharedNativeBuilds:0,serverConnections:0,policy:'Only ResourcePool cache lookup/eviction/clear and numeric snapshot diagnostics change; primary capacities, resource keys, material/render preparation and source validation remain original.'};
const file=path.join(stage,'manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({success:true,file,baseline,candidate,changed,backupVerified:manifest.backup.verified}));
