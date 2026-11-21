import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';import {stage,hash} from './stage_library.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const file=path.join(project,'.cache/native-140fps/loading-agent/static-actor-route-runtime-v1/manifest.json');if(hash(fs.readFileSync(file))!=='2fb27aae19e349a7a01d0355dd066bc2a6cfb03717ae709923b9b68ea5691309')throw Error('Tested route runtime differs');const m=JSON.parse(fs.readFileSync(file));
console.log(JSON.stringify(stage(project,m.parent.file,'loading-route-fenced-v1',m.changes.map(p=>({...p,from:path.join(m.project,p.relative)})),[file])));
