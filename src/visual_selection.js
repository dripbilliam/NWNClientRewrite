const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native visual selection provider ${name} is unavailable`);return p[name](...args);};
// Complete client visual selection140761d90..140761ff7. scope10c is a
// priority BYTE within a program-type group; lower values win and equal
// values choose the last physical entry. Never deduplicate by visual ID.
export function selectVisualEffects(actor,type,p){
  if(actor.suppressed108)return;
  type&=255;let selected=null,priority=255;
  for(const e of actor.visuals80){
    if(e.finishedF4||call(p,'programType',e)!==type)continue;
    const visual=e.visualF8&65535;
    if((visual===182||((visual-242)&65535)<=2)&&actor.id!==call(p,'selectedObjectId1406ac1c0'))continue;
    const scope=e.scope10c&255;
    if(scope===0){
      if(e.field110&&!call(p,'viewGate1407dadb0')){if(e.attached114)call(p,'detach',e);continue;}
      if(!e.attached114)call(p,'attach',e);
    }else if(scope<=priority){selected=e;priority=scope;}
  }
  for(const e of actor.visuals80){
    if(e.finishedF4||call(p,'programType',e)!==type||(e.scope10c&255)===0)continue;
    if(e===selected){
      if(call(p,'programType',e)===4){
        if(e.field110&&!call(p,'viewGate1407dadb0')){if(e.attached114&&!e.closedEc)call(p,'stop',e,0);continue;}
        if(e.closedEc)call(p,'start',e);
      }
      if(!e.attached114)call(p,'attach',e);
    }else if(e.attached114)call(p,'detach',e);
  }
}
// Native accessors14096c5d0 and14096c610. Retirement requires all physical
// geometry flags, the finish flag AND no active procedural phase.
export const visualIsRetired=e=>e.retiredDc.every(v=>v!==0)&&e.finishedF4!==0&&(e.programPhaseFa&255)===0;
export const visualHasCessation=e=>e.models88.some((model,i)=>model&&(e.modelStates68[i]&65535)===3);

// Complete competing-effect detach140762c10..140762ccf. This searches from
// the physical tail, and returns at the first eligible candidate even when
// that candidate is already detached. The caller then stops/removes current.
export function detachCompetingVisual(actor,current,p){
  for(let i=actor.visuals80.length-1;i>=0;i--){
    const candidate=actor.visuals80[i];
    if(call(p,'programType',current)===7)continue;
    const kind=call(p,'programType',candidate);
    if(call(p,'programType',current)!==kind||candidate===current||(candidate.scope10c&255)===0||candidate.finishedF4)continue;
    if(candidate.attached114)call(p,'detach',candidate);
    return;
  }
}
