import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {stage,hash} from './stage_library.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const root=path.join(project,'.cache/native-140fps/root');
const parentFile=path.join(root,'combined-loading-fenced-v1/manifest.json'),parent=JSON.parse(fs.readFileSync(parentFile));
const sourceFile=path.join(project,'.cache/native-140fps/render-agent/pushed-fields-source-v4/manifest.json');
if(hash(fs.readFileSync(sourceFile))!=='2b891bf4a930d5d2eb65afbbce6a44424fa1f70af9e9f1a2f9bbecd4cee49d11')throw Error('Frozen authored field sources differ');
const source=JSON.parse(fs.readFileSync(sourceFile));
const before=JSON.parse(fs.readFileSync(source.parentFile));
if(hash(fs.readFileSync(source.parentFile))!==source.parentSha256)throw Error('Source parent differs');
const files=['model_point_light.gd','focus_lighting_native_input_candidate.gd','focus_lighting_builtin_input_candidate.gd'];
const changes=files.map(name=>{
 const relative='systems/native_render/'+name,p=source.fixtures.find(p=>p.relative===relative);
 if(!p||(before.pins.find(p=>p.relative===relative)?.sha256??null)!==(parent.pins.find(p=>p.relative===relative)?.sha256??null))throw Error('Field owner overlap: '+relative);
 return{relative,from:p.file,before:parent.pins.find(p=>p.relative===relative).sha256,after:p.sha256};
});
const label='light-fields-fenced-v4',draft=path.join(root,label+'-draft');
if(fs.existsSync(draft))throw Error('Existing draft is preserved');fs.mkdirSync(draft);
const end='\treport.perf140_view_end=perf140_witness()';
let entry=fs.readFileSync(path.join(parent.project,'native_live_world.gd'),'utf8');
if(entry.split(end).length!==2)throw Error('Post-window owner boundary differs');
entry=entry.replace(end,end+'\n\treport.perf140_light_fields_end=perf140_light_fields()');
entry+='\nfunc perf140_light_fields() -> Dictionary:\n\tif not is_instance_valid(world) or not is_instance_valid(world.focus_lighting):return {"available":false}\n\tvar registry: Variant=world.focus_lighting.get("input_registry")\n\tif not is_instance_valid(registry):return {"available":false}\n\tvar value: Dictionary={"available":true,"class":registry.get_class(),"outside_measurement":true}\n\tif value["class"]=="NwnBuiltinLightInputRegistry":value.counters=registry.call("dispatch",9,{})\n\treturn value\n';
let session=fs.readFileSync(path.join(parent.project,'native_session_world.gd'),'utf8');
const start='\t\t\tsamples.clear(); previous=0';
if(session.split(start).length!==2)throw Error('Measurement reset differs');
session=session.replace(start,'\t\t\treport.perf140_light_fields_begin=perf140_light_fields()\n'+start);
for(const [relative,text]of [['native_live_world.gd',entry],['native_session_world.gd',session]]){
 const from=path.join(draft,relative);fs.writeFileSync(from,text);
 changes.push({relative,from,before:parent.pins.find(p=>p.relative===relative).sha256,after:hash(Buffer.from(text))});
}
console.log(JSON.stringify(stage(project,parentFile,label,changes,[sourceFile])));
