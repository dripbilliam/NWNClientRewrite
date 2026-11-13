const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../../../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const label=process.argv[2]??'light-live-segment-a';if(!/^[a-z0-9-]+$/.test(label))throw Error('Fresh label required');const directory=path.join(project,'.cache/native-render-gap/scene',label);if(fs.existsSync(directory))throw Error('Previous proposal frozen');
const base=path.join(project,'.cache/native-render-gap/scene/light-live-b'),manifestFile=path.join(base,'manifest.json'),manifest=JSON.parse(fs.readFileSync(manifestFile));
function once(source,a,b){if(source.split(a).length!==2)throw Error('Segment source seam changed '+a);return source.replace(a,b);}
const segmentReader=`GDScriptInstance *NwnBuiltinLightInputRegistry::plain_reader_segment(Node3D *node, bool &proven) {
 auto invalidate = [&]() { if (proven) ++plain_segment_invalidations; proven = false; };
 if (!plain_requested || plain_writer.is_null() || Engine::get_singleton()->is_editor_hint()) { invalidate(); return nullptr; }
 // Every node still supplies its actual current Script and ScriptInstance.
 // Unknown/subclass/placeholder/language paths close the pure segment before
 // the original reflected getter is invoked. No instance/value is retained.
 if (Object::cast_to<GDScript>(node->get_script()) != plain_writer.ptr()) { invalidate(); return nullptr; }
 ScriptInstance *instance = node->get_script_instance();
 if (!instance || instance->is_placeholder() || instance->get_language() != GDScriptLanguage::get_singleton()) { invalidate(); return nullptr; }
 GDScriptInstance *reader = static_cast<GDScriptInstance *>(instance);
 if (reader->get_script().ptr() != plain_writer.ptr()) { invalidate(); return nullptr; }
 if (proven) { ++plain_segment_reuses; return reader; }
 // Reuse the exact B source/COW and current compiled-schema proof, including
 // restored text with stale compiled getters. No cross-poll proof survives.
 reader = plain_reader(node);
 if (!reader) { invalidate(); return nullptr; }
 proven = true; ++plain_segment_proofs; return reader;
}

`;
const pins=[];function put(relative,bytes,origin,beforeSha256=null){const file=path.join(directory,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});pins.push({relative,file,origin,beforeSha256,sha256:sha(bytes)});}
const moduleFiles=['SCsub','config.py','register_types.cpp','register_types.h','light_input_registry.cpp','light_input_registry.h'];
for(const name of moduleFiles){const relative='engine_module/nwn_light_input_registry/'+name,from=path.join(base,relative),before=fs.readFileSync(from);let source=before.toString();
 if(name==='light_input_registry.h'){
  source=once(source,' bool plain_requested=false;',' bool plain_requested=false, plain_segment_requested=false;');
  source=once(source,' bool plain_schema_valid();',' int64_t plain_segment_proofs=0, plain_segment_reuses=0, plain_segment_invalidations=0;\n bool plain_schema_valid();');
  source=once(source,' GDScriptInstance *plain_reader(Node3D *node);',' GDScriptInstance *plain_reader(Node3D *node);\n GDScriptInstance *plain_reader_segment(Node3D *node,bool &proven);');
 }
 if(name==='light_input_registry.cpp'){
  source=once(source,'  if (argument == "--light-input-read=typed") plain_requested = true;','  if (argument == "--light-input-read=typed") plain_requested = true;\n  if (argument == "--light-input-proof=segments") plain_segment_requested = true;');
  source=once(source,'Dictionary NwnBuiltinLightInputRegistry::dispatch(const Variant &operation_value,const Variant &input) {',segmentReader+'Dictionary NwnBuiltinLightInputRegistry::dispatch(const Variant &operation_value,const Variant &input) {');
  source=once(source,'out[SNAME("plain_schema_rejections")]=plain_schema_rejections;return out;}','out[SNAME("plain_schema_rejections")]=plain_schema_rejections;out[SNAME("plain_segment_proofs")]=plain_segment_proofs;out[SNAME("plain_segment_reuses")]=plain_segment_reuses;out[SNAME("plain_segment_invalidations")]=plain_segment_invalidations;return out;}');
  source=once(source,' const uint64_t generation=membership_generation;\n auto callback_boundary=',' const uint64_t generation=membership_generation;\n bool plain_segment_proven=false;\n auto end_plain_segment=[&]() { if(plain_segment_proven){plain_segment_proven=false;++plain_segment_invalidations;} };\n auto callback_boundary=');
  source=once(source,' auto callback_boundary=[&](int64_t id)->String {\n',' auto callback_boundary=[&](int64_t id)->String {\n  // Opaque authored access ends the callback-free proof segment, including\n  // callbacks that keep registry membership unchanged but reload a Script.\n  end_plain_segment();\n');
  source=once(source,'   plain=plain_reader(node);','   plain=plain_segment_requested?plain_reader_segment(node,plain_segment_proven):plain_reader(node);');
  source=once(source,'  if(!entry.has_row||entry.revision!=revision){\n','  if(!entry.has_row||entry.revision!=revision){\n   end_plain_segment(); // Replacement can destroy authored RefCounted values.\n');
  for(const seam of ['if(!entry.row.has("override")||entry.priority!=priority){','if(entry.position!=position){','if(entry.owner!=owner){','if(prior_view!=entry.in_view){'])source=once(source,seam,seam+'end_plain_segment();');
 }
 put(relative,Buffer.from(source),from,sha(before));
}
for(const name of ['native_light_input_registry.gd','canonical_facade.gd']){const from=path.join(base,name);put(name,fs.readFileSync(from),from);}
const output={version:1,createdAtUtc:new Date().toISOString(),directory,baseManifest:manifestFile,baseManifestSha256:sha(fs.readFileSync(manifestFile)),pins,flag:'--light-input-proof=segments',requires:'--light-input-read=typed plus unchanged cold source enrollment',default:'off, retains B per-row proof',installed:false,compiled:false,launched:false,scope:'One-poll callback-free proof reuse only; no cached fields/values/member indices/ObjectIDs/ScriptInstances. Script/instance identity checked live on every eligible node; current B proof recertifies every new pure segment.'};fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(output,null,2),{flag:'wx'});console.log(JSON.stringify({directory,files:pins.length,moduleCppSha256:pins.find(x=>x.relative.endsWith('light_input_registry.cpp')).sha256}));
