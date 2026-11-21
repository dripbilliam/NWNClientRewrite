import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';import {stage,hash,particleChanges} from './stage_library.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),root=path.join(project,'.cache/native-140fps/root'),parentFile=path.join(root,'lease-scene-diagnostics-v1/manifest.json'),parent=JSON.parse(fs.readFileSync(parentFile));
const file=path.join(project,'.cache/native-140fps/particles-agent/scene-snapshot-v4/candidate-built-sources.json');if(hash(fs.readFileSync(file))!=='289d31180f8336e771bdca98004352a44e1fc41f7bedeb3732b176f8836ffbb7')throw Error('Tested snapshot consumer differs');
const relative='tools/perf140/driver/particle_modes_dump.gd',from=path.join(project,relative);
console.log(JSON.stringify(stage(project,parentFile,'scene-snapshot-fenced-v4',[...particleChanges(file),{relative,from,before:parent.pins.find(p=>p.relative===relative).sha256,after:hash(fs.readFileSync(from))}],[file])));
