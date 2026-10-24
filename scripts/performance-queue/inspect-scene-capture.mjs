import fs from 'node:fs/promises';import path from 'node:path';
import {SceneReplay} from '../../electron/scene_replay.mjs';
const args=process.argv.slice(2),arg=name=>args.find(a=>a.startsWith('--'+name+'='))?.slice(name.length+3);
for(const value of args)if(!value.startsWith('--capture=')&&!value.startsWith('--output='))throw Error('Unknown option: '+value);
if(!arg('capture'))throw Error('Use --capture=<private capture directory> [--output=<new report.json>]');
const replay=await SceneReplay.open(path.resolve(arg('capture'))),summary={...replay.summary(),captureDirectory:replay.archive.directory,validation:'Event checksum, ordering, context bootstrap and camera fields verified; asset contents are checked on replay reads, not by this inspection.'};
if(arg('output'))await fs.writeFile(path.resolve(arg('output')),JSON.stringify(summary,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(summary,null,2));
