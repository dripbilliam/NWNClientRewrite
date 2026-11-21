const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../../../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const id=process.argv[2]??'light-live-a';if(!/^[a-z0-9-]+$/.test(id))throw Error('Fresh private source stage required');
const directory=path.join(project,'.cache/native-render-gap/scene',id),out=path.join(directory,'engine_module/nwn_light_input_registry');
if(fs.existsSync(directory))throw Error('Existing stage frozen');fs.mkdirSync(out,{recursive:true});
const moduleDirectory=path.join(project,'.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/source/modules/nwn_light_input_registry');
const pins=[],outputs=[];function input(file){const b=fs.readFileSync(file);pins.push({file,sha256:sha(b)});return b;}
function put(name,bytes){const file=path.join(out,name);fs.writeFileSync(file,bytes,{flag:'wx'});outputs.push({file,sha256:sha(bytes)});}
let h=input(path.join(moduleDirectory,'light_input_registry.h')).toString(),cpp=input(path.join(moduleDirectory,'light_input_registry.cpp')).toString();
function replace(text,from,to){if(text.split(from).length!==2)throw Error('Source seam changed: '+from);return text.replace(from,to);}
h=replace(h,'#include "core/object/ref_counted.h"','#include "core/object/ref_counted.h"\n#include "modules/gdscript/gdscript.h"');
h=replace(h,' Dictionary inspect() const;',` bool plain_requested=false;
 Ref<GDScript> plain_writer;
 String plain_source;
 int64_t plain_claims=0, plain_rows=0, plain_field_reads=0, plain_schema_checks=0, plain_source_rejections=0, plain_schema_rejections=0;
 bool plain_schema_valid();
 Dictionary enroll_plain_reader(const Variant &input);
 GDScriptInstance *plain_reader(Node3D *node);
 Dictionary inspect() const;`);
// Header's Node3D declaration arrives through the GDScript include? Keep it
// explicit rather than relying on that implementation detail.
h=replace(h,'// Private OPTIONAL counterpart','class Node3D;\n\n// Private OPTIONAL counterpart');
h=replace(h,' Dictionary dispatch(const Variant &operation, const Variant &input);',' NwnBuiltinLightInputRegistry();\n Dictionary dispatch(const Variant &operation, const Variant &input);');
cpp=replace(cpp,'#include "core/os/thread.h"','#include "core/os/thread.h"\n#include "core/os/os.h"\n#include "core/config/engine.h"');
const methods=input(path.join(__dirname,'reader.cpp.inc')).toString();
cpp=replace(cpp,'Dictionary NwnBuiltinLightInputRegistry::dispatch(',methods+'\nDictionary NwnBuiltinLightInputRegistry::dispatch(');
cpp=replace(cpp,' if(operation==3)return inspect();',` if(operation==3)return inspect();
 if(operation==6 && plain_requested)return enroll_plain_reader(input);
 if(operation==9 && plain_requested){Dictionary out;out[SNAME("plain_claims")]=plain_claims;out[SNAME("plain_rows")]=plain_rows;out[SNAME("plain_field_reads")]=plain_field_reads;out[SNAME("plain_schema_checks")]=plain_schema_checks;out[SNAME("plain_source_rejections")]=plain_source_rejections;out[SNAME("plain_schema_rejections")]=plain_schema_rejections;return out;}`);
cpp=replace(cpp,' if(operation==8){entries.clear();', ' if(operation==8){plain_writer.unref();plain_source=String();entries.clear();');
cpp=replace(cpp,'bool eligible=node!=nullptr;Variant props;','bool eligible=node!=nullptr;Variant props;GDScriptInstance *plain=nullptr;');
const props='   props=node->get(props_name);error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);';
cpp=replace(cpp,props,`   plain=plain_reader(node);
   if(plain){++plain_rows;plain->get(props_name,props);++plain_field_reads;}
   else{${props.trim()}}`);
cpp=replace(cpp,'error=callback_boundary(id);if(!error.is_empty())return failure(error);eligible=!(radius>=1000);','if(!plain){error=callback_boundary(id);if(!error.is_empty())return failure(error);}eligible=!(radius>=1000);');
const state='  Variant state=node->get(state_name);error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);';
cpp=replace(cpp,state,`  Variant state;
  if(plain){plain->get(state_name,state);++plain_field_reads;}
  else{state=node->get(state_name);error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);}`);
cpp=replace(cpp,'  error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);','  if(!plain){error=callback_boundary(id);if(!error.is_empty())return failure(error);node=node_from_id(id);}');
const revision='  Variant revision_value=node->get(revision_name);error=callback_boundary(id);if(!error.is_empty())return failure(error);';
cpp=replace(cpp,revision,`  Variant revision_value;
  if(plain){plain->get(revision_name,revision_value);++plain_field_reads;}
  else{revision_value=node->get(revision_name);error=callback_boundary(id);if(!error.is_empty())return failure(error);}`);
put('light_input_registry.h',h);put('light_input_registry.cpp',cpp);
for(const name of ['config.py','SCsub','register_types.h','register_types.cpp'])put(name,input(path.join(moduleDirectory,name)));
const facadeFile=process.argv.find(x=>x.startsWith('--facade='))?.slice(9)??path.join(project,'systems/native_render/model_point_light.gd');
const facade=input(path.resolve(facadeFile)),facadeSha256=sha(facade);
let wrapper=input(path.join(project,'systems/native_render/native_light_input_registry.gd')).toString();
wrapper=replace(wrapper,'const REVISION:=',`const CanonicalWriter=preload("res://systems/native_render/model_point_light.gd")\nconst CANONICAL_WRITER_SHA:="${facadeSha256}"\nconst REVISION:=`);
wrapper=replace(wrapper,'\teffective="builtin";return true',`\tif arguments.has("--light-input-read=typed"):
\t\tvar enrolled: Variant=native.call("dispatch",6,{"script":CanonicalWriter,"sha256":CANONICAL_WRITER_SHA})
\t\tif not enrolled is Dictionary or not bool(enrolled.get("accepted",false)):
\t\t\tnative.call("dispatch",8,{});native=null;return _fail("Typed light reader canonical source/schema enrollment rejected")
\teffective="builtin";return true`);
fs.writeFileSync(path.join(directory,'native_light_input_registry.gd'),wrapper,{flag:'wx'});outputs.push({file:path.join(directory,'native_light_input_registry.gd'),sha256:sha(wrapper)});
fs.writeFileSync(path.join(directory,'canonical_facade.gd'),facade,{flag:'wx'});outputs.push({file:path.join(directory,'canonical_facade.gd'),sha256:facadeSha256});
const manifest={version:1,createdAtUtc:new Date().toISOString(),directory,sourceModule:moduleDirectory,pins,outputs,facadeFile,facadeSha256,feature:'--light-input-read=typed',enrollment:'dispatch6(script,sha256), cold before polling',diagnostics:'dispatch9 separate from original inspect',builds:0,launches:0,installed:false,scope:'Private live canonical field reads; exact current legacy poll body retained for all noncanonical/getter/schema/source fallback cases. No pushed field/token cache.'};
fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2),{flag:'wx'});console.log(JSON.stringify({directory,facadeSha256,files:outputs.length}));
