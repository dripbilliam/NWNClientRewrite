// Retained synthetic observations from the original immutable binary. No
// executable bytes or proprietary art are copied into the native test fixture.
import fs from 'node:fs/promises';import crypto from 'node:crypto';
const target='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a',sources=[];
async function load(path){const bytes=await fs.readFile(path),v=JSON.parse(bytes);if(v.target!==target)throw Error('Wrong original target');sources.push({path,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),limits:v.limits??null});return v;}
const core=await load('backups/animations/native-camera-observations.json'),rates=await load('backups/animations/native-camera-rate-flags-observations.json');
if(core.frames.length!==432||core.modes.length!==720||core.pointers.length!==100||rates.rows.length!==403)throw Error('Incomplete retained original observations');
const output='godot-client/tests/fixtures/camera-core-original-v1.json';await fs.writeFile(output,JSON.stringify({version:1,target,sources,frames:core.frames,modes:core.modes,pointers:core.pointers,rates:rates.rows},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output,frames:432,modes:720,pointers:100,rates:403}));
