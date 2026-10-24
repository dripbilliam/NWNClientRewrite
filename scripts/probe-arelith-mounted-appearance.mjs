// Read cached active-server resources; save derived model/table metadata only.
import fs from 'node:fs/promises';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {ModelSourceCache} from '../src/model_source_cache.js';
import {parse2da} from '../src/area.js';
import {RESOURCE_TYPE,decodeResourceText} from '../src/resource_archive.js';
const[install,downloadFile,adFile,output]=process.argv.slice(2),download=JSON.parse(await fs.readFile(downloadFile)),ad=JSON.parse(await fs.readFile(adFile));
const report={httpAttempts:0,tables:[],models:[]},resources=installedNetworkResources({install,cacheDirectory:download.cache.directory,reuseInstalledNWSync:false,contentOptions:{fetch:()=>{report.httpAttempts++;throw Error('Offline only');}}});
try{
 const result=await resolveServerResources(ad.requirements,{...resources,language:0}),resolver=await resources.openModule(null,result.resolved),cache=new ModelSourceCache(resolver);
 for(const[name,ids]of [['appearance',[495]],['phenotype',[0,3]],['tailmodel',[0,14,34,347]],['wingmodel',[0]],['capart',[7]]]){const t=parse2da(decodeResourceText(await resolver.getResource(name,RESOURCE_TYPE.TWO_DA)));report.tables.push({name,columns:t.columns,rows:ids.map(id=>({id,...t.rows.get(id)}))});}
 const tail=report.tables.find(t=>t.name==='tailmodel').rows.find(r=>r.id===34);
 for(const name of ['pmh3','pmh0_chest057','pmh3_chest057',tail.MODEL].filter(Boolean)){
  if(!resolver.hasResource(name,RESOURCE_TYPE.MDL)){report.models.push({name,missing:true});continue;}
  const m=await cache.load(name);report.models.push({name,source:m.modelName,supermodel:m.supermodel,scale:m.animationScale,nodes:m.nodes.map(n=>({name:n.name,parent:n.parent,type:n.type,position:n.position,scale:n.scale,vertices:n.verts.length,faces:n.faces.length,skinned:n.skinned,bitmap:n.bitmap,properties:n.properties})),clips:m.animations.slice(0,5).map(a=>a.name)});
 }
 cache.dispose();report.success=true;
}catch(e){report.failure=e.stack;process.exitCode=1;}finally{resources.close();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:report.success,httpAttempts:report.httpAttempts,failure:report.failure}));}
