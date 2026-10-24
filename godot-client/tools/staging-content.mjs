import {exportGodotRoom} from './export-room.mjs';
import {prepareRigTransfer} from './export-rigs.mjs';
import {movementSnapshot} from './drive-staging.mjs';
import {prepareParticleTransfer,stampParticleBindings} from './export-particles.mjs';

export function createContentStaging({scene,camera,presentation,frontend}){
 const revisions=new WeakMap();let serial=0;
 const revision=b=>{if(!revisions.has(b))revisions.set(b,++serial);return revisions.get(b);};
 const rows=()=>[...(presentation()?.objects??[])].map(([id,b])=>({id,revision:revision(b)}));
 function snapshot(){
  const p=presentation(),world=frontend.world;
  const desired=[...(world?.registry.objects.values()??[])].filter(o=>o.areaId===world.areaId&&!o.replicationRemoved&&[5,6,7,9,10].includes(o.objectType)).map(o=>o.id);
  return{areaId:world?.areaId,generation:frontend.areaGeneration,desired,ready:rows().filter(row=>desired.includes(row.id))};
 }
 async function exportContent(request,prefix){
  const p=presentation(),ids=new Set(request.map(r=>r.id)),before=snapshot();
  if(request.some(r=>!before.ready.some(b=>b.id===r.id&&b.revision===r.revision)))return null;
  const inventory=request.map(({id})=>({id,resources:p.objects.get(id).models.map(m=>m.resourceName??m.root.name)}));
  const rigTransfer=prepareRigTransfer(p,ids),particleTransfer=prepareParticleTransfer({scene,camera,presentation:p,rigTransfer,objectIds:ids});
  const result=await exportGodotRoom({scene,camera,world:frontend.world,resolve:(v,id)=>frontend.resolveText(v,id),inventory,buffer:[1424,921],objectIds:ids,namePrefix:prefix,includeCamera:false,rigTransfer,particleTransfer});
  const after=snapshot();
  if(presentation()!==p||before.areaId!==after.areaId||before.generation!==after.generation||request.some(r=>!after.ready.some(b=>b.id===r.id&&b.revision===r.revision)))return null;
  for(const row of result.manifest.entities){const b=p.objects.get(row.id);row.pose={position:b.wrapper.position.toArray(),rotation:b.wrapper.rotation.y};}
  result.manifest.kind='entity-content';result.manifest.content=request;
  stampParticleBindings(result.manifest.particles,before.ready);
  result.manifest.clientMotion=movementSnapshot(p,ids);
  result.manifest.live={areaId:before.areaId,generation:before.generation,controlledId:frontend.world.localObjectId};
  return result;
 }
 return{snapshot,rows,export:exportContent};
}
