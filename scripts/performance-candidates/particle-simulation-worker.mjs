import {createParticleWorkerService} from '../../src/particle_worker_service.js';
const receive=createParticleWorkerService((value,transfers=[])=>self.postMessage(value,transfers));
self.onmessage=event=>receive(event.data);
