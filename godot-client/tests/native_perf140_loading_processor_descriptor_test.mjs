// Actual generator/descriptor isolation gate. No native DLL/engine/capture reads.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {buildDescriptor} from '../tools/perf140/loading/processor-descriptor.mjs';
import {digest} from '../tools/perf140/loading/processor-graph.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),label=process.argv[2];
if(!/^processor-identity-[a-z0-9-]+$/.test(label??''))throw Error('Pinned processor candidate required');
const stage=path.join(project,'.cache/native-140fps/loading-agent',label),manifest=JSON.parse(fs.readFileSync(path.join(stage,'manifest.json'))),directory=path.join(stage,'descriptor-scope-checks');
if(fs.existsSync(directory))throw Error('Existing evidence is immutable');fs.mkdirSync(directory);
const descriptor=JSON.parse(fs.readFileSync(path.join(manifest.candidate,'systems/native_data/scoped_processor_graph.json'))),paths=[...new Set([...Object.values(descriptor.graphs).flatMap(v=>v.files.map(v=>v.path)),'native_live_world.gd'])].sort();
const original=new Map(paths.map(relative=>[relative,fs.readFileSync(path.join(manifest.candidate,relative))]));
const candidates=[];let checks=0;const failures=[];const check=(value,message)=>{checks++;if(!value)failures.push(message);};
const signature=graph=>digest(Buffer.from(JSON.stringify(graph)));
function make(label,changes=[]){const target=path.join(directory,label);fs.mkdirSync(target);for(const [relative,bytes] of original){const file=path.join(target,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);}for(const [relative,change] of changes){const file=path.join(target,relative);fs.mkdirSync(path.dirname(file),{recursive:true});const before=fs.existsSync(file)?fs.readFileSync(file,'utf8'):'';fs.writeFileSync(file,change(before));}return target;}
const base=buildDescriptor(make('base')).descriptor;
check(JSON.stringify(base)===JSON.stringify(descriptor),'regeneration matches the exact complete pinned candidate descriptor');
for(const [label,relative,expected] of [
 ['unrelated-hud','native_live_world.gd',kind=>false],
 ['diagnostic-hud','systems/native_render/frame_summary_job.gd',kind=>kind==='finished-icon-v1'],
 ['world-material','systems/native_render/native_model_material.gd',kind=>kind==='finished-icon-v1'],
 ['true-preparation','systems/native_render/particle_math.gd',kind=>true],
 ['rejection-policy','systems/native_prework_assets.gd',kind=>kind.startsWith('rejection:')],
 ['pixel-render','systems/native_item_icons.gd',kind=>kind==='finished-icon-v1']
]){
 const result=buildDescriptor(make(label,[[relative,text=>(text||'extends Node\n')+'\n# Actual private source mutation\n']])).descriptor;
 for(const kind of Object.keys(base.graphs))check((signature(result.graphs[kind])!==signature(base.graphs[kind]))===expected(kind),label+' invalidates exactly the expected artifact graph: '+kind);
 candidates.push({label,source:relative,changed:Object.keys(base.graphs).filter(kind=>signature(result.graphs[kind])!==signature(base.graphs[kind]))});
}
for(const [label,mutation] of [
 ['unknown-class',text=>text+'\nfunc new_unknown():\n\treturn NwnMissingFixture.new()\n'],
 ['dynamic-load',text=>text+'\nfunc new_dynamic(name):\n\treturn ResourceLoader.load(name)\n'],
 ['new-transitive',text=>text+'\nconst Required=preload("res://systems/new_missing_dependency.gd")\n']
]){let rejected=false;try{buildDescriptor(make(label,[['systems/native_data/actor_model.gd',mutation]]));}catch{rejected=true;}check(rejected,label+' cannot generate a partially reusable descriptor');}
const actualSourceDrift=paths.filter(relative=>digest(fs.readFileSync(path.join(manifest.candidate,relative)))!==digest(original.get(relative)));
check(actualSourceDrift.length===0,'pinned candidate sources remain immutable');
const report={version:1,success:!failures.length,checks,failures,candidates,actualSourceDrift,manifestSha256:digest(fs.readFileSync(path.join(stage,'manifest.json'))),testSha256:digest(fs.readFileSync(fileURLToPath(import.meta.url))),generatorSha256:base.generator,engineProcessesStarted:0,nativeBytesRead:0,sharedFilesChanged:0,timingClaim:false};
fs.writeFileSync(path.join(directory,'receipt.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({directory,checks,success:report.success,failures}));if(!report.success)process.exitCode=1;
