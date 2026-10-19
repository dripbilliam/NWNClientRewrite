import {updateLinked} from './linked_effect.js';
const call=(p,n,...a)=>{if(typeof p[n]!=='function')throw new Error(`Native on-hit duration provider ${n} is unavailable`);return p[n](...a);};
// Original ApplyOnHit* engine owners, not authored spell IDs or impact scripts.
// Each entry describes its native core and successive right-hand linked nodes.
const plans={
 Slow:{impact:95,core:[3,[]],right:[[30,[207]]]},
 Sleep:{impact:94,core:[8,[9,1]],right:[[30,[7]],[30,[207]]]},
 Stun:{core:[8,[6]],right:[[30,[208]],[30,[207]]]},
 Hold:{core:[8,[8]],right:[[30,[232]],[30,[82]],[30,[207]]]},
 Confusion:{core:[8,[2]],right:[[30,[208]],[30,[207]]]},
 Daze:{core:[8,[5]],right:[[30,[209]],[30,[207]]]},
 Doom:{impact:57,core:[11,[2,0,28]],right:[[14,[2,0,28]],[56,[255,2,28]],[27,[0,2,28]],[30,[207]]]},
 Fear:{core:[8,[3]],right:[[30,[218]],[30,[207]]],update:false},
 Silence:{impact:93,core:[46,[]],right:[[30,[207]]]},
 Deafness:{impact:46,core:[21,[]],right:[[30,[207]]]},
 Blindness:{impact:46,core:[73,[16]],right:[[30,[207]]]},
};
export const onHitDurationNames=Object.freeze(Object.keys(plans));
export function applyOnHitDuration(name,actor,target,rounds,p){
 const plan=plans[name];if(!plan)throw new Error(`Native on-hit duration owner ${name} is unavailable`);
 const configure=(e,[type,values])=>{e.type=type;for(let i=0;i<values.length;i++)e.integers[i]=values[i]|0;call(p,'setCreator',e,actor.id);return e;};
 if(plan.impact!==undefined){const impact=call(p,'create');if(!impact)return;configure(impact,[30,[plan.impact]]);impact.durationType=0;call(p,'append',actor,impact);}
 let current=call(p,'create');if(!current)return;configure(current,plan.core);
 for(let index=0;index<plan.right.length;index++){
  const right=call(p,'copy',current,0);if(!right){call(p,'dispose',current);return;}configure(right,plan.right[index]);
  const link=call(p,'copy',right,0);if(!link){call(p,'dispose',current);call(p,'dispose',right);return;}
  link.type=40;link.linkLeft=current;link.linkRight=right;call(p,'setCreator',link,actor.id);
  if(index===plan.right.length-1){link.duration=Math.fround(Math.fround(rounds|0)*Math.fround(6));link.subtype=(link.subtype&0xffc8)|8;link.durationType=1;}
  if(plan.update!==false)updateLinked(link,0,p);current=link;
 }
 call(p,'append',actor,current);
}
