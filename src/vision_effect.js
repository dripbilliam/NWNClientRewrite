import {rulesetInt} from './combat_stats.js';
const call=(p,n,...a)=>{if(typeof p[n]!=='function')throw new Error(`Native vision provider ${n} is unavailable`);return p[n](...a);};
const value=e=>{if(!Number.isInteger(e.integers?.[0]))throw new Error('Native vision effect integer is unavailable');return e.integers[0]|0;};
const flags=o=>{if(!Number.isInteger(o.visionFlags))throw new Error('Native vision byte is unavailable');return o.visionFlags&255;};
async function child(o,e,type,n,icons,p,loading){const c=call(p,'copyConstruct',e,icons);c.type=type;c.integers[0]=n;await call(p,'apply',o,c,loading);}
// OnApplyBlindnessInactive140427f40 has no creature gate.
export async function applyInactiveBlindness(o,e,p,loading=0){await child(o,e,67,10,1,p,loading);return 0;}
// OnApplyBlindness427bb0. Mode8 darkness and mode16 blindness differ in
// immunity, vision admission and the miss-chance child's target restriction.
export async function applyBlindness(o,e,rules,p,loading=0){
 if(o.objectType!==5)return 0;const mode=value(e);if(mode!==8&&mode!==16)return 1;
 const source=call(p,'creature',e.creatorId);
 if(mode===16&&e.bypassImmunity===0&&await call(p,'immunity',o,7,source,1)!==0){const data={type:0,objects:[o.id]};if(source)await call(p,'feedback',source,139,structuredClone(data));await call(p,'feedback',o,139,data);return 1;}
 if(call(p,'plot',o)!==0)return 1;
 if(mode===16||(flags(o)&6)===0){
  const miss=call(p,'copyConstruct',e,0);miss.type=75;miss.integers[0]=rulesetInt(rules,'BLIND_MISS_CHANCE',50);miss.integers[1]=mode===8?1:0;await call(p,'apply',o,miss,loading);
  await child(o,e,69,4,0,p,loading);await child(o,e,30,5,0,p,loading);o.visionFlags=flags(o)|mode;
 }else e.type=89;
 await child(o,e,67,10,1,p,loading);return 0;
}
export function removeBlindness(o,e,p){
 if(o.objectType!==5)return 1;let next=flags(o)&~value(e);
 for(const row of call(p,'effects',o)){if(row.type>73)break;if(row.type===73&&row!==e)next|=value(row);}
 o.visionFlags=next&255;return 1;
}
// OnApplyDarkness42a590 always applies its invisibility child first. The
// source has no plot/dead gate; the blindness child's own admission still runs.
export async function applyDarkness(o,e,p,loading=0){
 if(o.objectType!==5||call(p,'dm',o)!==0)return 0;
 const invisible=call(p,'copyConstruct',e,0);invisible.type=47;invisible.integers[0]=2;invisible.integers[1]=28;await call(p,'apply',o,invisible,loading);
 if((flags(o)&0x26)===0){o.visionFlags=flags(o)|8;await child(o,e,73,8,0,p,loading);await child(o,e,67,47,1,p,loading);}
 else await child(o,e,89,8,0,p,loading);return 0;
}
export function removeDarkness(o,e,p){
 if(o.objectType!==5)return 1;let next=flags(o)&~8;
 for(const row of call(p,'effects',o)){if(row.type>73)break;if(row.type===73&&row!==e&&value(row)===8){next|=8;break;}}
 o.visionFlags=next&255;return 1;
}
// OnApplyVision434e80 is a visual child only. The owning vision effect
// separately controls +770; never derive blindness from a renderer filter.
export async function applyVisionFilter(o,e,p,loading=0){
 if(loading!==0&&call(p,'dead',o)!==0&&![3,4].includes(e.durationType&7))return 1;if(o.objectType!==5)return 1;
 const id=[242,243,182,244,247][value(e)&255];if(id===undefined)throw new Error('Native invalid vision filter deallocation result is unavailable');
 await child(o,e,30,id,0,p,loading);return 0;
}
async function deactivateDarkBlindness(o,p){
 for(;;){const row=call(p,'effects',o).find(e=>e.type===73&&value(e)===8);if(!row)return;
  const inactive=call(p,'assignFresh',row);inactive.type=89;await call(p,'remove',o,row);await call(p,'apply',o,inactive,0);
 }
}
// OnApplySeeInvisible4315e0/UltraVision434be0/TrueSeeing434990.
export async function applyVisionSource(o,e,p,loading=0){
 if(o.objectType!==5)return 0;
 if(e.type===70){o.visionFlags=flags(o)|1;await child(o,e,67,54,1,p,loading);}
 else if(e.type===71){await child(o,e,69,3,0,p,loading);o.visionFlags=flags(o)|2;await deactivateDarkBlindness(o,p);}
 else if(e.type===72){o.visionFlags=flags(o)|4;await child(o,e,67,53,1,p,loading);await deactivateDarkBlindness(o,p);}
 return 0;
}
// Removing the last source reactivates hidden blindness only while the
// canonical creature membership list still contains native darkness AoEs.
export async function removeVisionSource(o,e,p){
 if(o.objectType!==5)return 1;const bit=({70:1,71:2,72:4})[e.type];let next=flags(o)&~bit;
 if(call(p,'effects',o).some(row=>row!==e&&row.type===e.type))next|=bit;o.visionFlags=next&255;
 if(e.type===70||(next&6)!==0)return 1;
 const darkness=call(p,'inDarkness',o);
 for(;;){const row=call(p,'effects',o).find(e=>e.type===89);if(!row)break;
  const reactivate=value(row)!==8||darkness,active=reactivate?call(p,'assignPreservingId',row):null;if(active)active.type=73;
  await call(p,'remove',o,row);if(reactivate)await call(p,'apply',o,active,0);
 }
 return 1;
}
export function applyMissChance(o,e,p,loading=0){
 if(loading!==0&&call(p,'dead',o)!==0&&![3,4].includes(e.durationType&7))return 1;const n=value(e);return n>0&&n<101?0:1;
}
// OnApplyDeaf14042a790. The shared type23 mask owns both hearing admission
// and the verbal spell-failure flag; removing the shared ID recomputes it.
export async function applyDeafness(o,e,p,loading=0){
 if(loading!==0&&call(p,'dead',o)!==0&&![3,4].includes(e.durationType&7))return 1;
 if(o.objectType===5){
  const source=call(p,'creature',e.creatorId);
  if(e.bypassImmunity===0&&await call(p,'immunity',o,8,source,1)!==0){const data={type:0,objects:[o.id]};if(source)await call(p,'feedback',source,140,structuredClone(data));await call(p,'feedback',o,140,data);return 1;}
  if(call(p,'plot',o)!==0)return 1;
  await child(o,e,23,-17,0,p,loading);await child(o,e,67,7,1,p,loading);
 }
 if(e.exposed)await call(p,'floaty',o,2229);return 0;
}
