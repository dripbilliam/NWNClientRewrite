import fs from 'node:fs/promises';
import path from 'node:path';
import {ResourceResolver,parseErf,readFileBytes,RESOURCE_TYPE,INSTALLED_PORTRAIT_TYPES} from '../src/resource_archive.js';
import {workshopContent} from './workshop_content.mjs';
import {indexedErf} from './indexed_erf.mjs';

export const localResourceFile=(filename,install)=>({name:path.basename(filename),webkitRelativePath:path.relative(install,filename),arrayBuffer:async()=>{const data=await fs.readFile(filename);return data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength);}});
const extensions={...Object.fromEntries(Object.entries(RESOURCE_TYPE).map(([name,type])=>[name.toLowerCase(),type])),'2da':RESOURCE_TYPE.TWO_DA};
export async function looseResourceLayer(directory,{types=null}={}){
 let files;try{files=await fs.readdir(directory,{withFileTypes:true});}catch(error){if(error.code==='ENOENT')return null;throw error;}
 const entries=new Map();for(const file of files){if(!file.isFile())continue;const extension=path.extname(file.name).slice(1).toLowerCase(),type=extensions[extension],name=file.name.slice(0,-extension.length-1).toLowerCase();if(type&&name&&(!types||types.includes(type)))entries.set(`${name}:${type}`,path.join(directory,file.name));}
 return{name:directory,resourceKeys:()=>entries.keys(),hasResource:(name,type)=>entries.has(`${name.toLowerCase()}:${type}`),getResource:async(name,type)=>{const file=entries.get(`${name.toLowerCase()}:${type}`);if(!file)throw Object.assign(new Error('Loose resource is unavailable'),{code:'RESOURCE_NOT_FOUND'});const data=await fs.readFile(file);return data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength);}};
}

// The server's wire list is authoritative. Do not read a local module's IFO
// to rediscover HAKs: its requirements may differ from the running server.
export async function openServerResourceContext({install,userDirectory=null,modsDirectory=null,disabledMods=[],language='en',module=null,resolved=[],hakPriority=()=>30000000}){
 const workshop=workshopContent(modsDirectory,{disabledMods});
 const gameFiles=[];for(const directory of [path.join(install,'data'),path.join(install,'lang',language,'data')]){
  let files;try{files=await fs.readdir(directory,{withFileTypes:true});}catch(error){if(error.code==='ENOENT')continue;throw error;}
  gameFiles.push(...files.filter(file=>file.isFile()).map(file=>localResourceFile(path.join(directory,file.name),install)));
 }
 // Native PORTRAITSINSTALL maps to data/prt. Its registration is lazy: list
 // image filenames here and read bytes only if the active consumer asks.
 const installedPortraits=await looseResourceLayer(path.join(install,'data','prt'),{types:INSTALLED_PORTRAIT_TYPES});
 if(installedPortraits)gameFiles.push(...[...installedPortraits.resourceKeys()].map(key=>{const split=key.lastIndexOf(':'),name=key.slice(0,split),type=Number(key.slice(split+1));return{name:name+(type===RESOURCE_TYPE.TGA?'.tga':'.dds'),webkitRelativePath:'data/prt/'+name+(type===RESOURCE_TYPE.TGA?'.tga':'.dds'),arrayBuffer:()=>installedPortraits.getResource(name,type)};}));
 const resolver=await ResourceResolver.createGameData(gameFiles);
 if(module){resolver.module=parseErf(await readFileBytes(typeof module==='string'?localResourceFile(module,install):module));resolver.moduleName=typeof module==='string'?path.basename(module):module.name;}
 const haks=resolved.filter(entry=>entry.kind==='hak');
 const registered=new Map(),groups=new Map(),selected=[];
 for(const entry of [...haks].reverse()){
  const base=hakPriority(entry.resource),identity=base+':'+(typeof entry.resource==='string'?entry.resource:entry.name).toLowerCase();
  // Native duplicate registration rebuilds the existing table and does not
  // move it ahead of another archive. Only new registrations advance order.
  if(registered.has(identity))continue;const priority=base+(groups.get(base)??0);groups.set(base,(groups.get(base)??0)+1);registered.set(identity,true);selected.push({...entry,priority});
 }
 resolver.haks=await Promise.all(selected.map(async entry=>({name:entry.name,priority:entry.priority,...(typeof entry.resource==='string'?await indexedErf(entry.resource):parseErf(await readFileBytes(entry.resource)))})));
 resolver.haks.sort((a,b)=>b.priority-a.priority);
 // User-enabled Workshop mods are an explicit global local-content choice.
 // Their HAKs stay below the selected server's NWSync/HAKs, and are indexed
 // lazily rather than copying every installed archive payload into memory.
 resolver.localHaks=[];const serverFiles=new Set(selected.filter(e=>typeof e.resource==='string').map(e=>path.resolve(e.resource).toLowerCase()));for(const directory of await workshop.directories('hak'))for(const file of(await fs.readdir(directory,{withFileTypes:true})).sort((a,b)=>a.name.localeCompare(b.name))){if(!file.isFile()||!/\.hak$/i.test(file.name))continue;const filename=path.join(directory,file.name);if(serverFiles.has(path.resolve(filename).toLowerCase()))continue;resolver.localHaks.push({name:file.name,...await indexedErf(filename)});}
 // AddManifest40M registers primary first and selected additional manifests
 // afterwards. AddKeyTable18e330 increments ties: the last manifest wins.
 resolver.layers=[...new Map(resolved.filter(entry=>entry.kind==='nwsync').map(entry=>[entry.name.toLowerCase(),entry.resource])).values()].reverse();
 for(const directory of [...(userDirectory?[path.join(userDirectory,'override')]:[]),path.join(install,'ovr'),path.join(install,'override'),...await workshop.directories('override')]){const layer=await looseResourceLayer(directory);if(layer)resolver.fallbackLayers.push(layer);}
 // Portraits are user images, never a source of rules or another server's HAKs.
 const portraitLayers=[];for(const directory of[...(userDirectory?[path.join(userDirectory,'portraits')]:[]),...await workshop.directories('portraits')]){const layer=await looseResourceLayer(directory,{types:INSTALLED_PORTRAIT_TYPES});if(layer){layer.nativePriority=91000000;portraitLayers.push(layer);}}resolver.priorityLayers.unshift(...portraitLayers);
 resolver.resourceNames=type=>[...new Set([...resolver.key.resources.keys(),...resolver.module.entries.keys(),...resolver.haks.flatMap(h=>[...h.entries.keys()]),...resolver.localHaks.flatMap(h=>[...h.entries.keys()]),...resolver.layers.flatMap(l=>[...(l.catalog?.keys()??[])]),...resolver.priorityLayers.flatMap(l=>[...(l.resourceKeys?.()??[])]),...resolver.fallbackLayers.flatMap(l=>[...(l.resourceKeys?.()??[])])].filter(k=>k.endsWith(':'+type)).map(k=>k.slice(0,k.lastIndexOf(':'))))];
 return resolver;
}
