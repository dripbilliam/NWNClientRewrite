import {Worker} from 'node:worker_threads';
import {validateParticleLayout} from './particle-buffers.mjs';

// Persistent workers own simulation/RNG/storage as well as vertex preparation.
// No unbounded frame queue: the native owner must wait for readiness and supply
// its elapsed time/poses. This API never silently drops or reorders time steps.
export class NativeParticleWorkers {
 constructor({count = 2, layout, seed = 1} = {}) {
  validateParticleLayout(layout);
  if (!Number.isInteger(count) || count < 1 || count > 4) throw Error('Invalid particle worker count');
  this.options = {layout, seed}; this.epoch = 0; this.revision = 0; this.serial = 0; this.pending = new Map(); this.busy = false; this.closed = false; this.ready = false;
  this.slots = Array.from({length:count}, (_, index) => {
   const worker = new Worker(new URL('./particle-worker.mjs', import.meta.url)), slot = {worker, index, failed:false, ids:new Set()};
   worker.on('message', message => {
    const job = this.pending.get(message.id); if (!job || job.slot !== slot) return;
    this.pending.delete(message.id); message.error ? job.reject(Error(message.error)) : job.resolve(message);
   });
   const fail = error => {slot.failed = true; this.ready = false; for (const [id, job] of this.pending) if (job.slot === slot) {this.pending.delete(id); job.reject(error);}};
   worker.on('error', fail); worker.on('exit', code => {if (!this.closed) fail(Error('Particle worker exited: ' + code));});
   return slot;
  });
 }
 request(slot, value) {
  if (this.closed || slot.failed) return Promise.reject(Error('Particle worker is unavailable'));
  const id = ++this.serial;
  return new Promise((resolve, reject) => {this.pending.set(id, {slot, resolve, reject}); try {slot.worker.postMessage({id, ...value});} catch (error) {this.pending.delete(id); reject(error);}});
 }
 async reset({epoch, emitters, collision = []}) {
  if (this.closed || !Number.isSafeInteger(epoch) || epoch <= this.epoch || !Array.isArray(emitters) || emitters.length > 4096) throw Error('Invalid particle worker reset');
  const ids = new Set(); for (const row of emitters) {if (!Number.isSafeInteger(row.id) || ids.has(row.id)) throw Error('Duplicate or invalid particle worker emitter'); ids.add(row.id);}
  this.ready = false; this.epoch = epoch; const revision = ++this.revision;
  const groups = this.slots.map(() => []);
  emitters.forEach((row, i) => groups[i % groups.length].push(row));
  this.slots.forEach((slot, i) => slot.ids = new Set(groups[i].map(row => row.id)));
  await Promise.all(this.slots.map((slot, i) => this.request(slot, {kind:'initialize', options:{...this.options, seed:(this.options.seed + i) >>> 0}, scene:{epoch, emitters:groups[i], collision}})));
  if (!this.closed && this.revision === revision) this.ready = true;
  return {epoch, stale:this.revision !== revision, workers:this.slots.length};
 }
 async frame(frame) {
  if (this.closed) throw Error('Particle workers are closed');
  if (!this.ready || frame.epoch !== this.epoch) return {epoch:frame.epoch, sequence:frame.sequence, stale:true, emitters:[]};
  if (this.busy) return {epoch:frame.epoch, sequence:frame.sequence, busy:true, emitters:[]};
  if (!Array.isArray(frame.poses ?? [])) throw Error('Invalid particle worker poses');
  const seen = new Set(); for (const pose of frame.poses ?? []) {if (seen.has(pose.id) || !this.slots.some(slot => slot.ids.has(pose.id))) throw Error('Unknown or duplicate particle worker pose'); seen.add(pose.id);}
  this.busy = true; const revision = this.revision;
  try {
   const results = await Promise.all(this.slots.map(slot => this.request(slot, {kind:'frame', frame:{...frame, poses:(frame.poses ?? []).filter(pose => slot.ids.has(pose.id))}})));
   if (this.closed || revision !== this.revision) return {epoch:frame.epoch, sequence:frame.sequence, stale:true, emitters:[]};
   return {epoch:frame.epoch, sequence:frame.sequence, emitters:results.flatMap(r => r.result.emitters).sort((a,b) => a.id - b.id),
    diagnostics:results.flatMap(r => r.result.diagnostics ?? []), state:results.flatMap(r => r.result.state ?? []), randomDraws:results.map(r => r.result.randomDraws)};
  } finally {this.busy = false;}
 }
 async patch({epoch,add=[],remove=[]}) {
  if(this.closed||!this.ready||epoch!==this.epoch)return {stale:true};
  const retained=new Set(this.slots.flatMap(slot=>[...slot.ids]));
  for(const row of add){if(retained.has(row.id))throw Error('Particle patch reuses a live ID');retained.add(row.id);}
  if(retained.size>4096)throw Error('Particle patch exceeds emitter limit');
  const revision=++this.revision;this.ready=false;
  const groups=this.slots.map(()=>[]);for(const row of add){const slot=this.slots.reduce((best,slot)=>slot.ids.size<best.ids.size?slot:best);groups[slot.index].push(row);slot.ids.add(row.id);}
  const result=await Promise.all(this.slots.map((slot,index)=>{const retired=remove.filter(id=>slot.ids.has(id));for(const id of retired)slot.ids.delete(id);return this.request(slot,{kind:'patch',patch:{epoch,add:groups[index],remove:retired}});}));
  if(!this.closed&&this.revision===revision)this.ready=true;return {stale:this.revision!==revision,result};
 }
 async close() {
  if (this.closed) return; this.closed = true; this.ready = false; ++this.revision;
  for (const job of this.pending.values()) job.reject(Error('Particle workers closed')); this.pending.clear();
  await Promise.all(this.slots.map(slot => slot.worker.terminate()));
 }
}
