// Offline derived model metadata only. No mesh, texture or proprietary bytes
// are saved. Uses the authenticated cached context; network access is refused.
import fs from 'node:fs/promises';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {ModelSourceCache} from '../src/model_source_cache.js';
const[install,downloadFile,adFile,output]=process.argv.slice(2),download=JSON.parse(await fs.readFile(downloadFile)),ad=JSON.parse(await fs.readFile(adFile));
const report={httpAttempts:0,models:[]},resources=installedNetworkResources({install,cacheDirectory:download.cache.directory,reuseInstalledNWSync:false,contentOptions:{fetch:()=>{report.httpAttempts++;throw Error('Offline only');}}});
try{
 const result=await resolveServerResources(ad.requirements,{...resources,language:0});if(!result.ready)throw Error('Cached context unavailable');
 const resolver=await resources.openModule(null,result.resolved),cache=new ModelSourceCache(resolver);
 for(const name of ['c_drggreen','pmo0']){
  const model=await cache.load(name);report.models.push({name,sourceModel:model.modelName,superModel:model.superModel,animations:model.animations.map(a=>({name:a.name,length:a.length,inheritedFrom:a.inheritedFrom})),nodes:model.nodes.length,materials:model.materialNames});
 }
 cache.dispose();report.success=true;
}catch(error){report.failure=error.message;process.exitCode=1;}
finally{resources.close();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:report.success,httpAttempts:report.httpAttempts,models:report.models.map(m=>({name:m.name,clips:m.animations.length,pause:m.animations.filter(a=>/pause1/.test(a.name))})),failure:report.failure}));}
