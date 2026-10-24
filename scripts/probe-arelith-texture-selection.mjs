// Offline metadata only: no proprietary image/model bytes are written.
import fs from 'node:fs/promises';
import path from 'node:path';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {parse2da} from '../src/area.js';
import {decodeResourceText} from '../src/resource_archive.js';
const [install,downloadFile,adFile,output]=process.argv.slice(2);
const download=JSON.parse(await fs.readFile(downloadFile)),ad=JSON.parse(await fs.readFile(adFile));
const report={scope:'Offline texture catalog/headers only; original assets excluded',httpAttempts:0,samples:[],dragons:[]};
const resources=installedNetworkResources({install,cacheDirectory:download.cache.directory,reuseInstalledNWSync:false,contentOptions:{fetch:()=>{report.httpAttempts++;throw Error('Offline only');}}});
try{
 const result=await resolveServerResources(ad.requirements,{...resources,language:0});
 if(!result.ready)throw Error('Cached server context is not ready');
 const resolver=await resources.openModule(null,result.resolved),names=resolver.resourceNames(2033).filter(name=>resolver.hasResource(name,3));
 report.bothFormats=names.length;
 const dimensions=(bytes,type)=>{const v=new DataView(bytes);if(type===3)return[v.getUint16(12,true),v.getUint16(14,true)];return v.getUint32(0,false)===0x44445320?[v.getUint32(16,true),v.getUint32(12,true)]:[v.getUint32(0,true),v.getUint32(4,true)];};
 const candidates=names.filter(n=>/^t[ircns]/i.test(n));candidates.sort((a,b)=>Number(resolver.resourceLocation(b,2033)===5)-Number(resolver.resourceLocation(a,2033)===5));
 for(const name of candidates.slice(0,32)){
  const selected=await resolver.getTextureResource(name);
  report.samples.push({name,selected:selected.type,locations:{tga:resolver.resourceLocation(name,3),dds:resolver.resourceLocation(name,2033)},tga:dimensions(await resolver.getResource(name,3),3),dds:dimensions(await resolver.getResource(name,2033),2033)});
 }
 const appearance=parse2da(decodeResourceText(await resolver.getResource('appearance',2017)));
 for(const[id,row]of appearance.rows)if(/dragon/i.test(row.LABEL??''))report.dragons.push({id,label:row.LABEL,model:row.RACE,modelType:row.MODELTYPE});
 report.success=true;
}catch(error){report.failure=error.message;process.exitCode=1;}
finally{resources.close();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:report.success,httpAttempts:report.httpAttempts,bothFormats:report.bothFormats,samples:report.samples.length,failure:report.failure}));}
