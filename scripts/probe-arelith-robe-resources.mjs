// Offline, active-server resource metadata. Never writes model/texture bytes.
import fs from 'node:fs/promises';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {ModelSourceCache} from '../src/model_source_cache.js';
import {parse2da} from '../src/area.js';
import {RESOURCE_TYPE,decodeResourceText} from '../src/resource_archive.js';
const[install,downloadFile,adFile,output]=process.argv.slice(2),download=JSON.parse(await fs.readFile(downloadFile)),ad=JSON.parse(await fs.readFile(adFile));
const report={httpAttempts:0,tables:[],models:[]},resources=installedNetworkResources({install,cacheDirectory:download.cache.directory,reuseInstalledNWSync:false,contentOptions:{fetch:()=>{report.httpAttempts++;throw Error('Offline only');}}});
try{
 const result=await resolveServerResources(ad.requirements,{...resources,language:0});if(!result.ready)throw Error('Cached context unavailable');
 const resolver=await resources.openModule(null,result.resolved),cache=new ModelSourceCache(resolver);
 report.partTables=[...resolver.key.resources.values()].filter(e=>e.resourceType===2017&&/part|body/i.test(e.resref)).map(e=>e.resref);
 console.log(JSON.stringify({partTables:report.partTables}));
 for(const name of ['parts_robe',...report.partTables.filter(n=>!n.startsWith('parts_'))]){
  const table=parse2da(decodeResourceText(await resolver.getResource(name,RESOURCE_TYPE.TWO_DA)));
  report.tables.push({name,columns:table.columns,rows:[...table.rows].slice(0,name==='parts_robe'?6:19)});
 }
 for(const name of ['pmd0_robe003','pmh0_robe003']){
  const model=await cache.load(name);report.models.push({name,sourceModel:model.modelName,superModel:model.superModel,animations:model.animations.map(a=>a.name),nodes:model.nodes.map(n=>({name:n.name,parent:n.parent,type:n.type,skinned:n.skinned,slots:n.skinData?.boneConstantSlots?.filter(i=>i>=0)}))});
 }
 cache.dispose();report.success=true;
}catch(error){report.failure=error.message;process.exitCode=1;}
finally{resources.close();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:report.success,httpAttempts:report.httpAttempts,tables:report.tables,models:report.models.map(m=>({name:m.name,superModel:m.superModel,nodes:m.nodes.length,clips:m.animations.length})),failure:report.failure}));}
