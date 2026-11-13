// Same renderer/engine/DLL for legacy and indexed movement replay.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {stage,hash} from './stage_library.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const sourceFile=path.join(project,'.cache/native-140fps/loading-agent/drive-preview-index-v1/manifest.json');
if(hash(fs.readFileSync(sourceFile))!=='9194c5c9ef2e4b9c0e87875c573e8de229ec2a0d0fd267c1e2aca5b78d17e2d2')throw Error('Accepted drive cohort differs');
const source=JSON.parse(fs.readFileSync(sourceFile));
if(source.mode!=='index'||source.parent.sha256!=='672a89f094e3f8b845175b947556e3ca9b8c3bb4bd0e149a8f79058ad2cdc0d9')throw Error('Drive source lineage differs');
const parentFile=source.parent.file;
const changes=source.changes.map(p=>({...p,from:path.join(source.project,p.relative)}));
const expected=['systems/native_render/drive_collision.gd','systems/native_render/drive_collision_indexed.gd','systems/native_render/live_world.gd'].sort();
if(JSON.stringify(changes.map(p=>p.relative).sort())!==JSON.stringify(expected))throw Error('Drive scope differs');
console.log(JSON.stringify(stage(project,parentFile,'drive-replay-fenced-v1',changes,[sourceFile])));
