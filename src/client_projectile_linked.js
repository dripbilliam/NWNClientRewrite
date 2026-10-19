const f=Math.fround,call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native linked projectile provider ${n} is unavailable`);return p[n](...args);};

// Kind7 branch of initialize987f10. A missing target may produce a separate
// endpoint CAurObject; an existing target without a model is not replaced.
export function initializeLinkedClientProjectile(state,p){
 state.velocity=[0,0,0];state.acceleration=[0,0,0];
 const model=call(p,'model',state,255,1);if(!model||!call(p,'clientArray'))return;
 const found=call(p,'getObject',state.targetId>>>0);
 if(found.status===0){
  if(call(p,'model',found.object,255,1)){
   const second=call(p,'model',found.object,255,1),point=[0,0,0],quaternion=[1,0,0,0],name=state.impactNode??'';
   const exists=call(p,'nodePose',second,name,point,quaternion);
   call(p,'reattach',model,call(p,'model',found.object,255,1),exists?name:'root');
  }
 }else{
  const endpoint=call(p,'createAuxiliary',state,'ref','dummytarget',null);state.auxiliaryModel=endpoint;
  if(endpoint){call(p,'setModelPosition',endpoint,state.node.point.map(f));call(p,'reattach',model,endpoint,'root');}
 }
}

// Kind12 graph tail of initialize987f10, after the independently ported RNG
// math. Model P/Q and scene are separate from projectile position38/forward44.
export function linkRandomClientProjectile(state,p){
 const endpoint=call(p,'createAuxiliary',state,'ref','',null);state.auxiliaryModel=endpoint;
 if(endpoint){
  const model=call(p,'model',state,255,1),point=call(p,'modelPosition',model).map(f);
  call(p,'setModelPosition',endpoint,point.slice());
  call(p,'setModelPosition',model,[point[0],point[1],f(point[2]+f(.01))]);
  call(p,'setModelOrientation',endpoint,call(p,'modelOrientation',model).slice());
  call(p,'setModelScene',endpoint,call(p,'modelScene',model));call(p,'reattach',model,endpoint,'root');
 }
 return endpoint;
}

// Auxiliary-model portion of projectile destructor9835c0: detach, clear scene,
// delete with flag1, then clear230. The main animation/model handle follows.
export function destroyClientProjectileAuxiliary(state,p){
 if(!state.auxiliaryModel)return;
 call(p,'attachAuxiliary',state.auxiliaryModel,null,null,0);
 call(p,'setModelScene',state.auxiliaryModel,null);
 if(state.auxiliaryModel)call(p,'destroyAuxiliary',state.auxiliaryModel,1);
 state.auxiliaryModel=null;
}
