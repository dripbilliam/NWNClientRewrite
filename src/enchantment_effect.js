import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native enchantment ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native enchantment provider ${n} is unavailable`);return p[n](...args);};
const kind=e=>integer(e.integers?.[0],'kind');
async function feedback(actor,source,code,p){const data={objectIds:[actor.id>>>0]};if(source)await call(p,'feedback',source,code,structuredClone(data));await call(p,'feedback',actor,code,data);return 1;}
async function clearControllers(actor,p){
  for(;;){const e=call(p,'effects',actor).find(e=>e.type===9);if(!e)break;await call(p,'remove',actor,e);}
}
async function controller(actor,source,creator,spell,showIcon,p,loading,removing=false){
  const e=call(p,'create',9,creator,[],0);e.durationType=removing?2:4;e.exposed=false;e.integers[0]=source;
  if(spell!==undefined)e.spellId=spell;if(showIcon!==undefined)e.showIcon=showIcon;
  await call(p,'apply',actor,e,loading);
}
// OnApplySetState140431730. Parent type8 and internal type9 have distinct
// IDs. Numeric priority is native; duration/ID grouping is not a guessed enum.
export async function applyEnchantment(actor,effect,p,loading=0){
  if(actor.objectType!==5||call(p,'plot',actor)!==0)return 1;
  if(loading!==0&&call(p,'dead',actor)!==0&&![3,4].includes(effect.durationType&7))return 1;
  const value=kind(effect),associate=integer(actor.associateType,'associate type')&65535;
  if(integer(actor.nativeFlag8b8,'state immunity')!==0&&value!==20&&value!==21)return 1;
  const source=call(p,'creature',integer(effect.creatorId,'creator')>>>0),bypass=integer(effect.bypassImmunity,'immunity override')!==0;
  let skip=false;
  if(value===7&&integer(effect.spellId,'spell')===28){if(associate!==0)return feedback(actor,source,143,p);skip=true;}
  if(!skip){
    const gates={9:[13,135],8:[6,130],6:[12,138],1:[14,142],7:[15,143],2:[16,137],5:[18,136],3:[4,128]};
    let gate=gates[value];
    if(value===7){
      if(associate===5||associate===6){if(loading===0)return 1;}
      else if(loading===0&&associate!==0){
        const master=call(p,'creature',integer(actor.masterId,'master')>>>0);
        if(master&&call(p,'statsPC',master)!==0)return feedback(actor,source,143,p);
        gate=null; // Native falls straight to the general mind gate.
      }
    }
    if(gate&&!bypass&&await call(p,'immunity',actor,gate[0],source,1)===1)return feedback(actor,source,gate[1],p);
    if(value===1&&associate!==0){const master=call(p,'creature',integer(actor.masterId,'master')>>>0);if(master&&call(p,'statsPC',master)!==0)return feedback(actor,source,142,p);}
    if(!bypass&&![4,15,20,21].includes(value)&&await call(p,'immunity',actor,1,source,1)!==0){
      if((effect.subtype&56)!==16||integer(effect.integers?.[1],'extraordinary exemption')!==1)return feedback(actor,source,132,p);
    }
  }
  if(value!==5){const child=call(p,'copy',effect,0);child.type=23;child.integers[0]=-257;await call(p,'apply',actor,child,loading);}
  if(value>(integer(actor.nativeField771,'state')&255)){
    actor.nativeField771=value&255;await clearControllers(actor,p);
    await controller(actor,value,effect.creatorId,effect.spellId,effect.showIcon,p,loading);
  }
  return 0;
}
export async function removeEnchantment(actor,effect,p){
  if(actor.objectType!==5)return 1;actor.nativeFieldEc=1;actor.nativeField771=0;
  let highest=0,creator=OBJECT_INVALID;
  for(const e of call(p,'effects',actor)){if(e.type>8)break;if(e.type===8&&e!==effect&&kind(e)>highest){highest=kind(e);creator=e.creatorId;}}
  await clearControllers(actor,p);
  if(highest!==0){actor.nativeField771=highest&255;actor.nativeFieldEc=0;await controller(actor,highest,creator,undefined,undefined,p,0,true);}
  return 1;
}
async function child(actor,parent,type,values,icons,p,loading){const e=call(p,'copy',parent,icons);e.type=type;for(const [i,v] of values)e.integers[i]=v|0;await call(p,'apply',actor,e,loading);}
async function clearActions(actor,p,disable=true){actor.nativeFieldEc=1;await call(p,'clearActions',actor);if(disable)actor.nativeFieldEc=0;}
// OnApplySetStateInternal140432500. Association/reputation changes stay
// explicit lower owners, rather than treating Charm/Domination as inert icons.
export async function applyEnchantmentController(actor,effect,p,loading=0){
  if(actor.objectType!==5)return 0;actor.nativeField54c=0;actor.nativeField550=1;
  const value=kind(effect),copy=(type,values,icons=0)=>child(actor,effect,type,values,icons,p,loading),floaty=id=>call(p,'floaty',actor,id);
  let icon;
  if(value===1){await floaty(2230);await call(p,'clearActions',actor);
    const source=call(p,'creature',effect.creatorId);if(source){await call(p,'clearPersonal',source,actor.id);await call(p,'addPersonal',source,actor.id,100,0,0);}
    await call(p,'setLastHostile',actor,OBJECT_INVALID,1);icon=12;
  }else if(value===2){await clearActions(actor,p);icon=13;
  }else if(value===3||value===4){await copy(27,[[0,2],[1,0],[3,28]]);await floaty(2238);icon=value===3?14:24;
  }else if(value===5){await floaty(2235);await clearActions(actor,p,false);await copy(59,[[0,0]],1);await call(p,'ambient',actor);icon=17;
  }else if(value===6){await floaty(2244);await clearActions(actor,p);await copy(23,[[0,-3]]);await copy(30,[[0,208]]);await call(p,'ambient',actor);icon=18;
  }else if(value===7||value===21){await floaty(2236);await clearActions(actor,p);
    const source=call(p,'creature',effect.creatorId);if(source&&call(p,'statsPC',source)!==0)await call(p,'dominate',actor,source,loading);
    await call(p,'setLastHostile',actor,OBJECT_INVALID,1);icon=15;
  }else if(value===8){await copy(23,[[0,-15]]);await clearActions(actor,p);await floaty(2240);icon=16;
  }else if(value===9){await copy(23,[[0,-351]]);await clearActions(actor,p);await call(p,'ambient',actor);await floaty(2242);icon=19;
  }else if(value===15){await copy(23,[[0,-15]]);await copy(30,[[0,351]]);await copy(30,[[0,352]]);await copy(67,[[0,109]],1);await clearActions(actor,p);return 0;
  }else if(value===20){await copy(23,[[0,-15]]);await clearActions(actor,p);return 0;}
  if(icon!==undefined)await copy(67,[[0,icon]],1);return 0;
}
export async function removeEnchantmentController(actor,effect,p){
  if(actor.objectType!==5||!effect)return 1;const value=kind(effect);
  if([2,5,6,8,9,15,20].includes(value))await call(p,'ambient',actor);
  else if(value===1){const source=call(p,'creature',effect.creatorId);if(source)await call(p,'clearPersonal',source,actor.id);}
  else if(value===7||value===21)await call(p,'removeDomination',actor);
  if([1,7,21].includes(value))await call(p,'refreshObservers',actor);
  if(integer(actor.nativeField89c,'PC flag')===0&&call(p,'possessed',actor)===0){call(p,'clearVisible',actor);await call(p,'updateVisible',actor);}
  return 1;
}
