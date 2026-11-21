// Read-only catalog/authoring metadata. No NSS/NCS/GFF payloads are exported.
import fs from 'node:fs/promises';
import {openLocalModule} from './local-module.mjs';
import {parseGff} from '../src/gff.js';
const root='../FullDecomp/NwnRootInstall',r=await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),scripts=process.argv.slice(2).length?process.argv.slice(2):['script1','script2'],references=[];
for(const [key,bytes]of r.module.entries){
  if(![2012,2023,2014,2044,2042,2029].includes(Number(key.split(':').at(-1))))continue;
  const data=parseGff(bytes).root;
  const visit=(object,path)=>{if(!object||typeof object!=='object')return;for(const [field,value]of Object.entries(object)){
    if(scripts.includes(value))references.push({resource:key,field:path+field,script:value});
    else if(value&&typeof value==='object')visit(value,path+field+'.');
  }};visit(data,'');
}
const override=await fs.readdir(root+'/ovr');
console.log(JSON.stringify({keySources:r.key.sources,haks:r.haks.map(h=>h.name),scripts:scripts.map(name=>({name,moduleNcs:r.module.entries.has(name+':2010'),moduleNss:r.module.entries.has(name+':2009'),keyNcs:r.key.resources.has(name+':2010'),keyNss:r.key.resources.has(name+':2009'),looseOverride:override.filter(f=>[name+'.ncs',name+'.nss'].includes(f.toLowerCase()))})),references},null,2));
