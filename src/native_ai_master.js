import { NativeIdList } from './native_id_list.js';

// CServerAIMaster::SetAILevel140559cb0 entry / 140557430 implementation.
// Only canonical IDs live in the five level arrays; capacity survives moves.
// This does not yet implement CServerAIMaster's time-budget update traversal.
export class NativeAIMaster {
  constructor(){this.levels=Array.from({length:5},()=>{const list=new NativeIdList();list.cursor=0;return list;});this.durations=[0,0,0,0];}
  // RemoveObject1405595b0: removes the first matching ID at the stored
  // level, leaves capacity/cursor and AI lock intact, and sets level to -1.
  removeObject(actor){
    if(!actor||!Number.isInteger(actor.nativeAILevel7c)||!Number.isInteger(actor.id))
      throw new Error('Native AI removal metadata is unavailable');
    const level=actor.nativeAILevel7c>>>0;if(level>4)return 0;
    const list=this.levels[level],id=actor.id>>>0;
    // The >16-element sentinel search selects the LAST entry immediately
    // when it equals the ID; otherwise it finds the first earlier match.
    const index=list.count>16&&list.ids[list.count-1]===id?list.count-1:list.indexOf(id);
    if(index>=0){list.count--;list.ids.copyWithin(index,index+1,list.count+1);}
    actor.nativeAILevel7c=-1;return 1;
  }
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
  nextObject(level,p){
    const list=this.levels[level];if(list.count===0)return null;
    list.cursor=(list.cursor+1)|0;if(list.cursor>=list.count)list.cursor=0;
    if(list.cursor<0)throw new Error('Native AI list cursor is invalid');
    const object=p.object(list.ids[list.cursor]);
    return object&&object.objectType>4?object:null;
  }
  // UpdateState140559cf0..14055acb2. Full non-instrumentation traversal:
  // due events precede EACH object, and their elapsed time is excluded from
  // the 10ms AI budget. Higher levels each receive60% of remaining budget.
  // Time budget is an explicit native microsecond adapter, never a frame count.
  async updateState(p){
    for(const name of ['worldTime','microseconds','peekEvent','eventDue','takeEvent','dispatchEvent','deferEvent','random','disposeEvent','object','updateObject','updateDialog','resetWork','overflow','moduleUpdate','playerDialogs'])
      if(typeof p[name]!=='function')throw new Error(`Native AI master provider ${name} is unavailable`);
    const u64=value=>BigInt.asUintN(64,value),tick=()=>{const value=p.microseconds();if(typeof value!=='bigint')throw new Error('Native AI microsecond timer is unavailable');return u64(value);};
    const average=Math.max(1,(this.durations.reduce((sum,value)=>(sum+(value>>>0))>>>0,0)>>>2));
    const now=await p.worldTime(),tickStart=tick();let remaining=10000n;
    for(let level=4;level>=0;level--){
      const budget=level>0?u64(remaining*60n)/100n:remaining;
      let start=tick(),first=true,firstObject=null,done=false,end;
      do{
        const eventStart=tick();
        while(p.peekEvent()&&p.eventDue(p.peekEvent(),now)){
          const event=p.takeEvent(),object=p.object(event.targetId>>>0);
          if(object){
            if(object.objectType>4&&event.event?.type==='combatAI'&&event.event.eventId===15&&
               Number(u64(tick()-start)&0xffffffffn)>=(average>>>4)){
              const divisor=Math.imul(average,3)>>>0;
              if(divisor===0)throw new Error('Native AI deferred-event random divides by zero');
              const random=p.random();if(!Number.isInteger(random))throw new Error('Native AI deferred-event random is unavailable');
              const milliseconds=Math.max(1,Math.floor((((random>>>0)%divisor+average)>>>0)/1000));
              await p.deferEvent(event,milliseconds);
            }else await p.dispatchEvent(event);
          }else await p.disposeEvent(event);
        }
        let current=tick();start=u64(start+u64(current-eventStart));
        if(u64(current-start)<=budget){
          const object=this.nextObject(level,p);
          if(first)firstObject=object;
          const objectStart=tick();await p.resetWork();
          if(!object||object===firstObject&&!first)done=true;
          else{await p.updateObject(object);await p.updateDialog(object);}
          first=false;
          const elapsed=Number(u64(tick()-objectStart)&0xffffffffn);
          if(elapsed>=75000&&object)await p.overflow(object,163,elapsed,75000,0);
          current=tick();
        }
        end=current;
      }while(!(p.peekEvent()&&p.eventDue(p.peekEvent(),now))&&!done&&u64(end-start)<=budget);
      const elapsed=u64(end-start);remaining=u64(remaining-(elapsed<budget?elapsed:budget));
    }
    this.durations.shift();this.durations.push(Number(u64(tick()-tickStart)&0xffffffffn));
    await p.moduleUpdate();await p.playerDialogs();
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
