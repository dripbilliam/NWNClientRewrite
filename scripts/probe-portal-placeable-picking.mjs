// Read-only cached model metadata. Refuses HTTP and saves no asset bytes.
import fs from 'node:fs/promises';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {ModelSourceCache} from '../src/model_source_cache.js';
import {parse2da} from '../src/area.js';
import {RESOURCE_TYPE,decodeResourceText} from '../src/resource_archive.js';
import {parseWalkmesh} from '../src/walkmesh.js';
const [install,downloadFile,adFile,output]=process.argv.slice(2),download=JSON.parse(await fs.readFile(downloadFile)),ad=JSON.parse(await fs.readFile(adFile));
const report={httpAttempts:0,models:[]},resources=installedNetworkResources({install,cacheDirectory:download.cache.directory,reuseInstalledNWSync:false,contentOptions:{fetch:()=>{report.httpAttempts++;throw Error('Offline only');}}});let cache;
try{
 const result=await resolveServerResources(ad.requirements,{...resources,language:0});if(!result.ready)throw Error('Cached context unavailable');const resolver=await resources.openModule(null,result.resolved),table=parse2da(decodeResourceText(await resolver.getResource('placeables',2017)));cache=new ModelSourceCache(resolver);
 const rows=[...table.rows].filter(([,r])=>/portal/i.test(r.Label+' '+r.ModelName));report.placeables=rows.map(([id,r])=>({id,label:r.Label,model:r.ModelName}));
 const names=new Set(['plc_portal','plc_portal2',...rows.map(([,r])=>r.ModelName?.toLowerCase()).filter(Boolean)]);
 const bounds=vertices=>vertices?.length?{min:[0,1,2].map(i=>Math.min(...vertices.map(v=>v[i]))),max:[0,1,2].map(i=>Math.max(...vertices.map(v=>v[i])))}:null;
 for(const name of names){const row={name};report.models.push(row);try{const model=await cache.load(name);row.nodes=model.nodes.map(n=>({name:n.name,type:n.type,render:n.render??n.properties?.render,alpha:n.alpha??n.properties?.alpha,verts:n.verts?.length??0,faces:n.faces?.length??0,position:n.position,bounds:bounds(n.verts)}));try{const triangles=parseWalkmesh(await resolver.getResource(name,RESOURCE_TYPE.PWK));row.pwk={triangles:triangles.length,bounds:bounds(triangles.flatMap(t=>t.vertices))};}catch(error){row.pwk={error:error.code??error.message};}}catch(error){row.error=error.code??error.message;}}
 report.success=true;
}catch(error){report.failure=error.message;process.exitCode=1;}finally{cache?.dispose();resources.close();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:report.success,httpAttempts:report.httpAttempts,models:report.models.map(m=>({name:m.name,meshes:m.nodes?.filter(n=>n.verts),pwk:m.pwk,error:m.error})),failure:report.failure}));}
