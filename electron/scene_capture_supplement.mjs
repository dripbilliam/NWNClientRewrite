import fs from 'node:fs/promises';import path from 'node:path';
import {SceneCaptureArchive} from './scene_capture_archive.mjs';

// Optional, immutable, locally reconstructed input. The original capture stays
// authoritative for every key it recorded, including expected failures.
export class SceneCaptureSupplement {
 static async open(directory,parent){
  const archive=await SceneCaptureArchive.open(directory),source=JSON.parse(await fs.readFile(path.join(archive.directory,'source.json'),'utf8'));
  if(source.version!==1||source.parentEventsSha256!==parent.manifest.eventsSha256)throw Error('Supplement belongs to another scene capture');
  return new SceneCaptureSupplement(archive,source);
 }
 constructor(archive,source){this.archive=archive;this.source=source;}
 static combine(parent,supplements=[]){
  const output=Object.create(parent);output.unrecorded=new Set();output.supplementHits=new Set();
  output.resolver=contextId=>{
   const entries=[parent,...supplements.map(s=>s.archive)].filter(a=>Object.hasOwn(a.manifest.contexts,contextId)),raw=entries.map(a=>a.resolver(contextId));
   const missing=key=>{output.unrecorded.add(contextId+':'+key);throw Object.assign(Error('Resource was not recorded: '+key),{code:'CAPTURE_MISSING'});};
   const choose=(field,key)=>entries.findIndex(a=>Object.hasOwn(a.manifest.contexts[contextId][field],key));
   return{async getResource(name,type){const key=String(name).toLowerCase()+':'+type,index=choose('resources',key);if(index<0)return missing(key);if(index)output.supplementHits.add(contextId+':'+key);return raw[index].getResource(name,type);},
    async getTextureResource(name){const key=String(name).toLowerCase(),index=choose('textures',key);if(index<0)return missing(key+':texture');if(index)output.supplementHits.add(contextId+':'+key+':texture');return raw[index].getTextureResource(name);},
    resourceRecord(name,type){const key=String(name).toLowerCase()+':'+type,index=choose('resources',key);return index<0?null:raw[index].resourceRecord(name,type);},
    resourceNames(type){return [...new Set(raw.flatMap(r=>r.resourceNames(type)))];}};
  };
  return output;
 }
}
