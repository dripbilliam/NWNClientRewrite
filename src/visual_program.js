const f=Math.fround,call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native visual program provider ${name} is unavailable`);return p[name](...args);};
// Complete LoadProgram14096c8e0..14096ccb0. Only resource resolution yields;
// both runners retain the original query, store, callback and result order.
function* loadSteps(e,id,p){
 id&=65535;const type=call(p,'programType',e,id)&255;
 if(type===4){
  const object=call(p,'clientObject',e.target54),render=object?call(p,'renderObject',object):null;
  if(render){const name=String(call(p,'programString',id,'param7').value);e.proceduralB8=yield()=>call(p,'loadModel',name,'fx_light',0);}
  return e.proceduralB8?1:0;
 }
 if(type===7||type===12){
  const name=String(call(p,'programString',id,type===7?'param1':'param2').value);
  e.proceduralB8=yield()=>call(p,'loadModel',name,type===7?'fxbeam':'fxfail',0);
  const loaded=e.proceduralB8;if(!loaded)return 0;if(type===7)call(p,'modelSetting1a0',loaded,3);return 1;
 }
 if(type===5)e.field104=f(call(p,'programFloat',id,'param1').value);
 return 1;
}
export function loadVisualProgram(e,id,p){
 const steps=loadSteps(e,id,p);let step=steps.next();
 while(!step.done){const result=step.value();if(result&&typeof result.then==='function')throw new Error('Async visual model provider requires loadVisualProgramAsync');step=steps.next(result);}return step.value;
}
export async function loadVisualProgramAsync(e,id,p){
 const steps=loadSteps(e,id,p);let step=steps.next();while(!step.done)step=steps.next(await step.value());return step.value;
}
// Complete clear140971960..1409719bf. Read B8 after EACH callback.
export function clearVisualProgram(e,p){
 if(!e.proceduralB8)return;
 call(p,'setParent',e.proceduralB8,0,0,0);call(p,'setScene',e.proceduralB8,0);
 if(e.proceduralB8)call(p,'destroyModel',e.proceduralB8,1);e.proceduralB8=null;
}
// Complete program update dispatcher140972090..1409720db, with verified
// direct tail to1409720e0 for Type6. Type4 has no work in this dispatcher.
export function updateVisualProgram(e,id,delta,p){
 const type=call(p,'programType',e,id&65535)&255;delta>>>=0;
 if(type===5)call(p,'update140971e10',e,delta);else if(type===6)call(p,'update1409720e0',e,delta);
}
// Complete resource cleanup1409719c0..140971a76. Physical aliases are NOT
// deduplicated by the original owner. Outer destruction owns controller maps.
export function cleanupVisualModels(e,p){
 clearVisualProgram(e,p);
 for(let i=0;i<3;i++){
  if(e.models88[i]){call(p,'destroyModel',e.models88[i],1);e.models88[i]=null;}
  if(e.extraModelsA0[i]){call(p,'destroyModel',e.extraModelsA0[i],1);e.extraModelsA0[i]=null;}
 }
}
