// CExoArrayList<Particle*>::Add140061010. Storage belongs to the renderer;
// these entries are never canonical game objects or multiplayer identities.
export function appendEmitterParticle(emitter,particle,providers){
  const list=emitter.active188;
  if(list.records.length===list.capacity){
    const capacity=list.capacity===0?16:Math.imul(list.capacity,2);
    if(capacity<=list.capacity)throw new Error('Native emitter active-list capacity overflow is unavailable');
    list.capacity=capacity;
    if(typeof providers?.reserveActive!=='function')throw new Error('Native emitter active-list allocation owner is unavailable');
    providers.reserveActive(capacity);
  }
  list.records.push(particle);
}
