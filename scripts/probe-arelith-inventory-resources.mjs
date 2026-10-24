// Active-context metadata only; no game images/models are copied to the workspace.
import fs from 'node:fs/promises';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {parseModel} from '../src/model_parser.js';
import {parse2da} from '../src/area.js';
import {RESOURCE_TYPE,decodeResourceText} from '../src/resource_archive.js';
const[install,downloadFile,adFile,output]=process.argv.slice(2),download=JSON.parse(await fs.readFile(downloadFile)),ad=JSON.parse(await fs.readFile(adFile));
const report={httpAttempts:0,tables:[],models:[]},resources=installedNetworkResources({install,cacheDirectory:download.cache.directory,reuseInstalledNWSync:false,contentOptions:{fetch:()=>{report.httpAttempts++;throw Error('Offline only');}}});
try{
 const result=await resolveServerResources(ad.requirements,{...resources,language:0}),resolver=await resources.openModule(null,result.resolved);
 report.armorIconNames=[...resolver.key.resources.values()].filter(e=>e.resourceType===6&&/^ip/i.test(e.resref)).map(e=>e.resref).slice(0,25);
 for(const[name,ids]of [['baseitems',[0,1,16,17,26,35,42,49,54,75,80]],['capart',[6,7,8,14,15,18]],['cloakmodel',[1,14]]]){const t=parse2da(decodeResourceText(await resolver.getResource(name,RESOURCE_TYPE.TWO_DA)));report.tables.push({name,rows:ids.map(id=>({id,...t.rows.get(id)}))});}
 for(const name of ['pnl_inv','inv_slot_armor','inv_slot_right','inv_slot_left','inv_slot_helm','inv_slot_cloak','inv_slot_ring','inv_slot_belt','inv_slot_boots','inv_slot_gloves','inv_slot_amulet','inv_slot_arrow','inv_slot_bolts','inv_slot_sling']){
  if(!resolver.hasResource(name,RESOURCE_TYPE.MDL)){report.models.push({name,missing:true});continue;}const m=parseModel(await resolver.getResource(name,RESOURCE_TYPE.MDL));report.models.push({name,nodes:m.nodes.map(n=>({name:n.name,position:n.position,parent:n.parent,type:n.type,bitmap:n.bitmap,verts:n.verts.length}))});
 }
 report.success=true;
}catch(e){report.failure=e.stack;process.exitCode=1;}finally{resources.close();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:report.success,httpAttempts:report.httpAttempts,failure:report.failure}));}
