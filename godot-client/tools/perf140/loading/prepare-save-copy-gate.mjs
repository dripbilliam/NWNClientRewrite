// Source-only staging plan until Root grants a functional CPU window.
// Never writes main source or shared native binaries.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {digest} from './processor-graph.mjs';
import {buildDescriptor} from './processor-descriptor.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const label=process.argv[2];
if(!/^combined-loading-save-[a-z0-9-]+$/.test(label??''))throw Error('Fresh owned preparation-save candidate label required');
const stage=path.join(project,'.cache/native-140fps/loading-agent',label);
if(fs.existsSync(stage))throw Error('Existing evidence preserved');
const parentFile=path.join(project,'.cache/native-140fps/loading-agent/combined-loading-runtime-v1/manifest.json');
const parentBytes=fs.readFileSync(parentFile),parent=JSON.parse(parentBytes);
if(digest(parentBytes)!=='1f0fd6a94d4132ad8c14c822fefa69d7720ba7fadd7ab32a536ac709401d92f9')throw Error('Frozen parent differs');
const copy=path.join(stage,'project'),pins=new Map(),changes=[];
fs.mkdirSync(copy,{recursive:true});
for(const pin of parent.pins){
 const bytes=fs.readFileSync(path.join(parent.project,pin.relative));
 if(digest(bytes)!==pin.sha256)throw Error('Frozen parent source differs: '+pin.relative);
 const target=path.join(copy,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);pins.set(pin.relative,pin.sha256);
}
function patch(relative,changeset){
 const target=path.join(copy,relative),before=pins.get(relative);let source=fs.readFileSync(target,'utf8');const crlf=source.includes('\r\n');source=source.replaceAll('\r\n','\n');
 for(const [oldText,newText] of changeset){if(source.split(oldText).length!==2)throw Error('Guarded source seam differs: '+relative+' / '+oldText.slice(0,100));source=source.replace(oldText,newText);}
 if(crlf)source=source.replaceAll('\n','\r\n');fs.writeFileSync(target,source);const after=digest(Buffer.from(source));pins.set(relative,after);changes.push({relative,before,after});
}
patch('systems/native_data/preparation_store.gd',[
 ['var accounting:={"native":0,"serialized":0,"hinted":0,"usec":0,"shared_storage":0,"bounded":0}',
  'var accounting:={"native":0,"serialized":0,"hinted":0,"usec":0,"shared_storage":0,"bounded":0}\n# Only trusted, content-addressed completed-data publishers opt in. Generic\n# callers preserve the original graph admission and copy behavior.\nvar publication_copy_gate:=OS.get_cmdline_user_args().has("--preparation-save-copy-gate=enabled")\nvar copy_gate_stats:={"existing_after_cost":0,"stale_after_cost":0,"copies_created":0,"discarded_race":0}'],
 ['func save_data(request: String,identity: String,value: Dictionary,expected: int,size_hint: int=-1,retain_immutable: bool=false) -> void:',
  'func save_data(request: String,identity: String,value: Dictionary,expected: int,size_hint: int=-1,retain_immutable: bool=false,content_addressed: bool=false) -> void:'],
 ['\tif size>maximum_bytes or size<=0: return\n\t# Borrowing is restricted',
  '\tif size>maximum_bytes or size<=0: return\n\t# Preserve original accounting/admission, including over-budget and native\n\t# failure fallback. Avoid only a private copy that will not be retained.\n\tvar copy_gate: bool=publication_copy_gate and content_addressed and not retain_immutable and measured\n\tif copy_gate:\n\t\tmutex.lock()\n\t\tif epoch!=expected:\n\t\t\tcopy_gate_stats.stale_after_cost+=1; mutex.unlock(); return\n\t\tif entries.has(identity):\n\t\t\trequests[request]=identity; copy_gate_stats.existing_after_cost+=1; mutex.unlock(); return\n\t\tmutex.unlock()\n\t# Borrowing is restricted'],
 ['\tmutex.lock()\n\tif epoch!=expected: mutex.unlock(); return\n\tif not entries.has(identity):',
  '\tmutex.lock()\n\tif copy_gate: copy_gate_stats.copies_created+=1\n\tif epoch!=expected: mutex.unlock(); return\n\tif copy_gate and entries.has(identity): copy_gate_stats.discarded_race+=1\n\tif not entries.has(identity):'],
 ['"accounting":accounting.duplicate()}; mutex.unlock()',
  '"accounting":accounting.duplicate(),"publication_copy_gate":copy_gate_stats.duplicate()}; mutex.unlock()']
]);
patch('systems/native_data/asset_service.gd',[
 ['job.memory_store.save_data(memory_key,Cache.digest(var_to_bytes(saved.get("prework_inputs",[]))),saved,int(job.memory_epoch))',
  'job.memory_store.save_data(memory_key,Cache.digest(var_to_bytes(saved.get("prework_inputs",[]))),saved,int(job.memory_epoch),-1,false,true)'],
 ['job.memory_store.save_data(memory_key,identity,content,int(job.memory_epoch))',
  'job.memory_store.save_data(memory_key,identity,content,int(job.memory_epoch),-1,false,true)']
]);
const graph='systems/native_data/scoped_processor_graph.json',before=pins.get(graph);
const descriptor=Buffer.from(JSON.stringify(buildDescriptor(copy).descriptor,null,2)+'\n');fs.writeFileSync(path.join(copy,graph),descriptor);pins.set(graph,digest(descriptor));changes.push({relative:graph,before,after:digest(descriptor),generatedFromFinalCohort:true});
const manifest={version:1,label,stage,project:copy,candidate:copy,parent:{file:parentFile,sha256:digest(parentBytes)},changes,changed:[],pins:[...pins].map(([relative,sha256])=>({relative,sha256})),flags:['--preparation-save-copy-gate=enabled'],scope:'Experimental completed-data publication copy gate. Original accounting and admission run first. Only explicit internal content-addressed AssetService publishers may skip a discarded private copy for an already-present identity or stale epoch; generic callers, failed accounting, hints and immutable sources retain original behavior. No accounting/charge/limit approximation.',serverConnections:0,graphics:0,sharedNativeBuilds:0};
const file=path.join(stage,'manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({file,sha256:digest(fs.readFileSync(file)),changes}));
