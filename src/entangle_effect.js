const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native entangle ${n} is unavailable`);return v|0;};
const call=(p,n,...a)=>{if(typeof p?.[n]!=='function')throw new Error(`Native entangle provider ${n} is unavailable`);return p[n](...a);};
// OnApplyCutsceneImmobile1404286b0..140428734 has no admission gates.
// Native type94 has no removal handler; its shared-ID state child owns reset.
export async function applyCutsceneImmobile(object,effect,p,loading=0){
  const state=call(p,'copyConstruct',effect,0);state.type=23;state.integers[0]=-3;
  await call(p,'apply',object,state,loading);return 0;
}
// OnApplyEntangled14042d5d0. Allocate all three clearing copies BEFORE
// the first child application; callbacks cannot change their copied metadata.
export async function applyEntangle(object,effect,p,loading=0){
  if(loading!==0&&object&&call(p,'dead',object)!==0&&![3,4].includes(effect.durationType&7))return 1;
  if(call(p,'asCreature',object)){
    const actor=call(p,'asCreature',object),source=call(p,'creature',integer(effect.creatorId,'creator')>>>0);
    if(integer(effect.bypassImmunity,'immunity override')===0&&await call(p,'immunity',actor,10,source,1)!==0){
      const data={objectIds:[object.id>>>0]};if(source)await call(p,'feedback',source,144,structuredClone(data));await call(p,'feedback',call(p,'asCreature',object),144,data);return 1;
    }
    if(integer(call(p,'plot',actor),'plot')!==0)return 1;
    await call(p,'clearActions',actor);
    const attack=call(p,'copyConstruct',effect,0),dex=call(p,'copyConstruct',effect,0),state=call(p,'copyConstruct',effect,0);
    attack.type=11;attack.integers.splice(0,3,2,0,28);await call(p,'apply',actor,attack,loading);
    dex.type=37;dex.integers[0]=1;dex.integers[1]=4;await call(p,'apply',actor,dex,loading);
    state.type=23;state.integers[0]=-3;await call(p,'apply',actor,state,loading);
    const icon=call(p,'copyConstruct',effect,1);icon.type=67;icon.integers[0]=5;await call(p,'apply',object,icon,loading);
  }
  if(integer(typeof effect.exposed==='boolean'?Number(effect.exposed):effect.exposed,'exposure')!==0)await call(p,'floaty',object,2237);return 0;
}
// OnRemoveEntangled140436c20. NPC observers refresh only when the object PC
// field89c is0 and the existing possession provider reports no familiar client.
export async function removeEntangle(object,_effect,p){
  if(object&&call(p,'asCreature',object)){
    const actor=call(p,'asCreature',object);
    if(integer(actor.nativeField89c,'object PC flag')===0&&call(p,'possessed',actor)===0){await call(p,'clearVisible',actor);await call(p,'updateVisible',actor);}
  }return 1;
}
