import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';import {stage,hash} from './stage_library.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),parentFile=path.join(project,'.cache/native-140fps/root/particles-cold-v2/manifest.json'),parent=JSON.parse(fs.readFileSync(parentFile));
const relative='systems/native_render/perf140_cold_particle_dump.gd',from=path.join(project,'tools/perf140/driver/cold_particle_dump.gd');
console.log(JSON.stringify(stage(project,parentFile,'particles-cold-v3',[{relative,from,before:parent.pins.find(p=>p.relative===relative).sha256,after:hash(fs.readFileSync(from))}],[from])));
