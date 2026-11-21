// Read-only metadata comparison for the installed model's physical events.
// No model geometry/controllers/textures or complete game resources are saved.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {parseModel} from '../src/model_parser.js';
import {inheritAnimations} from '../src/mdl_animation.js';
import {isAsciiMdl} from '../src/mdl_format.js';
const install=path.resolve('../FullDecomp/NwnRootInstall'),resolver=await openLocalModule(install,path.join(install,'data/nwm/Prelude.nwm')),wanted=new Set(['1hslashr','1hslashl','1hstab']),models=new Map();
async function load(name){if(!models.has(name)){const resource=await resolver.getResource(name,2002),bytes=new Uint8Array(resource),model=parseModel(resource),physical=new Map();
 if(!isAsciiMdl(resource)){
  const v=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength),base=12,offset=base+v.getUint32(base+120,true),count=v.getUint32(base+124,true),string=(a,n)=>new TextDecoder('ascii').decode(bytes.subarray(a,a+n)).split('\0')[0];
  for(let i=0;i<count;i++){const a=base+v.getUint32(offset+i*4,true),clip=string(a+8,64).toLowerCase();if(!wanted.has(clip))continue;const start=base+v.getUint32(a+184,true),n=v.getUint32(a+188,true);physical.set(clip,Array.from({length:n},(_,i)=>({time:v.getFloat32(start+i*36,true),name:string(start+i*36+4,32)})));}
 }
 for(const clip of model.animations.filter(c=>wanted.has(c.name)))if(physical.has(clip.name))assert.deepEqual(clip.events,physical.get(clip.name));
 models.set(name,{model,physical});}return models.get(name).model;}
const model=await load('pmh0');await inheritAnimations(model,load);
const clips=model.animations.filter(c=>wanted.has(c.name)).map(c=>({name:c.name,length:c.length,inheritedFrom:c.inheritedFrom,events:c.events,physicalHitEvents:c.events.filter(e=>e.name.toLowerCase()==='hit').length}));
const result={scope:'Read-only installed asset metadata; physical binary event entries match parsed events; duplicate authored events retained',model:model.modelName,parents:[...models.keys()],clips};
fs.writeFileSync('backups/animations/installed-network-combat-clip-metadata.json',JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({model:model.modelName,parents:result.parents,clips:clips.map(c=>({name:c.name,length:c.length,hitEvents:c.physicalHitEvents}))}));
