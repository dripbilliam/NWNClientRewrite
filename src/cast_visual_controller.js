// Native client controller98b0a0/98b130/98b450/98b9f0/98baa0/98bb50.
// Model allocation, attachment, playback and sound are lower services. These
// owners never select a spell by name or duplicate authored spell effects.
const text=value=>String(value??'').split('\0')[0];
export function createCastVisualController(){return{conjure:[null,null,null],cast:[null,null,null],conjureTime:0,castTime:0,released:0,done:[0,0,0]};}
export function clearCastVisuals(state,group,p){
 for(let i=0;i<3;i++)if(state[group][i]){
  p.attach(state[group][i],null,null,0);
  // Native reloads the slot after the virtual detach call.
  if(state[group][i])p.destroy(state[group][i]);state[group][i]=null;
 }
}
export function castVisualDoneFade(model,state){
 if(state)for(let i=0;i<3;i++)if(model===state.conjure[i])state.done[i]=1;
}
export function releaseCastVisuals(state,refs,source,p){
 for(let i=0;i<3;i++)if(text(refs[i])){
  const model=p.create(text(refs[i]),i===2?'castgroundvisual':'castvisual');state.cast[i]=model;
  if(model){p.attach(model,p.sourceModel(source,255,1),['headconjure','handconjure','root'][i],0);p.play(state.cast[i],'cast01',1,1,0);}
 }
 for(const i of [1,0,2])if(state.conjure[i])p.play(state.conjure[i],'fade',1,1,0);
 return 1;
}
export function startConjureVisuals(state,refs,sounds,source,p){
 for(let i=0;i<3;i++)if(text(refs[i])){
  const model=p.create(text(refs[i]),i===2?'conjuregroundvisual':'conjurevisual');state.conjure[i]=model;
  if(model){
   state.done[i]=0;p.listen(model,'donefade',castVisualDoneFade,state);
   p.attach(model,p.sourceModel(source,255,1),['headconjure','handconjure','root'][i],0);p.play(state.conjure[i],'conjure01',1,0,0);
  }
 }
 const position=[0,0,0],quaternion=[1,0,0,0],model=p.sourceModel(source,255,1);
 if(!model||p.nodePose(model,'handconjure',position,quaternion)===0)position.splice(0,3,...source.position);
 for(const sound of sounds)if(text(sound))p.oneShot(text(sound),[...position],11,1.5);
 return 1;
}
export function updateCastVisualController(state,elapsed,p){
 for(let i=0;i<3;i++)if(state.done[i]!==0&&state.conjure[i]){
  p.attach(state.conjure[i],null,null,0);if(state.conjure[i])p.destroy(state.conjure[i]);state.conjure[i]=null;
 }
 elapsed>>>=0;
 if(state.released!==0){
  const first=state.conjureTime>>>0;
  if(first!==0){if(first<=elapsed){clearCastVisuals(state,'conjure',p);state.conjureTime=0;return;}state.conjureTime=(first-elapsed)>>>0;return;}
  if((state.castTime>>>0)===0){state.released=0;return;}
  const second=state.castTime>>>0;
  if(second<=elapsed){clearCastVisuals(state,'cast',p);state.castTime=0;state.released=0;return;}state.castTime=(second-elapsed)>>>0;
 }
}

// Creature driver8018d0. Input is a CLIENT field view, not a server creature.
// Original spell ID36c, previous-casting368 and sound-suppression374 are kept
// separately from the authoritative actor. Animation is narrowed to SHORT.
export function driveCastVisualController(actor,elapsed,p){
 const state=actor.visuals,animation=(actor.animation<<16)>>16,casting=((animation-15)&65535)<6||animation===61||((animation-250)&65535)<4||animation===261;
 const release=((animation-17)&65535)<4||animation===61||((animation-250)&65535)<4||animation===261;
 const spell=casting?p.spell(actor.spellId|0):null;
 if(release){if(actor.previousCasting===0){state.conjureTime=state.castTime=5000;state.released=0;actor.previousCasting=1;}actor.suppressSound=0;}
 if(casting){
  if(actor.previousCasting===0&&spell){
   const sounds=['',''];if(actor.suppressSound===0){if(actor.race>=0&&actor.race<=6)sounds[0]=actor.gender===1?spell.conjureSoundFemale:spell.conjureSoundMale;sounds[1]=spell.conjureSound;}
   clearCastVisuals(state,'conjure',p);clearCastVisuals(state,'cast',p);
   startConjureVisuals(state,spell.conjure,sounds,actor.source,p);state.conjureTime=state.castTime=5000;state.released=0;
  }
 }else if(actor.previousCasting===1){
  if(state.released===0){clearCastVisuals(state,'conjure',p);clearCastVisuals(state,'cast',p);}actor.spellId=-1;actor.suppressSound=0;
 }
 updateCastVisualController(state,elapsed,p);actor.previousCasting=Number(casting);
}
