// SOURCE OVERLAY ONLY. Do not run until root grants even this small preparer.
// Reads selected source/receipt files, never clones a graph or builds/launches.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';import {digest} from './processor-graph.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),[label,parentSha]=process.argv.slice(2);
if(!/^terrain-height-integration-[a-z0-9-]+$/.test(label??'')||!/^[0-9a-f]{64}$/.test(parentSha??''))throw Error('Fresh owned overlay label and root-reviewed parent manifest SHA required');
const parentFile=path.join(project,'.cache/native-140fps/root/drive-clear-fenced-v2/manifest.json'),parentBytes=fs.readFileSync(parentFile);if(digest(parentBytes)!==parentSha)throw Error('Frozen clear parent differs');const parent=JSON.parse(parentBytes),pins=new Map(parent.pins.map(p=>[p.relative,p.sha256]));
if(pins.get('.cache/native-kernel/nwn-particle-kernel.dll')!=='101efc79d3c2985d2267d05f9ffbd01578d2f14bbf52bad575ef921cd2412417')throw Error('Expected independently tested clear DLL parent');
const stage=path.join(project,'.cache/native-140fps/loading-agent',label),overlay=path.join(stage,'overlay');if(fs.existsSync(stage))throw Error('Existing source evidence preserved');
const goldenFile=path.join(project,'.cache/native-140fps/loading-agent/drive-height-golden-v1/receipt.json'),goldenBytes=fs.readFileSync(goldenFile),golden=JSON.parse(goldenBytes.toString('utf8').replace(/^\uFEFF/,''));
if(digest(goldenBytes)!=='78f4b8e56251b0a87ef74a8cde93d94de1bf3ff229f4d390f3a8972c961e4421'||golden.success!==true||golden.oracle?.checks!==103304)throw Error('Accepted standalone golden proof differs');
const kernelFile=path.join(project,'tools/perf140/loading/drive_height_kernel.hpp'),kernel=fs.readFileSync(kernelFile);if(digest(kernel)!=='1f38c101efd7e45dc50c2ba1af1a053736914a5012a32aa95a19db078d2b796a'||golden.sourcePins?.['drive_height_kernel.hpp']!==digest(kernel))throw Error('Accepted strict numeric kernel changed');
const inputs=[],outputs=new Map();
function source(relative){const bytes=fs.readFileSync(path.join(parent.project,relative));if(digest(bytes)!==pins.get(relative))throw Error('Selected source seam changed '+relative);inputs.push({relative,sha256:digest(bytes),bytes:bytes.length});return {text:bytes.toString('utf8').replaceAll('\r\n','\n'),crlf:bytes.includes(Buffer.from('\r\n'))};}
function once(text,before,after){if(text.split(before).length!==2)throw Error('Height overlay seam differs: '+before.slice(0,100));return text.replace(before,after);}
const cpp=source('native/particle_kernel.cpp');let code=cpp.text;
code=once(code,'#include <vector>\n','#include <vector>\n#include <thread>\n');
code=once(code,'#include "experimental/frame_pose_cache.hpp"\n','#include "experimental/frame_pose_cache.hpp"\n#include "experimental/terrain_height_kernel.hpp"\n');
code=once(code,'#include "drive_clear_bridge.hpp"\n','#include "drive_clear_bridge.hpp"\n#include "terrain_height.hpp"\n');
code=once(code,' register_scene_geometry(property);\n',' register_scene_geometry(property);\n terrain_height_native::register_owner(property);\n');
code=once(code,'if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;light_input_registry::unregister_owner();','if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;terrain_height_native::unregister_owner();light_input_registry::unregister_owner();');
code=once(code,' if(!visual_selection::bind(address))return false;\n',' if(!visual_selection::bind(address))return false;\n terrain_height_native::bind(address);\n');
outputs.set('native/particle_kernel.cpp',Buffer.from(cpp.crlf?code.replaceAll('\n','\r\n'):code));
const terrain=source('systems/native_render/terrain_surface.gd');let gd=terrain.text;
gd=once(gd,'const Geometry=preload("res://systems/native_render/scene_geometry.gd")\n','const Geometry=preload("res://systems/native_render/scene_geometry.gd")\nconst HeightCalculations=preload("res://systems/native_render/terrain_height_cache.gd")\n');
gd=once(gd,'var collision_meshes: Dictionary={}\n','var collision_meshes: Dictionary={}\nvar _height_calculations=HeightCalculations.new()\n');
gd=once(gd,'func configure(catalog,source: Dictionary,cache_path: String) -> void:\n','func configure(catalog,source: Dictionary,cache_path: String) -> void:\n\t_height_calculations.clear()\n');
gd=once(gd,'\tvar name:=str(requests[id]); requests.erase(id)\n','\tvar name:=str(requests[id]); requests.erase(id)\n\tif name=="@surfacemat":_height_calculations.clear()\n\telse:_height_calculations.invalidate(name)\n');
const originalReturn='\treturn Surface.f(Surface.height(meshes[tile.model],table,local)+Surface.f(tile.position.y))\n';
gd=once(gd,originalReturn,'\tif not _height_calculations.enabled:\n\t'+originalReturn+'\tvar calculated: Variant=_height_calculations.calculate(str(tile.model),meshes[tile.model],table,local)\n\tvar local_height: float=calculated if calculated is float else Surface.height(meshes[tile.model],table,local)\n\treturn Surface.f(local_height+Surface.f(tile.position.y))\n');
gd=once(gd,'\tvar state:=stats.duplicate(true); state.merge(','\tvar state:=stats.duplicate(true); state.height_calculations=_height_calculations.snapshot(); state.merge(');
gd=once(gd,'func detach_prepared_data() -> Dictionary:\n','func detach_prepared_data() -> Dictionary:\n\t_height_calculations.clear()\n');
gd=once(gd,'\tclosed=true\n','\t_height_calculations.close()\n\tclosed=true\n');
outputs.set('systems/native_render/terrain_surface.gd',Buffer.from(terrain.crlf?gd.replaceAll('\n','\r\n'):gd));
outputs.set('native/experimental/terrain_height_kernel.hpp',kernel);
outputs.set('native/terrain_height.hpp',fs.readFileSync(path.join(project,'tools/perf140/loading/terrain_height_adapter.hpp')));
outputs.set('systems/native_render/terrain_height_cache.gd',fs.readFileSync(path.join(project,'tools/perf140/loading/terrain_height_cache.gd')));
fs.mkdirSync(overlay,{recursive:true});const rows=[];
for(const [relative,bytes]of outputs){const file=path.join(overlay,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);rows.push({relative,beforeSha256:pins.get(relative)??null,sha256:digest(bytes),bytes:bytes.length});}
const manifest={version:1,label,kind:'source-only-overlay',parent:{file:parentFile,sha256:parentSha,project:parent.project},golden:{file:goldenFile,sha256:digest(goldenBytes)},inputs,outputs:rows,flag:{name:'terrain-height',choices:['script','native'],default:'script'},preservedParentPins:['systems/native_render/live_world.gd','systems/native_render/drive_collision_indexed.gd','native/scene_geometry.hpp','native/drive_clear_kernel.hpp','native/drive_clear_bridge.hpp'].map(relative=>({relative,sha256:pins.get(relative),scope:'Parent manifest identity retained; this small preparer does not rehash/copy the full graph.'})),class:'NwnTerrainHeight',projectCloned:false,nativeBuilds:0,testsRun:false,graphics:0,serverConnections:0,scope:'Independent source-only terrain height adapter. Existing physical/clear modes and accepted kernel unchanged; no runtime/latency/authority acceptance.'};
const file=path.join(stage,'source-overlay.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({file,sha256:digest(fs.readFileSync(file)),outputs:rows.length,sourceOnly:true}));
