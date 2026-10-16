const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native turn resistance ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native turn resistance provider ${n} is unavailable`);return p[n](...args);};

// OnApplyTurnResistance140434b20 shared by types77/88. Constants are not
// sequential: DAT140de7aec is88, not78 (which is bonus spell of level).
export function applyTurnResistance(object,effect,loading,p){
 if(loading!==0){if(!object)return 1;if(call(p,'dead',object)!==0&&![3,4].includes(effect.durationType&7))return 1;}
 if(!object||!call(p,'asCreature',object))return 1;
 if(call(p,'rule','TURN_RESISTANCE_AFFECTS_PCS',0)===0&&integer(call(p,'asCreature',object).nativeStatsIsPCb0,'stats PC')!==0)return 1;
 return 0;
}
// GetTurnResistanceHD140396290. Both signs use unrestricted raw INT amounts;
// no positive-only filtering or clamp. Native DWORD accumulation wraps.
export function turnResistanceHD(object){
 let result=0;for(let n=0;n<object.effects.length;n++){
  const effect=object.effects[n],type=effect.type&65535;
  if(type===77)result=(result+integer(effect.integers[0],'increase'))|0;
  if(type===88)result=(result-integer(effect.integers[0],'decrease'))|0;
 }
 return result;
}
// ExecuteCommandEffectTurnResistance14051c650, ordinals552/553. VM already
// popped/typed the required INT before allocation. Creator precedes type write.
export function constructTurnResistance(ordinal,args,self,p){
 const value=integer(args[0],'constructor magnitude'),effect=call(p,'create',0,0x7f000000,[],0);
 call(p,'setCreator',effect,self);effect.subtype=(effect.subtype&0xffcf)|8;effect.integers[0]=value;effect.type=ordinal===552?88:77;return effect;
}
