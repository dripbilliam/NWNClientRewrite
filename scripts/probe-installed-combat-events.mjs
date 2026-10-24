import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {openLocalModule} from './local-module.mjs';
import {parseModel} from '../src/model_parser.js';
import {inheritAnimations} from '../src/mdl_animation.js';
import {animateModelEvents} from '../src/model_events.js';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),install=path.resolve(root,'../FullDecomp/NwnRootInstall'),resolver=await openLocalModule(install,path.join(install,'data/nwm/Prelude.nwm')),cache=new Map(),bytes=new Map();
const load=async name=>{name=name.toLowerCase();if(!cache.has(name))cache.set(name,(async()=>{const raw=await resolver.getResource(name,2002);bytes.set(name,raw);return parseModel(raw);})());return cache.get(name);};
const requests=process.argv.slice(2);if(!requests.length||requests.some(r=>!/^\w{1,16}:\w{1,64}$/.test(r)))throw Error('Supply installed model:clip pairs');const observations=[];
for(const request of requests){const [name,clipName]=request.toLowerCase().split(':'),model=await load(name);await inheritAnimations(model,load);const clip=model.animations.find(c=>c.name===clipName);if(!clip)throw Error('Installed clip unavailable');const emitted=[];animateModelEvents(clip,0,clip.length,0,(event,_data,index)=>{if(event.toLowerCase()==='hit')emitted.push(index);});const owner=clip.inheritedFrom??name;observations.push({model:name,clip:clipName,inheritedFrom:clip.inheritedFrom??null,ownerSha256:crypto.createHash('sha256').update(Buffer.from(bytes.get(owner))).digest('hex'),length:clip.length,hitEntries:clip.events.map((e,index)=>({...e,index})).filter(e=>e.name.toLowerCase()==='hit'),emitted});}
const result={scope:'Read-only installed model metadata, format-aware parser and production physical-order event iterator. Duplicate authored entries are retained, not normalized. Does not execute the original model loader or audio device.',observations};await fs.writeFile(path.join(root,'backups/animations/installed-combat-events-v1.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
