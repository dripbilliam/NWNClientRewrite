import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';import {stage,hash,particleChanges} from './stage_library.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const file=path.join(project,'.cache/native-140fps/particles-agent/scene-snapshot-direct-slots-v1/candidate-built-sources.json');if(hash(fs.readFileSync(file))!=='41b57604b7810b216483e88def4d2268d28ce6eb8a7c015248b3ad45eba1262f')throw Error('Tested direct-slot consumer differs');
console.log(JSON.stringify(stage(project,path.join(project,'.cache/native-140fps/root/scene-snapshot-fenced-v4/manifest.json'),'scene-direct-slots-fenced-v1',particleChanges(file),[file])));
