// Read-only source/log diagnostic. No engine launch, GPU, connection, or fix.
// The factor-zero arithmetic is conditional; it does not measure an invalid GPU read.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const manifestFile=path.join(source,'.cache/native-presentation-parity/root/whole-character-client-v2/manifest.json');
const manifestBytes=fs.readFileSync(manifestFile),manifest=JSON.parse(manifestBytes);
const baseBytes=fs.readFileSync(manifest.base.file),base=JSON.parse(baseBytes);
if(sha(baseBytes)!==manifest.base.sha256)throw Error('Frozen V6 manifest changed');
const relatives=[
 'systems/native_render/native_surface_transfer.gd',
 'systems/native_render/native_surface_state.gd',
 'systems/native_render/native_model_material.gd',
 'systems/native_render/resource_pool.gd',
 'systems/native_render/model_instance.gd',
 'systems/native_render/model_template.gd',
 'systems/native_render/live_world.gd',
 'systems/native_render/native_scene_visibility_runtime.gd',
 'tools/native_parity/ui/actor-alpha-owner.gd',
 'tools/native_parity/ui/actor-alpha-publication.gd',
 'tools/native_parity/highlighting/native_highlight_material.gd',
];
const views=new Map(),pins=[];
for(const relative of relatives){
 const file=path.join(manifest.project,relative),bytes=fs.readFileSync(file),pin=manifest.pins.find(p=>p.relative===relative);
 if(!pin||sha(bytes)!==pin.sha256)throw Error('Live candidate source changed: '+relative);
 views.set(relative,bytes.toString('utf8'));pins.push({relative,sha256:sha(bytes)});
}
const transfer=views.get(relatives[0]),glow=views.get(relatives.at(-1));
if(!transfer.includes('instance uniform float nwn_tile_fog_factor=1.0;')||!transfer.includes('nwn_surface_fog_color*=nwn_tile_factor*nwn_tile_factor;')||/instance\s+uniform/.test(glow))throw Error('Audited shader branch changed');
const logFile=path.join(source,'reports/whole-character-live-test-v1.engine.log');
const liveBytes=fs.readFileSync(logFile),prefix=liveBytes.subarray(0,liveBytes.lastIndexOf(10)+1);
const lines=prefix.toString('utf8').split(/\r?\n/);
const occurrences=needle=>lines.flatMap((line,index)=>line.includes(needle)?[index+1]:[]);
const capacities=occurrences('Too many instances using shader instance variables. Increase buffer size in Project Settings.');
const duplicates=occurrences('global_shader_uniforms.instance_buffer_pos.has(p_instance)');
const offsets=values=>({count:values.length,firstLine:values[0]??null,lastLine:values.at(-1)??null});
const engineEvidence=path.join(source,'.cache/native-presentation-parity/loading-agent/instance-uniform-allocation-audit-v1/source-evidence.json');
const scenarios=[1,0].map(factor=>{
 // Literal vertex/transfer branch: normal fog disabled, depth1m, arbitrary area color/range.
 const state={enabled:0,begin:0,inverse:1,color:[0.725,0.627,0.290]};
 if(factor<1){state.begin=21.2132034301758*factor;const end=45*factor+0.1;state.color=state.color.map(c=>c*factor*factor);state.enabled=1;state.inverse=1/(end-state.begin);}
 const fog=state.enabled===0?0:(1-state.begin)*state.inverse,weight=Math.min(1,Math.max(0,fog));
 const display=[0.5,0.4,0.3],transferred=display.map((c,i)=>c*(1-weight)+state.color[i]*weight);
 return {factor,normalFogInitiallyEnabled:false,viewDepthMeters:1,fogWeight:weight,transferredRGB:transferred};
});
const report={
 version:1,scope:'Read-only live-overlay enrollment and conditional shader arithmetic; no GPU readback or fix',
 candidate:{file:manifestFile,sha256:sha(manifestBytes),mode:manifest.mode},
 base:manifest.base,
 overlayOnly:manifest.pins.filter(p=>base.pins.find(b=>b.relative===p.relative)?.sha256!==p.sha256).map(p=>({relative:p.relative,sha256:p.sha256})),
 sources:pins,
 logSnapshot:{file:logFile,prefixBytes:prefix.length,prefixSha256:sha(prefix),capacity:offsets(capacities),duplicate:offsets(duplicates),capacityPrecedesDuplicate:capacities.length>0&&duplicates.length>0&&capacities[0]<duplicates[0]},
 engineSourceEvidence:{file:engineEvidence,sha256:sha(fs.readFileSync(engineEvidence))},
 sourceFacts:[
  {source:relatives[0],line:12,fact:'Every native-surface shader declares an instance uniform even while physical tile fog is unbound.'},
  {source:relatives[3],line:221,fact:'Native surface materials enable the native world fog/transfer carrier.'},
  {source:relatives[4],line:88,fact:'Each renderable source Part owns a MeshInstance3D; compact layout reuses the Part node, not another Part renderer RID.'},
  {source:relatives[5],line:115,fact:'PackedScene instantiation creates physical placement instances while sharing material resources.'},
  {source:relatives[6],line:217,fact:'LiveWorld disables terrain MultiMesh batches; normal per-Part geometry remains enrolled.'},
  {source:relatives[7],line:165,fact:'Tile-fog callback rejects publication while the physical fog owner is unavailable; default1 remains intended.'},
  {source:relatives[8],line:41,fact:'Actor alpha replaces a mesh material with a private alpha material; it does not create another MeshInstance.'},
  {source:relatives[9],line:43,fact:'Alpha may change transparency; NativeModelMaterial24 then refreshes shader selection, making material dirtiness plausible on an already failed RID.'},
  {source:relatives[10],line:22,fact:'Whole-character glow uses an additive unshaded material with no instance-uniform declaration.'},
 ],
 conditionalShaderArithmetic:{implementation:'JavaScript scalar evaluation of the literal branch; not GPU execution',scenarios,invalidReadValueMeasured:false,conclusion:'A failed-offset value of0 forces black native-surface transfer at depth>=0.1m even when ordinary fog is disabled. The source error path has no declared-default fallback; the actual invalid GPU read remains unmeasured.'},
 actions:{engineLaunched:false,gpuUsed:false,connectionMade:false,productionEdited:false},
};
const output=process.argv[2];
if(output)fs.writeFileSync(path.resolve(output),JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({output:output?path.resolve(output):null,overlayFiles:report.overlayOnly.length,capacity:report.logSnapshot.capacity,duplicate:report.logSnapshot.duplicate,capacityPrecedesDuplicate:report.logSnapshot.capacityPrecedesDuplicate,scenarios,invalidReadValueMeasured:false}));
