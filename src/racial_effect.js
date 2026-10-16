import {intEntry} from './combat_stats.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native racial effect ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native racial effect provider ${n} is unavailable`);return p[n](...args);};

// CNWRace::LoadFeatsTable1402a1b1a..1402a1c00. Physical row count is a
// WORD, every slot starts0, successful INT reads narrow to WORD. Keep holes,
// zero feats, duplicate entries and original order; no playable-race switch.
export function loadRacialFeatList(table){
 if(!table)return new Uint16Array(0);
 const rows=table.orderedRows??[...table.rows.values()],list=new Uint16Array(rows.length&65535);
 for(let i=0;i<list.length;i++){const cell=intEntry(table,i,'FeatIndex');if(cell.found)list[i]=cell.value&65535;}
 return list;
}
// IsFirstLevelGrantedFeat1402a19a0; the native race owns one WORD array.
export function isFirstLevelRacialFeat(list,id){
 if(list===null)return 0;
 if(!(list instanceof Uint16Array))throw new Error('Native racial feat WORD storage is unavailable');
 return Number(list.includes(integer(id,'feat')&65535));
}
// OnApplyRacialType140430be0. Race stats are changed by the transform, not
// here. This owner adds innate visual filters with its parent's uint64 ID.
export async function applyRacialType(object,effect,p,loading=0){
 const actor=call(p,'asCreature',object);if(!actor)return 1;
 const list=await call(p,'raceFeats',integer(effect.integers[0],'race')&65535);
 for(const [feat,filter]of [[228,2],[354,1]])if(isFirstLevelRacialFeat(list,feat)){
  const child=call(p,'copyConstruct',effect,0);child.type=69;child.durationType=4;
  call(p,'setCreator',child,actor.id);child.integers[0]=filter;
  await call(p,'apply',actor,child,loading);
 }
 return 0;
}
// OnRemoveRacialType140437f00 returns1; shared group removal owns children.
export function removeRacialType(){return 1;}
