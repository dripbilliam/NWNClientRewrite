// Offline benchmark input only; the rendering path stays entirely native.
// Preserve the sealed capture and exact packed resources. Explicitly turn on
// particles in a NEW authored timeline, retaining the recorded camera/scene.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
const arg=name=>process.argv.find(x=>x.startsWith('--'+name+'='))?.slice(name.length+3);
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
if(!arg('capture')||!arg('output'))throw Error('Explicit --capture and new --output required');
const source=path.resolve(arg('capture')),destination=path.resolve(arg('output'));
if(source===destination)throw Error('Original recording must remain untouched');
const manifestBytes=await fs.readFile(path.join(source,'recording.json'));
const manifest=JSON.parse(manifestBytes),timeline=await fs.readFile(path.join(source,'timeline.jsonl'));
if(manifest.complete!==true||hash(timeline)!==manifest.timelineSha256)throw Error('Recording is not sealed');
await fs.mkdir(destination,{recursive:false});
for(const catalog of manifest.catalogs){
 if(!/^catalog-[0-9]+$/.test(catalog.directory))throw Error('Invalid catalogue directory');
 const input=path.join(source,catalog.directory),output=path.join(destination,catalog.directory);
 const bytes=await fs.readFile(path.join(input,'manifest.json')),data=JSON.parse(bytes);
 if(hash(bytes)!==catalog.sha256||data.complete!==true||data.packedSource?.file!=='resources.erf')throw Error('Exact packed catalogue required');
 await fs.mkdir(output);await fs.writeFile(path.join(output,'manifest.json'),bytes,{flag:'wx'});
 // The replay opens the archive read-only. A hard link avoids another large
 // backup copy; no resource bytes or availability metadata are altered.
 await fs.link(path.join(input,'resources.erf'),path.join(output,'resources.erf'));
}
let changedViews=0;
const rows=timeline.toString('utf8').trim().split('\n').map(line=>{
 const row=JSON.parse(line);
 if(row.kind==='view'){row.value.particles=true;row.value.particle_collision=true;changedViews++;}
 return JSON.stringify(row);
});
if(!changedViews)throw Error('Recording contains no particle view policy');
const changed=Buffer.from(rows.join('\n')+'\n');
await fs.writeFile(path.join(destination,'timeline.jsonl'),changed,{flag:'wx'});
const output={...manifest,bytes:changed.length,events:rows.length,timelineSha256:hash(changed),benchmarkClone:{
 version:1,parentRecordingSha256:hash(manifestBytes),parentTimelineSha256:hash(timeline),changedViews,
 particlesEnabled:true,collisionEnabled:true,networkConnections:0,
 scope:'Authored particle-on replay variant. Same captured scene/camera and exact packed resources, including explicit capture gaps. No missing payloads fabricated or effects deliberately omitted. Not an original-timing or complete-resource parity claim.'
}};
await fs.writeFile(path.join(destination,'recording.json'),JSON.stringify(output,null,2)+'\n',{flag:'wx'});
if(hash(await fs.readFile(path.join(source,'recording.json')))!==hash(manifestBytes)||hash(await fs.readFile(path.join(source,'timeline.jsonl')))!==hash(timeline))throw Error('Original recording changed');
console.log(JSON.stringify({destination,changedViews,timelineSha256:output.timelineSha256,originalUnchanged:true,networkConnections:0}));
