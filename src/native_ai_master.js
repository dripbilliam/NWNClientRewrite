import { NativeIdList } from './native_id_list.js';

// CServerAIMaster::SetAILevel140559cb0 entry / 140557430 implementation.
// Only canonical IDs live in the five level arrays; capacity survives moves.
// This does not yet implement CServerAIMaster's time-budget update traversal.
export class NativeAIMaster {
  constructor(){this.levels=Array.from({length:5},()=>new NativeIdList());}
  setLevel(actor,level){
    if(!actor||!Number.isInteger(level)||!Number.isInteger(actor.nativeAILevel7c)||!Number.isInteger(actor.nativeAILocked80))
      throw new Error('Native AI level metadata is unavailable');
    level|=0;
    if(actor.nativeAILocked80!==0)return 0;
    if(actor.nativeAILevel7c===level)return 1;
    if((level>>>0)>4)return 0;
    const old=actor.nativeAILevel7c>>>0;
    if(old<=4){this.levels[old].remove(actor.id>>>0);actor.nativeAILevel7c=-1;}
    const list=this.levels[level];if(list.indexOf(actor.id>>>0)<0)list.append(actor.id>>>0);
    actor.nativeAILevel7c=level;return 1;
  }
}

// ExecuteCommandSetAILevel14053d7b0. Script level4 clamps to3; internal
// PCs/DMs may use4. -1 unlocks and restores native automatic selection.
export function scriptSetAILevel(actor,level,p){
  if(!actor)return;
  if(!Number.isInteger(level))throw new Error('Native script AI level is unavailable');
  level|=0;
  if(!p.master){if(level===-1)actor.nativeAILocked80=0;return;}
  if(Number(actor.isPC)!==0||p.possessed(actor)!==0)return;
  level=level< -1?0:Math.min(level,3);
  if(level===-1){
    actor.nativeAILocked80=0;
    if((actor.masterId>>>0)===0x7f000000){
      const area=actor.nativeField700!==1?p.area(actor):null;
      p.master.setLevel(actor,area?Number(area.nativePlayerCount150>0):2);
    }else{
      const owner=p.creature(actor.masterId>>>0);
      if(owner?.stats&&Number(owner.isPC)===1)p.master.setLevel(actor,3);
    }
    return;
  }
  actor.nativeAILocked80=0;p.master.setLevel(actor,level);actor.nativeAILocked80=1;
}
