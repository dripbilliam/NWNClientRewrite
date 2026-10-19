import {createParticle,initializeParticle,randomizeParticleFrame,randomParticlePosition} from './particle_initialization.js';
import {moveStandardParticles} from './particle_movement.js';
const required=(p,key,...args)=>{if(typeof p?.[key]!=='function')throw new Error(`Native Fountain particle provider ${key} is unavailable`);return p[key](...args);};

// Compose real particle owners for the normal movement path. Render callbacks
// supply camera/scene services; none of these owners use authoritative RNG or
// allocate gameplay object IDs. JS arrays own backing storage while the ports
// retain the native active/free capacities and reuse order.
export function fountainParticleProviders(emitter,services){
  const p={...services};
  p.reserveActive??=()=>{};p.reserveFree??=()=>{};
  p.sourceFactor??=source=>{
    if(!Number.isFinite(source.adjustedScale))throw new Error('Native particle source adjusted scale is unavailable');
    return Math.fround(source.adjustedScale);
  };
  p.createParticle=(chunk,delta)=>{
    if(!chunk)return createParticle(emitter,delta,p);
    const particle=required(services,'createChunkParticle',emitter,delta,p);if(particle)particle.nativeChunky=true;return particle;
  };
  p.initializeParticle=(particle,delta,factor)=>particle.nativeChunky?required(services,'initializeChunkParticle',particle,delta,factor,p):initializeParticle(particle,delta,factor,p);
  p.randomizeParticle=(e,particle)=>randomizeParticleFrame(e,particle,p);
  p.randomPosition=(particle,x,y)=>randomParticlePosition(particle,x,y,p);
  p.moveParticles=(e,delta)=>moveStandardParticles(e,delta,p);
  return p;
}
