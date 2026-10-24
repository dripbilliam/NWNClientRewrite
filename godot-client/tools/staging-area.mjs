import {exportGodotRoom} from './export-room.mjs';
import {prepareRigTransfer} from './export-rigs.mjs';
import {movementSnapshot} from './drive-staging.mjs';
import {prepareParticleTransfer,stampParticleBindings} from './export-particles.mjs';

export function createAreaStaging({scene,camera,presentation,frontend,focus,stop,content,exporter=exportGodotRoom,rigs=prepareRigTransfer}){
 return async expected=>{
  stop();
  await frontend.queue;await frontend.areaAdmissionWork;
  const p=presentation(),world=frontend.world;
  const current=()=>p&&!p.closed&&p.area?.id===expected.areaId&&presentation()===p&&frontend.world===world&&world.areaId===expected.areaId&&frontend.areaGeneration===expected.generation;
  if(!current())return null;
  await p.syncWork;if(!current())return null;
  const bindings=new Map(p.objects),stable=()=>current()&&p.objects.size===bindings.size&&[...bindings].every(([id,b])=>p.objects.get(id)===b);
  const inventory=[...bindings].map(([id,b])=>({id,resources:b.models.map(m=>m.resourceName??m.root.name)}));
  try{
   const rigTransfer=rigs(p),particleTransfer=prepareParticleTransfer({scene,camera,presentation:p,rigTransfer});
   const result=await exporter({scene,camera,world,resolve:(value,id)=>frontend.resolveText(value,id),focus:focus(),inventory,buffer:[1424,921],rigTransfer,particleTransfer});
   if(!stable())return null;
   for(const entity of result.manifest.entities){const b=bindings.get(entity.id);entity.pose={position:b.wrapper.position.toArray(),rotation:b.wrapper.rotation.y};}
   result.manifest.live={areaId:expected.areaId,generation:expected.generation,controlledId:world.localObjectId,area:p.area.resRef};
   result.manifest.content=content.rows();
   stampParticleBindings(result.manifest.particles,result.manifest.content);
   result.manifest.clientMotion=movementSnapshot(p);
   result.manifest.scope='Live local area; original models and native animation; effect controllers/full gameplay pending';
   return result;
  }catch(error){if(!stable())return null;throw error;}
 };
}
