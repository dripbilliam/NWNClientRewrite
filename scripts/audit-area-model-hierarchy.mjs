import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {parseAreaModule} from '../src/area.js';
import {parseModel} from '../src/model_parser.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
const root='../FullDecomp/NwnRootInstall',r=await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),area=await parseAreaModule(process.argv[2]??'m0q1b',r);
const names=[...new Set([...area.tiles,...area.placeables,...area.doors,...area.creatures].map(n=>n.model).filter(Boolean))],duplicates=[],failures=[];
for(const name of names){try{
  const model=parseModel(await r.getResource(name,2002)),{root,nodeGroups}=createModelHierarchy(model);let count=0;root.traverse(()=>count++);assert.equal(count,model.nodes.length+1);
  const seen=new Set(),repeated=model.nodes.filter(n=>{const duplicate=seen.has(n.name);seen.add(n.name);return duplicate;});
  if(repeated.length)duplicates.push({name,nodes:repeated.map(n=>({name:n.name,parent:n.parent,parentIndex:n.parentIndex,distinctFromParent:nodeGroups.get(n)!==nodeGroups.get(model.nodes[n.parentIndex])}))});
}catch(error){failures.push({name,error:error.message});}}
console.log(JSON.stringify({area:area.resRef,models:names.length,duplicates,failures},null,2));assert.deepEqual(failures,[]);
