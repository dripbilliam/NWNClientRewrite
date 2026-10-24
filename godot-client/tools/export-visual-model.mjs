import {prepareVisualRigTransfer} from './export-rigs.mjs';
import {prepareParticleTransfer} from './export-particles.mjs';
import {exportGodotRoom} from './export-room.mjs';
import {modelReferenceParts} from '../../src/model_reference_scene.js';

// Callers instantiate assets in a private, identity scene. Referenced models
// remain independent siblings, as in the original P/Q-only attachment owner.
// Nothing is tagged with a canonical network ID, reparented or animated here.
export function prepareVisualModelTransfer({scene,camera,model}){
 const models=[],attachments=[],seen=new Set();
 function visit(instance){
  if(seen.has(instance))throw Error('Visual resource has a repeated model owner');
  seen.add(instance);models.push(instance);
  for(const child of instance.references?.models??[]){
   if(seen.has(child))throw Error('Visual resource has a repeated model owner');
   const attachment=instance.references.poses.attachmentFor(child);
   if(!attachment)throw Error('Referenced visual model has no attachment owner');
   attachments.push({root:child.root,...attachment});visit(child);
  }
 }
 visit(model);scene.updateMatrixWorld(true);
 if(scene.matrixWorld.elements.some((value,index)=>Math.abs(value-([0,5,10,15].includes(index)?1:0))>1e-12))throw Error('Visual resource scene must have an identity world transform');
 const rigs=prepareVisualRigTransfer({scene,models,attachments});
 for(const [index,instance]of models.entries()){
  const root=instance.references?.parts??modelReferenceParts(instance.model,instance.root),parts=new Array(instance.model.nodes.length);
  const visit=part=>{const id=part.group.userData.mdlNodeIndex;if(!Number.isInteger(id)||id<0||id>=parts.length||parts[id])throw Error('Invalid private reference physical index');
   const reference=part.node.type==='reference',child=part.model68?models.indexOf(part.model68):null;
   if(reference&&(!Number.isInteger(part.header8.reattachableE0)||child===-1))throw Error('Private reference child/reattachable metadata is unavailable');
   parts[id]={name:part.node.name,reference,flags98:part.header8.flags98,reattachableE0:reference?part.header8.reattachableE0:0,model:child,children:part.children38.map(p=>p.group.userData.mdlNodeIndex)};for(const child of part.children38)visit(child);
  };visit(root);if(parts.filter(Boolean).length!==parts.length)throw Error('Private reference hierarchy is incomplete');
  rigs.data.entities[0].models[index].referenceGraph={version:1,root:root.group.userData.mdlNodeIndex,parts};
 }
 const particles=prepareParticleTransfer({scene,camera,presentation:{instances:new Set(models)},rigTransfer:rigs});
 for(const emitter of particles.data.emitters)emitter.objectId=0;
 return{rigs,particles,models};
}

export async function exportVisualModel(context){
 const {rigs,particles,models}=prepareVisualModelTransfer(context);
 const result=await exportGodotRoom({...context,inventory:[],entities:[],buffer:[1,1],includeCamera:false,rigTransfer:rigs,particleTransfer:particles});
 result.manifest.kind='visual-model';
 result.manifest.scope='Render-only original model resource; private local rig handle, no gameplay entity or collision';
 result.manifest.modelResources=models.map(instance=>instance.resourceName??instance.model.modelName);
 return result;
}
