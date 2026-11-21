import {parentPort} from 'node:worker_threads';
import {NativeParticleSimulation} from './particle-simulation.mjs';
let simulation;
parentPort.on('message', message => {
 try {
  if (message.kind === 'initialize') {simulation?.close(); simulation = new NativeParticleSimulation(message.options); simulation.reset(message.scene); parentPort.postMessage({id:message.id, initialized:true}); return;}
  if (!simulation) throw Error('Particle worker has not been initialized');
  if(message.kind==='patch'){parentPort.postMessage({id:message.id,result:simulation.patch(message.patch)});return;}
  if (message.kind !== 'frame') throw Error('Unknown particle worker command');
  const result = simulation.frame(message.frame), transfer = result.emitters.flatMap(row => [row.positions, row.attributes]);
  parentPort.postMessage({id:message.id, result}, transfer);
 } catch (error) {parentPort.postMessage({id:message.id, error:error.message});}
});
