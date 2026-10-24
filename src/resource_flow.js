// Continue immediately while providers are ready; preserve asynchronous errors
// and ordering when a resource provider still needs IO. One algorithm owns both.
export function resourceFlow(iterator){
 const advance=(value,failed=false)=>{
  for(;;){const step=failed?iterator.throw(value):iterator.next(value);if(step.done)return step.value;
   const next=step.value;if(next&&typeof next.then==='function')return Promise.resolve(next).then(value=>advance(value),error=>advance(error,true));value=next;failed=false;
  }
 };return advance();
}
