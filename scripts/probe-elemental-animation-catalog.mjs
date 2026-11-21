// Offline derived metadata only. Never fetch from the public server or copy
// proprietary model/texture data into the workspace.
import fs from 'node:fs/promises';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {parse2da} from '../src/area.js';
import {decodeResourceText} from '../src/resource_archive.js';
import {ModelSourceCache} from '../src/model_source_cache.js';
const download=JSON.parse(await fs.readFile('backups/animations/arelith-fresh-download-v2.json'));
const advertisement=JSON.parse(await fs.readFile('backups/animations/arelith-authenticated-advertisement-v1.json'));
const report={scope:'Previously downloaded Arelith manifest; offline elemental appearance/animation metadata, not a live-session resource snapshot',httpAttempts:0,joins:0,rows:[]};
const resources=installedNetworkResources({install:'../FullDecomp/NwnRootInstall',cacheDirectory:download.cache.directory,reuseInstalledNWSync:false,contentOptions:{fetch:()=>{report.httpAttempts++;throw Error('Offline probe only');}}});
try{
 const context=await resolveServerResources(advertisement.requirements,{...resources,language:0});if(!context.ready)throw Error('Previously downloaded context is unavailable');
 const resolver=await resources.openModule(null,context.resolved),table=parse2da(decodeResourceText(await resolver.getResource('appearance',2017))),sources=new ModelSourceCache(resolver);
 for(const[id,row]of table.rows){if(id!==864&&!/elemental/i.test(row.LABEL??''))continue;const result={id,label:row.LABEL,modelType:row.MODELTYPE,model:row.RACE};
  try{const model=await sources.load(row.RACE);Object.assign(result,{supermodel:model.supermodel,clips:model.animations.map(a=>a.name),nodes:model.nodes.length});}catch(error){result.error=error.message;}report.rows.push(result);
 }
 report.transformedResources=[];
 for(const name of ['invis_cr_160','c_golstone']){const model=await sources.load(name);report.transformedResources.push({name,supermodel:model.supermodel,clips:model.animations.map(a=>a.name),nodes:model.nodes.map(n=>({name:n.name,parent:n.parent}))});}
 sources.dispose();report.success=true;
}catch(error){report.failure=error.stack;process.exitCode=1;}
finally{resources.close();await fs.writeFile('backups/animations/creation-experience-elemental-animation-catalog-v1.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));}
