import fs from 'node:fs/promises';
import {openLocalModule} from './local-module.mjs';
import {parseModel} from '../src/model_parser.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-model-reference-inventory-v1.json';
const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),keys=[...new Set([...resolver.key.resources.keys(),...resolver.module.entries.keys(),...resolver.haks.flatMap(h=>[...h.entries.keys()])])].filter(k=>k.endsWith(':2002')&&/^(v|fx)/i.test(k)).sort(),report={scope:'First 12 reference-containing active v*/fx* MDLs, or all candidates if fewer. Metadata only; not full installed model coverage.',candidates:keys.length,scanned:0,models:[],failures:[]};
for(const key of keys){
 const name=key.slice(0,-5);report.scanned++;
 try{
  const bytes=await resolver.getResource(name,2002),d=new DataView(bytes);let hasReference=false;
  if(d.getUint32(0,true)===0){
   const visited=new Set(),walk=offset=>{if(visited.has(offset))throw Error('Node cycle');visited.add(offset);const at=12+offset;if(d.getUint32(at+108,true)&16)hasReference=true;const children=d.getUint32(at+72,true),count=d.getUint32(at+76,true);for(let i=0;i<count;i++)walk(d.getUint32(12+children+i*4,true));};walk(d.getUint32(84,true));
  }else hasReference=/\bnode\s+reference\b/i.test(new TextDecoder().decode(bytes));
  if(hasReference){const parsed=parseModel(bytes);report.models.push({name,internalName:parsed.modelName,references:parsed.nodes.filter(n=>n.type==='reference').map(n=>({name:n.name,model:n.reference?.model??n.properties.refmodel,reattachable:n.reference?.reattachable??n.properties.reattachable})),nodes:parsed.nodes.length});if(report.models.length>=12)break;}
 }catch(error){report.failures.push({name,error:error.message});}
}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
