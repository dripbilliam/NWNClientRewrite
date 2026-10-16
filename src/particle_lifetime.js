const f=Math.fround;
// Complete PartEmitter::chkParticleLife140065f10..1400660bf. Active/free
// lists are local render state, not game-object IDs. Age is tested BEFORE
// adding delta; crossing lifetime is retired on the next call. The native
// backwards scan and free-list append order are observable when recycling.
export function checkParticleLife(emitter,delta,p) {
  const active=emitter.active188,free=emitter.free130;
  if(!Array.isArray(active?.records)||!Array.isArray(free?.records)||!Number.isInteger(free.capacity)||free.capacity<free.records.length)throw new Error('Native particle list storage is unavailable');
  const chunky=emitter.chunkName.length!==0;
  for(let i=active.records.length-1;i>=0;i--){
    const particle=active.records[i];if(!particle)throw new Error('Native particle active-list mutation is unavailable');
    // COMISS/JB takes unordered comparisons as well as strictly less.
    if(!(f(emitter.lifeExp)>=0)||!(f(particle.age)>=f(emitter.lifeExp))){
      particle.age=f(f(delta)+f(particle.age));
      if(particle.age<0){particle.age=0;particle.field48=0;}
    }else{
      if(i<active.records.length)active.records.splice(i,1);
      if(free.records.length===free.capacity){
        const capacity=free.capacity===0?16:Math.imul(free.capacity,2);
        if(capacity<=free.capacity)throw new Error('Native particle free-list capacity overflow is unavailable');
        free.capacity=capacity;
        if(typeof p?.reserveFree!=='function')throw new Error('Native particle free-list allocation owner is unavailable');
        p.reserveFree(capacity);
      }
      free.records.push(particle);
      if(chunky&&particle.chunk78){
        if(typeof p?.detachChunk!=='function')throw new Error('Native particle chunk teardown owner is unavailable');
        p.detachChunk(particle.chunk78,0);
      }
    }
  }
}
