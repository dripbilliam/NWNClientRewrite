// Derived inverse-bind diagnostics from offline active resources only.
import fs from 'node:fs/promises';
import * as THREE from 'three';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {ModelSourceCache} from '../src/model_source_cache.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {deformSkinnedVertices} from '../src/model_skinning.js';
import {TGALoader} from 'three/addons/loaders/TGALoader.js';
const[install,downloadFile,adFile,output]=process.argv.slice(2),download=JSON.parse(await fs.readFile(downloadFile)),ad=JSON.parse(await fs.readFile(adFile));
const report={httpAttempts:0,models:[]},resources=installedNetworkResources({install,cacheDirectory:download.cache.directory,reuseInstalledNWSync:false,contentOptions:{fetch:()=>{report.httpAttempts++;throw Error('Offline only');}}});
try{
 const result=await resolveServerResources(ad.requirements,{...resources,language:0}),resolver=await resources.openModule(null,result.resolved),cache=new ModelSourceCache(resolver);
 report.paletteRows=[];for(const name of ['pal_hair01','pal_skin01','pal_cloth01']){const p=new TGALoader().parse(await resolver.getResource(name,3));report.paletteRows.push({name,width:p.width,height:p.height,rows:[0,1,p.height-2,p.height-1].map(y=>({y,pixels:[64,128,255].map(x=>[...p.data.slice((y*p.width+x)*4,(y*p.width+x)*4+3)])}))});}
 for(const name of ['pmd0_robe003','pmd0_robe038','pmd0_robe172']){
  const model=await cache.load(name),{nodeGroups,groups}=createModelHierarchy(model),skins=[];
  for(const node of model.nodes.filter(n=>n.skinned)){
   const s=node.skinData,inverseSkin=nodeGroups.get(node).matrixWorld.clone().invert(),slots=s.boneConstantSlots.filter(i=>i>=0&&i<model.nodes.length),cases=[];
   for(const index of [...new Set(slots)]){const q=s.qboneRefInv[index],t=s.tboneRefInv[index];if(!q||!t)continue;
    const candidates={wxyz:new THREE.Quaternion(q[1],q[3],-q[2],q[0]),xyzw:new THREE.Quaternion(q[0],q[2],-q[1],q[3])};
    const errors=Object.fromEntries(Object.entries(candidates).map(([order,q])=>{const inverseBind=new THREE.Matrix4().compose(new THREE.Vector3(t[0],t[2],-t[1]),q,new THREE.Vector3(1,1,1)),matrix=inverseSkin.clone().multiply(nodeGroups.get(model.nodes[index]).matrixWorld).multiply(inverseBind),identity=new THREE.Matrix4().elements;return[order,Math.max(...matrix.elements.map((v,i)=>Math.abs(v-identity[i])))];}));cases.push({index,node:model.nodes[index].name,errors});
   }
   const deformed=deformSkinnedVertices(node,model.nodes,groups,nodeGroups.get(node),nodeGroups),restVertexError=Math.max(...deformed.flatMap((v,i)=>v.map((x,c)=>Math.abs(x-[node.verts[i][0],node.verts[i][2],-node.verts[i][1]][c]))));
   if(restVertexError>1e-5)throw Error(name+' inverse bind does not preserve the reference mesh: '+restVertexError);
   skins.push({name:node.name,qCount:s.qboneRefInv.length,tCount:s.tboneRefInv.length,slotMap:s.boneConstantSlots.slice(0,16),q0:s.qboneRefInv[0],t0:s.tboneRefInv[0],restVertexError,cases});
  }
  report.models.push({name,animationScale:model.animationScale,skins});
 }
 cache.dispose();report.success=true;
}catch(error){report.failure=error.stack;process.exitCode=1;}
finally{resources.close();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));}
