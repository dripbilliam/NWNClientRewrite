// Offline derived pose metadata only; no proprietary resource bytes are saved.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {ModelSourceCache} from '../src/model_source_cache.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {ModelAnimator} from '../src/model_animation.js';
const [install,downloadFile,adFile,output]=process.argv.slice(2),download=JSON.parse(await fs.readFile(downloadFile)),ad=JSON.parse(await fs.readFile(adFile));
const report={httpAttempts:0,models:[]},resources=installedNetworkResources({install,cacheDirectory:download.cache.directory,reuseInstalledNWSync:false,contentOptions:{fetch:()=>{report.httpAttempts++;throw Error('Offline only');}}});
try{
 const result=await resolveServerResources(ad.requirements,{...resources,language:0}),resolver=await resources.openModule(null,result.resolved),cache=new ModelSourceCache(resolver);
 for(const name of ['pmd0','pmd0_robe038','pmd0_robe172','pmd0_robe003']){
  const model=await cache.load(name),h=createModelHierarchy(model),a=new ModelAnimator(model,h.root),row={name,animationScale:model.animationScale,supermodel:model.supermodel,nodes:model.nodes.map(n=>({name:n.name,parent:n.parent,position:n.position,scale:n.scale,skinned:n.skinned})),poses:[]};
  for(const clipName of ['pause1','walk']){a.play(clipName);a.update(.3);h.root.updateMatrixWorld(true);row.poses.push({clip:clipName,inheritedFrom:a.clip?.inheritedFrom,tracks:a.clip?.tracks.filter(t=>t.property==='position').map(t=>({node:t.node,value:t.frames[0]?.value})),positions:[...h.groups].filter(([n])=>/root|pelvis|torso|neck|head|foot|robe/i.test(n)).map(([n,g])=>({node:n,position:g.position.toArray(),world:g.matrixWorld.elements.slice(12,15)}))});}
  report.models.push(row);
 }
 const body=report.models[0];for(const robe of report.models.slice(1))for(const pose of robe.poses){const a=body.poses.find(p=>p.clip===pose.clip).positions.find(p=>p.node==='rootdummy').world,b=pose.positions.find(p=>p.node==='rootdummy').world;assert.deepEqual(b,a,robe.name+' animation root must align with the body');}
 cache.dispose();report.success=true;
}catch(e){report.failure=e.stack;process.exitCode=1;}finally{resources.close();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:report.success,httpAttempts:report.httpAttempts,failure:report.failure}));}
