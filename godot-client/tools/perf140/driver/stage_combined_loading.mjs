// Root-only guarded full-room derivative. Does not promote shared runtime code.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {stage,hash} from './stage_library.mjs';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const root=path.join(project,'.cache/native-140fps/root');
const parentFile=path.join(root,'builtin-light-fenced-v2/manifest.json');
const parent=JSON.parse(fs.readFileSync(parentFile));
const loadingFolder=path.join(project,'.cache/native-140fps/loading-agent/combined-loading-runtime-v1');
const loadingManifest=path.join(loadingFolder,'manifest.json');
if(hash(fs.readFileSync(loadingManifest))!=='1f0fd6a94d4132ad8c14c822fefa69d7720ba7fadd7ab32a536ac709401d92f9')throw Error('Frozen combined loading identity differs');
const integrationFile=path.join(loadingFolder,'integration.json');
const integration=JSON.parse(fs.readFileSync(integrationFile));
if(integration.manifestSha256!==hash(fs.readFileSync(loadingManifest))||integration.changes.length!==10)throw Error('Loading integration proof differs');
const changes=integration.changes.map(p=>({relative:p.relative,before:p.before,after:p.after,from:p.candidateFile}));
const label='combined-loading-fenced-v1';
const draft=path.join(root,label+'-draft');
if(fs.existsSync(draft))throw Error('Existing staging evidence is preserved');
fs.mkdirSync(draft);
const relative='native_live_world.gd';
const before=parent.pins.find(p=>p.relative===relative).sha256;
let entry=fs.readFileSync(path.join(parent.project,relative),'utf8');
const anchor='\t\treport.static_leaf_census=preload("res://tools/perf140/render/static_leaf_census.gd").save(world,str(args.report)+".static-leaves.json")';
if(entry.split(anchor).length!==2)throw Error('Post-window census owner boundary differs');
entry=entry.replace(anchor,anchor+'\n\t\treport.perf140_rig_identity=preload("res://tools/perf140/particles/rig_owner_identity_census.gd").capture(world,report.static_leaf_census.get("process_tree",{}).get("rig_owners",[]),report.has("performance_window"))');
const from=path.join(draft,relative);fs.writeFileSync(from,entry);
changes.push({relative,before,after:hash(Buffer.from(entry)),from});
for(const relative of ['tools/perf140/particles/rig_owner_identity_census.gd','tests/native_perf140_particle_rig_identity_census_test.gd']){
 const from=path.join(project,relative);
 changes.push({relative,from,before:parent.pins.find(p=>p.relative===relative)?.sha256??null,after:hash(fs.readFileSync(from))});
}
console.log(JSON.stringify(stage(project,parentFile,label,changes,[loadingManifest,integrationFile])));
