const f=Math.fround,call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native emitter target provider ${n} is unavailable`);return p[n](...args);};
// Full SetEmitterTarget1400643c0..140064596. FIRST DIRECT physical reference
// child wins; names, descendant searches and nearest-object guesses do not.
export function setEmitterTarget(e,p){
 const children=call(p,'children',e);
 for(let i=0;i<children.length;i++){
  const child=children[i];if(!call(p,'referenceView',child))continue;
  e.target1c0=call(p,'referenceView',child).model68;
  const position=call(p,'globalPosition',e),target=call(p,'targetPosition',e.target1c0),difference=target.map((v,i)=>f(f(v)-f(position[i]))),[x,y,z]=difference;
  e.targetDistance20c=f(Math.sqrt(f(f(f(x*x)+f(y*y))+f(z*z))));
  if(!call(p,'lightningView',e))return;
  const direction=call(p,'targetPosition',e.target1c0).map((v,i)=>f(f(v)-f(e.position1e0[i])));
  call(p,'lightningView',e).lightningPreviousDirection=direction;
  call(p,'lightningView',e).lightningPreviousPosition=e.position1e0.map(f);return;
 }
 call(p,'removeListener',e.source50,e.targetListener128);
}
// Lightning Initialize061d30: base owner first; native lifetime1, callback
// registration and WORD age mode0 are explicit, not authored spell overrides.
export function initializeLightningEmitter(e,p){
 call(p,'baseInitialize',e);e.lifeExp=1;e.targetListener128=call(p,'listen',e.source50,setEmitterTarget,'_EmitterTarget',e);e.ageMode1cc=0;
}
