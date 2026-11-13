import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const label=process.argv[2]??'pushed-fields-source-v4';if(!/^[a-z0-9-]+$/.test(label))throw Error('Private label required');
const base=path.join(project,'.cache/native-140fps/render-agent'),stage=path.join(base,label);if(fs.existsSync(stage))throw Error('Previous source proof retained');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),fileHash=f=>hash(fs.readFileSync(f));
const parentFile=path.join(project,'.cache/native-140fps/root/builtin-light-fenced-v2/manifest.json'),parent=JSON.parse(fs.readFileSync(parentFile));
if(fileHash(parentFile)!=='672a89f094e3f8b845175b947556e3ca9b8c3bb4bd0e149a8f79058ad2cdc0d9')throw Error('Corrected runtime parent changed');
function original(relative){const pin=parent.pins.find(p=>p.relative===relative);if(!pin)throw Error('Missing parent pin '+relative);const b=fs.readFileSync(path.join(parent.project,relative));if(hash(b)!==pin.sha256)throw Error('Parent source drift '+relative);return b;}
const draft=path.join(project,'tools/perf140/render/pushed_fields_v4');
const point=fs.readFileSync(path.join(draft,'model_point_light.gd'));
const normalize=s=>s.replace(/\r\n/g,'\n').trim();
function methods(s){s=normalize(s).split('\n\n# Private candidate:')[0];const matches=[...s.matchAll(/^func (\w+)\([^]*?(?=^func |$(?![\s\S]))/gm)];return new Map(matches.map(m=>[m[1],normalize(m[0])]));}
const oldMethods=methods(original('systems/native_render/model_point_light.gd').toString()),newMethods=methods(point.toString());
for(const [name,old]of oldMethods){let next=newMethods.get(name);if(!next)throw Error('Canonical method disappeared '+name);if(name==='configure')next=next.replace(/^\t_begin_native_input_write\(\)\n/m,'').replace(/^\t_end_native_input_write\(\)\n?/m,'');if(name==='_exit_tree')next=next.replace(/^\tbind_native_input_registry\(null\)\n/m,'');if(normalize(next)!==old)throw Error('Unrelated canonical method changed '+name);}
const nativeFocusRelative='systems/native_render/focus_lighting_native_input_candidate.gd';
const focus=fs.readFileSync(path.join(draft,'focus_lighting_native_input_candidate.gd'),'utf8').replace('SOURCE_PREPARER_MUST_PIN_EXACT_POINT_SHA256',hash(point));
if(focus.includes('SOURCE_PREPARER_MUST_PIN'))throw Error('Source pin placeholder remains');
const oldFocusMethods=methods(original(nativeFocusRelative).toString()),newFocusMethods=methods(focus);
for(const name of ['_init','enable_history','close','history_frame'])if(oldFocusMethods.get(name)!==newFocusMethods.get(name))throw Error('Unrelated registry/history method changed '+name);
fs.mkdirSync(stage,{recursive:true});const module=path.join(stage,'engine-module/nwn_light_input_registry');fs.mkdirSync(module,{recursive:true});const pins=[];
for(const relative of ['config.py','SCsub','register_types.h','register_types.cpp','light_input_registry.h','light_input_registry.cpp']){const b=fs.readFileSync(path.join(draft,'engine_module/nwn_light_input_registry',relative));fs.writeFileSync(path.join(module,relative),b,{flag:'wx'});pins.push({relative,sha256:hash(b)});}
const fixtures=[];
function install(relative,bytes,scope){const destination=path.join(stage,relative);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,bytes,{flag:'wx'});fixtures.push({relative,file:destination,sha256:hash(bytes),scope});}
install('systems/native_render/model_point_light.gd',point,'Exact original canonical methods with field setters and scoped writer hooks');
install(nativeFocusRelative,Buffer.from(focus),'Same original solver/publication; exact-script opt-in claim and unregister hook only');
install('systems/native_render/focus_lighting_builtin_input_candidate.gd',original('systems/native_render/focus_lighting_builtin_input_candidate.gd'),'Retained explicit-super constructor and read-only actual class snapshot');
for(const relative of ['tests/native_perf140_render_pushed_fields_v4_test.gd','tests/native_perf140_render_builtin_light_registry_test.gd','tests/native_perf140_render_builtin_light_constructor_test.gd'])install(relative,fs.readFileSync(path.join(project,relative)),'Focused fixture');
const engineDescriptorFile=path.join(base,'engine-builtin-light-v2/engine-descriptor.json'),engineDescriptor=JSON.parse(fs.readFileSync(engineDescriptorFile));
if(fileHash(engineDescriptorFile)!=='0f640f95b3ffc2a0a2cf65695004ea5c77eae36718a6a43ae87199578902991e'||fileHash(engineDescriptor.engines.candidate.path)!==engineDescriptor.engines.candidate.sha256)throw Error('Exact ce2d parent engine changed');
const receipt={version:1,label,module,pins,fixtures,references:[...oldMethods.keys()].map(name=>({method:name,originalBodyRetained:true})),parentFile,parentSha256:fileHash(parentFile),parentProject:parent.project,engineDescriptorFile,engineDescriptorSha256:fileHash(engineDescriptorFile),canonicalWriterSha256:hash(point),flags:{registry:'--light-input-registry=builtin',fields:'--light-input-fields=published'},status:'SOURCE ONLY: requires fresh private engine, parse and functional gates; no graphics claim',builds:0,engineStarts:0,sharedSourceChanged:false};
fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify(receipt,null,2),{flag:'wx'});console.log(JSON.stringify({stage,manifestSha256:fileHash(path.join(stage,'manifest.json')),modulePins:pins.length,fixtures:fixtures.length,canonicalWriterSha256:hash(point)},null,2));
