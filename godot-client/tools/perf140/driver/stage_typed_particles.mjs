import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {stage,hash,particleChanges} from './stage_library.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const root=path.join(project,'.cache/native-140fps/root'),parentFile=path.join(root,'builtin-light-fenced-v2/manifest.json'),parent=JSON.parse(fs.readFileSync(parentFile));
const receiptFile=path.join(project,'.cache/native-140fps/particles-agent/typed-boundary-v2/candidate-built-sources.json');
if(hash(fs.readFileSync(receiptFile))!=='074fe64b820e215b5f5a3f289390ffb828c40767b1ff585df0782f56dd92bc43')throw Error('Only frozen typed V2 is accepted');
// Inherited overrides are already in the parent's compiled lease cohort.
// Apply only actual differences to the typed candidate's own frozen baseline.
const changes=particleChanges(receiptFile).filter(p=>p.before!==p.after);
const expected=['.cache/native-kernel/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','native/particle_presentation.hpp','systems/native_render/particle_stream_group.gd'].sort();
if(JSON.stringify(changes.map(p=>p.relative).sort())!==JSON.stringify(expected))throw Error('Unexpected typed boundary scope');
const label='typed-particles-fenced-v2',draft=path.join(root,label+'-draft');if(fs.existsSync(draft))throw Error('Prior derivative preserved');fs.mkdirSync(draft);
const relative='native_live_world.gd';let entry=fs.readFileSync(path.join(parent.project,relative),'utf8');
const before='preload("res://tools/perf140/driver/particle_modes_dump.gd").capture(world)';
if(entry.split(before).length!==2)throw Error('Post-window mode export boundary differs');
entry=entry.replace(before,'preload("res://tools/perf140/driver/typed_particle_modes_dump.gd").capture(world)');
const from=path.join(draft,relative);fs.writeFileSync(from,entry);
changes.push({relative,from,before:parent.pins.find(p=>p.relative===relative).sha256,after:hash(Buffer.from(entry))});
const helper='tools/perf140/driver/typed_particle_modes_dump.gd',helperFile=path.join(project,helper);
changes.push({relative:helper,from:helperFile,before:null,after:hash(fs.readFileSync(helperFile))});
console.log(JSON.stringify(stage(project,parentFile,label,changes,[receiptFile])));
