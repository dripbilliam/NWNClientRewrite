import path from 'node:path';import {fileURLToPath} from 'node:url';import {stage,particleChanges} from './stage_library.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),file=path.join(project,'.cache/native-140fps/particles-agent/combined-particle-census-v1/candidate-built-sources.json');
console.log(JSON.stringify(stage(project,path.join(project,'.cache/native-140fps/root/common-v1/manifest.json'),'particles-census-v1',particleChanges(file),[file])));
