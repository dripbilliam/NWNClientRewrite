const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native sanctuary ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p[n]!=='function')throw new Error(`Native sanctuary provider ${n} is unavailable`);return p[n](...args);};
const effectId=e=>{if(typeof e.id!=='string'||!/^[0-9a-f]{1,16}$/i.test(e.id))throw new Error('Native sanctuary effect ID is unavailable');return BigInt('0x'+e.id);};

// ExecuteCommandEffectSanctuary14051b1c0..14051b30e. DC<=0 still creates
// an invalid effect; valid DC stores raw INTs (only the apply save narrowsBYTE).
export function sanctuaryEffect(dc,versus,creator,p){
 dc=integer(dc,'DC');versus=integer(versus,'save flag');
 return dc<1?call(p,'invalid'):call(p,'create',63,creator,[8,28,0,0,dc,versus],8);
}

// ExecuteCommandEffectEthereal140519e10 uses this same native type63 with
// DC0/versus0: no saving throw, the ethereal icon and the same visibility owner.
export function etherealEffect(creator,p){return call(p,'create',63,creator,[8,28,0,0,0,0],8);}

// OnApplySanctuary140431120..14043135c. Existing observer nodes only;
// this initial pass ignores reaction/vision and narrows save DC to BYTE.
export async function applySanctuary(actor,effect,p,loading=0){
 if(loading!==0&&actor&&await call(p,'dead',actor)!==0&&(((effect.durationType&7)-3)&65535)>=2)return 1;
 const creature=call(p,'asCreature',actor);if(!creature)return 0;
 const area=call(p,'area',creature);if(!area)return 0;
 const dc=integer(effect.integers[4],'DC'),versus=integer(effect.integers[5],'save flag');
 for(let i=0;i<call(p,'areaIds',area).length;i++){
  const observer=call(p,'creature',call(p,'areaIds',area)[i]);if(!observer||observer.id===creature.id)continue;
  const node=call(p,'visibility',observer,creature.id);if(!node)continue;
  if(versus!==0&&(integer(await call(p,'save',observer,3,dc&255,0,creature.id,1,0,0),'save result')&255)!==0)node.flags=((integer(node.flags,'visibility flags')&~4)|8)&255;
  else{await call(p,'pacify',creature,observer.id);node.flags=((integer(node.flags,'visibility flags')&~8)|4)&255;}
 }
 call(p,'addInvisible',creature.id);
 const icon=call(p,'copyConstruct',effect,1);icon.type=67;icon.integers[0]=versus===0?107:52;await call(p,'apply',actor,icon,loading);return 0;
}

// OnRemoveSanctuary140437ff0..140438245. Clear successful-save bits
// immediately; defer failed-save node removal until all source IDs are checked.
export async function removeSanctuary(actor,effect,p){
 const creature=call(p,'asCreature',actor);if(!creature)return 1;
 const area=call(p,'area',creature);if(!area)return 1;
 const blocked=[];
 for(let i=0;i<call(p,'areaIds',area).length;i++){
  const observer=call(p,'creature',call(p,'areaIds',area)[i]);if(!observer)continue;
  const node=call(p,'visibility',observer,creature.id);if(!node)continue;
  const state=integer(node.flags,'visibility flags')&12;if(state===4)blocked.push(observer.id);else if(state===8)node.flags&=~12;
 }
 let invisible=false,sanctuary=false;const id=effectId(effect);
 for(let i=integer(call(p,'index',creature),'effect index')&65535;i<call(p,'effects',creature).length;i++){
  const candidate=call(p,'effects',creature)[i],type=integer(candidate.type,'effect type')&65535;if(type>63)break;
  if((type===47||type===63)&&effectId(candidate)!==id){invisible=true;if(type===63)sanctuary=true;}
 }
 if(!invisible)call(p,'removeInvisible',creature.id);
 if(!sanctuary)for(const id of blocked){const observer=call(p,'creature',id);if(observer)call(p,'removeVisibility',observer,creature.id);}
 return 1;
}
