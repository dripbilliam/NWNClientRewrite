import { creatureRoot, creatureAlignment } from './creature_rules.js';
import { OBJECT_INVALID } from './game_object_array.js';

const f=Math.fround;
const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native invisibility ${name} is unavailable`);return v|0;};
const requireCallback=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native invisibility provider ${name} is unavailable`);return p[name];};
const at=(e,i)=>integer(e.integers?.[i]??0,'effect integer');
// GetInvisible 140390cd0..14039107d. Observer-specific vision differs from
// the mere presence of an invisibility effect. Type63 retains its native
// hostile reaction, cached visibility, save, pacification and node updates.
export async function invisibleVersus(actor,observer,feedback,p){
  const viewer=await requireCallback(p,'creature')(observer);if(!viewer)return 0;
  const subject=creatureAlignment(creatureRoot(viewer));
  const effects=await requireCallback(p,'effects')(actor);
  if(!Array.isArray(effects))throw new Error('Native invisibility effect list is unavailable');
  const index=integer(await requireCallback(p,'index')(actor),'effect index')&65535;
  for(let i=index;i<effects.length;i++){
    const effect=effects[i],type=integer(effect?.type,'effect type')&65535;
    if(type>63)return 0;
    if(type!==47&&type!==63)continue;
    if(at(effect,1)!==(subject.race&65535)&&at(effect,1)!==28||
        at(effect,2)!==subject.lawChaos&&at(effect,2)!==0||at(effect,3)!==subject.goodEvil&&at(effect,3)!==0)continue;
    const flags=integer(viewer.visionFlags,'observer vision flags')&255;
    if(type===47){
      if(flags&0x20){
        if(![actor,observer].every(o=>o.position?.length===3&&o.position.every(Number.isFinite)))throw new Error('Native blindsight positions are unavailable');
        if(!Number.isFinite(viewer.blindSightRange))throw new Error('Native blindsight range is unavailable');
        const dx=f(f(observer.position[0])-f(actor.position[0])),dy=f(f(observer.position[2])-f(actor.position[2]));
        // Eye-height 1.0 is added to BOTH heights before subtraction.
        const dz=f(f(f(observer.position[1])+1)-f(f(actor.position[1])+1));
        const distance=f(f(f(dy*dy)+f(dx*dx))+f(dz*dz));
        if(distance<=f(f(viewer.blindSightRange)*f(viewer.blindSightRange)))continue;
      }
      const subtype=at(effect,0);
      if(subtype===1||subtype===4){if((flags&5)===0)return 1;}
      else if(subtype===2){if((flags&6)===0)return 1;}
      else return 1;
    }else if((integer(await requireCallback(p,'reaction')(viewer,actor.id),'observer reaction')&255)===2){
      const node=await requireCallback(p,'visibility')(viewer,actor.id);
      if(node!==null){
        const state=integer(node,'visibility flags')&12;
        if(state===4&&(flags&4)===0||state===8)return 1;
        if(state!==0)continue;
      }
      if(at(effect,5)!==0){
        const result=integer(await requireCallback(p,'savingThrow')(viewer,3,at(effect,4)&65535,0,OBJECT_INVALID,feedback,0,0),'sanctuary save')&255;
        if(result!==0){await requireCallback(p,'addVisibility')(viewer,actor.id,0,0,2,0);return 1;}
      }
      await requireCallback(p,'pacify')(actor,viewer.id);
      await requireCallback(p,'addVisibility')(viewer,actor.id,0,0,1,0);
    }
  }
  return 0;
}
