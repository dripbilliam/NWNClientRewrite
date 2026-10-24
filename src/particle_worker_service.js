import {ParticleWorkerScene} from './particle_worker_scene.js';

// Shared service for an actual dedicated worker and the independent oracle.
// Full cyclic state is returned only when explicitly requested by a test.
export function createParticleWorkerService(post){
 let scene=null;
 return message=>{try{
  if(message.type==='init'){if(scene)throw Error('Particle worker already initialized');scene=new ParticleWorkerScene(message.scene);post({id:message.id,ready:true,...(message.oracle?{state:scene.state()}:{})});}
  else if(message.type==='frame'){if(!scene)throw Error('Particle worker not initialized');const start=performance.now();scene.frame(message.frame);const simulationMs=performance.now()-start,frames=[],transfers=[];
   if(!message.oracle&&!message.discardVertices)for(const[mesh,entry]of scene.presentation.entries){if(entry.failed)continue;const count=entry.drawCount??0,attributes={};for(const[name,attribute]of Object.entries(mesh.geometry.attributes)){const array=attribute.array.slice(0,count*attribute.itemSize);attributes[name]={array,itemSize:attribute.itemSize,normalized:attribute.normalized};transfers.push(array.buffer);}frames.push({id:scene.ids.get(mesh),count,visible:mesh.visible,active:entry.e.active188.records.length,attributes});}
   post({id:message.id,simulationMs,timing:scene.timing,random:{state:scene.presentation.random.state,draws:scene.presentation.random.draws},...(message.oracle?{state:scene.state()}:{frames})},transfers);
  }else if(message.type==='close'){scene?.dispose();scene=null;post({id:message.id,closed:true});}
  else throw Error('Unknown particle worker message');
 }catch(error){post({id:message.id,error:error.message});}};
}
