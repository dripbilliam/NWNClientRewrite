const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native ability effect ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native ability effect provider ${n} is unavailable`);return p[n](...args);};
const i8=n=>(n<<24)>>24;
export function abilityEffect(type,ability,amount,creator,p){
  ability=integer(ability,'selector');if(ability<0||ability>5)ability=0;
  return call(p,'create',type,creator,[ability,integer(amount,'magnitude')],8);
}
// GetTotalEffectBonus393340 category4. Two native fifty-slot pools use
// magnitude-1 as FREE, distinct item/spell key arrays, and raw INT sums/caps.
export function abilityEffectBonus(effects,ability,p){
  ability=integer(ability,'selector')&255;
  const pools=[0,1].map(()=>Array.from({length:50},()=>({amount:-1,spell:-1,item:0x7f000000})));
  const first=effects.findIndex(e=>e.type>=36);
  if(first>=0)for(let index=first;index<effects.length;index++){
    const e=effects[index];if(e.type<36||e.type>37)break;if(integer(e.integers?.[0],'stored selector')!==ability)continue;
    // Offline equipment projections carry a calculation-only source key;
    // live CGameEffects resolve their canonical creator through the registry.
    const pool=pools[e.type===36?0:1],item=Object.hasOwn(e,'sourceItemId')?{id:e.sourceItemId}:call(p,'item',integer(e.creatorId,'creator')>>>0),spell=integer(e.spellId,'spell'),amount=integer(e.integers?.[1],'stored magnitude');
    const matching=item?pool.filter(slot=>slot.item===item.id):spell===-1?[]:pool.filter(slot=>slot.spell===spell);
    if(matching.length){for(const slot of matching)if(slot.amount<amount)slot.amount=amount;}
    else{const slot=pool.find(slot=>slot.amount===-1);if(slot){if(item)slot.item=item.id;else slot.spell=spell;slot.amount=amount;}}
  }
  const sum=pool=>pool.reduce((total,s)=>s.amount===-1?total:(total+s.amount)|0,0);
  const increase=Math.min(sum(pools[0]),integer(call(p,'bonusLimit'),'bonus limit')),decrease=Math.min(sum(pools[1]),integer(call(p,'penaltyLimit'),'penalty limit'));
  return{increase,decrease,total:(increase-decrease)|0};
}
// Six CNWSCreatureStats current stat getters narrow effect/gain/race to
// signed BYTE, test minimum3 in INT, then wrap the result to unsigned BYTE.
export function nativeAbilityScore(base,race,gain,effect,{dex=false,state=65535,mode=0}={}){
  if(dex&&(state&6)!==6&&(state&65535)!==0&&(mode&255)!==11)return 3;
  const total=(integer(base,'base')&255)+i8(integer(race,'race'))+i8(integer(gain,'class gain'))+i8(integer(effect,'bonus'));
  return total<3?3:total&255;
}
// OnApplyAbilityIncrease427140/decrease426db0, before insertion. A
// decrease mutates its amount to current score-3 before plot/positive gates.
export async function applyAbilityEffect(actor,effect,p,loading=0){
  if(actor.objectType!==5)return 1;
  if(loading!==0&&(call(p,'dead',actor)!==0||call(p,'dying',actor)!==0)&&![3,4].includes(effect.durationType&7))return 1;
  const down=effect.type===37,ability=integer(effect.integers?.[0],'selector');let amount=integer(effect.integers?.[1],'magnitude');
  if(down){const source=call(p,'creature',integer(effect.creatorId,'creator')>>>0);
    if(integer(effect.bypassImmunity,'immunity override')===0&&await call(p,'immunity',actor,19,source,1)!==0)return 1;
    if((ability>>>0)<=5){let score=integer(call(p,'score',actor,ability),'current score')&255;
      if(amount>score-3){effect.integers[1]=(integer(call(p,'score',actor,ability),'current score')&255)-3;amount=(integer(call(p,'score',actor,ability),'current score')&255)-3;}
    }
    if(amount<1||integer(call(p,'plot',actor),'plot')!==0)return 1;
  }else if(amount<1)return 1;
  const icon=call(p,'copy',effect,1);icon.type=67;
  if((ability>>>0)<=5)icon.integers[0]=[27,59,61,63,65,67][ability]+Number(down);
  await call(p,'apply',actor,icon,loading);return 0;
}

// UpdateAttributesOnEffect1403a7030 runs AFTER insert/erase. CON compares
// old cached-modifier maximum with the newly computed maximum and preserves
// the signed-short injury, then delivers native dying/death transitions.
export async function updateAbilityAttributes(actor,effect,p,loading=0){
  if(!effect||![36,37].includes(effect.type))return;
  const ability=integer(effect.integers?.[0],'selector');if(ability<0||ability>5)return;
  const cells=['nativeStrModifierD39','nativeDexModifierD3b','nativeConModifierD3d','nativeIntModifierD3f','nativeWisModifierD41','nativeChaModifierD43'];
  if(ability===2){
    const wasDying=call(p,'dying',actor),wasDead=call(p,'dead',actor),oldMaximum=integer(call(p,'maximumHP',actor),'old maximum')&65535;
    actor[cells[2]]=integer(call(p,'modifier',integer(call(p,'score',actor,2),'score')&255),'modifier')&255;
    if(wasDead===0||loading!==0){
      const current=(integer(call(p,'currentBaseHP',actor),'base HP')<<16)>>16,old=(oldMaximum<<16)>>16;
      const delta=(current-old)|0,newMaximum=(integer(call(p,'maximumHP',actor),'new maximum')<<16)>>16;
      call(p,'writeBaseHP',actor,(newMaximum+delta)|0);
    }
    if(wasDying===0&&call(p,'dying',actor)===1&&call(p,'dead',actor)===0){
      if(![3,4].includes(actor.nativeBodyState&255)){actor.nativeBodyState=4;await call(p,'setAnimation',actor,6);}
      actor.nativeFieldEc=0;await call(p,'enqueueDying',actor);await call(p,'closePanels',actor,0);return;
    }
    if(wasDead===0&&call(p,'dead',actor)===1){
      const death=call(p,'create',19,effect.creatorId,[],0);death.integers[1]=1;await call(p,'apply',actor,death,0);
    }
    return;
  }
  actor[cells[ability]]=integer(call(p,'modifier',integer(call(p,'score',actor,ability),'score')&255),'modifier')&255;
  if(ability===0){await call(p,'encumbrance',actor,1);actor.combatInformationDirty=1;}
  else if(ability===1)actor.combatInformationDirty=1;
  else actor.nativeField544=1;
}
